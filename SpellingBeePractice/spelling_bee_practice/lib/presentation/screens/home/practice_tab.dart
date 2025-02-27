//ESTA EN HOME_SCREEN
import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/practice_session.dart';
import 'package:spelling_bee_practice/helpers/db_helper.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/practice_session_repository.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/presentation/widgets/shared/word_card_practice.dart';
import 'package:spelling_bee_practice/presentation/screens/home/random_practice_view.dart';
import 'package:spelling_bee_practice/domain/entities/practice_history.dart';
// Importa PracticeHistory

class PracticeTab extends StatefulWidget {
  const PracticeTab({super.key});

  @override
  State<PracticeTab> createState() => PracticeTabState();
}

class PracticeTabState extends State<PracticeTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  Future<List<Word>>? _wordsFuture;
  List<PracticeSession> sessions = [];
  PracticeSession? selectedSession;
  Set<int> practicedWords = {};
  int correctCount = 0;
  int incorrectCount = 0;
  int resetCounter = 0; // Para reiniciar WordCardPractice

  late TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // final dbHelper = DBHelper();
    // try {
    //   final db = await dbHelper.database;
    //   final wordCount = Sqflite.firstIntValue(
    //       await db.rawQuery('SELECT COUNT(*) FROM ${dbHelper.tableWords}'));

    //   if (wordCount == 0) {
    //     await dbHelper
    //         .loadSampleData(); // Usar dbHelper, no DBHelper directamente.
    //   }
    // } catch (e) {
    //   if (mounted) {
    //     // context check
    //     ScaffoldMessenger.of(context)
    //         .showSnackBar(SnackBar(content: Text("Error al cargar datos iniciales: $e")));
    //   }
    //   return; // Early return on error
    // }
    await loadPracticeSessions();
  }

  // Método público para recargar sesiones.  Llamado desde HomePage.
  Future<void> loadPracticeSessions() async {
    try {
      List<PracticeSession> fixedSessions =
          await PracticeSessionRepository.getFixedSessions();

      List<PracticeSession> loadedSessions =
          await PracticeSessionRepository.getAllSessions();
      

      setState(() {
        sessions = [...fixedSessions, ...loadedSessions];

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

  Future<void> _loadSessionWords() async {
    if (selectedSession == null) {
      setState(() {
        _wordsFuture = Future.value([]);
      });
      return;
    }

    setState(() {
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
          sessionType: 'session');

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
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error al registrar la práctica: $e")));
        }
      }
    }
  }

  // Wrapper para pasar el estado a WordCardPractice
  void _recordPracticeWrapper(
      Word word, bool isCorrect, WordCardPracticeState cardState) {
    _recordPractice(word, isCorrect);
    cardState.setState(() {
      cardState.practiceResult = isCorrect;
      cardState.isPracticed = true;
    });
  }

  void _resetPractice() {
    setState(() {
      practicedWords.clear();
      correctCount = 0;
      incorrectCount = 0;
      _loadSessionWords();
      resetCounter++; // Incrementa el contador para forzar la reconstrucción
    });
  }

    void _showDeleteSessionDialog(BuildContext context, PracticeSession sessionToDelete) {
        showDialog(
            context: context,
            builder: (context) {
                return AlertDialog(
                    title: const Text('Eliminar Sesión'),
                    content: Text(
                        '¿Está seguro de que desea eliminar la sesión "${sessionToDelete.name}"? Esta acción no se puede deshacer.'),
                    actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                        ),
                        TextButton(
                            onPressed: () async {
                                try {
                                    await PracticeSessionRepository.deleteSession(sessionToDelete.id!);
                                    if (context.mounted) {
                                        Navigator.pop(context); // Cerrar diálogo
                                        loadPracticeSessions();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Sesión "${sessionToDelete.name}" eliminada.')),
                                        );
                                    }
                                } catch (e) {
                                    if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error al eliminar la sesión: $e')),
                                        );
                                    }
                                }
                            },
                            child: const Text('Eliminar'),
                        ),
                    ],
                );
            },
        );
    }

  @override
  Widget build(BuildContext context) {
    super.build(context); //  super.build

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
          _buildSessionPractice(context), // Contenido de la pestaña "Por sesión"
          RandomPracticeView(), // Contenido de la pestaña "Aleatorio"
        ],
      ),
    );
  }

  Widget _buildSessionPractice(BuildContext context) {
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
                      child: Row( // Usar Row para mostrar texto e icono
                        children: [
                          Expanded(child: Text(session.name)), // Para que el texto ocupe el espacio disponible
                          if(!session.isFixed) // Mostrar solo si no es fijo
                            IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              _showDeleteSessionDialog(context, session);
                            },
                            tooltip: 'Borrar sesión', //  tooltip
                          ),

                        ],
                      ),
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
              IconButton( // Botón de refrescar
                icon: const Icon(Icons.refresh),
                onPressed: _resetPractice,
                tooltip: 'Reiniciar práctica',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Aciertos: $correctCount | Errores: $incorrectCount',
            style: Theme.of(context).textTheme.titleMedium, // Use a suitable text style
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
                    onRefresh:
                        loadPracticeSessions,
                    child: ListView.builder(
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final word = snapshot.data![index];
                          return WordCardPractice(
                            key: ValueKey(
                                '${word.id}-$resetCounter'), // Usa resetCounter
                            word: word,
                            onDelete: () async {
                              //Ya no se usa en esta vista
                            },
                            onRecordPracticeCallback: _recordPracticeWrapper,
                            practicedWords: practicedWords,
                            selectedSession: selectedSession,
                            resetCounter: resetCounter,
                            showRemoveButton:
                                false, //  No mostrar el botón de eliminar
                          );
                        }));
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}