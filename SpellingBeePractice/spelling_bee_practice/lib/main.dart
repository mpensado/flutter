import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';
import 'dart:math';

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
          letterSeparated += '---'; // Coma entre letras
        }
      }
      if (i < words.length - 1) {
        letterSeparated +=
            '---space---'; // Doble coma entre palabras compuestas
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
            Tab(text: 'SpelliongBee', icon: Icon(Icons.bug_report_rounded)),
            //Tab(text: 'Estadísticas', icon: Icon(Icons.bar_chart)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          WordsTab(),
          PracticeTab(),
          SpellingBeeView(),
          //StatsTab(),
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
  final void Function(
          Word word, bool isCorrect, _WordCardPracticeState cardState)
      onRecordPracticeCallback;
  final Set<int> practicedWords;
  final PracticeSession? selectedSession; // <---- ASEGÚRATE DE QUE ESTÉ AÑADIDO
  final int resetCounter; // <---- AÑADE ESTA LÍNEA:  Propiedad resetCounter
  final bool
      showRemoveButton; // <---- AÑADE ESTA LÍNEA: Nueva propiedad showRemoveButton

  const WordCardPractice({
    super.key,
    required this.word,
    required this.onDelete,
    required this.onRecordPracticeCallback,
    required this.practicedWords,
    this.selectedSession, // <---- ASEGÚRATE DE QUE ESTÉ EN EL CONSTRUCTOR
    required this.resetCounter, // <---- ASEGÚRATE DE AÑADIR resetCounter AQUÍ
    this.showRemoveButton =
        true, // <----  Valor por defecto: true (mostrar botón)
  });

  @override
  State<WordCardPractice> createState() => _WordCardPracticeState();
}

class _WordCardPracticeState extends State<WordCardPractice> {
  bool isPracticed = false;
  bool? practiceResult;

  @override
  void initState() {
    print(
        "initState de _WordCardPracticeState ejecutándose para palabra: ${widget.word.word}"); // <---- AÑADE ESTE PRINT
    super.initState();
    isPracticed = widget.practicedWords.contains(widget.word.id);

    // **INICIALIZAR practiceResult BASADO EN practicedWords (y si es practicada)**
    if (isPracticed) {
      _loadLastPracticeResult(); // <---- LLAMAR a nueva función para cargar el último resultado
    } else {
      practiceResult =
          null; // Si no practicada, practiceResult es null inicialmente
    }
  }

  @override
  void didUpdateWidget(covariant WordCardPractice oldWidget) {
    super.didUpdateWidget(oldWidget);
    // **COMPROBAR SI resetCounter HA CAMBIADO**
    if (widget.resetCounter != oldWidget.resetCounter) {
      print(
          "didUpdateWidget de _WordCardPracticeState - resetCounter ha cambiado. Reseteando estado.");
      setState(() {
        isPracticed = false; // Forzar isPracticed a false
        practiceResult = null; // Forzar practiceResult a null
      });
    }
  }

  Future<void> _loadLastPracticeResult() async {
    // Función para cargar el último resultado de práctica desde la base de datos
    final dbHelper =
        DBHelper(); // Create an instance (if you don't have one already in scope)
    final db = await dbHelper.database; // Correct instance access
    final List<Map<String, dynamic>> history = await db.query(
      'practice_history',
      orderBy:
          'practiced_at DESC', // Ordenar por fecha descendente para obtener el más reciente primero
      where: 'word_Id = ? AND session_Id = ?',
      whereArgs: [
        widget.word.id,
        widget.selectedSession?.id
      ], // Filtrar por palabra y sesión actual
      limit: 1, // Limitar a 1 resultado (el más reciente)
    );

    if (history.isNotEmpty) {
      final lastPractice = PracticeHistory.fromMap(history.first);
      setState(() {
        practiceResult = lastPractice
            .isCorrect; // Establecer practiceResult con el resultado del historial
      });
    } else {
      practiceResult =
          null; // Si no hay historial, practiceResult es null (aunque isPracticed sea true, caso raro)
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        "_WordCardPracticeState - build: Palabra: ${widget.word.word}, isPracticed: $isPracticed, practiceResult: $practiceResult"); // <---- AÑADIR ESTE PRINT
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
        side: BorderSide(
          width: 2.0,
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
                    if (!isPracticed) ...[
                      IconButton(
                        icon: const Icon(Icons.check_circle),
                        color: Colors.green,
                        onPressed: () {
                          widget.onRecordPracticeCallback(
                              widget.word, true, this);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel),
                        color: Colors.red,
                        onPressed: () {
                          widget.onRecordPracticeCallback(
                              widget.word, false, this);
                        },
                      ),
                    ],
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
                if (widget
                    .showRemoveButton) // <----  CONDICIÓN: Mostrar solo si showRemoveButton es true
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

class DBHelper {
  static Database? _database;

  // Nombres de tablas
  String tableWords = 'words';
  String tablePractice = 'practice';
  String tableCategories = 'categories';

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  // Inicializar base de datos
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'word_trainer_database.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
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
  }
} // word_model.dart

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
    final dbHelper =
        DBHelper(); // Create an instance (if you don't have one already in scope)
    final db = await dbHelper.database; // Correct instance access
    return await db.insert(dbHelper.tableWords, word.toMap());
  }

