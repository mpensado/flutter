import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';
import 'dart:math';
import 'dart:async'; // Importante para Timer (debounce)

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
  Timer? _debounce; // Para el debounce de la traducción

  void refreshPracticeTab() {
    Builder(
      builder: (BuildContext context) {
        final practiceTabState =
            context.findAncestorStateOfType<_PracticeTabState>();
        if (practiceTabState != null) {
          practiceTabState._loadPracticeSessions();
        }
        return const SizedBox.shrink(); // Builder debe devolver un widget
      },
    );
  }

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
    _debounce
        ?.cancel(); // MUY IMPORTANTE cancelar el timer en dispose para evitar leaks
    _tabController.dispose();
    super.dispose();
  }

  void _showAddWordDialog(BuildContext context, VoidCallback onWordAdded,
      {Word? wordToEdit}) {
    final wordController = TextEditingController();
    final translationController = TextEditingController();
    bool isAutoTranslating = true;

    String dialogTitle = 'Nueva Palabra';
    String saveButtonText = 'Guardar';

    if (wordToEdit != null) {
      dialogTitle = 'Editar Palabra';
      saveButtonText = 'Actualizar';
      wordController.text = wordToEdit.word;
      translationController.text = wordToEdit.translation;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(dialogTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: wordController,
                  decoration: const InputDecoration(
                    labelText: 'Palabra en Inglés',
                  ),
                  onChanged: (value) {
                    // Debounce para la traducción automática
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      if (isAutoTranslating && value.isNotEmpty) {
                        TranslationService.translate(text: value)
                            .then((translated) {
                          if (mounted) {
                            setState(() {
                              translationController.text = translated;
                            });
                          }
                        }).catchError((e) {
                          // Manejo de errores de traducción
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text("Error al traducir: $e")));
                          }
                        });
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                Focus(
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
                            // Forzar traducción si se reactiva
                            if (isAutoTranslating &&
                                wordController.text.isNotEmpty) {
                              TranslationService.translate(
                                      text: wordController.text)
                                  .then((translated) {
                                if (mounted) {
                                  setState(() {
                                    translationController.text = translated;
                                  });
                                }
                              }).catchError((e) {
                                // Manejo de errores
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text("Error al traducir: $e")));
                                }
                              });
                            }
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
                      id: wordToEdit?.id,
                      word: wordController.text,
                      translation: translationController.text,
                      spelling:
                          "${wordController.text}.${_spelling(wordController.text)}.${wordController.text}",
                      createdAt: wordToEdit?.createdAt ?? DateTime.now(),
                    );
                    try {
                      if (wordToEdit == null) {
                        await WordRepository.insertWord(word);
                      } else {
                        await WordRepository.updateWord(word);
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        onWordAdded(); // Usar el callback

                        // Actualizar PracticeTab (si existe)
                        final practiceTabState = context
                            .findAncestorStateOfType<_PracticeTabState>();
                        if (practiceTabState != null) {
                          practiceTabState
                              ._loadPracticeSessions(); // Actualizar sesiones
                        }
                      }
                    } catch (e) {
                      //Manejo de errores de guardado
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("Error al guardar/actualizar: $e")));
                      }
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Por favor complete todos los campos'),
                        ),
                      );
                    }
                  }
                },
                child: Text(saveButtonText),
              ),
            ],
          );
        },
      ),
    );
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
          controller: _tabController, // Usa el TabController
          tabs: const [
            Tab(text: 'Palabras', icon: Icon(Icons.book)),
            Tab(text: 'Práctica', icon: Icon(Icons.edit)),
            Tab(text: 'SpellingBee', icon: Icon(Icons.bug_report_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController, // Usa el TabController
        children: [
          WordsTab(onSessionUpdated: refreshPracticeTab),
          const PracticeTab(),
          const SpellingBeeView(),
        ],
      ),
    );
  }
}

class WordsTab extends StatefulWidget {
  final VoidCallback? onSessionUpdated; // <---  Añade el callback

  const WordsTab(
      {super.key, this.onSessionUpdated}); // <---  Añade al constructor

  @override
  State<WordsTab> createState() => _WordsTabState();
}

