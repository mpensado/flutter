import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/helpers/db_helper.dart';
import 'package:sqflite/sqflite.dart';

class InitDB {

  static Future<Word?> getWordByText(Database db,String wordText) async {
    //final db = await DBHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      DBHelper().tableWords,
      where: 'word = ?',
      whereArgs: [wordText],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      final List<String> lists = await _getListsForWord(db, maps.first['id']);
      return Word.fromMap(maps.first, lists: lists); // Usa el helper
    } else {
      return null;
    }
  }

  static Future<List<String>> _getListsForWord(Database db, int wordId) async {
    //final db = await DBHelper().database;
    final List<Map<String, dynamic>> listMaps = await db.query(
      DBHelper().tableWordLists, // Usa la tabla word_lists
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
    return listMaps.map<String>((map) => map['list_name'] as String).toList();
  }

  static Future<void> loadInitialData(Database db) async {
    try {
      final wordCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM words'));

      if (wordCount == 0) {
        await _loadSampleData(db); // Pasa 'db'
        await _loadSampleWordLists(db); // Pasa 'db'
      } else {}
    } catch (e) {
      rethrow; // Importante
    }
  }

  // _loadSampleData:  Ahora es *privada* y recibe la conexión 'db'.
  static Future<void> _loadSampleData(Database db) async {
    final List<Map<String, dynamic>> sampleWords = [
      {
        'word': 'mangoes',
        'translation': 'mangos',
        'spelling': 'mangoes---m---a---n---g---o---e---s---mangoes'
      },
      {
        'word': 'potatoes',
        'translation': 'patatas',
        'spelling': 'potatoes---p---o---t---a---t---o---e---s---potatoes'
      },
      {
        'word': 'peaches',
        'translation': 'melocotones',
        'spelling': 'peaches---p---e---a---c---h---e---s---peaches'
      },
      {
        'word': 'carrots',
        'translation': 'zanahorias',
        'spelling': 'carrots---c---a---r---r---o---t---s---carrots'
      },
      {
        'word': 'tomatoes',
        'translation': 'tomates',
        'spelling': 'tomatoes---t---o---m---a---t---o---e---s---tomatoes'
      },
      {
        'word': 'cucumbers',
        'translation': 'pepinos',
        'spelling': 'cucumbers---c---u---c---u---m---b---e---r---s---cucumbers'
      },
      {
        'word': 'avocados',
        'translation': 'aguacates',
        'spelling': 'avocados---a---v---o---c---a---d---o---s---avocados'
      },
      {
        'word': 'pasta',
        'translation': 'pasta',
        'spelling': 'pasta---p---a---s---t---a---pasta'
      },
      {
        'word': 'popcorn',
        'translation': 'palomitas de maíz',
        'spelling': 'popcorn---p---o---p---c---o---r---n---popcorn'
      },
      {'word': 'tea', 'translation': 'té', 'spelling': 'tea---t---e---a---tea'},
      {
        'word': 'coffee',
        'translation': 'café',
        'spelling': 'coffee---c---o---f---f---e---e---coffee'
      },
      {
        'word': 'soda',
        'translation': 'gaseosa',
        'spelling': 'soda---s---o---d---a---soda'
      },
      {
        'word': 'beef',
        'translation': 'carne de res',
        'spelling': 'beef---b---e---e---f---beef'
      },
      {
        'word': 'chicken',
        'translation': 'pollo',
        'spelling': 'chicken---c---h---i---c---k---e---n---chicken'
      },
      {
        'word': 'lemonade',
        'translation': 'limonada',
        'spelling': 'lemonade---l---e---m---o---n---a---d---e---lemonade'
      },
      {
        'word': 'rainy',
        'translation': 'lluvioso',
        'spelling': 'rainy---r---a---i---n---y---rainy'
      },
      {
        'word': 'windy',
        'translation': 'ventoso',
        'spelling': 'windy---w---i---n---d---y---windy'
      },
      {
        'word': 'hot',
        'translation': 'caliente',
        'spelling': 'hot---h---o---t---hot'
      },
      {
        'word': 'sunny',
        'translation': 'soleado',
        'spelling': 'sunny---s---u---n---n---y---sunny'
      },
      {
        'word': 'cloudy',
        'translation': 'nublado',
        'spelling': 'cloudy---c---l---o---u---d---y---cloudy'
      },
      {
        'word': 'cold',
        'translation': 'frío',
        'spelling': 'cold---c---o---l---d---cold'
      },
      {
        'word': 'snowy',
        'translation': 'nevado',
        'spelling': 'snowy---s---n---o---w---y---snowy'
      },
      {
        'word': 'roller skate',
        'translation': 'patinar',
        'spelling':
            'roller skate---r---o---l---l---e---r---space---s---k---a---t---e---roller skate'
      },
      {
        'word': 'surf',
        'translation': 'surfear',
        'spelling': 'surf---s---u---r---f---surf'
      },
      {
        'word': 'dive',
        'translation': 'bucear',
        'spelling': 'dive---d---i---v---e---dive'
      },
      {
        'word': 'ski',
        'translation': 'esquiar',
        'spelling': 'ski---s---k---i---ski'
      },
      {
        'word': 'hike',
        'translation': 'senderismo',
        'spelling': 'hike---h---i---k---e---hike'
      },
      {
        'word': 'university',
        'translation': 'universidad',
        'spelling':
            'university---u---n---i---v---e---r---s---i---t---y---university'
      },
      {
        'word': 'supermarket',
        'translation': 'supermercado',
        'spelling':
            'supermarket---s---u---p---e---r---m---a---r---k---e---t---supermarket'
      },
      {
        'word': 'snack',
        'translation': 'bocadillo',
        'spelling': 'snack---s---n---a---c---k---snack'
      },
      {
        'word': 'nap',
        'translation': 'siesta',
        'spelling': 'nap---n---a---p---nap'
      },
      {
        'word': 'internet',
        'translation': 'internet',
        'spelling': 'internet---i---n---t---e---r---n---e---t---internet'
      },
      {
        'word': 'shark',
        'translation': 'tiburón',
        'spelling': 'shark---s---h---a---r---k---shark'
      },
      {
        'word': 'fish',
        'translation': 'pez',
        'spelling': 'fish---f---i---s---h---fish'
      },
      {
        'word': 'shop',
        'translation': 'tienda',
        'spelling': 'shop---s---h---o---p---shop'
      },
      {
        'word': 'brush',
        'translation': 'cepillo',
        'spelling': 'brush---b---r---u---s---h---brush'
      },
      {
        'word': 'suitcase',
        'translation': 'maleta',
        'spelling': 'suitcase---s---u---i---t---c---a---s---e---suitcase'
      },
      {
        'word': 'catch',
        'translation': 'atrapar',
        'spelling': 'catch---c---a---t---c---h---catch'
      },
      {
        'word': 'chair',
        'translation': 'silla',
        'spelling': 'chair---c---h---a---i---r---chair'
      },
      {
        'word': 'scratch',
        'translation': 'rasguño',
        'spelling': 'scratch---s---c---r---a---t---c---h---scratch'
      },
      {
        'word': 'hair',
        'translation': 'pelo',
        'spelling': 'hair---h---a---i---r---hair'
      },
      {
        'word': 'shower',
        'translation': 'ducha',
        'spelling': 'shower---s---h---o---w---e---r---shower'
      },
      {
        'word': 'paramedic',
        'translation': 'paramédico',
        'spelling': 'paramedic---p---a---r---a---m---e---d---i---c---paramedic'
      },
      {
        'word': 'face',
        'translation': 'cara',
        'spelling': 'face---f---a---c---e---face'
      },
      {
        'word': 'fisherman',
        'translation': 'pescador',
        'spelling': 'fisherman---f---i---s---h---e---r---m---a---n---fisherman'
      },
      {
        'word': 'breakfast',
        'translation': 'desayuno',
        'spelling': 'breakfast---b---r---e---a---k---f---a---s---t---breakfast'
      },
      {
        'word': 'school',
        'translation': 'escuela',
        'spelling': 'school---s---c---h---o---o---l---school'
      },
      {
        'word': 'taxi',
        'translation': 'taxi',
        'spelling': 'taxi---t---a---x---i---taxi'
      },
      {
        'word': 'train',
        'translation': 'tren',
        'spelling': 'train---t---r---a---i---n---train'
      },
      {
        'word': 'bus',
        'translation': 'autobús',
        'spelling': 'bus---b---u---s---bus'
      },
      {
        'word': 'subway',
        'translation': 'metro',
        'spelling': 'subway---s---u---b---w---a---y---subway'
      },
      {
        'word': 'walk',
        'translation': 'caminar',
        'spelling': 'walk---w---a---l---k---walk'
      },
      {
        'word': 'bicycle',
        'translation': 'bicicleta',
        'spelling': 'bicycle---b---i---c---y---c---l---e---bicycle'
      },
      {
        'word': 'art',
        'translation': 'arte',
        'spelling': 'art---a---r---t---art'
      },
      {
        'word': 'English',
        'translation': 'inglés',
        'spelling': 'english---capital e---n---g---l---i---s---h---english'
      },
      {
        'word': 'music',
        'translation': 'música',
        'spelling': 'music---m---u---s---i---c---music'
      },
      {
        'word': 'math',
        'translation': 'matemáticas',
        'spelling': 'math---m---a---t---h---math'
      },
      {
        'word': 'health',
        'translation': 'salud',
        'spelling': 'health---h---e---a---l---t---h---health'
      },
      {
        'word': 'science',
        'translation': 'ciencia',
        'spelling': 'science---s---c---i---e---n---c---e---science'
      },
      {
        'word': 'gym',
        'translation': 'gimnasio',
        'spelling': 'gym---g---y---m---gym'
      },
      {
        'word': 'cafeteria',
        'translation': 'cafetería',
        'spelling': 'cafeteria---c---a---f---e---t---e---r---i---a---cafeteria'
      },
      {
        'word': 'classroom',
        'translation': 'aula',
        'spelling': 'classroom---c---l---a---s---s---r---o---o---m---classroom'
      },
      {
        'word': 'wave',
        'translation': 'ola',
        'spelling': 'wave---w---a---v---e---wave'
      },
      {
        'word': 'wait',
        'translation': 'espere',
        'spelling': 'wait---w---a---i---t---wait'
      },
      {
        'word': 'pond',
        'translation': 'estanque',
        'spelling': 'pond---p---o---n---d---pond'
      },
      {
        'word': 'watch',
        'translation': 'reloj',
        'spelling': 'watch---w---a---t---c---h---watch'
      },
      {
        'word': 'play',
        'translation': 'jugar',
        'spelling': 'play---p---l---a---y---play'
      },
      {
        'word': 'smile',
        'translation': 'sonreír',
        'spelling': 'smile---s---m---i---l---e---smile'
      },
      {
        'word': 'juggle',
        'translation': 'hacer malabares',
        'spelling': 'juggle---j---u---g---g---l---e---juggle'
      },
      {
        'word': 'bounce',
        'translation': 'rebotar',
        'spelling': 'bounce---b---o---u---n---c---e---bounce'
      },
      {
        'word': 'push',
        'translation': 'empujar',
        'spelling': 'push---p---u---s---h---push'
      },
      {
        'word': 'pull',
        'translation': 'halar',
        'spelling': 'pull---p---u---l---l---pull'
      },
      {
        'word': 'carry',
        'translation': 'cargar',
        'spelling': 'carry---c---a---r---r---y---carry'
      },
      {
        'word': 'candy',
        'translation': 'caramelo',
        'spelling': 'candy---c---a---n---d---y---candy'
      },
      {
        'word': 'movie',
        'translation': 'película',
        'spelling': 'movie---m---o---v---i---e---movie'
      },
      {
        'word': 'turkey',
        'translation': 'pavo',
        'spelling': 'turkey---t---u---r---k---e---y---turkey'
      },
      {
        'word': 'roast',
        'translation': 'asado',
        'spelling': 'roast---r---o---a---s---t---roast'
      },
      {
        'word': 'bacon',
        'translation': 'tocino',
        'spelling': 'bacon---b---a---c---o---n---bacon'
      },
      {
        'word': 'oysters',
        'translation': 'ostras',
        'spelling': 'oysters---o---y---s---t---e---r---s---oysters'
      },
      {
        'word': 'shrimp',
        'translation': 'camarón',
        'spelling': 'shrimp---s---h---r---i---m---p---shrimp'
      }
    ];

    try {
      // Insertar cada palabra de ejemplo y obtener su ID.
      for (var wordData in sampleWords) {
        final word = Word.fromMap(wordData); // Crear objeto Word
        await db.insert('words', word.toMap()); // Usar db directamente
      }
    } catch (e) {
      print("Error loading sample data: $e");
      rethrow; // Importante
    }
  }

  // _loadSampleWordLists:  Ahora es *privada* y recibe la conexión 'db'.
  static Future<void> _loadSampleWordLists(Database db) async {
    final List<Map<String, dynamic>> sampleWordLists = [
      {'word': 'mangoes', 'list_name': 'Frutas'},
      {'word': 'mangoes', 'list_name': 'Comida'},
      {'word': 'potatoes', 'list_name': 'Vegetales'},
      {'word': 'potatoes', 'list_name': 'Comida'},
      {'word': 'peaches', 'list_name': 'Frutas'},
      {'word': 'peaches', 'list_name': 'Comida'},
      {'word': 'carrots', 'list_name': 'Vegetales'},
      {'word': 'carrots', 'list_name': 'Comida'},
      {'word': 'tomatoes', 'list_name': 'Vegetales'},
      {'word': 'tomatoes', 'list_name': 'Comida'},
      {'word': 'cucumbers', 'list_name': 'Vegetales'},
      {'word': 'cucumbers', 'list_name': 'Comida'},
      {'word': 'avocados', 'list_name': 'Frutas'},
      {'word': 'avocados', 'list_name': 'Comida'},
      {'word': 'pasta', 'list_name': 'Comida'},
      {'word': 'popcorn', 'list_name': 'Comida'},
      {'word': 'tea', 'list_name': 'Bebidas'},
      {'word': 'coffee', 'list_name': 'Bebidas'},
      {'word': 'soda', 'list_name': 'Bebidas'},
      {'word': 'beef', 'list_name': 'Comida'},
      {'word': 'chicken', 'list_name': 'Comida'},
      {'word': 'lemonade', 'list_name': 'Bebidas'},
      {'word': 'rainy', 'list_name': 'Clima'},
      {'word': 'windy', 'list_name': 'Clima'},
      {'word': 'hot', 'list_name': 'Clima'},
      {'word': 'sunny', 'list_name': 'Clima'},
      {'word': 'cloudy', 'list_name': 'Clima'},
      {'word': 'cold', 'list_name': 'Clima'},
      {'word': 'snowy', 'list_name': 'Clima'},
      {'word': 'roller skate', 'list_name': 'Actividades'},
      {'word': 'surf', 'list_name': 'Actividades'},
      {'word': 'dive', 'list_name': 'Actividades'},
      {'word': 'ski', 'list_name': 'Actividades'},
      {'word': 'hike', 'list_name': 'Actividades'},
      {'word': 'university', 'list_name': 'Lugares'},
      {'word': 'supermarket', 'list_name': 'Lugares'},
      {'word': 'snack', 'list_name': 'Comida'},
      {'word': 'nap', 'list_name': 'Actividades'},
      {'word': 'internet', 'list_name': 'Tecnologia'},
      {'word': 'shark', 'list_name': 'Animales'},
      {'word': 'fish', 'list_name': 'Animales'},
      {'word': 'shop', 'list_name': 'Lugares'},
      {'word': 'brush', 'list_name': 'Objetos'},
      {'word': 'suitcase', 'list_name': 'Objetos'},
      {'word': 'catch', 'list_name': 'Acciones'},
      {'word': 'chair', 'list_name': 'Objetos'},
      {'word': 'scratch', 'list_name': 'Acciones'},
      {'word': 'hair', 'list_name': 'Cuerpo'},
      {'word': 'shower', 'list_name': 'Actividades'},
      {'word': 'paramedic', 'list_name': 'Gente'},
      {'word': 'face', 'list_name': 'Cuerpo'},
      {'word': 'fisherman', 'list_name': 'Gente'},
      {'word': 'breakfast', 'list_name': 'Comida'},
      {'word': 'school', 'list_name': 'Lugares'},
      {'word': 'taxi', 'list_name': 'Transporte'},
      {'word': 'train', 'list_name': 'Transporte'},
      {'word': 'bus', 'list_name': 'Transporte'},
      {'word': 'subway', 'list_name': 'Transporte'},
      {'word': 'walk', 'list_name': 'Acciones'},
      {'word': 'bicycle', 'list_name': 'Transporte'},
      {'word': 'art', 'list_name': 'Metas'},
      {'word': 'English', 'list_name': 'Metas'},
      {'word': 'music', 'list_name': 'Metas'},
      {'word': 'math', 'list_name': 'Metas'},
      {'word': 'health', 'list_name': 'Metas'},
      {'word': 'science', 'list_name': 'Metas'},
      {'word': 'gym', 'list_name': 'Lugares'},
      {'word': 'cafeteria', 'list_name': 'Lugares'},
      {'word': 'classroom', 'list_name': 'Lugares'},
      {'word': 'wave', 'list_name': 'Naturaleza'},
      {'word': 'wait', 'list_name': 'Acciones'},
      {'word': 'pond', 'list_name': 'Naturaleza'},
      {'word': 'watch', 'list_name': 'Objetos'},
      {'word': 'play', 'list_name': 'Acciones'},
      {'word': 'smile', 'list_name': 'Acciones'},
      {'word': 'juggle', 'list_name': 'Acciones'},
      {'word': 'bounce', 'list_name': 'Acciones'},
      {'word': 'push', 'list_name': 'Acciones'},
      {'word': 'pull', 'list_name': 'Acciones'},
      {'word': 'carry', 'list_name': 'Acciones'},
      {'word': 'candy', 'list_name': 'Comida'},
      {'word': 'movie', 'list_name': 'Entretenimiento'},
      {'word': 'turkey', 'list_name': 'Comida'},
      {'word': 'roast', 'list_name': 'Comida'},
      {'word': 'bacon', 'list_name': 'Comida'},
      {'word': 'oysters', 'list_name': 'Comida'},
      {'word': 'shrimp', 'list_name': 'Comida'}
    ];

    // Lista de palabras únicas (para evitar duplicados en el bucle).
    final List<String> uniqueWords = [];

    try {
      for (final entry in sampleWordLists) {
        final wordText = entry['word'] as String;
        final listName = entry['list_name'] as String;

        // Obtener el ID de la palabra *usando getWordByText*.
        final word = await getWordByText(db, wordText);

        if (word != null) {
          // Insertar la asociación en word_lists, *solo si* la palabra existe.
          await db.insert(
            DBHelper().tableWordLists,
            {'word_id': word.id, 'list_name': listName},
          );

          //Añadimos la palabra a "Todas" si es que aun no ha sido agregada a la lista
          if (!uniqueWords.contains(wordText)) {
            await db.insert(
              DBHelper().tableWordLists,
              {'word_id': word.id, 'list_name': 'Todas'}, // Agregar a "Todas"
            );
            uniqueWords.add(wordText); // Agrega la palabra a la lista
          }
        } else {
          print(
              'Error: No se encontró la palabra "$wordText" al cargar listas.');
        }
      }
    } catch (e) {
      print("Error loading sample word lists data: $e");
      rethrow; //Importante
    }
  }
}
