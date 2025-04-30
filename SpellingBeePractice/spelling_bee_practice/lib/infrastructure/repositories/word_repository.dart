// Para firstWhereOrNull
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/domain/entities/word_practice.dart';
import 'package:spelling_bee_practice/domain/entities/word_practice_history.dart';
import 'package:spelling_bee_practice/helpers/db_helper.dart';
import 'package:spelling_bee_practice/domain/entities/practice_history.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import SharedPreferences

class WordRepository {
  static const _selectedListsKey =
      'selected_lists'; // Clave para SharedPreferences

  // Obtener una palabra por su texto (para verificar duplicados).
  static Future<Word?> getWordByText(String wordText) async {
    final db = await DBHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      DBHelper().tableWords,
      where: 'word = ?',
      whereArgs: [wordText],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      final List<String> lists = await _getListsForWord(maps.first['id']);
      return Word.fromMap(maps.first, lists: lists); // Usa el helper
    } else {
      return null;
    }
  }

  static Future<WordPractice?> getWordById(
      int? wordId, List<String> lists) async {
    WordPractice? result;

    final db = await DBHelper().database;
    List<Map<String, dynamic>> maps = [];
    try {
      if (lists.contains("Por practicar")) {
        maps = await db.rawQuery('''
        SELECT
            w.*,
            ph.correct_count,
            ph.incorrect_count,
            ph.total_incorrect_count
        FROM
            words w
        JOIN
            word_lists wl ON w.id = wl.word_id
        LEFT JOIN
            practice_history ph ON ph.word_id = w.id AND ph.session_type = 'random'
        WHERE ph.total_incorrect_count > 0
        GROUP BY
            w.id,
            ph.session_type,
            ph.list_name
        ORDER BY
            ph.practiced_at DESC;
      ''');
      } else {
        // Consulta original para otras listas
        String whereClause = '';
        List<String> whereArgs = [];

        if (lists.isNotEmpty) {
          whereClause = '(${lists.map((_) => '?').join(',')})';
          whereArgs.addAll(lists);
        } else {
          whereClause = '1 = 1';
        }

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
            debugPrint(
                '[MI_LOG]Contenido practice_history: $tableMap.tostring()');
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
            WHERE w.id = $wordId
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
            WHERE wl.word_id = $wordId
          ''');
          if (tableMap.isNotEmpty) {
            debugPrint('[MI_LOG]Contenido word_lists: $tableMap.tostring()');
          }
        } catch (e) {
          debugPrint('[MI_LOG]Error en word_lists: $e');
        }

        try {
          List<Map<String, dynamic>> tableMap = await db.rawQuery('''
            SELECT
              w.*,
              wl.list_name,
              ph.correct_count,
              ph.incorrect_count,
              ph.total_incorrect_count
            FROM
              words w 
            JOIN 
              word_lists wl ON w.id = $wordId AND w.id = wl.word_id AND wl.list_name IN $whereClause
            LEFT JOIN
              practice_history ph ON ph.word_id = wl.word_id AND ph.session_type = 'list' AND ph.list_name = wl.list_name;
            ORDER BY
                ph.practiced_at DESC;
          ''', whereArgs);
          if (tableMap.isNotEmpty) {
            debugPrint('[MI_LOG]Contenido consulta: $tableMap.tostring()');
          }
        } catch (e) {
          debugPrint('[MI_LOG]Error en consulta: $e');
        }

        maps = await db.rawQuery('''
          SELECT
            w.*,
            wl.list_name,
            ph.correct_count,
            ph.incorrect_count,
            ph.total_incorrect_count
          FROM
            words w 
          JOIN 
            word_lists wl ON w.id = $wordId AND w.id = wl.word_id AND wl.list_name IN $whereClause
          LEFT JOIN
            practice_history ph ON ph.word_id = wl.word_id AND ph.session_type = 'list' AND ph.list_name = wl.list_name;
          ORDER BY
            ph.practiced_at DESC;
        ''', whereArgs);
      }
    } catch (e) {
      debugPrint('[MI_LOG]$e');
      result = null;
    }

    if (maps.isNotEmpty) {
      final List<String> lists = await _getListsForWord(maps.first['id']);
      result = WordPractice.fromMap(maps.first, lists: lists); // Usa el helper
    } else {
      result = null;
    }

    return result;
  }
  
  // Método auxiliar para obtener las listas de una palabra (privado).
  static Future<List<String>> _getListsForWord(int wordId) async {
    final db = await DBHelper().database;
    final List<Map<String, dynamic>> listMaps = await db.query(
      DBHelper().tableWordLists, // Usa la tabla word_lists
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
    return listMaps.map<String>((map) => map['list_name'] as String).toList();
  }

  static Future<int> insertWord(Word word) async {
    final db = await DBHelper().database;
    // Verificar duplicados PRIMERO.
    final existingWord = await getWordByText(word.word);

    if (existingWord != null) {
      if (!existingWord!.lists.contains("Todo")) {
        existingWord.lists.insert(0, "Todo");
      }

      await updateWord(word.copyWith(id: existingWord.id)); // Copia el ID
      return existingWord.id!;
    } else {
      if (!word.lists.contains("Todo")) {
        word.lists.insert(0, "Todo");
      }
    }

    final wordId = await db.insert(DBHelper().tableWords, word.toMap());

    // Insertar las asociaciones en word_lists.
    for (final listName in word.lists) {
      await db.insert(
        DBHelper().tableWordLists, // Usa la tabla word_lists
        {'word_id': wordId, 'list_name': listName},
      );
    }
    return wordId;
  }

  static Future<int> updateWord(Word word) async {
    final db = await DBHelper().database;

    if (!word.lists.contains("Todo")) {
      word.lists.insert(0, "Todo");
    }

    await db.update(
      DBHelper().tableWords,
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );

    // Actualizar listas:
    // 1. Eliminar antiguas.
    await db.delete(
      DBHelper().tableWordLists, // Usa la tabla word_lists
      where: 'word_id = ?',
      whereArgs: [word.id],
    );
    // 2. Insertar nuevas.
    for (final listName in word.lists) {
      await db.insert(
        DBHelper().tableWordLists, // Usa la tabla word_lists
        {'word_id': word.id, 'list_name': listName},
      );
    }
    return word.id!;
  }

  static Future<int> deleteWord(int id) async {
    final db = await DBHelper().database;
    // ON DELETE CASCADE en la tabla word_lists se encargará de eliminar las asociaciones.
    return await db.delete(
      DBHelper().tableWords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Guardar las listas seleccionadas (NUEVA FUNCIÓN)
  static Future<void> saveSelectedLists(List<String> lists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedListsKey, lists);
  }

  // Obtener las listas seleccionadas (NUEVA FUNCIÓN)
  static Future<List<String>?> getSelectedLists() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_selectedListsKey);
  }

  // Obtener TODAS las palabras, incluyendo sus listas.
  static Future<List<Word>> getAllWords({String? sortOrder}) async {
    final db = await DBHelper().database;
    final orderByClause = _getOrderByClause(sortOrder);
    final List<Map<String, dynamic>> maps =
        await db.query(DBHelper().tableWords, orderBy: orderByClause);
    return await _mapToWords(maps);
  }

  // Obtener las palabras de una lista específica.
  static Future<List<Word>> getWordsByList(String listName,
      {String? sortOrder}) async {
    final db = await DBHelper().database;
    final orderByClause = _getOrderByClause(sortOrder);

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT DISTINCT w.*
        FROM ${DBHelper().tableWords} w
        INNER JOIN ${DBHelper().tableWordLists} wl ON w.id = wl.word_id
        WHERE wl.list_name = ?
        ORDER BY $orderByClause
    ''', [listName]);

    return await _mapToWords(maps);
  }

  static Future<List<Word>> getWordsByIdAndList(int wordId, String listName,
      {String? sortOrder}) async {
    final db = await DBHelper().database;
    final orderByClause = _getOrderByClause(sortOrder);

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT DISTINCT w.*
        FROM ${DBHelper().tableWords} w
        INNER JOIN ${DBHelper().tableWordLists} wl ON w.id = wl.word_id
        WHERE wl.list_name = ? and w.id = ?
        ORDER BY $orderByClause
    ''', [listName, wordId]);

    return await _mapToWords(maps);
  }

  //Obtener palabras por varias listas
  static Future<List<Word>> getWordsByLists(List<String> lists,
      {String? sortOrder}) async {
    final db = await DBHelper().database;
    final orderByClause = _getOrderByClause(sortOrder);
    List<Map<String, dynamic>> maps = [];

    if (lists.contains("Por practicar")) {
      // Modificar la consulta para obtener palabras de la lista "Por practicar"
      maps = await db.rawQuery('''
          SELECT DISTINCT w.*
          FROM ${DBHelper().tableWords} w
          ORDER BY $orderByClause
        ''');
    } else {
      // Consulta original para otras listas
      final placeholders = List.filled(lists.length, '?').join(',');
      final whereClause = 'wl.list_name IN ($placeholders)';

      maps = await db.rawQuery('''
          SELECT DISTINCT w.*
          FROM ${DBHelper().tableWords} w
          INNER JOIN ${DBHelper().tableWordLists} wl ON w.id = wl.word_id
          WHERE $whereClause
          ORDER BY $orderByClause
        ''', lists);
    }

    return await _mapToWords(maps);
  }

  static Future<List<WordPractice>> getWordsPracticeByLists(List<String> lists,
      {String? sortOrder}) async {
    List<WordPractice> result = [];
    final db = await DBHelper().database;
    final orderByClause = _getOrderByClause(sortOrder);
    List<Map<String, dynamic>> maps = [];
    try {
      if (lists.contains("Por practicar")) {
        // Modificar la consulta para obtener palabras de la lista "Por practicar"
        // maps = await db.rawQuery('''
        //     SELECT DISTINCT w.*
        //     FROM ${DBHelper().tableWords} w
        //     WHERE w.total_incorrect_count > 0
        //     ORDER BY $orderByClause
        //   ''');

        maps = await db.rawQuery('''
        SELECT
            w.*,
            ph.correct_count,
            ph.incorrect_count,
            ph.total_incorrect_count
        FROM
            words w
        JOIN
            word_lists wl ON w.id = wl.word_id
        LEFT JOIN
            practice_history ph ON ph.word_id = w.id AND ph.session_type = 'random'
        WHERE ph.total_incorrect_count > 0
        GROUP BY
            w.id,
            ph.session_type,
            ph.list_name
        ORDER BY
            ph.practiced_at DESC;
      ''');
      } else {
        // Consulta original para otras listas
        String whereClause = '';
        List<String> whereArgs = [];

        if (lists.isNotEmpty) {
          whereClause = '(${lists.map((_) => '?').join(',')})';
          whereArgs.addAll(lists);
        } else {
          // Si la lista está vacía, puedes devolver todos los resultados o manejarlo de otra manera
          whereClause =
              '1 = 1'; // Esto siempre es verdadero y devolverá todos los registros
        }

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
            debugPrint(
                '[MI_LOG]Contenido practice_history: $tableMap.tostring()');
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
          List<Map<String, dynamic>> tableMap = await db.rawQuery('''
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

        maps = await db.rawQuery('''
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
        ''', whereArgs);
      }
    } catch (e) {
      debugPrint('[MI_LOG]$e');
      return [];
    }
    result = await _mapToWordsPractice(maps);
    return result;
  }

  // Buscar palabras (incluyendo búsqueda en listas).
  static Future<List<Word>> searchWords(String query,
      {String? sortOrder}) async {
    final db = await DBHelper().database;
    final orderByClause = _getOrderByClause(sortOrder);

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT DISTINCT w.*
        FROM ${DBHelper().tableWords} w
        LEFT JOIN ${DBHelper().tableWordLists} wl ON w.id = wl.word_id
        WHERE w.word LIKE ? OR w.translation LIKE ? OR w.spelling LIKE ? OR wl.list_name LIKE ?
        ORDER BY $orderByClause
    ''', ['%$query%', '%$query%', '%$query%', '%$query%']);

    return await _mapToWords(maps);
  }

  // Función auxiliar para obtener la cláusula ORDER BY (privada).
  static String _getOrderByClause(String? sortOrder) {
    switch (sortOrder) {
      case 'nameAsc':
        return 'word ASC';
      case 'nameDesc':
        return 'word DESC';
      case 'dateAsc':
        return 'created_at ASC';
      case 'dateDesc':
        return 'created_at DESC';
      default:
        return 'created_at DESC'; // Orden por defecto
      //return ''; // Orden por defecto
    }
  }

  // Helper function to convert query results to a list of Word objects.
  static Future<List<WordPractice>> _mapToWordsPractice(
      List<Map<String, dynamic>> maps) async {
    final List<WordPractice> words = [];
    for (final map in maps) {
      final List<String> lists = await _getListsForWord(map['id']);
      if (lists.isNotEmpty) {
        // Obtener las listas
        words.add(WordPractice.fromMap(map, lists: lists)); // Crear la palabra
      }
    }
    return words;
  }

  static Future<List<Word>> _mapToWords(List<Map<String, dynamic>> maps) async {
    final List<Word> words = [];
    for (final map in maps) {
      final List<String> lists = await _getListsForWord(map['id']);
      if (lists.isNotEmpty) {
        // Obtener las listas
        words.add(Word.fromMap(map, lists: lists)); // Crear la palabra
      }
    }
    return words;
  }

  // Método para obtener todas las listas únicas (para el DropdownButton).
  static Future<List<String>> getAllLists() async {
    final db = await DBHelper().database;
    final List<Map<String, dynamic>> listMaps =
        await db.query(DBHelper().tableWordLists,
            where: "list_name <> 'Todo'",
            distinct: true, // Obtener solo nombres de lista únicos
            columns: ['list_name'], // Solo necesitamos la columna list_name
            orderBy: 'list_name');

    final lists =
        listMaps.map<String>((map) => map['list_name'] as String).toList();
    lists.insert(0, "Todo");
    lists.insert(1, "Por practicar");

    return lists;
  }

  static Future<int> updateLastPractice(int wordId) async {
    final db = await DBHelper().database;
    try {
      return await db.update(
        DBHelper().tableWords,
        {'last_practice': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [wordId],
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<WordPractice?> getWordsForRandomPractice(
      {List<WordPractice>? words, String? filter}) async {
    final db = await DBHelper().database;

    try {
      // 1. Obtener TODAS las palabras (o las filtradas).
      List<Map<String, dynamic>> allWordsMap;
      if (words != null && words.isNotEmpty) {
        if (filter != null && filter != 'Todo') {
          allWordsMap = await db.rawQuery('''
        SELECT
            w.*,
            ph.correct_count,
            ph.incorrect_count,
            ph.total_incorrect_count
        FROM
            words w
        LEFT JOIN
            practice_history ph ON ph.word_id = w.id AND ph.session_type = 'random'
        JOIN
            word_lists wl ON w.id = wl.word_id
        WHERE
            wl.list_name = ?
        GROUP BY
            w.id
        ORDER BY
            ph.practiced_at DESC;
      ''', [filter]);
        } else {
          allWordsMap = await db.rawQuery('''
        SELECT
            w.*,
            ph.correct_count,
            ph.incorrect_count,
            ph.total_incorrect_count
        FROM
            words w
        LEFT JOIN
            practice_history ph ON ph.word_id = w.id AND ph.session_type = 'random'
        JOIN
            word_lists wl ON w.id = wl.word_id
        GROUP BY
            w.id
        ORDER BY
            ph.practiced_at DESC;
      ''');
        }
      } else {
        allWordsMap = [];
      }

      final List<WordPractice> allWords =
          allWordsMap.map((map) => WordPractice.fromMap(map)).toList();

      final List<WordPractice> filteredWords = allWords
          .where((wordPractice) =>
              words!.any((word) => word.word == wordPractice.word))
          .toList();

      // Obtener la lista de PracticeHistory
      final List<Map<String, dynamic>> practiceHistoryMap =
          await db.query('practice_history');
      final List<PracticeHistory> practiceHistoryList = practiceHistoryMap
          .map((map) => PracticeHistory.fromMap(map))
          .toList();

      final List<WordPracticeHistory> wordPracticeHistory =
          filteredWords.map((wordPractice) {
        // Encuentra el PracticeHistory correspondiente a este WordPractice
        final practiceHistory = practiceHistoryList.firstWhere(
          (ph) => ph.wordId == wordPractice.id,
          orElse: () => PracticeHistory(
              id: 0, // Revisa si necesitas esto, o si debes dejarlo nulo
              wordId: wordPractice.id ?? 0,
              sessionId: 0,
              isCorrect: false,
              practicedAt: DateTime.fromMillisecondsSinceEpoch(
                  0), // Añadido un valor por defecto para practicedAt
              sessionType: '',
              correctCount: 0,
              incorrectCount: 0,
              totalIncorrectCount: 0,
              listName: filter ?? ''),
        );
        return WordPracticeHistory.fromWordPractice(practiceHistory);
      }).toList();

      final List<PracticeHistory> practiceHistory = wordPracticeHistory
          .map((wph) => PracticeHistory(
              id: 0, // Revisa si necesitas esto, o si debes dejarlo nulo
              wordId: wph.wordId,
              sessionId: wph.sessionId ?? 0,
              isCorrect: wph.isCorrect ?? false,
              practicedAt: wph
                  .practicedAt, // Añadido un valor por defecto para practicedAt
              sessionType: wph.sessionType ?? '',
              correctCount: wph.correctCount ?? 0,
              incorrectCount: wph.incorrectCount ?? 0,
              totalIncorrectCount: wph.totalIncorrectCount ?? 0,
              listName: filter ?? ''))
          .toList();

      // 3. Dividir las palabras en grupos
      final List<WordPractice> neverPracticed = [];
      final List<WordPractice> incorrectWords = [];

      for (final word in filteredWords) {
        if (word.lastPractice == null) {
          neverPracticed.add(word);
        } else if (word.incorrectCount > 0) {
          incorrectWords.add(word);
        }
      }

      // 4. Aplicar la lógica de prioridades y espaciado.
      WordPractice? selectedWord;

      // Prioridad 1: Incorrectas con espaciado.
      final List<WordPractice> eligibleIncorrectWords =
          incorrectWords.where((word) {
        List<int> lastPracticedDistinctWordIds = [];
        for (final historyEntry in practiceHistory) {
          if (!lastPracticedDistinctWordIds.contains(historyEntry.wordId)) {
            lastPracticedDistinctWordIds.add(historyEntry.wordId);
          }
          if (lastPracticedDistinctWordIds.length == 3) {
            break;
          }
        }

        return word.correctCount <= 0 &&
            !lastPracticedDistinctWordIds.contains(word.id);
      }).toList();

      eligibleIncorrectWords.sort(
          (a, b) => b.totalIncorrectCount.compareTo(a.totalIncorrectCount));

      if (eligibleIncorrectWords.isNotEmpty) {
        selectedWord = eligibleIncorrectWords[
            Random().nextInt(eligibleIncorrectWords.length)];
      } else if (neverPracticed.isNotEmpty) {
        selectedWord = neverPracticed[Random().nextInt(neverPracticed.length)];
      } else {
        // Prioridad 3: Todas las palabras, priorizando por incorrectCount y correctCount.
        if (filteredWords.isNotEmpty) {
          filteredWords.sort((a, b) {
            int incorrectComparison =
                b.totalIncorrectCount.compareTo(a.totalIncorrectCount);
            if (incorrectComparison != 0) {
              return incorrectComparison;
            }
            return a.correctCount.compareTo(b.correctCount);
          });
          selectedWord = filteredWords[Random().nextInt(filteredWords.length)];
        } else {
          selectedWord = null;
        }
      }

      return selectedWord;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> updateWordCounters(
      int wordId, bool isCorrect, String listName, String sessionType) async {
    final db = await DBHelper().database;
    try {
      if (isCorrect) {
        // Obtener los valores actuales (NECESARIO).
        final List<Map<String, dynamic>> wordData = await db.query(
          DBHelper().tablePracticeHistory,
          where: 'word_id = ? and list_name = ? and session_type = ?',
          whereArgs: [wordId, listName, sessionType],
        );
        //Si el contador de incorrecto es igual a 0, entonces incrementamos el correcto
        if (wordData.first['incorrect_count'] <= 1) {
          await db.rawUpdate('''
              UPDATE ${DBHelper().tablePracticeHistory}
              SET correct_count = correct_count + 1,
                  incorrect_count = 0,
                  total_incorrect_count = 0
              WHERE word_id = ? and list_name = ? and session_type = ?
              ''', [wordId, listName, sessionType]);
        } else {
          //Si no, se decrementa el contador de incorrectos.
          await db.rawUpdate('''
              UPDATE ${DBHelper().tablePracticeHistory}
              SET incorrect_count = incorrect_count - 1,
              correct_count = correct_count + 1
              WHERE word_id = ? and list_name = ? and session_type = ?
              ''', [wordId, listName, sessionType]);
        }
      } else {
        //Si es incorrecto, aumentar incorrect_count y total_incorrect_count
        await db.rawUpdate('''
            UPDATE ${DBHelper().tablePracticeHistory}
            SET correct_count = 0,
                incorrect_count = incorrect_count + 1,
                total_incorrect_count = total_incorrect_count + 1
            WHERE word_id = ? and list_name = ? and session_type = ?
            ''', [wordId, listName, sessionType]);
      }
    } catch (e) {
      rethrow;
    }
  }
}