class _WordsTabState extends State<WordsTab> {
  Future<List<Word>>? _wordsFuture; // Usar Future para carga asíncrona
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadWords(); // Inicializar la carga de palabras
  }

  Future<void> _loadWords() async {
    setState(() {
      //Set state antes de asignar el futuro
      if (searchQuery.isEmpty) {
        _wordsFuture = WordRepository.getAllWords();
      } else {
        _wordsFuture = WordRepository.searchWords(searchQuery);
      }
    });
  }

  void _showAddToSessionDialog(BuildContext context, Word wordToAdd) async {
    List<PracticeSession> sessions =
        await PracticeSessionRepository.getAllSessions();
    PracticeSession? selectedSession;
    final newSessionNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Añadir palabra a Sesión'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Seleccione una sesión existente o cree una nueva:'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PracticeSession>(
                    value: selectedSession,
                    decoration: const InputDecoration(
                      labelText: 'Sesión Existente (Opcional)',
                      hintText: 'Seleccionar sesión',
                    ),
                    items: sessions.map((session) {
                      return DropdownMenuItem<PracticeSession>(
                        value: session,
                        child: Text(session.name),
                      );
                    }).toList(),
                    onChanged: (PracticeSession? newValue) {
                      setState(() {
                        selectedSession = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('O'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newSessionNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de Nueva Sesión (Opcional)',
                      hintText: 'Ingrese un nombre para nueva sesión',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  bool newSession = false;
                  PracticeSession? sessionToUse = selectedSession;

                  if (sessionToUse == null &&
                      newSessionNameController.text.isNotEmpty) {
                    newSession = true;
                    sessionToUse = PracticeSession(
                      name: newSessionNameController.text,
                      createdAt: DateTime.now(),
                      wordIds: [wordToAdd.id!],
                    );
                    try {
                      await PracticeSessionRepository.insertSession(
                          sessionToUse);
                      sessions = await PracticeSessionRepository
                          .getAllSessions(); //Recargar después de añadir
                      sessionToUse = sessions.last;
                    } catch (e) {
                      //Manejo de errores
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("Error al crear sesión: $e")));
                      }
                      return; //Importante salir si hay un error
                    }
                  }

                  if (sessionToUse != null) {
                    try {
                      if (!newSession) {
                        await PracticeSessionRepository.addWordToSession(
                            wordToAdd, sessionToUse);
                      }

                      if (widget.onSessionUpdated != null) {
                        // <---  Usa widget.onSessionUpdated
                        widget.onSessionUpdated!();
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Palabra "${wordToAdd.word}" añadida a la sesión "${sessionToUse.name}"'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("Error al añadir palabra: $e")));
                      }
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Por favor, seleccione una sesión existente o ingrese un nombre para una nueva sesión.'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Añadir'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          (HomePage.of(context))._showAddWordDialog(context, () {
            setState(() {
              // Actualizar la lista de palabras al añadir una nueva
              _loadWords();
            });
          });
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SearchBar(
              hintText: 'Buscar palabra...',
              leading: const Icon(Icons.search),
              onChanged: (value) {
                setState(() {
                  // Actualizar la búsqueda al escribir
                  searchQuery = value;
                  _loadWords();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Word>>(
              // Usar FutureBuilder
              future: _wordsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator()); // Mostrar indicador de carga
                } else if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}')); // Mostrar error
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No words found.'));
                } else {
                  return RefreshIndicator(
                    onRefresh: _loadWords, // Recargar al deslizar hacia abajo
                    child: ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        return WordCard(
                          word: snapshot.data![index],
                          onDelete: () async {
                            try {
                              await WordRepository.deleteWord(
                                  snapshot.data![index].id!);
                              setState(() {
                                _loadWords();
                              });
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text("Error al eliminar: $e")));
                              }
                            }
                          },
                          onAddToSession: () {
                            _showAddToSessionDialog(
                                context, snapshot.data![index]);
                          },
                        );
                      },
                    ),
                  );
                }
              },
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
  final VoidCallback? onAddToSession;

  const WordCard({
    super.key,
    required this.word,
    required this.onDelete,
    this.onAddToSession,
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
              children: [
                Expanded(
                  child: Text(
                    word.word,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.start,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        (HomePage.of(context))._showAddWordDialog(
                          context,
                          () {
                            final wordsTabState = context
                                .findAncestorStateOfType<_WordsTabState>();
                            if (wordsTabState != null) {
                              wordsTabState
                                  ._loadWords(); //Recargar usando el estado del tab
                            }
                          },
                          wordToEdit: word,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: onDelete,
                    ),
                    const SizedBox(width: 8),
                    if (onAddToSession != null)
                      IconButton(
                        icon: const Icon(
                            Icons.add_circle_outline), // Icono de "añadir"
                        tooltip: 'Añadir a Sesión', // Tooltip para el icono
                        onPressed:
                            onAddToSession, // Llama al callback onAddToSession
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
                    TextToSpeechService.speak(word.word);
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Pronunciar'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
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
  final PracticeSession? selectedSession;
  final int resetCounter;
  final bool showRemoveButton; //  propiedad showRemoveButton

  const WordCardPractice({
    super.key,
    required this.word,
    required this.onDelete,
    required this.onRecordPracticeCallback,
    required this.practicedWords,
    this.selectedSession,
    required this.resetCounter,
    this.showRemoveButton = true, //  Valor por defecto: true (mostrar botón)
  });

  @override
  State<WordCardPractice> createState() => _WordCardPracticeState();
}

class _WordCardPracticeState extends State<WordCardPractice> {
  bool isPracticed = false;
  bool? practiceResult;

  @override
  void initState() {
    super.initState();
    isPracticed = widget.practicedWords.contains(widget.word.id);

    if (isPracticed) {
      _loadLastPracticeResult();
    } else {
      practiceResult = null;
    }
  }

  @override
  void didUpdateWidget(covariant WordCardPractice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetCounter != oldWidget.resetCounter) {
      setState(() {
        isPracticed = false;
        practiceResult = null;
      });
    }
  }

  Future<void> _loadLastPracticeResult() async {
    final dbHelper = DBHelper();
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> history = await db.query(
        'practice_history',
        orderBy: 'practiced_at DESC',
        where: 'word_id = ? AND session_id = ?',
        whereArgs: [widget.word.id, widget.selectedSession?.id],
        limit: 1,
      );

      if (history.isNotEmpty) {
        final lastPractice = PracticeHistory.fromMap(history.first);
        setState(() {
          practiceResult = lastPractice.isCorrect;
        });
      } else {
        practiceResult = null;
      }
    } catch (e) {
      //Manejo de errores
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
            SnackBar(content: Text("Error cargando historial: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  label: const Text(
                    'Pronunciar',
                    style: TextStyle(fontSize: 10.0),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    TextToSpeechService.speak(widget.word.spelling);
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text(
                    'Deletrear',
                    style: TextStyle(fontSize: 10.0),
                  ),
                ),
                if (widget
                    .showRemoveButton) //  Mostrar solo si showRemoveButton es true
                  ElevatedButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.remove),
                    label: const Text(
                      'Quitar',
                      style: TextStyle(fontSize: 10.0),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

//Vista de estadisticas (borrar si no se usa al final)
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

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'word_trainer_database.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableCategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

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
}

class TextToSpeechService {
  static FlutterTts? _flutterTts;

  static Future<FlutterTts> _getInstance() async {
    if (_flutterTts == null) {
      _flutterTts = FlutterTts();

      try {
        await _flutterTts!.setEngine('com.google.android.tts');
        await _flutterTts!.setLanguage('en-US');
        await _flutterTts!.setPitch(1.0);
        await _flutterTts!.setSpeechRate(0.5);
        await _flutterTts!.setVolume(1.0);
      } catch (e) {
        debugPrint('Error inicializando TTS: $e');
        // Consider showing a SnackBar to the user
      }
    }
    return _flutterTts!;
  }

  static Future<void> speak(String text) async {
    try {
      final tts = await _getInstance();
      await tts.speak(text);
    } catch (e) {
      debugPrint('Error al pronunciar: $e');
      // Show a SnackBar (you'll need a BuildContext for this)
    }
  }

  static Future<void> stop() async {
    try {
      final tts = await _getInstance();
      await tts.stop();
    } catch (e) {
      debugPrint('Error al detener TTS: $e');
      // Show a SnackBar
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
      print("Error en la traduccion: $e");
      return text; // Return original text on error
    }
  }
}

class PracticeSessionRepository {
  static Future<List<PracticeSession>> getAllSessions() async {
    final db = await DBHelper().database;
    try {
      final List<Map<String, dynamic>> maps =
          await db.query('practice_sessions');
      return List.generate(
          maps.length, (i) => PracticeSession.fromMap(maps[i]));
    } catch (e) {
      print("Error getting all sessions: $e");
      rethrow;
    }
  }

  static Future<void> insertSession(PracticeSession session) async {
    final db = await DBHelper().database;
    try {
      await db.insert('practice_sessions', session.toMap());
    } catch (e) {
      print("Error inserting session: $e");
      rethrow;
    }
  }

  static Future<void> addWordToSession(
      Word word, PracticeSession session) async {
    final db = await DBHelper().database;
    try {
      final List<Map<String, dynamic>> sessionMap = await db.query(
        'practice_sessions',
        where: 'id = ?',
        whereArgs: [session.id],
      );
      if (sessionMap.isEmpty) {
        return;
      }
      final PracticeSession currentSession =
          PracticeSession.fromMap(sessionMap.first);
      List<int> wordIdList = currentSession.wordIds;

      if (!wordIdList.contains(word.id)) {
        wordIdList.add(word.id!);
        final updatedWordIdsString =
            wordIdList.map((id) => id.toString()).join(',');

        await db.update(
          'practice_sessions',
          {'word_ids': updatedWordIdsString},
          where: 'id = ?',
          whereArgs: [session.id],
        );
      }
    } catch (e) {
      print("Error adding word to session: $e");
      rethrow;
    }
  }

  //Optimización de la consulta a base de datos.
  static Future<List<Word>> loadSessionWords(PracticeSession session) async {
    final db = await DBHelper().database;
    try {
      if (session.wordIds.isEmpty) {
        return []; // Return empty list if no word IDs
      }
      final List<Map<String, dynamic>> maps = await db.query(
        DBHelper().tableWords,
        where:
            'id IN (${session.wordIds.map((_) => '?').join(',')})', // Create placeholders
        whereArgs: session.wordIds, // Pass the IDs as arguments
      );
      return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
    } catch (e) {
      print("Error loading session words: $e");
      rethrow;
    }
  }

  //Borrado de sesiones
  static Future<void> deleteSession(int sessionId) async {
    final db = await DBHelper().database;
    try {
      await db.delete(
        'practice_sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    } catch (e) {
      print("Error deleting session: $e");
      rethrow;
    }
  }

  //Quitar palabras de una sesión
  static Future<void> removeWordFromSession(
      Word word, PracticeSession session) async {
    final db = await DBHelper().database;
    try {
      final List<Map<String, dynamic>> sessionMap = await db.query(
        'practice_sessions',
        where: 'id = ?',
        whereArgs: [session.id],
      );
      if (sessionMap.isEmpty) {
        return;
      }

      final PracticeSession currentSession =
          PracticeSession.fromMap(sessionMap.first);
      List<int> wordIdList = currentSession.wordIds;

      if (wordIdList.contains(word.id)) {
        wordIdList.remove(word.id); // Remove the word ID
        final updatedWordIdsString =
            wordIdList.map((id) => id.toString()).join(',');

        await db.update('practice_sessions', {'word_ids': updatedWordIdsString},
            where: 'id = ?', whereArgs: [session.id]);
      }
    } catch (e) {
      print("Error removing word from session: $e");
      rethrow;
    }
  }
}

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
    List<int> parseWordIds(dynamic wordIdsData) {
      if (wordIdsData is String) {
        return wordIdsData
            .split(',')
            .where((str) => str.isNotEmpty)
            .map((str) {
              String trimmedStr =
                  str.trim(); // Trim y guarda en variable para imprimir
              try {
                return int.parse(trimmedStr);
              } catch (e) {
                print(
                    "Error al parsear: '$trimmedStr'. Error: $e"); // Imprime el error también
                return 0; // or handle as needed
              }
            })
            .whereType<int>()
            .toList();
      } else if (wordIdsData is List) {
        return wordIdsData.map((e) => int.parse(e.toString())).toList();
      }
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
  Future<List<Word>>? _wordsFuture; // Usar Future para la carga
  List<PracticeSession> sessions = [];
  PracticeSession? selectedSession;
  Set<int> practicedWords = {};
  int correctCount = 0;
  int incorrectCount = 0;
  int resetCounter = 0;

  @override
  bool get wantKeepAlive => true; // Para mantener el estado

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final dbHelper = DBHelper();
    try {
      final db = await dbHelper.database;
      final wordCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM ${dbHelper.tableWords}'));

      if (wordCount == 0) {
        await loadSampleData();
      }
    } catch (e) {
      if (mounted) {
        // context check
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
            SnackBar(content: Text("Error al cargar datos iniciales: $e")));
      }
      return; // Early return on error
    }

    await _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      List<PracticeSession> loadedSessions =
          await PracticeSessionRepository.getAllSessions();
      setState(() {
        sessions = loadedSessions;
        if (sessions.isNotEmpty) {
          selectedSession = sessions.first;
          _loadSessionWords(); // Cargar palabras de la primera sesión
        } else {
          selectedSession = null;
          _wordsFuture = Future.value([]); // Set future to empty list
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
            SnackBar(content: Text("Error al cargar sesiones: $e")));
      }
    }
  }

  Future<void> _loadPracticeSessions() async {
    setState(() {
      _loadSessions(); //Recargar sesiones
    });
  }

  Future<void> _loadSessionWords() async {
    if (selectedSession == null) {
      setState(() {
        _wordsFuture = Future.value([]); // Set future to an empty list
      });
      return;
    }

    setState(() {
      // Assign the future to _wordsFuture *before* the async operation starts.
      _wordsFuture =
          PracticeSessionRepository.loadSessionWords(selectedSession!);
    });
  }

  Future<void> _recordPractice(Word word, bool isCorrect) async {
    if (selectedSession != null) {
      final practice = PracticeHistory(
        wordId: word.id!,
        sessionId: selectedSession!.id!,
        isCorrect: isCorrect,
        practicedAt: DateTime.now(),
      );

      final dbHelper = DBHelper();
      try {
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
      } catch (e) {
        if (mounted) {
          // context check
          ScaffoldMessenger.of(context as BuildContext).showSnackBar(
              SnackBar(content: Text("Error al registrar la práctica: $e")));
        }
      }
    }
  }

  void _recordPracticeWrapper(
      Word word, bool isCorrect, _WordCardPracticeState cardState) {
    _recordPractice(word, isCorrect); // Registrar el resultado
    cardState.setState(() {
      cardState.practiceResult = isCorrect; // Actualizar estado de la tarjeta
      cardState.isPracticed = true;
    });
  }

  void _resetPractice() {
    setState(() {
      practicedWords.clear();
      correctCount = 0;
      incorrectCount = 0;
      _loadSessionWords(); // Recargar las palabras
      resetCounter++; // Incrementar para forzar actualización
    });
  }

  //Función para mostrar dialogo de borrado de sesión
  void _showDeleteSessionDialog(BuildContext context, PracticeSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar Sesión'),
        content: Text(
            '¿Estás seguro de que quieres borrar la sesión "${session.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await PracticeSessionRepository.deleteSession(session.id!);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sesión "${session.name}" borrada')),
                  );
                }
                _loadPracticeSessions(); //Recargar lista
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error al borrar la sesión: $e")),
                  );
                }
              }
            },
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
  }

  //Función para mostrar el dialogo de quitar palabra de sesión
  void _showRemoveWordDialog(
      BuildContext context, Word word, PracticeSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar Palabra'),
        content: Text(
            '¿Estás seguro de que quieres quitar la palabra "${word.word}" de la sesión "${session.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await PracticeSessionRepository.removeWordFromSession(
                    word, session);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Palabra "${word.word}" eliminada de la sesión "${session.name}"')),
                  );
                }
                _loadSessionWords(); // Reload after removing the word
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error al quitar palabra: $e")),
                  );
                }
              }
            },
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
                          child: Row(
                            //Para poder añadir el icono de borrado
                            children: [
                              Expanded(child: Text(session.name)),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  _showDeleteSessionDialog(context,
                                      session); //Mostrar dialogo de borrado
                                },
                              ),
                            ],
                          ));
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
                    _loadSessionWords(); // Recargar palabras
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
            child: FutureBuilder<List<Word>>(
              future: _wordsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text("No hay palabras en esta sesión."));
                } else {
                  // ENVUELVE el ListView.builder con RefreshIndicator.
                  return RefreshIndicator(
                    onRefresh:
                        _loadSessions, // <--- Llama a _loadSessions() al recargar
                    child: ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        // ... (resto del itemBuilder: creación de WordCardPractice) ...
                        final word = snapshot.data![index];
                        return WordCardPractice(
                          key: ValueKey(word.id), // Usar ValueKey
                          word: word,
                          onDelete: () async {
                            if (selectedSession != null) {
                              _showRemoveWordDialog(context, word,
                                  selectedSession!); //Mostrar el dialogo de quitar palabra
                            }
                          },
                          onRecordPracticeCallback: _recordPracticeWrapper,
                          practicedWords: practicedWords,
                          selectedSession: selectedSession,
                          resetCounter: resetCounter, // Pasar resetCounter
                          showRemoveButton: true, //Mostrar botón de quitar
                        );
                      },
                    ),
                  );
                }
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

  try {
    List<int> wordIds = [];
    for (var wordData in sampleWords) {
      final id = await db.insert(dbHelper.tableWords, wordData);
      wordIds.add(id);
    }

    final sessionId = await db.insert('practice_sessions', {
      'name': '3o de Primaria',
      'created_at': DateTime.now().toIso8601String(),
      'word_ids': wordIds.join(','),
    });

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
  } catch (e) {
    print("Error loading sample data: $e");
    // Consider showing a SnackBar to the user.  You'll need a BuildContext.
  }
}

