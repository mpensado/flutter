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
        version: 5, onCreate: _onCreate);
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
            correct_count INTEGER DEFAULT 0,
            incorrect_count INTEGER DEFAULT 0,
            total_incorrect_count INTEGER DEFAULT 0,
            practiced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            session_type TEXT NOT NULL,
            list_name TEXT NOT NULL,
            FOREIGN KEY (word_id) REFERENCES words(id),
            FOREIGN KEY (session_id) REFERENCES practice_sessions (id)
          )
        ''');
    // Crear sesiones fijas DESPUÉS de crear las tablas.
    //await _createFixedSessions(db);

    await InitDB.loadInitialData(db);
  }
}
