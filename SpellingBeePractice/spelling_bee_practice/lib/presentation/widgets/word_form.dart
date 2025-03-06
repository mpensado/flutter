import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';

class WordForm extends StatefulWidget {
  final Word? word; // Palabra a editar (null si es una nueva palabra)
  final Function(Word) onSave;

  const WordForm({super.key, this.word, required this.onSave});

  @override
  State<WordForm> createState() => _WordFormState();
}

class _WordFormState extends State<WordForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _wordController;
  late TextEditingController _translationController;
  late TextEditingController _spellingController;
  late TextEditingController _notesController;

  // Lista de selección multiple.
  List<String> _selectedLists = []; // Lista para almacenar las listas seleccionadas
  final List<String> _availableLists = [
    'Fruits',
    'Vegetables',
    'Food',
    'Drinks',
    'Weather',
    'Activities',
    'Places',
    'Technology',
    'Animals',
    'Objects',
    'Actions',
    'Body Parts',
    'People',
    'Transportation',
    'Subjects',
    'Nature',
    'Entertainment',
    'Numbers',
    'Holidays',
  ]; //  listas

  @override
  void initState() {
    super.initState();

    // Inicializar los controladores con los valores de la palabra existente (si hay)
    _wordController = TextEditingController(text: widget.word?.word ?? '');
    _translationController =
        TextEditingController(text: widget.word?.translation ?? '');
    _spellingController =
        TextEditingController(text: widget.word?.spelling ?? '');
    _notesController = TextEditingController(text: widget.word?.notes ?? '');
    _selectedLists = List.from(
        widget.word?.lists ?? []); //  copia de las listas existentes
  }

  @override
  void dispose() {
    _wordController.dispose();
    _translationController.dispose();
    _spellingController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.word == null ? 'Agregar Palabra' : 'Editar Palabra'),
      content: SingleChildScrollView(
        //Para que no haya problemas con teclados en pantallas pequeñas
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _wordController,
                decoration: const InputDecoration(labelText: 'Palabra'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingrese la palabra';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _translationController,
                decoration: const InputDecoration(labelText: 'Traducción'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingrese la traducción';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _spellingController,
                decoration:
                    const InputDecoration(labelText: 'Deletreo (opcional)'),
              ),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
                maxLines: 3, // Permite múltiples líneas para las notas.
              ),
              const SizedBox(height: 16), //Espacio
              //Selector de listas.
              const Text('Listas:'),
              Wrap(
                //  Wrap para que los chips se ajusten en varias líneas
                spacing: 8.0, // Espacio horizontal entre chips
                children: _availableLists.map((list) {
                  return FilterChip(
                    label: Text(list),
                    selected: _selectedLists.contains(list),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedLists.add(list);
                        } else {
                          _selectedLists.remove(list);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
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
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              // Crear una nueva palabra o actualizar la existente.
              final updatedWord = Word(
                id: widget.word?.id, // Mantener el ID si es una edición.
                word: _wordController.text,
                translation: _translationController.text,
                spelling: _spellingController.text,
                notes: _notesController.text,
                lists: _selectedLists,
                createdAt: DateTime.now(), //  listas seleccionadas
                // Los contadores (correct_count, etc.) se manejan en el repositorio.
              );

              widget.onSave(updatedWord); // Llama a la función onSave
              Navigator.of(context).pop(); // Cerrar el diálogo
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}