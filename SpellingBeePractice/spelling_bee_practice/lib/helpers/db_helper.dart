import 'dart:io';

import 'package:spelling_bee_practice/infrastructure/repositories/practice_session_repository.dart';
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
    String path = join(await getDatabasesPath(), 'spellingbee.db');
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
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        word_ids TEXT NOT NULL,
        isFixed BOOLEAN
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
        await PracticeSessionRepository.createFixedSessions();
    }
  }

  static Future<String?> _createTemporaryDatabaseCopy() async {
    try {
      String dbPath = await getDatabasesPath();
      String originalDbPath = join(dbPath, 'spellingbee.db');
      String tempDbPath = join(dbPath, 'temp_spellingbee.db');

      // Copia la base de datos a un archivo temporal
      File originalDbFile = File(originalDbPath);
      await originalDbFile.copy(tempDbPath);

      return tempDbPath; // Devuelve la ruta del archivo temporal

    } catch (e) {
      print('Error al crear la copia temporal de la base de datos: $e');
      return null;
    }
  }

  static Future<void> copyTempDbToLaptop() async {
    String? tempDbPath = await _createTemporaryDatabaseCopy();
    if (tempDbPath != null) {
      // Usa adb para copiar el archivo TEMPORAL
      // (¡IMPORTANTE! Usa el comando adb adaptado al archivo temporal)
      ProcessResult result = await Process.run('adb', [
        'shell',
        'run-as',
        'com.example.spelling_bee_practice',
        'cat',
        tempDbPath,
        '>',
        'spellingbee.db' // Nombre en tu LAPTOP
      ]);

      if (result.exitCode == 0) {
        print("Base de Datos temporal copiada a la laptop.");
      }
      else
      {
          print("Error al copiar: ${result.stderr}");
      }
    }
  }

}