import 'package:path/path.dart';
import 'package:spelling_bee_practice/helpers/initdb_helper.dart';
import 'package:sqflite/sqflite.dart';

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
  String tableCategories = 'categories';
  String tableWordLists = 'word_lists';
  String tablePracticeHistory = 'practice_history';

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'spellingbee.db');
    //  Incrementa la versión a 5 para reflejar todos los cambios en la BD.
    return await openDatabase(path,
        version: 5, onCreate: _onCreate, onUpgrade: _onUpgrade);
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
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            word_ids TEXT NOT NULL,
            isFixed BOOLEAN
          )
        ''');
    // Crear la tabla 'word_lists' (tabla de unión) en la versión 5
    await db.execute('''
        CREATE TABLE $tableWordLists (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word_id INTEGER NOT NULL,
          list_name TEXT NOT NULL,
          FOREIGN KEY (word_id) REFERENCES $tableWords(id) ON DELETE CASCADE
        )
      ''');

    await db.execute('''
          CREATE TABLE $tablePracticeHistory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL,
            session_id INTEGER NOT NULL,
            is_correct BOOLEAN NOT NULL,
            practiced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            session_type TEXT NOT NULL,
            FOREIGN KEY (word_id) REFERENCES words(id),
            FOREIGN KEY (session_id) REFERENCES practice_sessions (id)
          )
        ''');
    // Crear sesiones fijas DESPUÉS de crear las tablas.
    //await _createFixedSessions(db);

    await InitDB.loadInitialData(db);
  }

  Future<void> _createFixedSessions(Database db) async {
    // <- Recibe db
    await db.insert(
        'practice_sessions',
        {
          'id': -1, // ID negativo para "Errores"
          'name': 'Errores',
          'created_at': DateTime.now().toIso8601String(),
          'word_ids': '', // Inicialmente vacía
          'isFixed': 1, //  true (1 en SQLite)
        },
        conflictAlgorithm:
            ConflictAlgorithm.ignore); //Evita errores si ya existe

    await db.insert(
        'practice_sessions',
        {
          'id': -3, // ID negativo para "Todas"
          'name': 'Todas',
          'created_at': DateTime.now().toIso8601String(),
          'word_ids': '', // Inicialmente vacía
          'isFixed': 1, //  true (1 en SQLite)
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  //  onUpgrade para manejar cambios en la estructura de la BD.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
            ALTER TABLE practice_history
            ADD COLUMN session_type TEXT NOT NULL DEFAULT 'session'
        ''');
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE words ADD COLUMN correct_count INTEGER DEFAULT 0');
      await db.execute(
          'ALTER TABLE words ADD COLUMN incorrect_count INTEGER DEFAULT 0');
      await db.execute(
          'ALTER TABLE words ADD COLUMN total_incorrect_count INTEGER DEFAULT 0');
    }
    if (oldVersion < 4) {
      // await _createFixedSessions(db); //Se movio a la version 5
    }
    if (oldVersion < 5) {
      //  Crear la tabla 'word_lists'
      await db.execute('''
        CREATE TABLE $tableWordLists (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word_id INTEGER NOT NULL,
          list_name TEXT NOT NULL,
          FOREIGN KEY (word_id) REFERENCES $tableWords(id) ON DELETE CASCADE
        )
      ''');
      await _createFixedSessions(db); //  crear/insertar las sesiones fijas
    }
  }
}
