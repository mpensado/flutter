import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spelling_bee_practice/domain/entities/practice_history.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/domain/entities/practice_session.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/practice_session_repository.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/word_repository.dart';

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

// Estados
abstract class PracticeState {}

class PracticeInitial extends PracticeState {}

class PracticeLoading extends PracticeState {}

class PracticeLoaded extends PracticeState {
  final List<Word> words;

  PracticeLoaded(this.words);
}

class PracticeError extends PracticeState {
  final String message;

  PracticeError(this.message);
}

// BLoC
class PracticeBloc extends Bloc<PracticeEvent, PracticeState> {
  // final PracticeSessionRepository _practiceSessionRepository =
  //     PracticeSessionRepository();
  // final WordRepository _wordRepository = WordRepository();
  List<Word> currentWords = [];

  PracticeBloc() : super(PracticeInitial()) {
    on<LoadWordsEvent>(_onLoadWords);
    on<RecordPracticeEvent>(_onRecordPractice);
    on<RemoveWordEvent>(_onRemoveWord);
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
      emit(PracticeLoaded(currentWords));
    } catch (e) {
      emit(PracticeError("Error al cargar palabras: $e"));
    }
  }

  Future<void> _onRecordPractice(
      RecordPracticeEvent event, Emitter<PracticeState> emit) async {
    try {
      final history = PracticeHistory( // Construye el objeto PracticeHistory
        wordId: event.word.id!,
        sessionId: event.session?.id ?? -1, // Usa -1 si no hay sesión
        isCorrect: event.isCorrect,
        practicedAt: DateTime.now(),
        sessionType: event.session != null ? "custom" : "list",
      );
      if (event.session != null) {
        await PracticeSessionRepository.insertHistory(history);
      } else {
        await PracticeSessionRepository.insertHistory(history);
      }
      await WordRepository.updateWordCounters(event.word.id!, event.isCorrect);
      // Obtener la palabra actualizada de la base de datos
    final updatedWord = await WordRepository.getWordById(event.word.id!);

    // Emitir un nuevo estado PracticeLoaded si el estado actual es PracticeLoaded
    if (state is PracticeLoaded) {
      final loadedState = state as PracticeLoaded;
      List<Word> updatedWords = loadedState.words.map((word) {
        if (word.id == event.word.id) {
          // Devuelve la palabra actualizada
          return updatedWord!;
        }
        return word;
      }).toList();

      emit(PracticeLoaded(updatedWords));
      }
    } catch (e) {
      emit(PracticeError("Error al registrar práctica: $e"));
    }
  }

  Future<void> _onRemoveWord(
      RemoveWordEvent event, Emitter<PracticeState> emit) async {
    try {
      final session = PracticeSession( // Crea el objeto PracticeSession
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
      await PracticeSessionRepository.removeWordFromSession(word, session);
      currentWords.remove(event.word);
      emit(PracticeLoaded(currentWords)); // Actualizar la UI
    } catch (e) {
      emit(PracticeError("Error al eliminar palabra: $e"));
    }
  }
}