import 'package:bloc/bloc.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
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
        List<Word> filteredWords = await WordRepository.getFilteredWords(filter);
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
        List<Word> filteredWords =
            await WordRepository.getFilteredWords(event.filter);
        List<String> lists =
            await WordRepository.getAllLists(); // Obtener la lista de listas
        emit(PracticeLoaded(
            words: filteredWords, lists: lists, filter: event.filter));
      } catch (e) {
        emit(PracticeError(message: e.toString()));
      }
    }

    Future<void> _onRecordPracticeEvent(
        RecordPracticeEvent event, Emitter<PracticeState> emit) async {
      // ... (tu código existente para actualizar la base de datos)
      final currentState = state as PracticeLoaded;
      try {
        List<Word> filteredWords =
            await WordRepository.getFilteredWords(currentState.filter);
        List<String> lists =
            await WordRepository.getAllLists(); // Obtener la lista de listas
        emit(PracticeLoaded(
            words: filteredWords, lists: lists, filter: currentState.filter));
      } catch (e) {
        emit(PracticeError(message: e.toString()));
      }
    }

    Future<void> _onRemoveWordEvent(
        RemoveWordEvent event, Emitter<PracticeState> emit) async {
      // ... (tu código existente para eliminar la palabra)
      final currentState = state as PracticeLoaded;
      try {
        List<Word> filteredWords =
            await WordRepository.getFilteredWords(currentState.filter);
        List<String> lists =
            await WordRepository.getAllLists(); // Obtener la lista de listas
        emit(PracticeLoaded(
            words: filteredWords, lists: lists, filter: currentState.filter));
      } catch (e) {
        emit(PracticeError(message: e.toString()));
      }
    }
  }
