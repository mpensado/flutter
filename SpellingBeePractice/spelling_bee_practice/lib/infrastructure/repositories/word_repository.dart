import 'package:collection/collection.dart'; // Importante para firstWhereOrNull
import 'package:spelling_bee_practice/domain/entities/practice_history.dart';
import 'dart:math';
import 'package:spelling_bee_practice/domain/entities/word.dart'; // Asegúrate de que la ruta es correcta
import 'package:spelling_bee_practice/helpers/db_helper.dart';
import 'package:sqflite/sqflite.dart'; // Asegúrate de que la ruta es correcta

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
      final List<Map<String, dynamic>> maps =
          await db.query(DBHelper().tableWords);
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
      final List<Map<String, dynamic>> maps =
          await db.query(DBHelper().tableWords);
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
      final List<Map<String, dynamic>> allWordsMap =
          await db.query(DBHelper().tableWords);
      final List<Word> allWords =
          allWordsMap.map((map) => Word.fromMap(map)).toList();

      // 2. Obtener el historial de práctica aleatoria.  Filtra por session_type = 'random'.
      final List<Map<String, dynamic>> practiceHistoryMap = await db.query(
        'practice_history',
        where: "session_type = 'random'", // Filtramos por tipo de sesión
        orderBy: 'practiced_at DESC', // Ordenamos por fecha descendente
      );
      final List<PracticeHistory> practiceHistory = practiceHistoryMap
          .map((map) => PracticeHistory.fromMap(map))
          .toList();

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
        } else if (!lastPractice.isCorrect) {
          //Solo se añaden las incorrectas
          incorrectWords.add(word);
        }
      }
      // 4. Aplicar lógica de prioridades y espaciado.
      Word? selectedWord;
      //Prioridad 1: Incorrectas con espaciado.
      final List<Word> eligibleIncorrectWords = incorrectWords.where((word) {
        //Obtener las últimas 3 palabras DISTINTAS practicadas.
        List<int> lastPracticedDistinctWordIds = [];
        for (final historyEntry in practiceHistory) {
          if (!lastPracticedDistinctWordIds.contains(historyEntry.wordId)) {
            //Si no la hemos añadido
            lastPracticedDistinctWordIds.add(historyEntry.wordId);
          }
          if (lastPracticedDistinctWordIds.length == 3) {
            break;
          } //Ya tenemos las 3.
        }

        return word.correctCount <= 0 &&
            !lastPracticedDistinctWordIds
                .contains(word.id); //Filtro correctCount
      }).toList();

      // Ordenar eligibleIncorrectWords por totalIncorrectCount (mayor a menor)
      eligibleIncorrectWords.sort(
          (a, b) => b.totalIncorrectCount.compareTo(a.totalIncorrectCount));

      if (eligibleIncorrectWords.isNotEmpty) {
        selectedWord = eligibleIncorrectWords[
            Random().nextInt(eligibleIncorrectWords.length)];
      } else if (neverPracticed.isNotEmpty) {
        // Prioridad 2: Palabras nunca practicadas.
        selectedWord = neverPracticed[Random().nextInt(neverPracticed.length)];
      } else {
        // Prioridad 3: Todas las palabras, priorizando por incorrectCount
        if (allWords.isNotEmpty) {
          // Ordenar allWords por incorrectCount (de mayor a menor) y luego por correctCount (de menor a mayor).
          allWords.sort((a, b) {
            int incorrectComparison =
                b.totalIncorrectCount.compareTo(a.totalIncorrectCount);
            if (incorrectComparison != 0) {
              return incorrectComparison;
            }
            return a.correctCount
                .compareTo(b.correctCount); // Menos aciertos primero
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
      if (isCorrect) {
        //Obtener los valores actuales
        final List<Map<String, dynamic>> wordData = await db.query(
          DBHelper().tableWords,
          where: 'id = ?',
          whereArgs: [wordId],
        );
        //Si el contador de incorrecto es igual a 0, entonces incrementamos el correcto
        if (wordData.first['incorrect_count'] == 0) {
          await db.rawUpdate('''
                      UPDATE ${DBHelper().tableWords}
                      SET correct_count = correct_count + 1
                      WHERE id = ?
                    ''', [wordId]);
        } else {
          //Si no, se decrementa el contador de incorrectos.
          await db.rawUpdate('''
                      UPDATE ${DBHelper().tableWords}
                      SET incorrect_count = incorrect_count - 1
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
      print("Error updating word counters: $e");
      rethrow;
    }
  }

  static Future<String> loadInitialData() async {
    final dbHelper = DBHelper();
    try {
      final db = await dbHelper.database;
      final wordCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM ${dbHelper.tableWords}'));

      if (wordCount == 0) {
        _loadSampleData(); // Usar dbHelper, no DBHelper directamente.
      }
    } catch (e) {
      return "Error al cargar datos iniciales: $e"; // Early return on error
    }
    return "";
  }

  static Future<void> _loadSampleData() async {
    final dbHelper =
        DBHelper(); // Create an instance (if you don't have one already in scope)
    final db = await dbHelper.database;

    // Lista de Vocabulario de ejemplo
    final List<Map<String, dynamic>> sampleWords = [
      {
        'word': 'Mangoes',
        'translation': 'mangos',
        'spelling': 'mangoes---m---a---n---g---o---e---s---mangoes'
      },
      {
        'word': 'Potatoes',
        'translation': 'patatas',
        'spelling': 'potatoes---p---o---t---a---t---o---e---s---potatoes'
      },
      {
        'word': 'Peaches',
        'translation': 'melocotones',
        'spelling': 'peaches---p---e---a---c---h---e---s---peaches'
      },
      {
        'word': 'Carrots',
        'translation': 'zanahorias',
        'spelling': 'carrots---c---a---r---r---o---t---s---carrots'
      },
      {
        'word': 'Tomatoes',
        'translation': 'tomates',
        'spelling': 'tomatoes---t---o---m---a---t---o---e---s---tomatoes'
      },
      {
        'word': 'Cucumbers',
        'translation': 'pepinos',
        'spelling': 'cucumbers---c---u---c---u---m---b---e---r---s---cucumbers'
      },
      {
        'word': 'Avocados',
        'translation': 'aguacates',
        'spelling': 'avocados---a---v---o---c---a---d---o---s---avocados'
      },
      {
        'word': 'Pasta',
        'translation': 'pasta',
        'spelling': 'pasta---p---a---s---t---a---pasta'
      },
      {
        'word': 'Popcorn',
        'translation': 'palomitas de maíz',
        'spelling': 'popcorn---p---o---p---c---o---r---n---popcorn'
      },
      {'word': 'Tea', 'translation': 'té', 'spelling': 'tea---t---e---a---tea'},
      {
        'word': 'Coffee',
        'translation': 'café',
        'spelling': 'coffee---c---o---f---f---e---e---coffee'
      },
      {
        'word': 'Soda',
        'translation': 'gaseosa',
        'spelling': 'soda---s---o---d---a---soda'
      },
      {
        'word': 'Beef',
        'translation': 'carne de res',
        'spelling': 'beef---b---e---e---f---beef'
      },
      {
        'word': 'Chicken',
        'translation': 'pollo',
        'spelling': 'chicken---c---h---i---c---k---e---n---chicken'
      },
      {
        'word': 'Lemonade',
        'translation': 'limonada',
        'spelling': 'lemonade---l---e---m---o---n---a---d---e---lemonade'
      },
      {
        'word': 'Rainy',
        'translation': 'lluvioso',
        'spelling': 'rainy---r---a---i---n---y---rainy'
      },
      {
        'word': 'Windy',
        'translation': 'ventoso',
        'spelling': 'windy---w---i---n---d---y---windy'
      },
      {
        'word': 'Hot',
        'translation': 'caliente',
        'spelling': 'hot---h---o---t---hot'
      },
      {
        'word': 'Sunny',
        'translation': 'soleado',
        'spelling': 'sunny---s---u---n---n---y---sunny'
      },
      {
        'word': 'Cloudy',
        'translation': 'nublado',
        'spelling': 'cloudy---c---l---o---u---d---y---cloudy'
      },
      {
        'word': 'Cold',
        'translation': 'frío',
        'spelling': 'cold---c---o---l---d---cold'
      },
      {
        'word': 'Snowy',
        'translation': 'nevado',
        'spelling': 'snowy---s---n---o---w---y---snowy'
      },
      {
        'word': 'Roller skate',
        'translation': 'patinar',
        'spelling':
            'roller skate---r---o---l---l---e---r---space---s---k---a---t---e---roller skate'
      },
      {
        'word': 'Surf',
        'translation': 'surfear',
        'spelling': 'surf---s---u---r---f---surf'
      },
      {
        'word': 'Dive',
        'translation': 'bucear',
        'spelling': 'dive---d---i---v---e---dive'
      },
      {
        'word': 'Ski',
        'translation': 'esquiar',
        'spelling': 'ski---s---k---i---ski'
      },
      {
        'word': 'Hike',
        'translation': 'senderismo',
        'spelling': 'hike---h---i---k---e---hike'
      },
      {
        'word': 'University',
        'translation': 'Universidad',
        'spelling':
            'University---U---n---i---v---e---r---s---i---t---y---University'
      },
      {
        'word': 'Supermarket',
        'translation': 'Supermercado',
        'spelling':
            'Supermarket---S---u---p---e---r---m---a---r---k---e---t---Supermarket'
      },
      {
        'word': 'Snack',
        'translation': 'bocadillo',
        'spelling': 'Snack---S---n---a---c---k---Snack'
      },
      {
        'word': 'Nap',
        'translation': 'siesta',
        'spelling': 'nap---n---a---p---nap'
      },
      {
        'word': 'Internet',
        'translation': 'internet',
        'spelling': 'internet---i---n---t---e---r---n---e---t---internet'
      },
      {
        'word': 'Shark',
        'translation': 'tiburón',
        'spelling': 'shark---s---h---a---r---k---shark'
      },
      {
        'word': 'Fish',
        'translation': 'pez',
        'spelling': 'fish---f---i---s---h---fish'
      },
      {
        'word': 'Shop',
        'translation': 'tienda',
        'spelling': 'shop---s---h---o---p---shop'
      },
      {
        'word': 'Brush',
        'translation': 'cepillo',
        'spelling': 'brush---b---r---u---s---h---brush'
      },
      {
        'word': 'Suitcase',
        'translation': 'maleta',
        'spelling': 'suitcase---s---u---i---t---c---a---s---e---suitcase'
      },
      {
        'word': 'Catch',
        'translation': 'atrapar',
        'spelling': 'catch---c---a---t---c---h---catch'
      },
      {
        'word': 'Chair',
        'translation': 'silla',
        'spelling': 'chair---c---h---a---i---r---chair'
      },
      {
        'word': 'Scratch',
        'translation': 'rasguño',
        'spelling': 'scratch---s---c---r---a---t---c---h---scratch'
      },
      {
        'word': 'Hair',
        'translation': 'pelo',
        'spelling': 'hair---h---a---i---r---hair'
      },
      {
        'word': 'Shower',
        'translation': 'ducha',
        'spelling': 'Shower---S---h---o---w---e---r---Shower'
      },
      {
        'word': 'Paramedic',
        'translation': 'paramédico',
        'spelling': 'paramedic---p---a---r---a---m---e---d---i---c---paramedic'
      },
      {
        'word': 'Face',
        'translation': 'cara',
        'spelling': 'face---f---a---c---e---face'
      },
      {
        'word': 'Fisherman',
        'translation': 'pescador',
        'spelling': 'fisherman---f---i---s---h---e---r---m---a---n---fisherman'
      },
      {
        'word': 'Breakfast',
        'translation': 'desayuno',
        'spelling': 'breakfast---b---r---e---a---k---f---a---s---t---breakfast'
      },
      {
        'word': 'School',
        'translation': 'Escuela',
        'spelling': 'School---S---c---h---o---o---l---School'
      },
      {
        'word': 'Taxi',
        'translation': 'taxi',
        'spelling': 'taxi---t---a---x---i---taxi'
      },
      {
        'word': 'Train',
        'translation': 'tren',
        'spelling': 'train---t---r---a---i---n---train'
      },
      {
        'word': 'Bus',
        'translation': 'autobús',
        'spelling': 'bus---b---u---s---bus'
      },
      {
        'word': 'Subway',
        'translation': 'Metro',
        'spelling': 'Subway---S---u---b---w---a---y---Subway'
      },
      {
        'word': 'Walk',
        'translation': 'caminar',
        'spelling': 'walk---w---a---l---k---walk'
      },
      {
        'word': 'Bicycle',
        'translation': 'bicicleta',
        'spelling': 'bicycle---b---i---c---y---c---l---e---bicycle'
      },
      {'word': 'Art', 'translation': 'arte', 'spelling': 'art---a---r---t---art'},
      {
        'word': 'English',
        'translation': 'Inglés',
        'spelling': 'English---E---n---g---l---i---s---h---English'
      },
      {
        'word': 'Music',
        'translation': 'música',
        'spelling': 'music---m---u---s---i---c---music'
      },
      {
        'word': 'Math',
        'translation': 'matemáticas',
        'spelling': 'math---m---a---t---h---math'
      },
      {
        'word': 'Health',
        'translation': 'salud',
        'spelling': 'health---h---e---a---l---t---h---health'
      },
      {
        'word': 'Science',
        'translation': 'ciencia',
        'spelling': 'science---s---c---i---e---n---c---e---science'
      },
      {
        'word': 'Gym',
        'translation': 'gimnasio',
        'spelling': 'gym---g---y---m---gym'
      },
      {
        'word': 'Cafeteria',
        'translation': 'cafetería',
        'spelling': 'cafeteria---c---a---f---e---t---e---r---i---a---cafeteria'
      },
      {
        'word': 'Classroom',
        'translation': 'aula',
        'spelling': 'classroom---c---l---a---s---s---r---o---o---m---classroom'
      },
      {
        'word': 'Wave',
        'translation': 'ola',
        'spelling': 'wave---w---a---v---e---wave'
      },
      {
        'word': 'Pond',
        'translation': 'estanque',
        'spelling': 'Pond---P---o---n---d---Pond'
      },
      {
        'word': 'Watch',
        'translation': 'Reloj',
        'spelling': 'Watch---W---a---t---c---h---Watch'
      },
      {
        'word': 'Play',
        'translation': 'jugar',
        'spelling': 'play---p---l---a---y---play'
      },
      {
        'word': 'Smile',
        'translation': 'Sonreír',
        'spelling': 'Smile---S---m---i---l---e---Smile'
      },
      {
        'word': 'Juggle',
        'translation': 'Malabarismo',
        'spelling': 'Juggle---J---u---g---g---l---e---Juggle'
      },
      {
        'word': 'Bounce',
        'translation': 'rebotar',
        'spelling': 'bounce---b---o---u---n---c---e---bounce'
      },
      {
        'word': 'Push',
        'translation': 'Empujar',
        'spelling': 'Push---P---u---s---h---Push'
      },
      {
        'word': 'Pull',
        'translation': 'Tirar',
        'spelling': 'Pull---P---u---l---l---Pull'
      },
      {
        'word': 'Carry',
        'translation': 'cargar',
        'spelling': 'carry---c---a---r---r---y---carry'
      },
      {
        'word': 'Candy',
        'translation': 'caramelo',
        'spelling': 'candy---c---a---n---d---y---candy'
      },
      {
        'word': 'Movie',
        'translation': 'película',
        'spelling': 'movie---m---o---v---i---e---movie'
      },
      {
        'word': 'Turkey',
        'translation': 'pavo',
        'spelling': 'turkey---t---u---r---k---e---y---turkey'
      },
      {
        'word': 'Roast',
        'translation': 'Asado',
        'spelling': 'Roast---R---o---a---s---t---Roast'
      },
      {
        'word': 'Bacon',
        'translation': 'tocino',
        'spelling': 'bacon---b---a---c---o---n---bacon'
      },
      {
        'word': 'Oysters',
        'translation': 'ostras',
        'spelling': 'oysters---o---y---s---t---e---r---s---oysters'
      },
      {
        'word': 'Shrimp',
        'translation': 'camarón',
        'spelling': 'shrimp---s---h---r---i---m---p---shrimp'
      },
    ];

    try {
      List<int> wordIds = [];
      for (var wordData in sampleWords) {
        final id = await db.insert(dbHelper.tableWords, wordData);
        wordIds.add(id);
      }
    } catch (e) {
      print("Error loading sample data: $e");
      // Consider showing a SnackBar to the user.  You'll need a BuildContext.
    }
  }
}
