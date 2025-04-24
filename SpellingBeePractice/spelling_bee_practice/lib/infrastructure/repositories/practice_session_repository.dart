import 'package:flutter/foundation.dart';
import 'package:spelling_bee_practice/domain/entities/practice_history.dart';
import 'package:spelling_bee_practice/domain/entities/practice_session.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/helpers/db_helper.dart';
import 'package:sqflite/sqflite.dart';

class PracticeSessionRepository {
  static Future<List<PracticeSession>> getAllSessions() async {
    final db = await DBHelper().database;
    try {
      final List<Map<String, dynamic>> maps = await db.query('practice_sessions',
          where:
              'id > 0' // Excluir sesiones fijas
          );
      return List.generate(
          maps.length, (i) => PracticeSession.fromMap(maps[i]));
    } catch (e) {
      debugPrint("[MI_LOG]Error getting all sessions: $e");
      rethrow;
    }
  }

  static Future<void> insertSession(PracticeSession session) async {
    final db = await DBHelper().database;
    try {
      await db.insert('practice_sessions', session.toMap());
    } catch (e) {
      debugPrint("[MI_LOG]Error inserting session: $e");
      rethrow;
    }
  }

  static Future<List<PracticeSession>> getFixedSessions() async {
    final db = await DBHelper().database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'practice_sessions',
        where: 'id < 0', // Obtener solo sesiones fijas.
      );

      // Simplificado ahora que isFixed se guarda correctamente.
      return List.generate(maps.length, (i) => PracticeSession.fromMap(maps[i]));

    } catch (e) {
      debugPrint("[MI_LOG]Error getting fixed sessions: $e");
      rethrow;
    }
  }


  static Future<void> addWordToSession(
      Word word, PracticeSession session) async {
    //No permitir añadir a sesiones fijas
    if (session.id < 0) return;

    final db = await DBHelper().database;
    try {
      final List<Map<String, dynamic>> sessionMap = await db.query(
        'practice_sessions',
        where: 'id = ?',
        whereArgs: [session.id],
      );
      if (sessionMap.isEmpty) {
        return;
      }
      final PracticeSession currentSession =
          PracticeSession.fromMap(sessionMap.first);
      List<int> wordIdList = currentSession.wordIds;

      if (!wordIdList.contains(word.id)) {
        wordIdList.add(word.id!);
        final updatedWordIdsString =
            wordIdList.map((id) => id.toString()).join(',');

        await db.update(
          'practice_sessions',
          {'word_ids': updatedWordIdsString},
          where: 'id = ?',
          whereArgs: [session.id],
        );
      }
    } catch (e) {
      debugPrint("[MI_LOG]Error adding word to session: $e");
      rethrow;
    }
  }

  static Future<List<Word>> loadSessionWords(PracticeSession session) async {
    final db = await DBHelper().database;
    try {
      if (session.id == -1) {
        // Errores
        final List<Map<String, dynamic>> maps = await db.query(
          DBHelper().tableWords,
          where: 'total_incorrect_count > 0', // Solo palabras con errores
          orderBy:
              'total_incorrect_count DESC', // Ordenar por errores (descendente)
        );
        return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
      }  else if (session.id == -2) {
        // Todas  --  ¡¡¡CAMBIO AQUÍ!!!
        final List<Map<String, dynamic>> maps = await db.query(
          DBHelper().tableWords,
          orderBy:
              'total_incorrect_count DESC', // Ordenar por total_incorrect_count (descendente)
        );
        return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
      } else {
        // Sesiones normales (IDs positivos)
        if (session.wordIds.isEmpty) {
          return [];
        }
        final List<Map<String, dynamic>> maps = await db.query(
          DBHelper().tableWords,
          where: 'id IN (${session.wordIds.map((_) => '?').join(',')})',
          whereArgs: session.wordIds,
        );
        return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
      }
    } catch (e) {
      debugPrint("[MI_LOG]Error loading session words: $e");
      rethrow;
    }
  }

    static Future<void> insertHistory(PracticeHistory history) async {
    final db = await DBHelper().database;
    try {
      await db.delete('practice_history',
          where: 'word_id = ? AND list_name = ? AND session_type = ?',
          whereArgs: [history.wordId, history.listName, history.sessionType]);

      await db.insert('practice_history', {
        'word_id': history.wordId,
        'session_id': history.sessionId,
        'practiced_at': DateTime.now().toIso8601String(),
        'correct_count': history.correctCount,
        'incorrect_count': history.incorrectCount,
        'total_incorrect_count': history.totalIncorrectCount,
        'session_type': history.sessionType,
        'list_name': history.listName
      });
    } catch (e) {
      debugPrint("[MI_LOG]Error inserting practice history: $e");
      rethrow;
    }
  }

  static Future<void> deleteSession(int sessionId) async {
    //No se pueden borrar las sesiones fijas
    if (sessionId < 0) return;
    final db = await DBHelper().database;
    try {
      await db.delete(
        'practice_sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    } catch (e) {
      debugPrint("[MI_LOG]Error deleting session: $e");
      rethrow;
    }
  }

  static Future<void> removeWordFromSession(
      Word word, PracticeSession session) async {
    //No permitir quitar palabras de sesiones fijas
    if (session.id < 0) return;

    final db = await DBHelper().database;
    try {
      final List<Map<String, dynamic>> sessionMap = await db.query(
        'practice_sessions',
        where: 'id = ?',
        whereArgs: [session.id],
      );
      if (sessionMap.isEmpty) {
        return;
      }

      final PracticeSession currentSession =
          PracticeSession.fromMap(sessionMap.first);
      List<int> wordIdList = currentSession.wordIds;

      if (wordIdList.contains(word.id)) {
        wordIdList.remove(word.id); // Remove the word ID
        final updatedWordIdsString =
            wordIdList.map((id) => id.toString()).join(',');

        await db.update('practice_sessions', {'word_ids': updatedWordIdsString},
            where: 'id = ?', whereArgs: [session.id]);
      }
    } catch (e) {
      debugPrint("[MI_LOG]Error removing word from session: $e");
      rethrow;
    }
  }

  static Future<void> createFixedSessions() async {
    final db = await DBHelper().database;
    await db.insert(
        'practice_sessions',
        {
          'id': -1, // ID negativo para "Errores"
          'name': 'Por practicar',
          'created_at': DateTime.now().toIso8601String(),
          'word_ids': '',
          'isFixed': 1, //  CORREGIDO: Ahora es true (1 en SQLite)
        },
        conflictAlgorithm:
            ConflictAlgorithm.ignore); //Evita errores si ya existe

        await db.insert(
        'practice_sessions',
        {
          'id': -2, // ID negativo para "Todas"
          'name': 'Todo',
          'created_at': DateTime.now().toIso8601String(),
          'word_ids': '',
          'isFixed': 1, // CORREGIDO: Ahora es true (1 en SQLite)
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<int> getLastIdFixedSessions() async {
    final db = await DBHelper().database;
    final List<Map<String, dynamic>> result =
        await db.rawQuery('SELECT last_insert_rowid()');
    int newId = result[0]['last_insert_rowid()'] as int;
    return newId;
  }
}