//VISTA SPELLINGBEE
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
  //String? displayedSpelling; // Variable para mostrar el deletreo

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
      //displayedSpelling = null; // Reset displayed spelling

      _generateRandomWordList().then((wordList) {
        setState(() {
          currentWordList = wordList;
          _loadCurrentWord();
        });
      });
    });
  }

  void _loadCurrentWord() {
    if (currentWordIndex < currentWordList.length) {
      setState(() {
        currentWord = currentWordList[currentWordIndex];
        TextToSpeechService.speak(currentWord!.word);
        //displayedSpelling = null; // Reset spelling on new word.
      });
    } else {
      setState(() {
        currentWord = null; // Set to null to indicate end of session
        //displayedSpelling = null; // Also clear spelling at the end.
      });
    }
  }

  Future<List<Word>> _generateRandomWordList() async {
    final random = Random();
    try {
      final wordsData =
          await WordRepository.getWords(); // Obtener la lista de palabras
      if (wordsData.isNotEmpty) {
        List<Word> shuffledWords = List.from(wordsData);
        shuffledWords.shuffle(random);
        return shuffledWords.take(10).toList(); // Tomar 10 palabras aleatorias
      }
    } catch (e) {
      print("Error al cargar palabras para SpellingBee: $e");
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
            SnackBar(content: Text("Error al cargar palabras: $e")));
      }
      return []; // Return empty list on error
    }
    return []; // Return empty list if no words
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
    _loadCurrentWord(); // Cargar la siguiente palabra
  }

  void _resetSpellingBee() {
    _startNewSpellingBeeSession(); // Reiniciar la sesión
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
          //Instrucciones
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Presiona el botón para escuchar el deletreo de la palabra. Luego, indica si lo has deletreado correctamente.',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Center(
                child: currentWord != null
                    ? Column(
                        // Mostrar palabra y deletreo
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            currentWord!.word,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              TextToSpeechService.speak(currentWord!.spelling)
                                  .then((_) {
                                // setState(() {
                                //   // Remove "word." and ".word" and split by "---"
                                //   String cleanedSpelling = currentWord!.spelling
                                //       .replaceAll("${currentWord!.word}.",
                                //           "") // Remove word at start.
                                //       .replaceAll(".${currentWord!.word}",
                                //           "") // Remove word at the end.
                                //       .trim(); // Remove leading/trailing spaces if any
                                //   displayedSpelling = cleanedSpelling;
                                // });
                              });
                            },
                            icon: const Icon(Icons.volume_up),
                            label: const Text('Escuchar Deletreo'),
                          ),
                          //const SizedBox(height: 20),
                          // if (displayedSpelling != null)
                          //   Text(
                          //     displayedSpelling!, // Mostrar el deletreo
                          //     style: Theme.of(context).textTheme.titleLarge,
                          //     textAlign: TextAlign.center,
                          //   ),
                          const SizedBox(height: 20),
                          Row(
                            // Botones de correcto/incorrecto
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle,
                                    color: Colors.green),
                                onPressed: () => _recordSpellingBeeResult(true),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () =>
                                    _recordSpellingBeeResult(false),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        // Mostrar mensaje de finalización
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            const Text('¡SpellingBee Finalizado!',
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            Text(
                                'Puntuación Final: $correctCount / ${correctCount + incorrectCount}',
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _resetSpellingBee,
                              child: const Text('Volver a Jugar'),
                            ),
                          ])),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
