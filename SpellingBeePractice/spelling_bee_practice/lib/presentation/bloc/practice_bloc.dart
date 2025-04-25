import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:spelling_bee_practice/domain/entities/practice_history.dart';
import 'package:spelling_bee_practice/domain/entities/word_practice.dart';
import 'package:spelling_bee_practice/helpers/db_helper.dart';
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
        listName: event.listName,
      );

      await PracticeSessionRepository.insertHistory(history);

      await WordRepository.updateWordCounters(event.word.id!, event.isCorrect,event.listName, history.sessionType);

      //
      String whereClause = '';
      List<String> whereArgs = [];
      List<String> lists = [event.listName]; 

      if (lists.isNotEmpty) {
        whereClause = '(${lists.map((_) => '?').join(',')})';
        whereArgs.addAll(lists);
      } else {
        whereClause =
            '1 = 1';
      }
      final db = await DBHelper().database;
      try {
          List<Map<String, dynamic>> tableMap = await db.rawQuery('''
            SELECT
              ph.*
            FROM
              practice_history ph
            ORDER BY
              ph.practiced_at DESC;
          ''');
          if (tableMap.isNotEmpty) {
            debugPrint('[MI_LOG]Contenido practice_history: $tableMap.tostring()');
          }
        } catch (e) {
          debugPrint('[MI_LOG]Error en practice_history: $e');
        }

        try {
            List<Map<String, dynamic>> tableMap = await db.rawQuery('''
            SELECT
              w.*
            FROM
              words w
            WHERE w.id = 3
          ''');
          if (tableMap.isNotEmpty) {
            debugPrint('[MI_LOG]Contenido words: $tableMap.tostring()');
          }
        } catch (e) {
          debugPrint('[MI_LOG]Error en words: $e');
        }

        try {
            List<Map<String, dynamic>> tableMap = await db.rawQuery('''
            SELECT
              wl.*
            FROM
              word_lists wl
            WHERE wl.word_id = 3
          ''');
          if (tableMap.isNotEmpty) {
            debugPrint('[MI_LOG]Contenido word_lists: $tableMap.tostring()');
          }
        } catch (e) {
          debugPrint('[MI_LOG]Error en word_lists: $e');
        }

        try {
            List<Map<String, dynamic>>   tableMap = await db.rawQuery('''
            SELECT
              w.*,
              wl.list_name,
              ph.correct_count,
              ph.incorrect_count,
              ph.total_incorrect_count
            FROM
              words w 
            JOIN 
              word_lists wl ON w.id = wl.word_id AND wl.list_name IN $whereClause
            LEFT JOIN
              practice_history ph ON ph.word_id = wl.word_id AND ph.session_type = 'list' AND ph.list_name = wl.list_name;
            ORDER BY
                ph.practiced_at DESC;
          ''');
          if (tableMap.isNotEmpty) {
            debugPrint('[MI_LOG]Contenido consulta: $tableMap.tostring()');
          }
        } catch (e) {
          debugPrint('[MI_LOG]Error en consulta: $e');
        }
      //

      // Obtener la palabra actualizada de la base de datos
      final updatedWord = await WordRepository.getWordById(event.word.id!, [event.listName]);

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
