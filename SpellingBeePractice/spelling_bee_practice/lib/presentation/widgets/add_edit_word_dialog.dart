import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/word_repository.dart'; // Importa el repositorio
import 'package:spelling_bee_practice/presentation/utils/translation_service.dart';

class AddEditWordDialog extends StatefulWidget {
  final Word? wordToEdit;
  final Function(Word) onWordSaved; // Cambia el tipo del callback

  const AddEditWordDialog({
    super.key,
    required this.onWordSaved, // Cambia el nombre
    this.wordToEdit,
  });

  @override
  State<AddEditWordDialog> createState() => _AddEditWordDialogState();
}

class _AddEditWordDialogState extends State<AddEditWordDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _wordController;
  late TextEditingController _translationController;
  late TextEditingController _spellingController;
  final List<String> _selectedLists = []; //  Listas seleccionadas

  //Para Nuevas listas
  final TextEditingController _newListController = TextEditingController();
  bool _isAddingNewList = false;


  @override
  void initState() {
    super.initState();
    _wordController =
        TextEditingController(text: widget.wordToEdit?.word ?? '');
    _translationController =
        TextEditingController(text: widget.wordToEdit?.translation ?? '');
    _spellingController =
        TextEditingController(text: widget.wordToEdit?.spelling ?? '');

    // Inicializar _selectedLists. Importante para la edición.
    if (widget.wordToEdit != null) {
      _selectedLists.addAll(widget.wordToEdit!.lists);
    }
  }

  @override
  void dispose() {
    _wordController.dispose();
    _translationController.dispose();
    _spellingController.dispose();
    _newListController.dispose();
    super.dispose();
  }

   Future<void> _getSuggestedTranslation() async {
          if (_wordController.text.isNotEmpty) {
            try {
              final translation =
                  await TranslationService.translate(text: _wordController.text, from: "en", to: "es");  //Usar el servicio
              if (translation != null) {
                setState(() {
                  _translationController.text = translation;
                });
              }
            } catch (e) {
              // Manejar errores (mostrar un snackbar, log, etc.).
              print("Error al obtener la traducción: $e");
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al obtener la traducción: $e')),
                );
              }
            }
          }
        }

      @override
      Widget build(BuildContext context) {
        return AlertDialog(
          title: Text(widget.wordToEdit == null ? 'Añadir palabra' : 'Editar palabra'),
          content: SingleChildScrollView(
            // Para evitar overflow con el teclado
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _wordController,
                    decoration:  InputDecoration(
                        labelText: 'Palabra (Inglés)',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.translate),
                          onPressed:
                              _getSuggestedTranslation, //  Usa el servicio aquí
                        ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, introduce una palabra';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _translationController,
                    decoration: const InputDecoration(labelText: 'Traducción (Español)'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, introduce una traducción';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _spellingController,
                    decoration: const InputDecoration(labelText: 'Deletreo'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, introduce el deletreo';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                    _buildListSelection(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                    final newWord = Word(
                    id: widget.wordToEdit?.id,
                    word: _wordController.text,
                    translation: _translationController.text,
                    spelling: _spellingController.text,
                    createdAt: DateTime.now(),
                    lists: _selectedLists, // Guarda las listas seleccionadas
                  );

                  // Llama a onWordSaved *con* el objeto Word.
                  widget.onWordSaved(newWord);
                  Navigator.of(context).pop();

                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      }
        //Widget para mostrar las listas
      Widget _buildListSelection() {
          return FutureBuilder<List<String>>(
            future: WordRepository.getAllLists(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              if (snapshot.hasError) {
                return const Text('Error al cargar las listas');
              }
              final List<String> allLists = snapshot.data ?? [];

                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    const Text('Selecciona listas:', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8.0, // Espacio horizontal entre chips
                    children: allLists.map((listName) {
                        return FilterChip(
                            label: Text(listName),
                          selected: _selectedLists.contains(listName),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                _selectedLists.add(listName);
                              } else {
                                _selectedLists.remove(listName);
                              }
                            });
                          },
                        );
                    }).toList(),
                  ),
                      const SizedBox(height: 8),
                      // Campo de texto y botón para agregar una nueva lista
                      if (_isAddingNewList) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _newListController,
                                decoration: const InputDecoration(
                                  labelText: 'Nueva lista',
                                ),
                                onFieldSubmitted: (value) {
                                    _addNewList();
                                },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _addNewList,
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel), // Icono para cancelar
                            onPressed: () {
                              setState(() {
                                _isAddingNewList = false; // Oculta el campo
                                _newListController
                                    .clear(); // Limpia el controlador
                              });
                            },
                          ),
                        ],
                      ),
                    ] else
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isAddingNewList =
                                true; // Muestra el campo y el botón
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Crear nueva lista'),
                      ),
                ]);
            },
          );
        }

        Future<void> _addNewList() async {
          final newListName = _newListController.text.trim();
          if (newListName.isNotEmpty) {
            // 1. Verificar si la lista ya existe.
            final allLists = await WordRepository.getAllLists();
            if (allLists.contains(newListName)) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('La lista "$newListName" ya existe.')),
                );
              }
              return; // No agrega la lista si ya existe
            }

            // 2. Si no existe, agregarla.
            setState(() {
              _selectedLists.add(newListName); // Añadir a la selección actual
              _isAddingNewList = false; // Ocultar el campo
              _newListController.clear(); // Limpiar el controlador
            });
          }
        }
    }