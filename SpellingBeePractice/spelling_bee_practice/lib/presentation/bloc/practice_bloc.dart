import 'package:bloc/bloc.dart';
import 'package:spelling_bee_practice/domain/entities/practice_history.dart';
import 'package:spelling_bee_practice/domain/entities/word_practice.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/practice_session_repository.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/word_repository.dart';
import 'package:spelling_bee_practice/presentation/bloc/practice_event.dart';
import 'package:spelling_bee_practice/presentation/bloc/practice_state.dart';

class PracticeBloc extends Bloc<PracticeEvent, PracticeState> {
  PracticeBloc() : super(PracticeInitial()) {
    on<LoadWordsEvent>(_onLoadWordsEvent);
    on<ChangeFilterEvent>(_onChangeFilterEvent);
    on<RecordPracticeEvent>(_onRecordPracticeEvent);
    on<RemoveWordEvent>(_onRemoveWordEvent);
  }

  Future<void> _onLoadWordsEvent(
        LoadWordsEvent event, Emitter<PracticeState> emit) async {
      emit(PracticeLoading());
      try {
        String filter = 'Todo'; // O el filtro predeterminado que prefieras
        if (event.selectedSession != null) {
          filter = event.selectedSession!.name;
        }
        List<WordPractice> filteredWords = await WordRepository.getWordsPracticeByLists([filter]);
        List<String> lists =
            await WordRepository.getAllLists(); // Obtener la lista de listas
        emit(PracticeLoaded(
            words: filteredWords, lists: lists, filter: filter));
      } catch (e) {
        emit(PracticeError(message: e.toString()));
      }
    }

    Future<void> _onChangeFilterEvent(
        ChangeFilterEvent event, Emitter<PracticeState> emit) async {
      try {
        List<WordPractice> filteredWords = await WordRepository.getWordsPracticeByLists([event.filter]);
        List<String> lists = await WordRepository.getAllLists(); // Obtener la lista de listas
        emit(PracticeLoaded(
            words: filteredWords, lists: lists, filter: event.filter));
      } catch (e) {
        emit(PracticeError(message: e.toString()));
      }
    }

    Future<void> _onRecordPracticeEvent(RecordPracticeEvent event, Emitter<PracticeState> emit) async {
      final currentState = state as PracticeLoaded;
    try {
      final history = PracticeHistory( // Construye el objeto PracticeHistory
        wordId: event.word.id!,
        sessionId: event.session?.id ?? -1, // Usa -1 si no hay sesión
        isCorrect: event.isCorrect,
        practicedAt: DateTime.now(),
        sessionType: event.session != null ? "custom" : "list", 
        correctCount: 0, 
        incorrectCount: 0,
        totalIncorrectCount: 0,
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
        List<WordPractice> updatedWords = loadedState.words.map((word) {
          if (word.id == event.word.id) {
            // Devuelve la palabra actualizada
            return updatedWord!;
          }
          return word;
        }).toList();

        emit(PracticeLoaded(words: updatedWords, lists: loadedState.lists, filter: currentState.filter));
      }
    } catch (e) {
      emit(PracticeError(message: e.toString()));
    }
  }

    Future<void> _onRemoveWordEvent(
        RemoveWordEvent event, Emitter<PracticeState> emit) async {
      // ... (tu código existente para eliminar la palabra)
      final currentState = state as PracticeLoaded;
      try {
        List<WordPractice> filteredWords = await WordRepository.getWordsPracticeByLists([currentState.filter]);
        List<String> lists = await WordRepository.getAllLists(); // Obtener la lista de listas
        emit(PracticeLoaded(words: filteredWords, lists: lists, filter: currentState.filter));
      } catch (e) {
        emit(PracticeError(message: e.toString()));
      }
    }
  }
