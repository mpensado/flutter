import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _database;
  static final DBHelper _instance =
      DBHelper._privateConstructor(); // Instancia Singleton

  factory DBHelper() {
    return _instance;
  }

  DBHelper._privateConstructor(); // Constructor privado

  String tableWords = 'words';
  String tablePractice = 'practice';
  String tableCategories = 'categories'; // Aunque no la uses, la dejo por si acaso

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'word_trainer_database.db');
    // Incrementa la versión a 4 para reflejar todos los cambios en la BD.
    return await openDatabase(path, version: 4, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }


  Future<void> _onCreate(Database db, int version) async {
    // Crear tabla de categorías (si la necesitas en el futuro)
    await db.execute('''
      CREATE TABLE $tableCategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Crear tabla de palabras (con los contadores)
    await db.execute('''
      CREATE TABLE $tableWords (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        translation TEXT NOT NULL,
        pronunciation TEXT,
        spelling TEXT,
        category_id INTEGER,
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        last_practice TIMESTAMP,
        correct_count INTEGER DEFAULT 0,
        incorrect_count INTEGER DEFAULT 0,
        total_incorrect_count INTEGER DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES $tableCategories (id)
      )
    ''');

    // Crear tabla de práctica (sin cambios, pero la incluyo para que esté completa)
    await db.execute('''
      CREATE TABLE $tablePractice (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER,
        success BOOLEAN,
        practice_type TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (word_id) REFERENCES $tableWords (id)
      )
    ''');

    // Crear tabla de sesiones de práctica (sin cambios)
    await db.execute('''
      CREATE TABLE practice_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        word_ids TEXT NOT NULL
      )
    ''');

     //Crear tabla practice_history
    await db.execute(''' 
      CREATE TABLE practice_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER NOT NULL,
        session_id INTEGER NOT NULL,
        is_correct BOOLEAN NOT NULL,
        practiced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        session_type TEXT NOT NULL,
        FOREIGN KEY (word_id) REFERENCES words (id),
        FOREIGN KEY (session_id) REFERENCES practice_sessions (id)
      )
    ''');

    // Crear sesiones fijas DESPUÉS de crear las tablas.
    await _createFixedSessions(db);
  }
  Future<void> _createFixedSessions(Database db) async{
    await db.insert('practice_sessions', {
      'id': -1, // ID negativo para "Errores"
      'name': 'Errores',
      'created_at': DateTime.now().toIso8601String(),
      'word_ids': '', // Inicialmente vacía
    }, conflictAlgorithm: ConflictAlgorithm.ignore); //Evita errores si ya existe

    await db.insert('practice_sessions', {
      'id': -2, // ID negativo para "No Practicadas"
      'name': 'No Practicadas',
      'created_at': DateTime.now().toIso8601String(),
      'word_ids': '', // Inicialmente vacía
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('practice_sessions', {
      'id': -3, // ID negativo para "Todas"
      'name': 'Todas',
      'created_at': DateTime.now().toIso8601String(),
      'word_ids': '', // Inicialmente vacía
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
}

  // IMPORTANTÍSIMO: Implementar onUpgrade para manejar cambios en la estructura de la BD.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
        await db.execute('''
            ALTER TABLE practice_history
            ADD COLUMN session_type TEXT NOT NULL DEFAULT 'session'
        ''');
    }
    if (oldVersion < 3) {
        await db.execute('ALTER TABLE words ADD COLUMN correct_count INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE words ADD COLUMN incorrect_count INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE words ADD COLUMN total_incorrect_count INTEGER DEFAULT 0');
    }
    if(oldVersion < 4){
        await _createFixedSessions(db);
    }
  }
}

Future<void> loadSampleData() async {
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

    // final sessionId = await db.insert('practice_sessions', {
    //   'name': '3o de Primaria',
    //   'created_at': DateTime.now().toIso8601String(),
    //   'word_ids': wordIds.join(','),
    // });

    // final sampleHistory = [
    //   {
    //     'word_id': wordIds[0],
    //     'session_id': sessionId,
    //     'is_correct': 1,
    //     'practiced_at':
    //         DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    //   },
    //   {
    //     'word_id': wordIds[1],
    //     'session_id': sessionId,
    //     'is_correct': 1,
    //     'practiced_at':
    //         DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    //   },
    //   {
    //     'word_id': wordIds[2],
    //     'session_id': sessionId,
    //     'is_correct': 0,
    //     'practiced_at':
    //         DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    //   },
    // ];

    // for (var historyData in sampleHistory) {
    //   await db.insert('practice_history', historyData);
    // }
  } catch (e) {
    print("Error loading sample data: $e");
    // Consider showing a SnackBar to the user.  You'll need a BuildContext.
  }
}
