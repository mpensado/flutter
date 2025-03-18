//lib/presentation/widgets/add_edit_word_dialog.dart
import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/word_repository.dart';
import 'package:spelling_bee_practice/presentation/utils/text_to_speech_service.dart';
import 'package:spelling_bee_practice/presentation/utils/translation_service.dart';

class AddEditWordDialog extends StatefulWidget {
  final Word? wordToEdit;
  final Function(Word) onWordSaved;

  const AddEditWordDialog({
    super.key,
    required this.onWordSaved,
    this.wordToEdit,
  });

  @override
  State<AddEditWordDialog> createState() => _AddEditWordDialogState();
}

class _AddEditWordDialogState extends State<AddEditWordDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _wordController;
  late TextEditingController _translationController;
  // Eliminar _spellingController
  final List<String> _selectedLists = [];
  final TextEditingController _newListController = TextEditingController();
  bool _isAddingNewList = false;
  final _wordFocusNode = FocusNode();

  List<String> _allLists = []; //  Lista para almacenar TODAS las listas.

  @override
  void initState() {
    super.initState();
    _wordController =
        TextEditingController(text: widget.wordToEdit?.word ?? '');
    _translationController =
        TextEditingController(text: widget.wordToEdit?.translation ?? '');
    // Eliminar _spellingController
    if (widget.wordToEdit != null) {
      _selectedLists.addAll(widget.wordToEdit!.lists);
      _selectedLists.remove("Todo");
    }

    _wordFocusNode.addListener(_onWordFocusChange);
    _loadAllLists(); // Cargar las listas al inicio.
  }

    Future<void> _loadAllLists() async {
    final lists = await WordRepository.getAllLists();
    // allLists.remove("Todas"); //"Todas" no se debe de mostrar.
    setState(() {
      _allLists = lists;
       _allLists.remove("Todo");
    });
  }


  @override
  void dispose() {
    _wordController.dispose();
    _translationController.dispose();
    // Eliminar _spellingController.dispose()
    _newListController.dispose();
    _wordFocusNode.removeListener(_onWordFocusChange);
    _wordFocusNode.dispose();
    super.dispose();
  }

  void _onWordFocusChange() {
    if (!_wordFocusNode.hasFocus && _wordController.text.isNotEmpty) {
      _getSuggestedTranslation();
    }
  }
  Future<void> _getSuggestedTranslation() async {
    if (_wordController.text.isNotEmpty) {
      try {
        final translation = await TranslationService.translate(
            text: _wordController.text, from: "en", to: "es");
        if (translation != null) {
            _translationController.text = translation;
        }
      } catch (e) {
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _wordController,
                focusNode: _wordFocusNode,
                decoration: InputDecoration(
                    labelText: 'Palabra (Inglés)',
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.translate),
                        onPressed: _getSuggestedTranslation)),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce una palabra';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _translationController,
                decoration:
                    const InputDecoration(labelText: 'Traducción (Español)'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce una traducción';
                  }
                  return null;
                },
              ),
              // Eliminar TextFormField de spelling
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
                spelling: TextToSpeechService.spelling(_wordController.text), // Ya no se usa spelling
                createdAt: DateTime.now(),
                lists: _selectedLists,
              );

              widget.onWordSaved(newWord);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _buildListSelection() {
    // Ya no se usa FutureBuilder aquí.
    // Ordenar _allLists para mostrar las seleccionadas primero.
    _allLists.sort((a, b) {
      final aSelected = _selectedLists.contains(a);
      final bSelected = _selectedLists.contains(b);

      if (aSelected && !bSelected) {
        return -1;
      } else if (!aSelected && bSelected) {
        return 1;
      } else {
        return a.compareTo(b);
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Selecciona listas:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8.0,
          children: _allLists.map((listName) { // Usa _allLists directamente, YA ORDENADO
            return FilterChip(
              label: Text(listName),
              selected: _selectedLists.contains(listName),
              onSelected: (bool selected) {
                setState(() { // <-- setState Sigue siendo necesario para la selección.
                  if (selected) {
                    _selectedLists.add(listName);
                  } else {
                    _selectedLists.remove(listName);
                  }
                  // ¡NO RECARGUES _allLists aquí!
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
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
                icon: const Icon(Icons.cancel),
                onPressed: () {
                  setState(() {
                    _isAddingNewList = false;
                    _newListController.clear();
                  });
                },
              ),
            ],
          ),
        ] else
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isAddingNewList = true;
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Crear nueva lista'),
          ),
      ],
    );
  }



  Future<void> _addNewList() async {
    final newListName = _newListController.text.trim();
    if (newListName.isNotEmpty) {

      final allLists = await WordRepository.getAllLists();
      if (allLists.contains(newListName)) {
        if(context.mounted){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('La lista "$newListName" ya existe.')),
          );
        }
        return;
      }

      setState(() {
        _selectedLists.add(newListName);
        _allLists.add(newListName); // Agregar a la lista completa
        _isAddingNewList = false;
        _newListController.clear();
      });
       _allLists.sort((a, b) {
          final aSelected = _selectedLists.contains(a);
          final bSelected = _selectedLists.contains(b);

          if (aSelected && !bSelected) {
            return -1; // a va antes que b (a seleccionado, b no)
          } else if (!aSelected && bSelected) {
            return 1; // b va antes que a (b seleccionado, a no)
          } else {
            return a.compareTo(b); // Ambos seleccionados o no, orden alfabético
          }
        });
    }
  }
}