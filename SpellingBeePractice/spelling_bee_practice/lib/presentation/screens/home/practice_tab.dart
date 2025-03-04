// practice_tab.dart
import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/practice_session.dart';
import 'package:spelling_bee_practice/helpers/db_helper.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/practice_session_repository.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/presentation/widgets/shared/word_card_practice.dart';
import 'package:spelling_bee_practice/presentation/screens/home/random_practice_view.dart';
import 'package:spelling_bee_practice/domain/entities/practice_history.dart';

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
  int correctCount = 0;
  int incorrectCount = 0;

  late TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
        _tabController.addListener(_handleTabSelection); // Add listener
    _loadInitialData();
  }

    void _handleTabSelection() {
    if (_tabController.indexIsChanging) { //  Check if index is changing
      _resetPractice();
    }
  }

  Future<void> _loadInitialData() async {
    await loadPracticeSessions();
  }

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
    if (selectedSession == null) return;

    final practice = PracticeHistory(
      wordId: word.id!,
      sessionId: selectedSession!.id,
      isCorrect: isCorrect,
      practicedAt: DateTime.now(),
      sessionType: 'session',
    );

    final dbHelper = DBHelper();
    try {
      final db = await dbHelper.database;
      await db.insert('practice_history', practice.toMap());

        // Update the UI *before* fetching the new word data.  Optimistic update.
        setState(() {
          if (isCorrect) {
            correctCount++;
          } else {
            incorrectCount++;
          }
        });


    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al registrar la práctica: $e")),
        );
      }
    }
  }


    Future<Word> _getWordData(Word word) async {
        final dbHelper = DBHelper();
        try {
            final db = await dbHelper.database;
            final List<Map<String, dynamic>> result = await db.query(
                dbHelper.tableWords,
                where: 'id = ?',
                whereArgs: [word.id],
                limit: 1,
            );

            if (result.isNotEmpty) {
                // Create a *new* Word object with the updated data.  Don't modify the original.
                return Word.fromMap(result.first);
            } else {
                return word; // Return original word if not found (shouldn't happen)
            }
        } catch (e) {
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error al obtener datos de la palabra: $e")),
                );
            }
            return word; // Return the original word in case of error.
        }
    }

  void _resetPractice() {
    setState(() {
      correctCount = 0;
      incorrectCount = 0;
      _loadSessionWords();
    });
  }


  void _showDeleteSessionDialog(
      BuildContext context, PracticeSession sessionToDelete) {
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
                  await PracticeSessionRepository.deleteSession(
                      sessionToDelete.id);
                  if (context.mounted) {
                    Navigator.pop(context); // Cerrar diálogo
                    loadPracticeSessions();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Sesión "${sessionToDelete.name}" eliminada.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error al eliminar la sesión: $e')),
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
          _buildSessionPractice(context),
          RandomPracticeView(),
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
                      child: Row(
                        children: [
                          Expanded(child: Text(session.name)),
                          if (!session.isFixed)
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                _showDeleteSessionDialog(context, session);
                              },
                              tooltip: 'Borrar sesión',
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (PracticeSession? newValue) {
                    setState(() {
                      selectedSession = newValue;
                      _resetPractice(); // Reset practice when session changes
                      _loadSessionWords();
                    });
                  },
                ),
              ),
              IconButton(
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
            style: Theme.of(context)
                .textTheme
                .titleMedium, // Use a suitable text style
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
                      loadPracticeSessions, // Consider using _refreshCurrentSessionWords
                  child: ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final word = snapshot.data![index];
                      // Wrap EACH WordCardPractice with its OWN FutureBuilder
                      return FutureBuilder<Word>(
                        future: _getWordData(word), // Fetch updated word data
                        builder: (context, wordSnapshot) {
                          if (wordSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const LinearProgressIndicator(); // Or some other placeholder
                          } else if (wordSnapshot.hasError) {
                            return Text('Error: ${wordSnapshot.error}');
                          } else if (!wordSnapshot.hasData) {
                            return const Text("No data"); // Shouldn't happen
                          }

                          final updatedWord =
                              wordSnapshot.data!; // This is the updated Word

                          return WordCardPractice(
                            key: Key(
                                updatedWord.id!.toString()), // Use a simple Key.  No need for resetCounter.
                            word: updatedWord, // Pass the UPDATED word
                            onDelete: () async {
                              // Not used in this view
                            },
                            onRecordPracticeCallback:(word, isCorrect) {
                                _recordPractice(word, isCorrect);
                            },

                            selectedSession: selectedSession,
                            showRemoveButton: false,
                          );
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
    );
  }


  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }
}