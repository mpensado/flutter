import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Diccionario',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();

  static _HomePageState of(BuildContext context) =>
      context.findAncestorStateOfType<_HomePageState>()!;
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _spelling(String word) {
    String letterSeparated = '';
    List<String> words =
        word.split(' '); // Separar por espacios para palabras compuestas
    for (int i = 0; i < words.length; i++) {
      String currentWord = words[i];
      for (int j = 0; j < currentWord.length; j++) {
        letterSeparated += currentWord[j];
        if (j < currentWord.length - 1) {
          letterSeparated += ','; // Coma entre letras
        }
      }
      if (i < words.length - 1) {
        letterSeparated += ',,'; // Doble coma entre palabras compuestas
      }
    }
    return letterSeparated;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Diccionario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Implementar configuración
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Palabras', icon: Icon(Icons.book)),
            Tab(text: 'Práctica', icon: Icon(Icons.edit)),
            Tab(text: 'Estadísticas', icon: Icon(Icons.bar_chart)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          WordsTab(),
          PracticeTab(),
          StatsTab(),
        ],
      ),
    );
  }

  void _showAddWordDialog(BuildContext context, VoidCallback onWordAdded) {
    final wordController = TextEditingController();
    final translationController = TextEditingController();
    bool isAutoTranslating = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Nueva Palabra'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: wordController,
                  decoration: const InputDecoration(
                    labelText: 'Palabra en Inglés',
                  ),
                ),
                const SizedBox(height: 8),
                Focus(
                  onFocusChange: (hasFocus) async {
                    if (hasFocus &&
                        isAutoTranslating &&
                        wordController.text.isNotEmpty) {
                      try {
                        final translatedText =
                            await TranslationService.translate(
                                text: wordController.text,
                                from: 'en',
                                to: 'es');
                        translationController.text = translatedText;
                        setState(() {});
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Error al traducir. Intente nuevamente.'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: TextField(
                    controller: translationController,
                    decoration: InputDecoration(
                      labelText: 'Traducción',
                      suffixIcon: IconButton(
                        icon: Icon(
                          isAutoTranslating ? Icons.sync : Icons.sync_disabled,
                          color: isAutoTranslating ? Colors.green : Colors.red,
                        ),
                        tooltip: isAutoTranslating
                            ? 'Traducción automática activada'
                            : 'Traducción automática desactivada',
                        onPressed: () {
                          setState(() {
                            isAutoTranslating = !isAutoTranslating;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  if (wordController.text.isNotEmpty &&
                      translationController.text.isNotEmpty) {
                    final word = Word(
                      word: wordController.text,
                      translation: translationController.text,
                      spelling:
                          "${wordController.text}.${_spelling(wordController.text)}.${wordController.text}",
                      createdAt: DateTime.now(),
                    );
                    await WordRepository.insertWord(word);
                    if (context.mounted) {
                      Navigator.pop(context);
                      onWordAdded();
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Por favor complete todos los campos'),
                      ),
                    );
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class WordsTab extends StatefulWidget {
  const WordsTab({super.key});

  @override
  State<WordsTab> createState() => _WordsTabState();
}

class _WordsTabState extends State<WordsTab> {
  List<Word> words = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    print('Cargando palabras en _WordsTabState');
    if (searchQuery.isEmpty) {
      print('Cargando TODAS las palabras');
      words = await WordRepository.getAllWords();
    } else {
      words = await WordRepository.searchWords(searchQuery);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Envolvemos el Column con Scaffold para el FAB
      floatingActionButton: FloatingActionButton(
        // FAB AHORA en WordsTab
        onPressed: () {
          (HomePage.of(context))._showAddWordDialog(context, _loadWords);
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        // Column ahora como body del Scaffold
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SearchBar(
              hintText: 'Buscar palabra...',
              leading: const Icon(Icons.search),
              onChanged: (value) {
                searchQuery = value;
                _loadWords();
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadWords,
              child: ListView.builder(
                itemCount: words.length,
                itemBuilder: (context, index) {
                  return WordCard(
                    word: words[index],
                    onDelete: () async {
                      await WordRepository.deleteWord(words[index].id!);
                      _loadWords();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WordCard extends StatelessWidget {
  final Word word;
  final VoidCallback onDelete;

  const WordCard({
    super.key,
    required this.word,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              // mainAxisAlignment: MainAxisAlignment.spaceBetween, // Ya no es necesario spaceBetween aquí
              children: [
                Expanded(
                  // Usamos Expanded para que el Text ocupe todo el espacio posible a la izquierda
                  child: Text(
                    word.word,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign
                        .start, // Alineamos el texto a la izquierda dentro del espacio Expanded
                  ),
                ),
                Row(
                  // Row para agrupar los iconos a la derecha
                  mainAxisSize: MainAxisSize
                      .min, // Para que el Row de iconos solo ocupe el espacio necesario
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        // TODO: Implementar configuración
                      },
                    ),
                    const SizedBox(
                        width:
                            8), // Añadimos un SizedBox para un pequeño espacio entre iconos
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
            Text(
              word.translation,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // Pronunciar la palabra
                    TextToSpeechService.speak(word.word);
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Escuchar'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // Deletrear la palabra
                    TextToSpeechService.speak(word.spelling);
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Deletrear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WordCardPractice extends StatefulWidget {
  final Word word;
  final VoidCallback onDelete;
  // **MODIFIED: Rename and change type to receive the callback function directly**
  final void Function(
          Word word, bool isCorrect, _WordCardPracticeState cardState)
      onRecordPracticeCallback; // <---- CHANGED TO void Function(...)

  const WordCardPractice({
    super.key,
    required this.word,
    required this.onDelete,
    required this.onRecordPracticeCallback, // <---- UPDATED CONSTRUCTOR
  });

  @override
  State<WordCardPractice> createState() => _WordCardPracticeState();
}

class _WordCardPracticeState extends State<WordCardPractice> {
  bool isPracticed = false;
  bool? practiceResult;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6.0),
        side: BorderSide(
            width: 6.0,
            color: practiceResult == true
                ? Colors.green
                : practiceResult == false
                    ? Colors.red
                    : Colors.transparent,
        ),
    ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.word.word,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.start,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Buttons in the top right corner
                    IconButton(
                      icon: const Icon(Icons.check_circle),
                      color: Colors.green,
                      onPressed: () {
                        print(
                            "WordCardPractice: Botón ACIERTO presionado para palabra: ${widget.word.word}");
                        // **MODIFIED: Call the passed callback DIRECTLY**
                        widget.onRecordPracticeCallback(widget.word, true,
                            this); // <---- DIRECT CALL to callback
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel),
                      color: Colors.red,
                      onPressed: () {
                        print(
                            "WordCardPractice: Botón ERROR presionado para palabra: ${widget.word.word}");
                        // **MODIFIED: Call the passed callback DIRECTLY**
                        widget.onRecordPracticeCallback(widget.word, false,
                            this); // <---- DIRECT CALL to callback
                      },
                    ),
                  ],
                ),
              ],
            ),
            Text(
              widget.word.translation,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    TextToSpeechService.speak(widget.word.word);
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Escuchar'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    TextToSpeechService.speak(widget.word.spelling);
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Deletrear'),
                ),
                ElevatedButton.icon(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.remove),
                  label: const Text('Quitar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Pantalla de Estadísticas'),
    );
  }
}

// db_helper.dart

class DBHelper {
  static Database? _database;
  static const String dbName = 'dictionary.db';

  // Nombres de tablas
  static const String tableWords = 'words';
  static const String tablePractice = 'practice';
  static const String tableCategories = 'categories';

  // Obtener instancia de base de datos
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB();
    return _database!;
  }

  // Inicializar base de datos
  static Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), dbName);
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        // Crear tabla de categorías
        await db.execute('''
          CREATE TABLE $tableCategories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // Crear tabla de palabras
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

        // Crear tabla de práctica
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

        await db.execute('''
          CREATE TABLE practice_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            word_ids TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE practice_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL,
            session_id INTEGER NOT NULL,
            is_correct BOOLEAN NOT NULL,
            practiced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (word_id) REFERENCES words (id),
            FOREIGN KEY (session_id) REFERENCES practice_sessions (id)
          )
        ''');
      },
    );
  }
}

// word_model.dart
class Word {
  final int? id;
  final String word;
  final String translation;
  final String? pronunciation;
  final String spelling;
  final int? categoryId;
  final String? notes;
  final DateTime createdAt;
  final DateTime? lastPractice;

  Word({
    this.id,
    required this.word,
    required this.translation,
    this.pronunciation,
    required this.spelling,
    this.categoryId,
    this.notes,
    required this.createdAt,
    this.lastPractice,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'translation': translation,
      'pronunciation': pronunciation,
      'spelling': spelling,
      'category_id': categoryId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'last_practice': lastPractice?.toIso8601String(),
    };
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'],
      word: map['word'],
      translation: map['translation'],
      pronunciation: map['pronunciation'],
      spelling: map['spelling'],
      categoryId: map['category_id'],
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
      lastPractice: map['last_practice'] != null
          ? DateTime.parse(map['last_practice'])
          : null,
    );
  }
}

// word_repository.dart
class WordRepository {
  // Insertar nueva palabra
  static Future<int> insertWord(Word word) async {
    final db = await DBHelper.database;
    return await db.insert(DBHelper.tableWords, word.toMap());
  }

  // Obtener todas las palabras
  static Future<List<Word>> getAllWords() async {
    final db = await DBHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(DBHelper.tableWords);
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  // Buscar palabras
  static Future<List<Word>> searchWords(String query) async {
    final db = await DBHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DBHelper.tableWords,
      where: 'word LIKE ? OR translation LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  // Actualizar palabra
  static Future<int> updateWord(Word word) async {
    final db = await DBHelper.database;
    return await db.update(
      DBHelper.tableWords,
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  // Eliminar palabra
  static Future<int> deleteWord(int id) async {
    final db = await DBHelper.database;
    return await db.delete(
      DBHelper.tableWords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Actualizar última práctica
  static Future<int> updateLastPractice(int wordId) async {
    final db = await DBHelper.database;
    return await db.update(
      DBHelper.tableWords,
      {'last_practice': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [wordId],
    );
  }
}

class TextToSpeechService {
  static FlutterTts? _flutterTts;

  // Método para obtener o inicializar la instancia de FlutterTts
  static Future<FlutterTts> _getInstance() async {
    if (_flutterTts == null) {
      _flutterTts = FlutterTts();

      try {
        // Intentar configurar opciones básicas
        await _flutterTts!.setLanguage('en-US');
        await _flutterTts!.setPitch(1.0);
        await _flutterTts!.setSpeechRate(0.5);
        await _flutterTts!.setVolume(1.0);
      } catch (e) {
        debugPrint('Error inicializando TTS: $e');
      }
    }
    return _flutterTts!;
  }

  // Método para pronunciar una palabra
  static Future<void> speak(String text) async {
    try {
      final tts = await _getInstance();
      await tts.speak(text);
    } catch (e) {
      debugPrint('Error al pronunciar: $e');
    }
  }

  // Detener la pronunciación
  static Future<void> stop() async {
    try {
      final tts = await _getInstance();
      await tts.stop();
    } catch (e) {
      debugPrint('Error al detener TTS: $e');
    }
  }
}

class TranslationService {
  static final GoogleTranslator _translator = GoogleTranslator();

  static Future<String> translate(
      {required String text, String from = 'en', String to = 'es'}) async {
    try {
      Translation translation =
          await _translator.translate(text, from: from, to: to);
      return translation.text;
    } catch (e) {
      return text; // En caso de error, retorna el mismo texto sin traducir
    }
  }
}

//VISTA DE PRACTICAS
// Modelo para las sesiones de práctica
class PracticeSession {
  final int? id;
  final String name;
  final DateTime createdAt;
  final List<int> wordIds;

  PracticeSession({
    this.id,
    required this.name,
    required this.createdAt,
    required this.wordIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'word_ids':
          wordIds.join(','), // Guardamos los IDs como string separado por comas
    };
  }

  factory PracticeSession.fromMap(Map<String, dynamic> map) {
    // Manejar el caso cuando word_ids es una cadena
    List<int> parseWordIds(dynamic wordIdsData) {
      if (wordIdsData is String) {
        return wordIdsData
            .split(',')
            .where((str) => str.isNotEmpty)
            .map((str) => int.parse(str.trim()))
            .toList();
      }
      // Si ya es una lista, convertir cada elemento a int
      else if (wordIdsData is List) {
        return wordIdsData.map((e) => int.parse(e.toString())).toList();
      }
      // Si no es ninguno de los anteriores, retornar lista vacía
      return [];
    }

    return PracticeSession(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['created_at']),
      wordIds: parseWordIds(map['word_ids']),
    );
  }
}

// Modelo para el historial de práctica
class PracticeHistory {
  final int? id;
  final int wordId;
  final int sessionId;
  final bool isCorrect;
  final DateTime practicedAt;

  PracticeHistory({
    this.id,
    required this.wordId,
    required this.sessionId,
    required this.isCorrect,
    required this.practicedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word_id': wordId,
      'session_id': sessionId,
      'is_correct': isCorrect ? 1 : 0,
      'practiced_at': practicedAt.toIso8601String(),
    };
  }

  factory PracticeHistory.fromMap(Map<String, dynamic> map) {
    return PracticeHistory(
      id: map['id'],
      wordId: map['word_id'],
      sessionId: map['session_id'],
      isCorrect: map['is_correct'] == 1,
      practicedAt: DateTime.parse(map['practiced_at']),
    );
  }
}

class PracticeTab extends StatefulWidget {
  const PracticeTab({super.key});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  List<Word> words = [];
  List<PracticeSession> sessions = [];
  PracticeSession? selectedSession;
  Set<int> practicedWords = {};
  int correctCount = 0;
  int incorrectCount = 0;

  // Modificar el método initState en PracticeTab para cargar los datos de ejemplo
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Verificar si ya existen datos
    final db = await DBHelper.database;
    final wordCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DBHelper.tableWords}'));

    // Si no hay datos, cargar los datos de ejemplo
    if (wordCount == 0) {
      await loadSampleData();
    }

    // Cargar las sesiones
    await _loadSessions();
  }

  Future<void> _loadSessions() async {
    // Cargar las sesiones desde la base de datos
    final db = await DBHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('practice_sessions');
    setState(() {
      sessions =
          List.generate(maps.length, (i) => PracticeSession.fromMap(maps[i]));
    });
  }

  Future<void> _loadSessionWords() async {
    if (selectedSession != null) {
      // Cambia el tipo de la lista temporalmente para permitir nulos durante el proceso
      List<Word?> possibleWords = await Future.wait(
        selectedSession!.wordIds.map((id) async {
          final db = await DBHelper.database;
          print(
              'Cargando palabra con ID: $id'); // Añadido log ANTES de la query
          final List<Map<String, dynamic>> maps = await db.query(
            DBHelper.tableWords,
            where: 'id = ?',
            whereArgs: [id],
          );
          print(
              'Resultado de la query para ID $id: $maps'); // Añadido log DESPUÉS de la query
          if (maps.isEmpty) {
            print(
                'Error: No se encontró ninguna palabra con ID: $id'); // Log si no se encuentra la palabra
            // Retorna un Future<Word?> que se completa con null
            return Future<Word?>.value(null);
          }
          return Word.fromMap(maps.first);
        }),
      );
      // Filtra los valores nulos de la lista resultingWords y asigna el resultado a words
      words = possibleWords
          .whereType<Word>()
          .toList(); // Usa whereType<Word>() para filtrar los null y asegurar List<Word>
      setState(() {});
    }
  }

  Future<void> _recordPractice(Word word, bool isCorrect) async {
    if (selectedSession != null) {
      final practice = PracticeHistory(
        wordId: word.id!,
        sessionId: selectedSession!.id!,
        isCorrect: isCorrect,
        practicedAt: DateTime.now(),
      );

      final db = await DBHelper.database;
      await db.insert('practice_history', practice.toMap());

      setState(() {
        print(
            "_recordPractice: setState de PracticeTab -  Correcto: $isCorrect, Aciertos: ${correctCount + (isCorrect ? 1 : 0)}, Errores: ${incorrectCount + (isCorrect ? 0 : 1)}"); // <--- AÑADE ESTE PRINT
        practicedWords.add(word.id!);
        if (isCorrect) {
          correctCount++;
        } else {
          incorrectCount++;
        }
      });
    }
  }

  // Wrapper para _recordPractice que también actualiza el estado del WordCard
  void _recordPracticeWrapper(
      Word word, bool isCorrect, _WordCardPracticeState cardState) {
    print(
        "_recordPracticeWrapper:  Palabra: ${word.word}, Correcto: $isCorrect"); // <--- AÑADE ESTE PRINT al INICIO
    _recordPractice(word, isCorrect);
    cardState.setState(() {
      print(
          "_recordPracticeWrapper: setState de cardState -  Resultado: $isCorrect"); // <--- AÑADE ESTE PRINT dentro del setState
      cardState.isPracticed = true;
      cardState.practiceResult = isCorrect;
    });
  }

  void _resetPractice() {
    setState(() {
      practicedWords.clear();
      correctCount = 0;
      incorrectCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<PracticeSession>(
                    value: selectedSession,
                    hint: const Text('Seleccionar sesión'),
                    isExpanded: true,
                    items: sessions.map((session) {
                      return DropdownMenuItem(
                        value: session,
                        child: Text(session.name),
                      );
                    }).toList(),
                    onChanged: (PracticeSession? newValue) {
                      setState(() {
                        selectedSession = newValue;
                        _resetPractice();
                        _loadSessionWords();
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _resetPractice();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Aciertos: $correctCount | Errores: $incorrectCount',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: words.length,
              itemBuilder: (context, index) {
                final word = words[index];
                final bool isPracticed = practicedWords.contains(word.id);

                return WordCardPractice(
                  // WordCard AHORA ES STATEFULWIDGET
                  word: word,
                  onDelete: () async {
                    await WordRepository.deleteWord(words[index].id!);
                    _loadSessionWords();
                  },
                  // **MODIFIED: Pass _recordPracticeWrapper directly as a callback**
                  onRecordPracticeCallback:
                      _recordPracticeWrapper, // <---- PASS _recordPracticeWrapper HERE
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Función para cargar datos de ejemplo
Future<void> loadSampleData() async {
  final db = await DBHelper.database;

  // Lista de palabras de ejemplo
  final List<Map<String, dynamic>> sampleWords = [
    {
      'word': 'house',
      'translation': 'casa',
      'spelling': 'house.h,o,u,s,e.house',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'word': 'book',
      'translation': 'libro',
      'spelling': 'book.b,o,o,k.book',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'word': 'car',
      'translation': 'coche',
      'spelling': 'car.c,a,r.car',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'word': 'tree',
      'translation': 'árbol',
      'spelling': 'tree.t,r,e,e.tree',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'word': 'dog',
      'translation': 'perro',
      'spelling': 'dog.d,o,g.dog',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'word': 'cat',
      'translation': 'gato',
      'spelling': 'cat.c,a,t.cat',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'word': 'table',
      'translation': 'mesa',
      'spelling': 'table.t,a,b,l,e.table',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'word': 'phone',
      'translation': 'teléfono',
      'spelling': 'phone.p,h,o,n,e.phone',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'word': 'computer',
      'translation': 'computadora',
      'spelling': 'computer.c,o,m,p,u,t,e,r.computer',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'word': 'water',
      'translation': 'agua',
      'spelling': 'water.w,a,t,e,r.water',
      'created_at': DateTime.now().toIso8601String(),
    },
  ];

  // Insertar palabras y obtener sus IDs
  List<int> wordIds = [];
  for (var wordData in sampleWords) {
    final id = await db.insert(DBHelper.tableWords, wordData);
    wordIds.add(id);
  }

  // Crear una sesión de práctica de ejemplo
  final sessionId = await db.insert('practice_sessions', {
    'name': 'Vocabulario básico',
    'created_at': DateTime.now().toIso8601String(),
    'word_ids': wordIds.join(','),
  });

  // Crear algunos registros históricos de ejemplo
  final sampleHistory = [
    {
      'word_id': wordIds[0],
      'session_id': sessionId,
      'is_correct': 1,
      'practiced_at':
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    },
    {
      'word_id': wordIds[1],
      'session_id': sessionId,
      'is_correct': 1,
      'practiced_at':
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    },
    {
      'word_id': wordIds[2],
      'session_id': sessionId,
      'is_correct': 0,
      'practiced_at':
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    },
  ];

  for (var historyData in sampleHistory) {
    await db.insert('practice_history', historyData);
  }
}
