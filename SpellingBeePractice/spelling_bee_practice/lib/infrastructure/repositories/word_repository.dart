import 'package:collection/collection.dart'; // Para firstWhereOrNull
import 'dart:math';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/helpers/db_helper.dart';
import 'package:spelling_bee_practice/domain/entities/practice_history.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import SharedPreferences

class WordRepository {
  static const _selectedListsKey =
      'selected_lists'; // Clave para SharedPreferences

  // static Future<List<Word>> getFilteredWords(String filter) async {
  //   final db = await DBHelper().database;
  //   final List<Map<String, dynamic>> wordsMap =
  //       await db.query(DBHelper().tableWords);
  //   List<Word> words = wordsMap.map((map) => Word.fromMap(map)).toList();
  //   List<Word> wordsFiltered = [];

  //   if (filter == 'Por practicar') {
  //     wordsFiltered = words.where((word) => word.totalIncorrectCount > 0).toList()
  //       ..sort(
  //           (a, b) => b.totalIncorrectCount.compareTo(a.totalIncorrectCount));
  //   } else if (filter != 'Todo') {
  //     wordsFiltered = words.where((word) => word.lists.contains(filter)).toList();
  //   } else{
  //     wordsFiltered = words;
  //   }
  //   return wordsFiltered; // Retorna todas las palabras si el filtro es 'Todo'
  // }

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

  static Future<Word?> getWordById(int? wordId) async {
    final db = await DBHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      DBHelper().tableWords,
      where: 'id = ?',
      whereArgs: [wordId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      final List<String> lists = await _getListsForWord(maps.first['id']);
      return Word.fromMap(maps.first, lists: lists); // Usa el helper
    } else {
      return null;
    }
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
      // La palabra ya existe.  Actualiza la palabra incluyendo la lista.
      await updateWord(word.copyWith(id: existingWord.id)); // Copia el ID
      return existingWord.id!;
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
          WHERE w.total_incorrect_count > 0
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
      case 'az':
        return 'word ASC';
      case 'za':
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

//Este metodo ya no es necesario
  // static Future<List<Word>> getWords() async {
  //   final db = await DBHelper().database;
  //   try {
  //     final List<Map<String, dynamic>> maps =
  //         await db.query(DBHelper().tableWords);
  //     return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  //   } catch (e) {
  //     print("Error al obtener palabras $e");
  //     return []; // Return an empty list in case of error.
  //   }
  // }

  static Future<Word?> getWordsForRandomPractice({List<Word>? words}) async {
    final db = await DBHelper().database;

    try {
      // 1. Obtener TODAS las palabras (o las filtradas).
      List<Map<String, dynamic>> allWordsMap;
      if (words != null && words.isNotEmpty) {
        allWordsMap = await db.query(
          DBHelper().tableWords,
          where: 'id IN (${words.map((word) => word.id).join(',')})',
        );
      } else {
        allWordsMap = await db.query(DBHelper().tableWords);
      }
      final List<Word> allWords =
          allWordsMap.map((map) => Word.fromMap(map)).toList();

      // 2. Obtener el historial de práctica aleatoria.
      final List<Map<String, dynamic>> practiceHistoryMap = await db.query(
        'practice_history',
        where: "session_type = 'random'",
        orderBy: 'practiced_at DESC',
      );
      final List<PracticeHistory> practiceHistory = practiceHistoryMap
          .map((map) => PracticeHistory.fromMap(map))
          .toList();

      // 3. Dividir las palabras en grupos
      final List<Word> neverPracticed = [];
      final List<Word> incorrectWords = [];

      for (final word in allWords) {
        final lastPractice = practiceHistory.firstWhereOrNull(
          (history) => history.wordId == word.id,
        );

        if (lastPractice == null) {
          neverPracticed.add(word);
        } else if (!lastPractice.isCorrect) {
          incorrectWords.add(word);
        }
      }

      // 4. Aplicar la lógica de prioridades y espaciado.
      Word? selectedWord;

      // Prioridad 1: Incorrectas con espaciado.
      final List<Word> eligibleIncorrectWords = incorrectWords.where((word) {
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
        if (allWords.isNotEmpty) {
          allWords.sort((a, b) {
            int incorrectComparison =
                b.totalIncorrectCount.compareTo(a.totalIncorrectCount);
            if (incorrectComparison != 0) {
              return incorrectComparison;
            }
            return a.correctCount.compareTo(b.correctCount);
          });
          selectedWord = allWords[Random().nextInt(allWords.length)];
        } else {
          selectedWord = null;
        }
      }

      return selectedWord;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> updateWordCounters(int wordId, bool isCorrect) async {
    final db = await DBHelper().database;
    try {
      if (isCorrect) {
        // Obtener los valores actuales (NECESARIO).
        final List<Map<String, dynamic>> wordData = await db.query(
          DBHelper().tableWords,
          where: 'id = ?',
          whereArgs: [wordId],
        );
        //Si el contador de incorrecto es igual a 0, entonces incrementamos el correcto
        if (wordData.first['incorrect_count'] == 1) {
          await db.rawUpdate('''
              UPDATE ${DBHelper().tableWords}
              SET correct_count = correct_count + 1,
                  incorrect_count = 0,
                  total_incorrect_count = 0
              WHERE id = ?
              ''', [wordId]);
        } else {
          //Si no, se decrementa el contador de incorrectos.
          await db.rawUpdate('''
              UPDATE ${DBHelper().tableWords}
              SET incorrect_count = incorrect_count - 1,
              correct_count = correct_count + 1
              WHERE id = ?
              ''', [wordId]);
        }
      } else {
        //Si es incorrecto, aumentar incorrect_count y total_incorrect_count
        await db.rawUpdate('''
            UPDATE ${DBHelper().tableWords}
            SET incorrect_count = incorrect_count + 1,
                total_incorrect_count = total_incorrect_count + 1
            WHERE id = ?
            ''', [wordId]);
      }
    } catch (e) {
      rethrow;
    }
  }
}
