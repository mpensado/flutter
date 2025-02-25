// HomePage
import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/word_repository.dart';
import 'package:spelling_bee_practice/presentation/screens/home/spelling_bee_view.dart';
import 'package:spelling_bee_practice/presentation/utils/text_to_speech_service.dart';
import 'dart:async';
import 'package:spelling_bee_practice/presentation/utils/translation_service.dart';
import 'package:spelling_bee_practice/domain/entities/practice_history.dart';
import 'package:spelling_bee_practice/domain/entities/practice_session.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/practice_session_repository.dart';
import 'package:spelling_bee_practice/helpers/db_helper.dart';
import 'package:spelling_bee_practice/presentation/screens/home/random_practice_view.dart';
import 'package:sqflite/sqflite.dart';

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
//WORDS TAB
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


//PRACTICA TAB
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
        ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
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

//WORDCAR
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
        ScaffoldMessenger.of(context).showSnackBar(
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

//WORDCARD
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
