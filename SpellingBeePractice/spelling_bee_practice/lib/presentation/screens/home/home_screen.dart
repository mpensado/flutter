import 'dart:io';

import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/helpers/db_helper.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/word_repository.dart';
import 'package:spelling_bee_practice/presentation/screens/home/practice_tab.dart';
import 'package:spelling_bee_practice/presentation/screens/home/words_tab.dart';
import 'package:file_picker/file_picker.dart';
import 'package:spelling_bee_practice/presentation/utils/text_to_speech_service.dart';
import 'package:spelling_bee_practice/presentation/utils/translation_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  String _actualFilter = "Todo";
  late TabController _tabController;

  // Lista de pestañas (ahora solo 2).
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabs = [
      WordsTab(), //Pasa el callback
      const PracticeTab(),
    ];
  }

  Future<void> _uploadAndProcessFile(BuildContext context) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar el archivo: $e')),
        );
      }
      return;
    }

    if (!mounted) return; // **Verificar si el widget sigue montado**

    if (result != null && result.files.isNotEmpty) {
      PlatformFile file = result.files.first;
      if (file.path != null) {
        String? fileContent;
        try {
          // **Cambiamos la forma de leer el archivo aquí:**
          File selectedFile = File(file.path!);
          fileContent = await selectedFile.readAsString();
          // **Fin del cambio**
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al leer el archivo: $e')),
            );
          }
          return;
        }

        if (!mounted) return;

        final List<String> wordsFromFile = fileContent
            .split('\n')
            .map((word) => word.trim())
            .where((word) => word.isNotEmpty)
            .toList();
        // Asegúrate de tener una forma de acceder a tu DatabaseHelper
        // Idealmente, no crear una nueva instancia aquí en cada llamada.
        // Podrías tenerla como una propiedad de tu _HomeScreenState
        final db = await DBHelper().database;

        for (final wordText in wordsFromFile) {
          // 1. Insertar en la tabla words si no existe
          final word = Word(
              word: wordText,
              translation: await TranslationService.translate(
                  text: wordText, from: "en", to: "es"),
              spelling: TextToSpeechService.spelling(wordText),
              createdAt: DateTime.now());

          int wordId = 0;
          final existingWord = await WordRepository.getWordByText(word.word);
          if (existingWord == null) {
            wordId = await db.insert('words', word.toMap());
          } else {  
            wordId =existingWord.id!;
          }

          final existsInTodo = await WordRepository.getWordsByIdAndList(wordId, 'Todo');
          if (existsInTodo.isEmpty) {
            await db.insert(DBHelper().tableWordLists,{'word_id': wordId, 'list_name': 'Todo'});
          }

          final existsInCurrentCategory = await WordRepository.getWordsByIdAndList(wordId, _actualFilter);
          if (existsInCurrentCategory.isEmpty) {
            await db.insert(DBHelper().tableWordLists,{'word_id': wordId, 'list_name': _actualFilter});
          }
        }

        if (mounted) {
          // 4. Actualizar la vista actual
          // Llama a setState solo si el widget sigue montado
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Archivo subido y procesado')),
          );
        }
      }
    } else {
      if (mounted) {
        // El usuario canceló la selección del archivo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selección de archivo cancelada')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ListTile(
          leading: Image.asset('assets/icon/icon.png', width: 24, height: 24),
          title: Text('Spelling Bee'),

          // subtitle: Text('Subtítulo'), //  Subtítulo (opcional)
        ),
        actions: <Widget>[
          if (_currentIndex == 0)
            IconButton(
              icon: Icon(
                  Icons.file_upload), // Puedes usar otro icono de configuración
              onPressed: () {
                _uploadAndProcessFile(context);
              },
            )
        ],
      ),
      body: _tabs[_currentIndex], // Muestra la pestaña actual.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Vocabulario',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Práctica',
          ),
        ],
      ),
    );
  }
}
