import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';
import 'dart:math';
import 'dart:async'; // Importante para Timer (debounce)
import 'package:collection/collection.dart'; // Importante para firstWhereOrNull

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
        word.split(' '); // Separar por espacios para Vocabulario compuestas
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
            '---space---'; // Doble coma entre Vocabulario compuestas
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
            Tab(text: 'Vocabulario', icon: Icon(Icons.book)),
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
    _loadWords(); // Inicializar la carga de Vocabulario
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
              // Actualizar la lista de Vocabulario al añadir una nueva
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
                    // const SizedBox(width: 8),
                    // if (onAddToSession != null)
                    //   IconButton(
                    //     icon: const Icon(
                    //         Icons.add_circle_outline), // Icono de "añadir"
                    //     tooltip: 'Añadir a Sesión', // Tooltip para el icono
                    //     onPressed:
                    //         onAddToSession, // Llama al callback onAddToSession
                    //   ),
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

class DBHelper {
  static Database? _database;
  static final DBHelper _instance = DBHelper._privateConstructor();

  factory DBHelper() {
    return _instance;
  }

  DBHelper._privateConstructor();

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
    return await openDatabase(path,
        version: 4, onCreate: _onCreate, onUpgrade: _onUpgrade);
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
        correct_count INTEGER DEFAULT 0,
        incorrect_count INTEGER DEFAULT 0,
        total_incorrect_count INTEGER DEFAULT 0,
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
        session_type TEXT NOT NULL,
        FOREIGN KEY (word_id) REFERENCES words (id),
        FOREIGN KEY (session_id) REFERENCES practice_sessions (id)
      )
    ''');

    // Crear sesiones fijas DESPUÉS de crear las tablas.
    await _createFixedSessions(db);
  }

  Future<void> _createFixedSessions(Database db) async {
    await db.insert(
        'practice_sessions',
        {
          'id': -1, // ID negativo para "Errores"
          'name': 'Errores',
          'created_at': DateTime.now().toIso8601String(),
          'word_ids': '', // Inicialmente vacía
        },
        conflictAlgorithm:
            ConflictAlgorithm.ignore); //Evita errores si ya existe

    await db.insert(
        'practice_sessions',
        {
          'id': -2, // ID negativo para "No Practicadas"
          'name': 'No Practicadas',
          'created_at': DateTime.now().toIso8601String(),
          'word_ids': '', // Inicialmente vacía
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert(
        'practice_sessions',
        {
          'id': -3, // ID negativo para "Todas"
          'name': 'Todas',
          'created_at': DateTime.now().toIso8601String(),
          'word_ids': '', // Inicialmente vacía
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

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
    //Añadimos las sesiones fijas
    if (oldVersion < 4) {
      await _createFixedSessions(db);
    }
  }
}

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
  final int correctCount; // Contador de aciertos
  final int incorrectCount; // Contador de errores (para espaciado)
  final int totalIncorrectCount; // Contador total de errores

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
    this.correctCount = 0, // Valor inicial 0
    this.incorrectCount = 0, // Valor inicial 0
    this.totalIncorrectCount = 0,
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
      'correct_count': correctCount,
      'incorrect_count': incorrectCount,
      'total_incorrect_count': totalIncorrectCount,
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
      correctCount: map['correct_count'] ?? 0, // Valor por defecto 0
      incorrectCount: map['incorrect_count'] ?? 0, // Valor por defecto 0
      totalIncorrectCount: map['total_incorrect_count'] ?? 0,
    );
  }
}

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
      final List<Word> correctWords = []; //Ya no se usa

      for (final word in allWords) {
        // Buscar la ÚLTIMA vez que se practicó esta palabra.
        final lastPractice = practiceHistory.firstWhereOrNull(
          (history) => history.wordId == word.id,
        );

        if (lastPractice == null) {
          neverPracticed.add(word);
        } else if (!lastPractice.isCorrect || word.incorrectCount>0) {
          //Solo se añaden las incorrectas
          incorrectWords.add(word);
        } else {
          //Si la palabra se ha respondido correctamente, no se vuelve a mostrar
          //correctWords.add(word); //Ya no se usa
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
      final List<Map<String, dynamic>> maps = await db
          .query('practice_sessions', where: 'id > 0' // Excluir sesiones fijas
              );
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

  //Añadimos un nuevo método para obtener las sesiones fijas
  static Future<List<PracticeSession>> getFixedSessions() async {
    final db = await DBHelper().database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
          'practice_sessions',
          where: 'id < 0' // Obtener solo sesiones fijas.
          );
      return List.generate(
          maps.length, (i) => PracticeSession.fromMap(maps[i]));
    } catch (e) {
      print("Error getting fixed sessions: $e");
      rethrow;
    }
  }

  static Future<void> addWordToSession(
      Word word, PracticeSession session) async {
    //No permitir añadir a sesiones fijas
    if (session.id! < 0) return;

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

  static Future<List<Word>> loadSessionWords(PracticeSession session) async {
    final db = await DBHelper().database;
    try {
      if (session.id == -1) {
        // Errores
        final List<Map<String, dynamic>> maps = await db.query(
          DBHelper().tableWords,
          where: 'total_incorrect_count > 0', // Solo palabras con errores
          orderBy:
              'total_incorrect_count DESC', // Ordenar por errores (descendente)
        );
        return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
      } else if (session.id == -2) {
        // No Practicadas
        // Obtener todas las palabras
        final List<Map<String, dynamic>> allWordsMap =
            await db.query(DBHelper().tableWords);
        final List<Word> allWords =
            allWordsMap.map((map) => Word.fromMap(map)).toList();

        // Obtener todas las palabras practicadas (en cualquier tipo de sesión)
        final List<Map<String, dynamic>> practicedWordsMap = await db.query(
            'practice_history',
            columns: ['word_id'],
            distinct: true); //Usamos distinct
        final List<int> practicedWordIds =
            practicedWordsMap.map((map) => map['word_id'] as int).toList();

        // Filtrar para obtener solo las palabras NO practicadas
        final List<Word> neverPracticedWords = allWords
            .where((word) => !practicedWordIds.contains(word.id))
            .toList();
        return neverPracticedWords;
      } else if (session.id == -3) {
        // Todas

        final List<Map<String, dynamic>> maps = await db.query(
          DBHelper().tableWords,
          orderBy:
              'correct_count + incorrect_count ASC', // Menos practicadas primero
        );
        return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
      } else {
        // Sesiones normales (IDs positivos)
        if (session.wordIds.isEmpty) {
          return [];
        }
        final List<Map<String, dynamic>> maps = await db.query(
          DBHelper().tableWords,
          where: 'id IN (${session.wordIds.map((_) => '?').join(',')})',
          whereArgs: session.wordIds,
        );
        return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
      }
    } catch (e) {
      print("Error loading session words: $e");
      rethrow;
    }
  }

  static Future<void> deleteSession(int sessionId) async {
    //No se pueden borrar las sesiones fijas
    if (sessionId < 0) return;
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

  static Future<void> removeWordFromSession(
      Word word, PracticeSession session) async {
    //No permitir quitar palabras de sesiones fijas
    if (session.id! < 0) return;

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
  final String sessionType; // Nueva columna

  PracticeHistory({
    this.id,
    required this.wordId,
    required this.sessionId,
    required this.isCorrect,
    required this.practicedAt,
    required this.sessionType, // Añadido al constructor
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word_id': wordId,
      'session_id': sessionId,
      'is_correct': isCorrect ? 1 : 0,
      'practiced_at': practicedAt.toIso8601String(),
      'session_type': sessionType, // Añadido al mapa
    };
  }

  factory PracticeHistory.fromMap(Map<String, dynamic> map) {
    return PracticeHistory(
      id: map['id'],
      wordId: map['word_id'],
      sessionId: map['session_id'],
      isCorrect: map['is_correct'] == 1,
      practicedAt: DateTime.parse(map['practiced_at']),
      sessionType: map['session_type'], // Añadido desde el mapa
    );
  }
}

class PracticeTab extends StatefulWidget {
  const PracticeTab({super.key});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  // ... (variables de estado, como antes) ...
  Future<List<Word>>? _wordsFuture; // Usar Future para la carga
  List<PracticeSession> sessions = [];
  PracticeSession? selectedSession;
  Set<int> practicedWords = {};
  int correctCount = 0;
  int incorrectCount = 0;
  int resetCounter = 0;

  late TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this); // Initialize TabController
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
          await PracticeSessionRepository.getAllSessions(); //Sesiones normales
      List<PracticeSession> fixedSessions = await PracticeSessionRepository
          .getFixedSessions(); // Obtener sesiones fijas

      setState(() {
        sessions = [
          ...fixedSessions,
          ...loadedSessions
        ]; // Combinar sesiones fijas y normales

        //Seleccionar la sesión por defecto (Errores)
        if (selectedSession == null ||
            !sessions.any((s) => s.id == selectedSession!.id)) {
          selectedSession = sessions.isNotEmpty ? sessions.first : null;
        }
        _loadSessionWords();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
            SnackBar(content: Text("Error al cargar sesiones: $e")));
      }
    }
  }

  Future<void> _loadPracticeSessions() async {
    await _loadSessions(); //Recargar sesiones
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
          sessionId: selectedSession!.id!, //Ahora puede ser -1, -2, -3
          isCorrect: isCorrect,
          practicedAt: DateTime.now(),
          sessionType: 'session' //Tipo sesión
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
  //Ya no se usa
  /*void _showDeleteSessionDialog(BuildContext context, PracticeSession session) {

    }*/

  //Ya no se usa
  /*void _showRemoveWordDialog(BuildContext context, Word word, PracticeSession session) {

  }*/

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Por Sesión'),
            Tab(text: 'Aleatorio'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSessionPractice(context), // Pasa el context
          RandomPracticeView(),
        ],
      ),
    );
  }

  Widget _buildSessionPractice(BuildContext context) {
    // Recibe BuildContext
    return Column(
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
                          children: [
                            Expanded(child: Text(session.name)),
                            //Se quita el icono de borrar
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
              //Se quita el icono de refrescar
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Aciertos: $correctCount | Errores: $incorrectCount',
            style: Theme.of(context)
                .textTheme
                .titleMedium, // Usa el context del build
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
                return RefreshIndicator(
                  onRefresh: _loadSessions, //Llama a la funcion
                  child: ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final word = snapshot.data![index];
                      return WordCardPractice(
                        key: ValueKey(word.id),
                        word: word,
                        onDelete: () async {
                          /*if(selectedSession != null){
                                _showRemoveWordDialog(context, word, selectedSession!);
                            }*/ //QUITAR
                        },
                        onRecordPracticeCallback: _recordPracticeWrapper,
                        practicedWords: practicedWords,
                        selectedSession: selectedSession,
                        resetCounter: resetCounter,
                        showRemoveButton: false, // <--- No mostrar el botón
                      );
                    },
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose(); // Dispose of the TabController
    super.dispose();
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

class RandomPracticeView extends StatefulWidget {
  const RandomPracticeView({super.key});

  @override
  State<RandomPracticeView> createState() => _RandomPracticeViewState();
}

class _RandomPracticeViewState extends State<RandomPracticeView> {
  Word? currentWord;
  bool hasRepeated = false;
  bool isLoading = false; // Para mostrar un indicador de carga
  List<int> lastPracticedWords = []; //Para controlar el espaciado.
  final AudioPlayer _audioPlayer = AudioPlayer();
  int totalCorrectCount = 0; // Aciertos totales en la sesión
  int totalIncorrectCount = 0; // Errores totales en la sesión
  int currentWordIncorrectCount = 0; //Errores para la palabra actual.
  bool gameStarted = false; // Para el botón de inicio
  bool practiceEnded = false; // Para mostrar el resumen final
  List<Map<String, dynamic>> practiceSummary = []; // Lista para el resumen

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  void _startNewPractice() {
    setState(() {
      currentWord = null;
      hasRepeated = false;
      isLoading = false;
      totalCorrectCount = 0;
      totalIncorrectCount = 0;
      currentWordIncorrectCount = 0;
      gameStarted = false; // Resetear
      practiceEnded = false; // Resetear
      practiceSummary.clear(); // Limpiar el resumen
      lastPracticedWords = [];
    });
  }

  Future<void> _loadNextWord() async {
    setState(() {
      isLoading = true;
      hasRepeated = false;
      // currentWordIncorrectCount = 0; // NO REINICIAR AQUÍ
    });

    try {
      final nextWord = await WordRepository.getWordsForRandomPractice();
      if (mounted) {
        setState(() {
          currentWord = nextWord;
          isLoading = false;
          if (currentWord != null) {
            TextToSpeechService.speak(currentWord!.word);
            currentWordIncorrectCount =
                currentWord!.totalIncorrectCount; //  CARGAR ERRORES
            if (practiceSummary.firstWhereOrNull(
                    (element) => element['word'] == currentWord!.word) ==
                null) {
              practiceSummary.add({
                'word': currentWord!.word,
                'attempts': 0,
                'errors': 0,
              });
            }
            practiceSummary.firstWhereOrNull((element) =>
                element['word'] == currentWord!.word)!['attempts']++;

            if (!lastPracticedWords.contains(currentWord!.id)) {
              lastPracticedWords.insert(0, currentWord!.id!);
              if (lastPracticedWords.length > 3) {
                lastPracticedWords.removeLast();
              }
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(content: Text("Error al cargar la palabra: $e")),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _recordPracticeResult(bool isCorrect) async {
    if (currentWord == null) return;

    try {
      final dbHelper = DBHelper();
      final db = await dbHelper.database;
      // Usar la nueva columna session_type.  NO usamos sessionID en la práctica aleatoria.
      await db.insert('practice_history', {
        'word_id': currentWord!.id,
        'session_id':
            -1, // Usar un valor centinela (-1) o NULL para indicar que no hay sesión.
        'is_correct': isCorrect ? 1 : 0,
        'practiced_at': DateTime.now().toIso8601String(),
        'session_type': 'random', //  Valor para la práctica aleatoria.
      });

      await WordRepository.updateWordCounters(currentWord!.id!, isCorrect);

      setState(() {
        if (isCorrect) {
          totalCorrectCount++;
        } else {
          totalIncorrectCount++;
          currentWordIncorrectCount++;
          // Actualizar errores en el resumen
          final wordSummary = practiceSummary.firstWhereOrNull(
              (element) => element['word'] == currentWord!.word);
          if (wordSummary != null) {
            wordSummary['errors']++;
          }
        }
      });

      _loadNextWord(); // Cargar la siguiente palabra
    } catch (e) {
      if (mounted) {
        //Siempre comprobar.
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
            SnackBar(content: Text("Error al guardar el resultado: $e")));
      }
    }
  }

  void _endPractice() {
    setState(() {
      practiceEnded = true; // Mostrar resumen
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!gameStarted) {
      return Scaffold(
        appBar: AppBar(title: const Text("Práctica Aleatoria")),
        body: Center(
          child: ElevatedButton(
            child: const Text("Comenzar Práctica"),
            onPressed: () {
              setState(() {
                gameStarted = true;
              });
              _loadNextWord(); // Iniciar carga de palabras
            },
          ),
        ),
      );
    }

    if (practiceEnded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Práctica Aleatoria - Resumen"),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Resumen de la Práctica:",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: practiceSummary.length,
                  itemBuilder: (context, index) {
                    final sortedSummary = List<Map<String, dynamic>>.from(
                        practiceSummary); // Copia para no modificar el original.
                    sortedSummary.sort((a, b) => a['attempts'].compareTo(
                        b['attempts'])); // Ordenar ASCENDENTE por intentos.

                    final wordData =
                        sortedSummary[index]; // Usa la lista ordenada.
                    return ListTile(
                      title: Text(wordData['word']),
                      subtitle: Text(
                          "Intentos: ${wordData['attempts']}, Errores: ${wordData['errors']}"),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: _startNewPractice,
                child: const Text("Nueva Práctica"),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Práctica Aleatoria'),
      ),
      body: SingleChildScrollView(
        // <-- Añade SingleChildScrollView
        child: Center(
          // <-- Centra la columna
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Centra verticalmente
            children: [
              if (isLoading) ...[
                const CircularProgressIndicator(),
              ] else if (currentWord != null) ...[
                Text(
                    "Aciertos: $totalCorrectCount | Errores: $totalIncorrectCount | Errores en palabra: $currentWordIncorrectCount"),
                const SizedBox(height: 8),
                Center(
                  //Centra el Card
                  child: WordCardPractice(
                    key: ValueKey(currentWord!.id),
                    word: currentWord!,
                    onDelete: () {},
                    onRecordPracticeCallback: (word, isCorrect, cardState) {
                      _recordPracticeResult(isCorrect);
                    },
                    practicedWords: {},
                    selectedSession: null,
                    resetCounter: 0,
                    showRemoveButton: false,
                  ),
                ),
              ] else ...[
                const Text("No hay palabras disponibles."),
              ]
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        //Dos botones flotantes
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _endPractice,
            tooltip: 'Terminar Práctica',
            child: const Icon(Icons.stop),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _startNewPractice,
            tooltip: 'Reiniciar Práctica',
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Liberar recursos
    super.dispose();
  }
}

//VISTA SPELLINGBEE
class SpellingBeeView extends StatefulWidget {
  const SpellingBeeView({super.key});

  @override
  State<SpellingBeeView> createState() => _SpellingBeeViewState();
}

class _SpellingBeeViewState extends State<SpellingBeeView> {
  int currentRound = 1;
  List<Word> wordsForCurrentRound = [];
  int currentWordIndexInRound = 0;
  bool hasRepeated = false;
  Word? currentWord;
  bool gameOver = false;
  String? errorMessage;
  int roundCorrectCount = 0;
  int roundIncorrectCount = 0;
  bool gameStarted = false;
  bool roundCompleted = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isSuddenDeath = false; // Indica si estamos en muerte súbita
  bool playerTurn = true; // Controla el turno (true: speller, false: oponente)
  String? winner;
  bool? isCorrect = true;

  List<Round> rounds = [
    Round(roundNumber: 1, numberOfWords: 3, canRepeat: true, canPause: true),
    Round(roundNumber: 2, numberOfWords: 3, canRepeat: true, canPause: false),
    Round(roundNumber: 3, numberOfWords: 2, canRepeat: false, canPause: false),
    Round(roundNumber: 4, numberOfWords: 1, canRepeat: false, canPause: false),
    Round(
        roundNumber: 5,
        numberOfWords: 5,
        canRepeat: false,
        canPause: false), // AHORA 5 Vocabulario
  ];

  Map<int, Map<String, int>> roundResults = {};

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  void _startNewSpellingBeeSession() {
    setState(() {
      currentRound = 1;
      wordsForCurrentRound = [];
      currentWordIndexInRound = 0;
      hasRepeated = false;
      currentWord = null;
      gameOver = false;
      errorMessage = null;
      roundCorrectCount = 0;
      roundIncorrectCount = 0;
      gameStarted = false;
      roundCompleted = false;
      roundResults.clear();
      isSuddenDeath = false; // Reiniciar la muerte súbita
      playerTurn = true; // Siempre empieza el speller
    });
  }

  void _nextRound() {
    roundResults[currentRound] = {
      'correct': roundCorrectCount,
      'incorrect': roundIncorrectCount,
    };

    if (currentRound < rounds.length) {
      setState(() {
        currentRound++;
        currentWordIndexInRound = 0;
        hasRepeated = false;
        roundCorrectCount = 0;
        roundIncorrectCount = 0;
        roundCompleted = false;
        _generateWordsForRound(currentRound);
      });
    } else {
      //Entrar a muerte súbita
      setState(() {
        isSuddenDeath = true;
        currentWordIndexInRound = 0;
        hasRepeated = false;
        roundCorrectCount = 0;
        roundIncorrectCount = 0;
        roundCompleted = false; // Reiniciar para la nueva palabra
        _generateWordsForRound(currentRound + 1);
      });
    }
  }

  Future<void> _generateWordsForRound(int roundNumber) async {
    int numWords;
    if (roundNumber <= rounds.length) {
      numWords = rounds[roundNumber - 1].numberOfWords;
    } else {
      numWords = 1; // Muerte súbita: 1 palabra por turno
    }

    final random = Random();
    try {
      final allWords = await WordRepository.getWords();
      if (allWords.isNotEmpty) {
        allWords.shuffle(random);
        setState(() {
          wordsForCurrentRound = allWords.take(numWords).toList();
          _loadCurrentWord();
        });
      } else {
        setState(() {
          wordsForCurrentRound = [];
          currentWord = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(content: Text("Error al generar Vocabulario: $e")),
        );
      }
      setState(() {
        wordsForCurrentRound = [];
        currentWord = null;
      });
    }
  }

  void _loadCurrentWord() {
    if (wordsForCurrentRound.isNotEmpty &&
        currentWordIndexInRound < wordsForCurrentRound.length) {
      setState(() {
        currentWord = wordsForCurrentRound[currentWordIndexInRound];
        hasRepeated = false;
        TextToSpeechService.speak(currentWord!.word);
      });
    } else {
      if (!isSuddenDeath) {
        //Si no estamos en muerte súbita, pasamos de ronda.
        _nextRound();
      } //Si estamos en muerte súbita, _recordSpellingBeeResult se encarga de la lógica
    }
  }

  void _handleRepeat() {
    if (rounds[min(currentRound - 1, rounds.length - 1)].canRepeat &&
        !hasRepeated) {
      setState(() {
        hasRepeated = true;
      });
      TextToSpeechService.speak(currentWord!.word);
    }
  }

  // Simula el resultado del oponente virtual.
  bool _simulateOpponent() {
    final random = Random();
    return random.nextInt(2) == 0; // 0 = acierto (true), 1 = fallo (false)
  }

  void _recordSpellingBeeResult(bool isCorrect) {
    if (currentWord == null) return;

    Round currentRoundRules = rounds[min(currentRound - 1, rounds.length - 1)];

    setState(() {
      //Logica de rondas normales
      if (!isSuddenDeath) {
        if (!isCorrect) {
          roundIncorrectCount++;
          if (!currentRoundRules.canRepeat) {
            //Si respondio incorrectamente
            roundResults[currentRound] = {
              'correct': roundCorrectCount,
              'incorrect': roundIncorrectCount,
            };
            gameOver = true;
            errorMessage = "Error en la Ronda $currentRound";
            _audioPlayer.setVolume(1.0);
            _audioPlayer.play(AssetSource('sounds/failure.mp3'));
            return;
          }
        } else {
          roundCorrectCount++;
        }

        currentWordIndexInRound++;
        if (currentWordIndexInRound < wordsForCurrentRound.length) {
          //Si aun hay Vocabulario
          _loadCurrentWord();
        } else {
          //Si ya no hay Vocabulario
          roundCompleted = true; // Fin de la ronda
          roundResults[currentRound] = {
            'correct': roundCorrectCount,
            'incorrect': roundIncorrectCount,
          };

          if (roundCorrectCount >= wordsForCurrentRound.length) {
            _audioPlayer.setVolume(1.0);
            _audioPlayer.play(AssetSource('sounds/success.mp3'));
          } else {
            _audioPlayer.setVolume(1.0);
            _audioPlayer.play(AssetSource('sounds/failure.mp3'));
          }
        }
      } else {
        //Logica de muerte súbita
        //MUERTE SÚBITA
        if (playerTurn) {
          // Turno del speller
          if (isCorrect) {
            playerTurn = false; // Turno del oponente
            roundCorrectCount++; //Aumentar aciertos en la ronda.
            roundCompleted = true; //Mostrar mensaje.
            _audioPlayer.setVolume(1.0);
            _audioPlayer
                .play(AssetSource('sounds/success.mp3')); //Sonido de exito
          } else {
            // El speller falló, ahora a ver que pasa con el oponente
            roundIncorrectCount++; //Aumentar fallos de la ronda
            if (_simulateOpponent()) {
              //Si el oponente virtual acierta.
              //El oponente virtual acertó, speller pierde
              gameOver = true;
              errorMessage = "Has perdido en la muerte súbita.";
              _audioPlayer.setVolume(1.0);
              _audioPlayer
                  .play(AssetSource('sounds/failure.mp3')); //Sonido de fallo
            } else {
              //Si el oponente falla, darle otra palabra al speller
              roundCompleted = true;
              playerTurn = true;
              _audioPlayer.setVolume(1.0);
              _audioPlayer.play(AssetSource(
                  'sounds/failure.mp3')); //Sonido de fallo para el oponente
            }
          }
        } else {
          // Turno del oponente (simulado)
          if (_simulateOpponent()) {
            // Oponente acertó, generar nueva palabra para el speller
            playerTurn = true; // Regresa el turno al speller
            roundCompleted = true;
          } else {
            // Oponente falló, el speller gana
            gameOver = true;
            winner = "¡Felicidades, has ganado!"; // Define winner
            _audioPlayer.setVolume(1.0);
            _audioPlayer.play(AssetSource('sounds/success.mp3'));
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (gameOver) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Spelling Bee"),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startNewSpellingBeeSession,
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                //Si winner es null, mostramos el mensaje de error, si no, mostramos el de ganador
                winner ?? errorMessage ?? "¡Completaste todas las rondas!",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text("Resultados por Ronda:",
                  style: Theme.of(context).textTheme.titleLarge),
              for (var round = 1; round <= roundResults.length; round++) ...[
                //Uso de la expansión de colecciones
                Text(
                    "Ronda $round: Aciertos: ${roundResults[round]!['correct']}, Errores: ${roundResults[round]!['incorrect']}",
                    style: Theme.of(context).textTheme.bodyLarge),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _startNewSpellingBeeSession,
                child: const Text("Jugar de Nuevo"),
              ),
            ],
          ),
        ),
      );
    }

    if (!gameStarted) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Spelling Bee"),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startNewSpellingBeeSession,
            ),
          ],
        ),
        body: Center(
          child: ElevatedButton(
            child: const Text("Iniciar Spelling Bee"),
            onPressed: () {
              setState(() {
                gameStarted = true;
                _generateWordsForRound(currentRound);
              });
            },
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SpellingBee'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startNewSpellingBeeSession,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Ronda $currentRound${isSuddenDeath ? ' (Muerte Súbita)' : ''}",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            if (currentWord != null && !roundCompleted)
              Text(
                "Palabra ${currentWordIndexInRound + 1} de ${wordsForCurrentRound.length}",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 20),
            if (roundCompleted) ...[
              // Mensajes de final de ronda
              if (!isSuddenDeath &&
                  roundCorrectCount == wordsForCurrentRound.length) ...[
                const Icon(Icons.check_circle, size: 100, color: Colors.green),
                const Text("¡Felicidades! Pasaste a la siguiente ronda.",
                    textAlign: TextAlign.center),
              ] else if (!isSuddenDeath) ...[
                const Icon(Icons.cancel, size: 100, color: Colors.red),
                Text("Lo siento, no pasaste la ronda $currentRound",
                    textAlign: TextAlign.center),
              ] else if (isSuddenDeath) ...[
                //Mensajes para la muerte súbita.
                if (!playerTurn && isCorrect!) ...[
                  //Si acierta el speller, turno del oponente
                  const Icon(Icons.check_circle,
                      size: 100, color: Colors.green),
                  const Text("Turno del contrincante.",
                      textAlign: TextAlign.center),
                ] else if (!playerTurn && !isCorrect!) ...[
                  const Icon(Icons.cancel, size: 100, color: Colors.red),
                  const Text("¡Felicidades!.", textAlign: TextAlign.center),
                ] else if (playerTurn && isCorrect!) ...[
                  const Icon(Icons.check_circle,
                      size: 100, color: Colors.green),
                  const Text("Contrincante ha acertado. Tu turno",
                      textAlign: TextAlign.center),
                ] else ...[
                  //Falla el speller, turno del oponente a ver que pasa.
                  const Icon(Icons.cancel, size: 100, color: Colors.red),
                  Text("Turno del contrincante", textAlign: TextAlign.center),
                ]
              ],

              const SizedBox(height: 20),
              if (!gameOver &&
                      (!isSuddenDeath &&
                          roundCorrectCount == wordsForCurrentRound.length) ||
                  (isSuddenDeath)) // Mostrar solo si no es Game Over y pasó la ronda.
                ElevatedButton(
                  onPressed: () {
                    if (isSuddenDeath) {
                      if (playerTurn) {
                        _generateWordsForRound(currentRound + 1);
                        setState(() {
                          //Resetear variables
                          roundCompleted = false;
                        });
                      } else {
                        //Si le toca al oponente, simular
                        if (_simulateOpponent()) {
                          setState(() {
                            roundCompleted = false;
                            playerTurn = true;
                          });
                          _generateWordsForRound(currentRound +
                              1); //Generar nueva palabra para el speller
                        } else {
                          //El oponente ha fallado, el speller gana.
                          setState(() {
                            gameOver = true;
                            winner = "¡Felicidades, has ganado!";
                            _audioPlayer.setVolume(1.0);
                            _audioPlayer
                                .play(AssetSource('sounds/success.mp3'));
                          });
                        }
                      }
                    } else if (!isSuddenDeath &&
                        roundCorrectCount == wordsForCurrentRound.length) {
                      //Si pasamos la ronda, y no estamos en muerte súbita, siguiente ronda.
                      _nextRound();
                    }
                  },
                  child: Text(isSuddenDeath
                      ? "Siguiente Palabra"
                      : "Iniciar Siguiente Ronda"), //Texto del botón
                ),
            ],
            if (currentWord != null && !roundCompleted) ...[
              Text(currentWord!.word,
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: rounds[min(currentRound - 1, rounds.length - 1)]
                            .canRepeat &&
                        !hasRepeated
                    ? _handleRepeat
                    : null,
                child:
                    Text(hasRepeated ? "Repetición usada" : "Repetir Palabra"),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text("Correcto"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      _recordSpellingBeeResult(true);
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text("Incorrecto"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      _recordSpellingBeeResult(false);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "Aciertos: $roundCorrectCount - Errores: $roundIncorrectCount",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ] else if (!roundCompleted)
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

class Round {
  final int roundNumber;
  final int numberOfWords;
  final bool canRepeat;
  final bool canPause;

  Round({
    required this.roundNumber,
    required this.numberOfWords,
    required this.canRepeat,
    required this.canPause,
  });
}
