import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/word_repository.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/practice_session_repository.dart';
import 'package:spelling_bee_practice/domain/entities/practice_session.dart';
import 'package:spelling_bee_practice/presentation/widgets/shared/word_card.dart';
import 'package:spelling_bee_practice/presentation/utils/translation_service.dart';
import 'dart:async';

class WordsTab extends StatefulWidget {
  final VoidCallback? onWordAdded;

  const WordsTab({super.key, required this.onWordAdded});

  @override
  State<WordsTab> createState() => WordsTabState();
}

class WordsTabState extends State<WordsTab> with AutomaticKeepAliveClientMixin {
  Future<List<Word>>? _wordsFuture;
  String searchQuery = '';
  Timer? _debounce;
  String? selectedList; // Lista seleccionada (null = Todas)
  String? sortOrder = 'dateDesc'; // Orden por defecto

  @override
  bool get wantKeepAlive => true; // Add this

  @override
  void initState() {
    super.initState();
    selectedList = "Todas"; //Valor por defecto en el dropdown
    _wordsFuture = _loadWords(); // Inicializa el Future al inicio.
  }

  @override
  void dispose() {
    _debounce?.cancel(); // Cancelar si existe
    super.dispose();
  }

  Future<List<Word>> _loadWords() async {
    //Ya no es necesario cargar las palabras de ejemplo en cada carga
    //await WordRepository.loadInitialData();
    //await PracticeSessionRepository.createFixedSessions();

    List<Word> words;
    if (searchQuery.isNotEmpty) {
      words = await WordRepository.searchWords(searchQuery,
          sortOrder: sortOrder); // Búsqueda
    } else if (selectedList != null &&
        selectedList!.isNotEmpty &&
        selectedList != "Todas") {
      words = await WordRepository.getWordsByList(selectedList!,
          sortOrder: sortOrder); // Filtrado por lista
    } else {
      words = await WordRepository.getAllWords(
          sortOrder: sortOrder); // Todas las palabras
    }
    return words;
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

  //Dentro de word_tab.dart
  void showAddWordDialog(BuildContext context, VoidCallback onWordAdded,
      {Word? wordToEdit}) {
    final wordController = TextEditingController();
    final translationController = TextEditingController();
    bool isAutoTranslating = true;
    List<String> selectedLists = []; // Listas seleccionadas

    String dialogTitle = 'Nueva Palabra';
    String saveButtonText = 'Guardar';

    if (wordToEdit != null) {
      dialogTitle = 'Editar Palabra';
      saveButtonText = 'Actualizar';
      wordController.text = wordToEdit.word;
      translationController.text = wordToEdit.translation;
      selectedLists =
          List.from(wordToEdit.lists); // Copia las listas existentes.
    }
    // Obtener todas las listas disponibles (para el diálogo).
    Future<List<String>> allLists = WordRepository.getAllLists();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // Usar setStateDialog
          return AlertDialog(
            title: Text(dialogTitle),
            content: SingleChildScrollView(
              // Para evitar overflow si hay muchas listas
              child: Column(
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
                              setStateDialog(() {
                                // Usa setStateDialog
                                translationController.text = translated;
                              });
                            }
                          }).catchError((e) {
                            // Manejo de errores de traducción
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
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
                            isAutoTranslating
                                ? Icons.sync
                                : Icons.sync_disabled,
                            color:
                                isAutoTranslating ? Colors.green : Colors.red,
                          ),
                          tooltip: isAutoTranslating
                              ? 'Traducción automática activada'
                              : 'Traducción automática desactivada',
                          onPressed: () {
                            setStateDialog(() {
                              // Usa setStateDialog
                              isAutoTranslating = !isAutoTranslating;
                              // Forzar traducción si se reactiva
                              if (isAutoTranslating &&
                                  wordController.text.isNotEmpty) {
                                TranslationService.translate(
                                        text: wordController.text)
                                    .then((translated) {
                                  if (mounted) {
                                    setStateDialog(() {
                                      // Usa setStateDialog
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
                  const SizedBox(height: 16),

                  // Lista de selección de listas (FutureBuilder).
                  FutureBuilder<List<String>>(
                    future: allLists,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text('No hay listas disponibles.');
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Seleccionar Listas:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8.0, // Espacio horizontal entre chips
                              runSpacing: 4.0, // Espacio vertical entre líneas
                              children: snapshot.data!.map((listName) {
                                if (listName == "Todas") {
                                  return const SizedBox
                                      .shrink(); // No mostrar chip para "Todas"
                                }
                                return FilterChip(
                                  label: Text(listName),
                                  selected: selectedLists.contains(listName),
                                  onSelected: (bool selected) {
                                    setStateDialog(() {
                                      // Usa setStateDialog
                                      if (selected) {
                                        selectedLists.add(listName);
                                      } else {
                                        selectedLists.remove(listName);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(
                                height:
                                    10), //  espacio antes del botón de agregar lista
                            ElevatedButton.icon(
                              onPressed: () {
                                // Diálogo para crear nueva lista
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    String newListName = '';
                                    return AlertDialog(
                                      title: const Text('Crear nueva lista'),
                                      content: TextField(
                                        onChanged: (value) =>
                                            newListName = value,
                                        decoration: const InputDecoration(
                                            labelText: 'Nombre de la lista'),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Cancelar'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            if (newListName.isNotEmpty) {
                                              // Agregar la nueva lista a la base de datos y a la lista seleccionada.
                                              try {
                                                // Obtener la palabra actual (si existe)
                                                final word =
                                                    await WordRepository
                                                        .getWordByText(
                                                            wordController
                                                                .text);

                                                // Si la palabra NO existe, añadirla a la lista de seleccionadas.
                                                if (word == null) {
                                                  setStateDialog(() {
                                                    selectedLists
                                                        .add(newListName);
                                                  });
                                                } else {
                                                  //Si la palabra existe, insertarla en la nueva lista.

                                                  // Ya no se llama a insertWordToList, se maneja en update/insert
                                                  //await WordRepository.insertWordToList(word.id!, newListName);

                                                  //Actualizar la lista de las listas seleccionadas.
                                                  final updatedLists = List<
                                                      String>.from(word.lists)
                                                    ..add(
                                                        newListName); //Añadimos la lista
                                                  //Actualizar en la BD.
                                                  await WordRepository
                                                      .updateWord(word.copyWith(
                                                          lists: updatedLists));

                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(SnackBar(
                                                            content: Text(
                                                                "Lista $newListName agregada.")));
                                                  }
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content: Text(
                                                              "Error al crear lista: $e")));
                                                }
                                              }
                                              if (context.mounted) {
                                                Navigator.pop(
                                                    context); //Cerrar el dialogo
                                              }
                                            }
                                          },
                                          child: const Text('Crear'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Crear Lista'),
                            ),
                          ],
                        );
                      }
                    },
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
                  if (wordController.text.isNotEmpty &&
                      translationController.text.isNotEmpty) {
                    final word = Word(
                      id: wordToEdit?.id,
                      word: wordController.text,
                      translation: translationController.text,
                      spelling:
                          "${wordController.text}.${_spelling(wordController.text)}.${wordController.text}",
                      createdAt: wordToEdit?.createdAt ?? DateTime.now(),
                      lists: selectedLists, // Guarda las listas seleccionadas
                    );
                    try {
                      if (wordToEdit == null) {
                        await WordRepository.insertWord(word);
                      } else {
                        await WordRepository.updateWord(word);
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                        widget.onWordAdded!(); //Notificar a HomePage
                        setState(() {
                          _wordsFuture = _loadWords();
                        });
                      }
                    } catch (e) {
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
                child: Text(wordToEdit == null ? 'Guardar' : 'Actualizar'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Elimina esta función, ya no se usa
  // void _showAddToSessionDialog(BuildContext context, Word wordToAdd) async {
  //   // ... (Toda la lógica de añadir a sesión se ha eliminado) ...
  // }

  @override
  Widget build(BuildContext context) {
    super.build(context); //  super.build

    return Scaffold(
      floatingActionButton: null, // Quita el botón flotante
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              // Usa TextField en lugar de SearchBar
              decoration: const InputDecoration(
                labelText: 'Buscar palabras',
                suffixIcon: Icon(Icons.search),
                border: OutlineInputBorder(), // Añade un borde
              ),
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  // Añadido debounce
                  setState(() {
                    searchQuery = value;
                    _wordsFuture =
                        _loadWords(); // Actualiza el Future al buscar.
                  });
                });
              },
            ),
          ),
          // Dropdown para seleccionar la lista
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: FutureBuilder<List<String>>(
              future: WordRepository.getAllLists(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator(); // Muestra un indicador de carga
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text(
                      'No hay listas disponibles.'); // Mensaje si no hay listas
                } else {
                  // Añadir la opción "Todas" a la lista de listas.
                  final List<String> allLists = [
                    ...snapshot.data!
                  ]; // Agrega "Todas"

                  // Asegurarse de que selectedList tenga un valor válido.
                  if (selectedList == null ||
                      !allLists.contains(selectedList)) {
                    selectedList =
                        'Todas'; // Establecer "Todas" como valor por defecto
                  }

                  return DropdownButtonFormField<String>(
                    value: selectedList, //  valor seleccionado
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por lista',
                    ),
                    items: allLists.map((String listName) {
                      return DropdownMenuItem<String>(
                        value: listName,
                        child: Text(listName),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedList = newValue;
                        _wordsFuture =
                            _loadWords(); // Recargar las palabras al cambiar la lista
                      });
                    },
                  );
                }
              },
            ),
          ),
          //Dropdown para ordenar palabras
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButtonFormField<String>(
              value: sortOrder,
              decoration: const InputDecoration(
                labelText: 'Ordenar por',
              ),
              items: const [
                DropdownMenuItem(
                    value: 'dateDesc', child: Text('Más recientes')),
                DropdownMenuItem(value: 'dateAsc', child: Text('Más antiguas')),
                DropdownMenuItem(value: 'az', child: Text('A-Z')),
                DropdownMenuItem(value: 'za', child: Text('Z-A')),
              ],
              onChanged: (String? newValue) {
                setState(() {
                  sortOrder = newValue;
                  _wordsFuture = _loadWords(); // Recargar al cambiar el orden
                });
              },
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Word>>(
              future: _wordsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay palabras.'));
                } else {
                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {
                        _wordsFuture = _loadWords();
                      });
                    },
                    child: ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final word = snapshot.data![index];
                        return WordCard(
                            word: word,
                            onDelete: () async {
                              try {
                                await WordRepository.deleteWord(word.id!);
                                // _loadWords(); // Recarga, asignando el nuevo Future.
                                widget.onWordAdded!(); //Llamada a HomePage
                                setState(() {
                                  _wordsFuture = _loadWords();
                                });

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Palabra "${word.word}" eliminada.'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text("Error al eliminar palabra: $e"),
                                    ),
                                  );
                                }
                              }
                            },
                            onEdit: () {
                              showAddWordDialog(context, () {
                                //Se llama asi mismo.
                                setState(() {
                                  //No es necesario usar setState
                                  _wordsFuture = _loadWords();
                                });
                              }, wordToEdit: word);
                            },
                            onAddToSession: () {
                              //No es necesario usar este parametro
                            });
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
