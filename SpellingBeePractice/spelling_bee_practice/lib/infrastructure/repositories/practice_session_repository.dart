import 'package:spelling_bee_practice/domain/entities/practice_session.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/helpers/db_helper.dart';
import 'package:sqflite/sqflite.dart';

class PracticeSessionRepository {
  static Future<List<PracticeSession>> getAllSessions() async {
    final db = await DBHelper().database;
    try {
      final List<Map<String, dynamic>> maps = await db.query('practice_sessions', where: 'id > 0' // Excluir sesiones fijas
              );
      return List.generate(
          maps.length, (i) => PracticeSession.fromMap(maps[i]));
    } catch (e) {
      print("Error getting all sessions: $e");
      rethrow;
    }
  }

  static Future<void> insertSession(PracticeSession session) async {
    final db = await DBHelper().database;
    try {
      await db.insert('practice_sessions', session.toMap());
    } catch (e) {
      print("Error inserting session: $e");
      rethrow;
    }
  }

  static Future<List<PracticeSession>> getFixedSessions() async {
    final db = await DBHelper().database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
          'practice_sessions',
          where: 'id < 0' // Obtener solo sesiones fijas.
      );

        // Usamos map, en lugar de List.generate
      return maps.map((map) {
        PracticeSession session = PracticeSession.fromMap(map); // Crea la sesión
        session.isFixed = true; // Establece isFixed a true *aquí*.
        return session;
      }).toList();

    } catch (e) {
      print("Error getting fixed sessions: $e");
      rethrow;
    }
  }

  static Future<void> addWordToSession(
      Word word, PracticeSession session) async {
    //No permitir añadir a sesiones fijas
    if (session.id! < 0) return;

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
      print("Error adding word to session: $e");
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
      } else if (session.id == -2) {
        // No Practicadas
        // Obtener todas las palabras
        final List<Map<String, dynamic>> allWordsMap =
            await db.query(DBHelper().tableWords);
        final List<Word> allWords =
            allWordsMap.map((map) => Word.fromMap(map)).toList();

        // Obtener todas las palabras practicadas (en cualquier tipo de sesión)
        final List<Map<String, dynamic>> practicedWordsMap = await db.query(
            'practice_history',
            columns: ['word_id'],
            distinct: true); //Usamos distinct
        final List<int> practicedWordIds =
            practicedWordsMap.map((map) => map['word_id'] as int).toList();

        // Filtrar para obtener solo las palabras NO practicadas
        final List<Word> neverPracticedWords = allWords
            .where((word) => !practicedWordIds.contains(word.id))
            .toList();
        return neverPracticedWords;
      } else if (session.id == -3) {
        // Todas
        final List<Map<String, dynamic>> maps = await db.query(
          DBHelper().tableWords,
          orderBy:
              'correct_count + incorrect_count ASC', // Menos practicadas primero
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
      print("Error loading session words: $e");
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
      print("Error deleting session: $e");
      rethrow;
    }
  }

  static Future<void> removeWordFromSession(
      Word word, PracticeSession session) async {
    //No permitir quitar palabras de sesiones fijas
    if (session.id! < 0) return;

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
      print("Error removing word from session: $e");
      rethrow;
    }
  }

  static Future<void> createFixedSessions() async {
    final db = await DBHelper().database;
    await db.insert(
        'practice_sessions',
        {
          'id': -1, // ID negativo para "Errores"
          'name': 'Errores',
          'created_at': DateTime.now().toIso8601String(),
          'word_ids': '', 
          'isFixed': false,
        },
        conflictAlgorithm:
            ConflictAlgorithm.ignore); //Evita errores si ya existe

    await db.insert(
        'practice_sessions',
        {
          'id': -2, // ID negativo para "Todas"
          'name': 'Todas',
          'created_at': DateTime.now().toIso8601String(),
          'word_ids': '',
          'isFixed': false,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<int> getLastIdFixedSessions() async {
    final db = await DBHelper().database;
    final List<Map<String, dynamic>> result = await db.rawQuery('SELECT last_insert_rowid()');
    int newId = result[0]['last_insert_rowid()'] as int;
      return newId;
  }
}