  // Obtener todas las palabras
  static Future<List<Word>> getAllWords() async {
    final dbHelper =
        DBHelper(); // Create an instance (if you don't have one already in scope)
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(dbHelper.tableWords);
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  // Buscar palabras
  static Future<List<Word>> searchWords(String query) async {
    final dbHelper =
        DBHelper(); // Create an instance (if you don't have one already in scope)
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      dbHelper.tableWords,
      where: 'word LIKE ? OR translation LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  // Actualizar palabra
  static Future<int> updateWord(Word word) async {
    final dbHelper =
        DBHelper(); // Create an instance (if you don't have one already in scope)
    final db = await dbHelper.database;
    return await db.update(
      dbHelper.tableWords,
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  // Eliminar palabra
  static Future<int> deleteWord(int id) async {
    final dbHelper =
        DBHelper(); // Create an instance (if you don't have one already in scope)
    final db = await dbHelper.database;
    return await db.delete(
      dbHelper.tableWords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Actualizar última práctica
  static Future<int> updateLastPractice(int wordId) async {
    final dbHelper =
        DBHelper(); // Create an instance (if you don't have one already in scope)
    final db = await dbHelper.database;
    return await db.update(
      dbHelper.tableWords,
      {'last_practice': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [wordId],
    );
  }

  // Ejemplo de cómo modificar WordRepository.getWords() para que sea asíncrona
  static Future<List<Word>> getWords() async {
    final dbHelper = DBHelper();
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(dbHelper.tableWords);
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
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
        await _flutterTts!.setEngine('com.google.android.tts');
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
      print("$e");
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

class _PracticeTabState extends State<PracticeTab>
    with AutomaticKeepAliveClientMixin {
  // <---- AÑADE with AutomaticKeepAliveClientMixin{
  List<Word> words = [];
  List<PracticeSession> sessions = [];
  PracticeSession? selectedSession;
  Set<int> practicedWords = {};
  int correctCount = 0;
  int incorrectCount = 0;
  int resetCounter = 0;

  @override
  bool get wantKeepAlive => true; // <---- AÑADE ESTE MÉTODO Y RETORNA true

  // Modificar el método initState en PracticeTab para cargar los datos de ejemplo
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Verificar si ya existen datos
    final dbHelper =
        DBHelper(); // Create an instance (if you don't have one already in scope)
    final db = await dbHelper.database;
    final wordCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${dbHelper.tableWords}'));

    // Si no hay datos, cargar los datos de ejemplo
    if (wordCount == 0) {
      await loadSampleData();
    }

    // Cargar las sesiones
    await _loadSessions();
  }

  Future<void> _loadSessions() async {
    // Cargar las sesiones desde la base de datos
    final dbHelper = DBHelper();
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('practice_sessions');
    final List<PracticeSession> loadedSessions =
        List.generate(maps.length, (i) => PracticeSession.fromMap(maps[i]));

    setState(() {
      sessions = loadedSessions;

      // **SELECCIONAR AUTOMÁTICAMENTE LA PRIMERA SESIÓN SI HAY ALGUNA**
      if (sessions.isNotEmpty) {
        selectedSession = sessions.first; // Selecciona la primera sesión
        _loadSessionWords(); // Carga las palabras de la sesión seleccionada inmediatamente
      } else {
        selectedSession =
            null; // Si no hay sesiones, selectedSession queda en null
      }
    });
  }

  Future<void> _loadSessionWords() async {
    if (selectedSession != null) {
      // Cambia el tipo de la lista temporalmente para permitir nulos durante el proceso
      List<Word?> possibleWords = await Future.wait(
        selectedSession!.wordIds.map((id) async {
          final dbHelper =
              DBHelper(); // Create an instance (if you don't have one already in scope)
          final db = await dbHelper.database;
          print(
              'Cargando palabra con ID: $id'); // Añadido log ANTES de la query
          final List<Map<String, dynamic>> maps = await db.query(
            dbHelper.tableWords,
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

      final dbHelper =
          DBHelper(); // Create an instance (if you don't have one already in scope)
      final db = await dbHelper.database;
      await db.insert('practice_history', practice.toMap());

      setState(() {
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
    _recordPractice(word, isCorrect);
    cardState.setState(() {
      print(
          "_recordPracticeWrapper: setState de cardState -  Resultado: $isCorrect");
      cardState.practiceResult = isCorrect;
      cardState.isPracticed = true;
      print(
          "_recordPracticeWrapper: setState de cardState - isPracticed DESPUÉS de asignar: ${cardState.isPracticed}"); // <---- AÑADIR ESTE PRINT
    });
  }

  void _resetPractice() {
    setState(() {
      print("_resetPractice: setState ejecutándose!"); // <---- AÑADE ESTE PRINT
      practicedWords.clear();
      correctCount = 0;
      incorrectCount = 0;
      _loadSessionWords();
      resetCounter++; // <---- AÑADE ESTA LÍNEA: Incrementa el contador de reseteo
    });
    print(
        "_resetPractice: Estado de la sesión de práctica y lista de cards reseteados.");
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
                    _loadSessionWords();
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
                  key: Key(word.id
                      .toString()), // <---- AÑADE ESTA LÍNEA: KEY con word.id
                  word: word,
                  onDelete: () async {
                    await WordRepository.deleteWord(words[index].id!);
                    _loadSessionWords();
                  },
                  onRecordPracticeCallback: _recordPracticeWrapper,
                  practicedWords: practicedWords,
                  selectedSession:
                      selectedSession, // <---- ASEGÚRATE DE QUE ESTÉS PASANDO selectedSession AQUÍ
                  resetCounter:
                      resetCounter, // <---- AÑADE ESTA LÍNEA: Pasar resetCounter como propiedad
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
  final dbHelper =
      DBHelper(); // Create an instance (if you don't have one already in scope)
  final db = await dbHelper.database;

  // Lista de palabras de ejemplo
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
  // Insertar palabras y obtener sus IDs
  List<int> wordIds = [];
  for (var wordData in sampleWords) {
    final id = await db.insert(dbHelper.tableWords, wordData);
    wordIds.add(id);
  }

  // Crear una sesión de práctica de ejemplo
  final sessionId = await db.insert('practice_sessions', {
    'name': '3o de Primaria',
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

//VISTA SPELLINGBEE
// Importar para usar Random

class SpellingBeeView extends StatefulWidget {
  const SpellingBeeView({super.key});

  @override
  State<SpellingBeeView> createState() => _SpellingBeeViewState();
}

class _SpellingBeeViewState extends State<SpellingBeeView> {
  int correctCount = 0;
  int incorrectCount = 0;
  List<Word> currentWordList = [];
  int currentWordIndex = 0;
  Word? currentWord;

  @override
  void initState() {
    super.initState();
    _startNewSpellingBeeSession();
  }

  void _startNewSpellingBeeSession() {
    setState(() {
      correctCount = 0;
      incorrectCount = 0;
      currentWordIndex = 0;
      currentWord = null; // Reset currentWord to null initially while loading

      _generateRandomWordList().then((wordList) {
        // Llamar a _generateRandomWordList y usar .then()
        setState(() {
          currentWordList = wordList; // Asignar la lista de palabras obtenida
          _loadCurrentWord(); // Cargar la primera palabra DESPUÉS de obtener la lista
        });
      });
    });
  }

  void _loadCurrentWord() {
    if (currentWordIndex < currentWordList.length) {
      setState(() {
        currentWord = currentWordList[currentWordIndex];
      });
    } else {
      currentWord = null;
      // Aquí mostraremos el score final (implementar después)
    }
  }

  Future<List<Word>> _generateRandomWordList() async {
    // <----  FUNCIÓN async y retorna Future<List<Word>>
    final random = Random();
    final allWordsFuture =
        WordRepository.getWords(); // Obtener Future<List<Word>>
    List<Word> selectedWords = [];
    const numberOfWords = 10;

    try {
      final wordsData =
          await allWordsFuture; // AWAIT para obtener la lista de palabras
      if (wordsData.isNotEmpty) {
        List<Word> shuffledWords = List.from(wordsData);
        shuffledWords.shuffle(random);
        selectedWords = shuffledWords.take(numberOfWords).toList();
      }
    } catch (e) {
      print("Error al cargar palabras para SpellingBee: $e"); // Manejo de error
      // En caso de error, retornar una lista vacía para evitar problemas
      return [];
    }

    return selectedWords; // Retornar la lista de palabras seleccionadas
  }

  void _recordSpellingBeeResult(bool isCorrect) {
    if (isCorrect) {
      setState(() {
        correctCount++;
      });
    } else {
      setState(() {
        incorrectCount++;
      });
    }
    currentWordIndex++;
    _loadCurrentWord();
  }

  void _resetSpellingBee() {
    _startNewSpellingBeeSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SpellingBee'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetSpellingBee,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Aciertos: $correctCount | Errores: $incorrectCount',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: Center(
              child: currentWord != null
                  ? WordCardPractice(
                      word: currentWord!,
                      onDelete: () {},
                      onRecordPracticeCallback: (word, isCorrect, cardState) {
                        _recordSpellingBeeResult(isCorrect);
                      },
                      practicedWords: {},
                      selectedSession: null,
                      showRemoveButton: false,
                      resetCounter: 0,
                    )
                  : const Text('¡SpellingBee Finalizado!'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
