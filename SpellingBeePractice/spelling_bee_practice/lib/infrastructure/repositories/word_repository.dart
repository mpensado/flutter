import 'package:collection/collection.dart'; // Importante para firstWhereOrNull
import 'package:spelling_bee_practice/domain/entities/practice_history.dart';
import 'dart:math';
import 'package:spelling_bee_practice/domain/entities/word.dart'; // Asegúrate de que la ruta es correcta
import 'package:spelling_bee_practice/helpers/db_helper.dart'; // Asegúrate de que la ruta es correcta

class WordRepository {

  static Future<int> insertWord(Word word) async {
    final db = await DBHelper()
        .database; // Acceder a la instancia de base de datos del Singleton
    try {
      return await db.insert(DBHelper().tableWords, word.toMap());
    } catch (e) {
      print("Error inserting word: $e");
      rethrow;
    }
  }

  static Future<List<Word>> getAllWords() async {
    final db = await DBHelper().database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(DBHelper().tableWords);
      return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
    } catch (e) {
      print("Error getting all words: $e");
      rethrow;
    }
  }

  static Future<List<Word>> searchWords(String query) async {
    final db = await DBHelper().database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        DBHelper().tableWords,
        where: 'word LIKE ? OR translation LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
      );
      return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
    } catch (e) {
      print("Error searching words: $e");
      rethrow;
    }
  }

    static Future<int> updateWord(Word word) async {
    final db = await DBHelper().database;
    try {
      return await db.update(
        DBHelper().tableWords,
        word.toMap(),
        where: 'id = ?',
        whereArgs: [word.id],
      );
    } catch (e) {
      print("Error updating word: $e");
      rethrow;
    }
  }

    static Future<int> deleteWord(int id) async {
    final db = await DBHelper().database;
    try {
      return await db.delete(
        DBHelper().tableWords,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print("Error deleting word: $e");
      rethrow;
    }
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
      print("Error updating last practice: $e");
      rethrow;
    }
  }

    static Future<List<Word>> getWords() async {
        final db = await DBHelper().database;
        try {
            final List<Map<String, dynamic>> maps = await db.query(DBHelper().tableWords);
            return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
        } catch (e) {
            print("Error al obtener palabras $e");
            return []; // Return an empty list in case of error.
        }
    }
  static Future<Word?> getWordsForRandomPractice() async {
    final db = await DBHelper().database;

    try {
      // 1. Obtener TODAS las palabras.
      final List<Map<String, dynamic>> allWordsMap = await db.query(DBHelper().tableWords);
      final List<Word> allWords = allWordsMap.map((map) => Word.fromMap(map)).toList();

      // 2. Obtener el historial de práctica aleatoria.  Filtra por session_type = 'random'.
      final List<Map<String, dynamic>> practiceHistoryMap = await db.query(
        'practice_history',
        where: "session_type = 'random'", // Filtramos por tipo de sesión
        orderBy: 'practiced_at DESC', // Ordenamos por fecha descendente
      );
      final List<PracticeHistory> practiceHistory = practiceHistoryMap.map((map) => PracticeHistory.fromMap(map)).toList();

      // 3. Dividir las palabras en grupos.
      final List<Word> neverPracticed = [];
      final List<Word> incorrectWords = [];
      //final List<Word> correctWords = []; //Ya no se usa

      for (final word in allWords) {
        // Buscar la ÚLTIMA vez que se practicó esta palabra.
        final lastPractice = practiceHistory.firstWhereOrNull(
          (history) => history.wordId == word.id,
        );

        if (lastPractice == null) {
          neverPracticed.add(word);
        } else if (!lastPractice.isCorrect) { //Solo se añaden las incorrectas
          incorrectWords.add(word);
        }
      }
      // 4. Aplicar lógica de prioridades y espaciado.
        Word? selectedWord;
        //Prioridad 1: Incorrectas con espaciado.
        final List<Word> eligibleIncorrectWords = incorrectWords.where((word) {
            //Obtener las últimas 3 palabras DISTINTAS practicadas.
            List<int> lastPracticedDistinctWordIds = [];
            for(final historyEntry in practiceHistory){
                if(!lastPracticedDistinctWordIds.contains(historyEntry.wordId)){ //Si no la hemos añadido
                    lastPracticedDistinctWordIds.add(historyEntry.wordId);
                }
                if(lastPracticedDistinctWordIds.length == 3){ break; } //Ya tenemos las 3.
            }

          return word.correctCount <= 0 && !lastPracticedDistinctWordIds.contains(word.id); //Filtro correctCount
        }).toList();

        // Ordenar eligibleIncorrectWords por totalIncorrectCount (mayor a menor)
        eligibleIncorrectWords.sort((a, b) => b.totalIncorrectCount.compareTo(a.totalIncorrectCount));


      if (eligibleIncorrectWords.isNotEmpty) {
        selectedWord = eligibleIncorrectWords[Random().nextInt(eligibleIncorrectWords.length)];
      } else if (neverPracticed.isNotEmpty) {
        // Prioridad 2: Palabras nunca practicadas.
        selectedWord = neverPracticed[Random().nextInt(neverPracticed.length)];
      } else {
        // Prioridad 3: Todas las palabras, priorizando por incorrectCount
        if (allWords.isNotEmpty) {
          // Ordenar allWords por incorrectCount (de mayor a menor) y luego por correctCount (de menor a mayor).
          allWords.sort((a, b) {
            int incorrectComparison = b.totalIncorrectCount.compareTo(a.totalIncorrectCount);
            if (incorrectComparison != 0) {
              return incorrectComparison;
            }
            return a.correctCount.compareTo(b.correctCount); // Menos aciertos primero
          });
          selectedWord = allWords[Random().nextInt(allWords.length)];
        } else {
          selectedWord = null; // No hay palabras disponibles
        }
      }

      return selectedWord;

    } catch (e) {
      print("Error en getWordsForRandomPractice: $e");
      rethrow;
    }
  }
    static Future<void> updateWordCounters(int wordId, bool isCorrect) async {
        final db = await DBHelper().database;
        try {
            if(isCorrect){
                //Obtener los valores actuales
                final List<Map<String, dynamic>> wordData = await db.query(
                    DBHelper().tableWords,
                    where: 'id = ?',
                    whereArgs: [wordId],
                );
                //Si el contador de incorrecto es igual a 0, entonces incrementamos el correcto
                if(wordData.first['incorrect_count'] == 0){
                    await db.rawUpdate('''
                      UPDATE ${DBHelper().tableWords}
                      SET correct_count = correct_count + 1
                      WHERE id = ?
                    ''', [wordId]);
                } else { //Si no, se decrementa el contador de incorrectos.
                  await db.rawUpdate('''
                      UPDATE ${DBHelper().tableWords}
                      SET incorrect_count = incorrect_count - 1
                      WHERE id = ?
                    ''', [wordId]);
                }
            } else { //Si es incorrecto, aumentar incorrect_count y total_incorrect_count
                await db.rawUpdate('''
                UPDATE ${DBHelper().tableWords}
                SET incorrect_count = incorrect_count + 1,
                    total_incorrect_count = total_incorrect_count + 1
                WHERE id = ?
                ''', [wordId]);
            }

        } catch (e) {
            print("Error updating word counters: $e");
            rethrow;
        }
    }
}