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
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddWordDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddWordDialog(BuildContext context) {
    final wordController = TextEditingController();
    final translationController = TextEditingController();
    bool isAutoTranslating = true; // Estado para la auto-traducción

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // Usamos StatefulBuilder para el setState dentro del diálogo
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Agregar Nueva Palabra'),
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
                  // Widget Focus para detectar cuando el TextField de traducción tiene el foco
                  onFocusChange: (hasFocus) async {
                    // Callback cuando cambia el foco
                    if (hasFocus &&
                        isAutoTranslating && // Solo traducir si auto-traducción está activada
                        wordController.text.isNotEmpty) {
                      // Y si el campo de palabra en inglés no está vacío
                      try {
                        final translatedText =
                            await TranslationService.translate(
                                // Llamamos al servicio de traducción
                                text: wordController.text,
                                from: 'en',
                                to: 'es');
                        translationController.text =
                            translatedText; // Establecemos el texto traducido en el TextField de traducción
                        setState(
                            () {}); // Actualizamos el estado del diálogo para que se refleje la traducción
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
                        // Icono para activar/desactivar la auto-traducción
                        icon: Icon(
                          isAutoTranslating
                              ? Icons.sync
                              : Icons
                                  .sync_disabled, // Icono cambia según el estado
                          color: isAutoTranslating
                              ? Colors.green
                              : Colors
                                  .red, // Color del icono cambia según el estado
                        ),
                        tooltip: isAutoTranslating
                            ? 'Traducción automática activada'
                            : 'Traducción automática desactivada',
                        onPressed: () {
                          setState(() {
                            // Cambiamos el estado de auto-traducción al presionar el icono
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
                      createdAt: DateTime.now(),
                    );
                    await WordRepository.insertWord(word);
                    if (context.mounted) {
                      Navigator.pop(context);
                      final wordTabState =
                          context.findAncestorStateOfType<_WordsTabState>();
                      if (wordTabState != null) {
                        wordTabState._loadWords();
                      }
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
    if (searchQuery.isEmpty) {
      words = await WordRepository.getAllWords();
    } else {
      words = await WordRepository.searchWords(searchQuery);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  word.word,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: onDelete,
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
                    // TODO: Implementar práctica
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Practicar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PracticeTab extends StatelessWidget {
  const PracticeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Pantalla de Práctica'),
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
  final int? categoryId;
  final String? notes;
  final DateTime createdAt;
  final DateTime? lastPractice;

  Word({
    this.id,
    required this.word,
    required this.translation,
    this.pronunciation,
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
