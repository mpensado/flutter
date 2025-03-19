import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/domain/entities/practice_session.dart';
import 'package:spelling_bee_practice/domain/entities/practice_history.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/practice_session_repository.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/word_repository.dart';

enum PracticeFilter { all, errors, list }

// Eventos
abstract class PracticeEvent {}

class LoadWordsEvent extends PracticeEvent {
  final PracticeSession? session;

  LoadWordsEvent(this.session);
}

class RecordPracticeEvent extends PracticeEvent {
  final Word word;
  final bool isCorrect;
  final PracticeSession? session;

  RecordPracticeEvent(this.word, this.isCorrect, this.session);
}

class RemoveWordEvent extends PracticeEvent {
  final Word word;
  final PracticeSession session;

  RemoveWordEvent(this.word, this.session);
}

class ChangeFilterEvent extends PracticeEvent {
  final String filter;

  ChangeFilterEvent(this.filter);
}

// Estados
abstract class PracticeState {}

class PracticeInitial extends PracticeState {}

class PracticeLoading extends PracticeState {}

class PracticeLoaded extends PracticeState {
  final List<Word> words;
  final String filter;
  final List<String> lists;
  final List<Word> originalWords; // Nueva propiedad: Lista original

  PracticeLoaded(this.words,
      {this.filter = 'Todo', required this.lists, required this.originalWords});

  PracticeLoaded copyWith({
    List<Word>? words,
    String? filter,
    List<String>? lists,
    List<Word>? originalWords,
  }) {
    return PracticeLoaded(
      words ?? this.words,
      filter: filter ?? this.filter,
      lists: lists ?? this.lists,
      originalWords: originalWords ?? this.originalWords,
    );
  }
}

class PracticeError extends PracticeState {
  final String message;

  PracticeError(this.message);
}

// BLoC
class PracticeBloc extends Bloc<PracticeEvent, PracticeState> {
  final WordRepository _wordRepository = WordRepository();
  List<Word> currentWords = [];

  PracticeBloc() : super(PracticeInitial()) {
    on<LoadWordsEvent>(_onLoadWords);
    on<RecordPracticeEvent>(_onRecordPractice);
    on<RemoveWordEvent>(_onRemoveWord);
    on<ChangeFilterEvent>(_onChangeFilter);
  }

  Future<void> _onLoadWords(
      LoadWordsEvent event, Emitter<PracticeState> emit) async {
    emit(PracticeLoading());
    try {
      if (event.session != null) {
        currentWords =
            await PracticeSessionRepository.loadSessionWords(event.session!);
      } else {
        final selectedLists = await WordRepository.getSelectedLists() ?? [];
        if (selectedLists.isNotEmpty) {
          currentWords =
              await WordRepository.getWordsByLists(selectedLists);
        } else {
          currentWords = await WordRepository.getAllWords();
        }
      }

      final lists = await WordRepository.getAllLists();

      if (state is PracticeLoaded) {
        final loadedState = state as PracticeLoaded;
        final filteredWords = _filterWords(currentWords, loadedState.filter);
        emit(PracticeLoaded(filteredWords,
            filter: loadedState.filter,
            lists: lists,
            originalWords: currentWords));
      } else {
        emit(PracticeLoaded(currentWords, lists: lists, originalWords: currentWords));
      }
    } catch (e) {
      emit(PracticeError("Error al cargar palabras: $e"));
    }
  }

  Future<void> _onRecordPractice(
      RecordPracticeEvent event, Emitter<PracticeState> emit) async {
    try {
      final history = PracticeHistory(
        wordId: event.word.id!,
        sessionId: event.session?.id ?? -1,
        isCorrect: event.isCorrect,
        practicedAt: DateTime.now(),
        sessionType: event.session != null ? "custom" : "list",
      );

      await PracticeSessionRepository.insertHistory(history);
      await WordRepository.updateWordCounters(event.word.id!, event.isCorrect);

      final updatedWord = await WordRepository.getWordById(event.word.id!);

      if (state is PracticeLoaded) {
        final loadedState = state as PracticeLoaded;
        List<Word> updatedWords = loadedState.words.map((word) {
          if (word.id == event.word.id) {
            return updatedWord!;
          }
          return word;
        }).toList();

        final filteredWords = _filterWords(updatedWords, loadedState.filter);

        emit(PracticeLoaded(filteredWords,
            filter: loadedState.filter,
            lists: loadedState.lists,
            originalWords: loadedState.originalWords));
      }
    } catch (e) {
      emit(PracticeError("Error al registrar práctica: $e"));
    }
  }

  Future<void> _onRemoveWord(
      RemoveWordEvent event, Emitter<PracticeState> emit) async {
    try {
      final session = PracticeSession(
        id: event.session.id,
        name: event.session.name,
        wordIds: event.session.wordIds,
        isFixed: event.session.isFixed, createdAt: DateTime.now(),
      );
      
      final word = Word( // Crea el objeto PracticeSession
        id: event.word.id,
        categoryId: event.word.categoryId,
        correctCount: event.word.correctCount,
        createdAt: event.word.createdAt, 
        incorrectCount: event.word.incorrectCount,
        totalIncorrectCount: event.word.totalIncorrectCount, 
        word: event.word.word, 
        translation: event.word.translation, 
        spelling: event.word.spelling,
      );

      await PracticeSessionRepository.removeWordFromSession(
          word, session);

      currentWords.remove(event.word);

      if (state is PracticeLoaded) {
        final loadedState = state as PracticeLoaded;
        final filteredWords = _filterWords(currentWords, loadedState.filter);

        emit(PracticeLoaded(filteredWords,
            filter: loadedState.filter,
            lists: loadedState.lists,
            originalWords: currentWords));
      }
    } catch (e) {
      emit(PracticeError("Error al eliminar palabra: $e"));
    }
  }

  Future<void> _onChangeFilter(
      ChangeFilterEvent event, Emitter<PracticeState> emit) async {
    if (state is PracticeLoaded) {
      final loadedState = state as PracticeLoaded;
      final filteredWords = _filterWords(loadedState.originalWords, event.filter);
      emit(PracticeLoaded(filteredWords,
          filter: event.filter,
          lists: loadedState.lists,
          originalWords: loadedState.originalWords));
    }
  }

  List<Word> _filterWords(List<Word> words, String filter) {
    if (filter == 'Por practicar') {
      return words
          .where((word) => word.totalIncorrectCount > 0)
          .toList()
        ..sort((a, b) => b.totalIncorrectCount.compareTo(a.totalIncorrectCount));
    } else if (filter != 'Todo' && filter != 'Por practicar') {
      return words.where((word) => word.lists.contains(filter)).toList();
    }
    return words;
  }
}