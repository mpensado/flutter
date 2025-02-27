//ESTA EN HOME_SCREEN
import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/word_repository.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/practice_session_repository.dart';
import 'package:spelling_bee_practice/domain/entities/practice_session.dart';
import 'package:spelling_bee_practice/presentation/widgets/shared/word_card.dart';
import 'package:spelling_bee_practice/presentation/utils/translation_service.dart';
import 'dart:async';


class WordsTab extends StatefulWidget {
  final VoidCallback onWordAdded;

  const WordsTab({super.key, required this.onWordAdded});

  @override
  State<WordsTab> createState() => WordsTabState();
}

class WordsTabState extends State<WordsTab> with AutomaticKeepAliveClientMixin {
  // Add this mixin
  Future<List<Word>>? _wordsFuture;
  String searchQuery = '';
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true; // Add this

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    await WordRepository.loadInitialData();
    await PracticeSessionRepository.createFixedSessions();
    //DBHelper.copyTempDbToLaptop();
    setState(() {
      if (searchQuery.isEmpty) {
        _wordsFuture = WordRepository.getAllWords();
      } else {
        _wordsFuture = WordRepository.searchWords(searchQuery);
      }
    });
  }

  void showAddWordDialog(BuildContext context, VoidCallback onWordAdded,
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
      builder: (context) => StatefulBuilder(builder: (context, setState) {
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
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error al traducir: $e")));
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
                      widget.onWordAdded(); // Usar el callback del widget

                      // Actualizar PracticeTab (si existe) ya no se hace aca
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
      }),
    );
  }

//Esta funcion no se puede hacer privada si se usa fuera de esta clase
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
                      id: await PracticeSessionRepository.getLastIdFixedSessions(),
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
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("Error al crear sesión: $e")));
                      }
                      return;
                    }
                  }

                  if (sessionToUse != null) {
                    try {
                      //Si se añadio exitosamente entonces actualiza la vista de la tab de practice
                      if (newSession) {
                        widget.onWordAdded();
                      }
                      if (!newSession) {
                        await PracticeSessionRepository.addWordToSession(
                            wordToAdd, sessionToUse);
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
    super.build(context); // Call super.build

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showAddWordDialog(context, () {
            // Usar la función local.  Más limpio.
            setState(() {
              _loadWords(); //Actualizar palabras
            });
          });
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        // Usa un Column para el buscador y la lista
        children: [
          Padding(
            // Agrega un Padding para el buscador
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar palabras',
                suffixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                  _loadWords(); //  Actualizar palabras
                });
              },
            ),
          ),
          Expanded(
            // Usa Expanded para que la lista ocupe el espacio restante
            child: FutureBuilder<List<Word>>(
              future: _wordsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay palabras.'));
                } else {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final word = snapshot.data![index];
                      return WordCard(
                        word: word,
                        onDelete: () async {
                          try {
                            await WordRepository.deleteWord(word.id!);
                            //Actualizar ambas tabs despues de borrar
                            widget.onWordAdded();
                            setState(() {
                              _loadWords();
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Palabra "${word.word}" eliminada.'),
                                ),
                              );
                            }
                          } catch (e) {
                            //Manejo de errores de borrado
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          "Error al eliminar palabra: $e")));
                            }
                          }
                        },
                        onEdit: () {
                          showAddWordDialog(context, () {
                            setState(() {
                              _loadWords(); //Actualizar palabras
                            });
                          }, wordToEdit: word);
                        },
                        onAddToSession: () {
                          _showAddToSessionDialog(context, word);
                        },
                      );
                    },
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
