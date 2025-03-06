import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/word_repository.dart';
import 'package:spelling_bee_practice/presentation/widgets/shared/word_card.dart';
import 'package:spelling_bee_practice/presentation/utils/translation_service.dart'; // Para la traducción
import 'dart:async'; // Para el debounce

class WordsTab extends StatefulWidget {
  final VoidCallback onWordAdded; // Callback para notificar adiciones/ediciones

  const WordsTab({super.key, required this.onWordAdded});

  @override
  State<WordsTab> createState() => WordsTabState();
}

class WordsTabState extends State<WordsTab> with AutomaticKeepAliveClientMixin {
  Future<List<Word>>? _wordsFuture;
  String searchQuery = '';
  String? selectedList; // Lista seleccionada (null = Todas)
  String? sortOrder = 'dateDesc'; // Criterio de ordenación
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true; // Para mantener el estado al cambiar de pestaña

  @override
  void initState() {
    super.initState();
    _wordsFuture = _loadWords();  // Iniciar la carga de palabras.
  }

  @override
  void dispose() {
    _debounce?.cancel(); // Buena práctica: cancelar el timer en dispose
    super.dispose();
  }

  Future<List<Word>> _loadWords() async {
      List<Word> words;
      if (searchQuery.isNotEmpty) {
        words = await WordRepository.searchWords(searchQuery, sortOrder: sortOrder);
      } else if (selectedList != null && selectedList!.isNotEmpty && selectedList != "Todas") {
        words = await WordRepository.getWordsByList(selectedList!, sortOrder: sortOrder);
      } else {
        words = await WordRepository.getAllWords(sortOrder: sortOrder);
      }
      return words;
  }

  // Diálogo para agregar/editar palabras (ahora un método de _WordsTabState)
  void showAddWordDialog(BuildContext context, VoidCallback onWordAdded,
      {Word? wordToEdit}) {
        // ... (código del diálogo, igual que antes, con setStateDialog y widget.onWordAdded) ...
        //VERSIÓN COMPLETA Y ACTUALIZADA DEL DIALOGO EN RESPUESTAS ANTERIORES

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
            //selectedLists = List.from(wordToEdit.lists);  // Copia las listas existentes.
        }

     showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // Usar StatefulBuilder
        builder: (context, setStateDialog) {  // Usar setStateDialog
          return AlertDialog(
            title: Text(dialogTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<String>(  // Usar Autocomplete<String>
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      // Usa tu WordRepository para buscar sugerencias.
                      final words = await WordRepository.searchWords(textEditingValue.text); // Limitado a 10 resultados para mayor eficiencia
                      return words.map((word) => word.word).toList();
                    },
                    displayStringForOption: (String option) => option,  // Mostrar la palabra
                    fieldViewBuilder: (
                        BuildContext context,
                        TextEditingController textEditingController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted) {

                        //Seteamos el valor inicial si se está editando
                        if(wordToEdit != null && wordController.text.isNotEmpty){
                            textEditingController.text = wordToEdit.word;
                          }
                        return TextField(
                        controller: textEditingController,  // Usar el controlador provisto
                        focusNode: focusNode, // Usar el FocusNode provisto
                        onSubmitted: (String value) {
                            onFieldSubmitted();
                        },
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
                                          setStateDialog(() {  // Usa setStateDialog
                                            translationController.text = translated;
                                          });
                                        }
                                    }).catchError((e) { // Manejo de errores de traducción
                                        if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al traducir: $e")));
                                        }
                                    });
                                }
                            });
                        },

                      );
                    },
                    onSelected: (String selection) {  //Se selecciona una palabra sugerida
                        setStateDialog(() { // Usa setStateDialog
                            wordController.text = selection;  //  selection;
                            TranslationService.translate(text: selection)
                                .then((translated) {
                                    if (mounted) {
                                        setStateDialog(() { // Usa setStateDialog
                                            translationController.text = translated;
                                        });
                                    }
                                    }).catchError((e) { // Manejo de errores
                                        if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al traducir: $e")));
                                        }
                                    });
                        });
                    },

                  ),
                  const SizedBox(height: 8),
                  Focus(
                    child: TextField(
                      controller: translationController,
                      decoration:   InputDecoration(
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
                                isAutoTranslating = !isAutoTranslating;
                                // Forzar traducción si se reactiva
                                if (isAutoTranslating &&
                                    wordController.text.isNotEmpty) {
                                  TranslationService.translate(
                                          text: wordController.text)
                                      .then((translated) {
                                    if (mounted) {
                                     setStateDialog(() {
                                        translationController.text = translated;
                                      });
                                    }
                                  }).catchError((e) {
                                    // Manejo de errores
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(
                                                  "Error al traducir: $e")));
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
                        widget.onWordAdded(); // Notificar a HomePage
                        setState(() {
                          _wordsFuture = _loadWords(); // Actualizar la lista
                        });
                        }

                    } catch (e) {
                    //Manejo de errores de guardado
                        if (context.mounted){
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al guardar/actualizar: $e")));
                        }
                    }
                  } else {
                    if (context.mounted){
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

    //Ya se usa en el dialogo
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
  Widget build(BuildContext context) {
    super.build(context); //  super.build

    return Scaffold(
      floatingActionButton: null, // Quitado el botón flotante
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
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No hay listas disponibles.');
                } else {
                      final List<String> allLists = [
                        ...snapshot.data!
                      ];
                    return DropdownButtonFormField<String>(
                    value: selectedList,
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
                            _loadWords(); // Recargar las palabras
                      });
                    },
                  );
                }
              },
            ),
          ),

          // Dropdown para ordenar palabras
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButtonFormField<String>(
              value: sortOrder,
              decoration: const InputDecoration(
                labelText: 'Ordenar por',
              ),
              items: const [
                DropdownMenuItem(value: 'dateDesc', child: Text('Más recientes')),
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
                        // Usa WordCard directamente.
                        word: word,
                        onDelete: () async {
                          try {
                            await WordRepository.deleteWord(word.id!);
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
                                setState(() { //No es necesario dentro del setState
                                    _wordsFuture = _loadWords();
                                });
                            }, wordToEdit: word);
                        },
                        onAddToSession: (){}, //  eliminado de wordcard
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