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
  double _uploadProgress = 0.0; // 0.0 significa que no hay carga en progreso
  bool _isUploading = false; // Para controlar si la carga está activa

  // Lista de pestañas (ahora solo 2).
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      WordsTab(onFilterChanged: _onFilterChangedInWordsTab), //Pasa el callback
      const PracticeTab(),
    ];
  }

  void _onFilterChangedInWordsTab(String newFilter) {
    _actualFilter = newFilter;
    //setState(() {});

    debugPrint('[MI_LOG]Filtro cambiado en HomeScreen: $_actualFilter');
    // Aquí puedes realizar cualquier acción necesaria en HomeScreen
    // cuando el filtro cambie, aunque en este caso, solo necesitamos el valor
    // para la subida del archivo.
  }

  Future<void> _uploadAndProcessFile(
      BuildContext context, String actualFilter) async {
    FilePickerResult? result;
    if (_isUploading) return; // Evitar múltiples cargas simultáneas

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

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
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
      return;
    }

    if (!mounted) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
      return;
    }

    if (result != null && result.files.isNotEmpty) {
      PlatformFile file = result.files.first;
      if (file.path != null) {
        String? fileContent;
        try {
          File selectedFile = File(file.path!);
          fileContent = await selectedFile.readAsString();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al leer el archivo: $e')),
            );
          }
          setState(() {
            _isUploading = false;
            _uploadProgress = 0.0;
          });
          return;
        }

        if (!mounted) {
          setState(() {
            _isUploading = false;
            _uploadProgress = 0.0;
          });
          return;
        }

        final List<String> wordsFromFile = fileContent
            .split('\n')
            .map((word) => word.trim())
            .where((word) => word.isNotEmpty)
            .toList();

        final db = await DBHelper().database;
        int processedCount = 0;
        final int totalWords = wordsFromFile.length;

        for (final wordText in wordsFromFile) {
          final word = Word(
              word: wordText,
              translation: await TranslationService.translate(
                  text: wordText, from: "en", to: "es"),
              spelling: TextToSpeechService.spelling(wordText),
              lists: ['Todo', actualFilter],
              createdAt: DateTime.now());

          int wordId = 0;
          final existingWord = await WordRepository.getWordByText(word.word);
          if (existingWord == null) {
            wordId = await db.insert('words', word.toMap());
          } else {
            wordId = existingWord.id!;
          }

          final existsInTodo =
              await WordRepository.getWordsByIdAndList(wordId, 'Todo');
          if (existsInTodo.isEmpty) {
            await db.insert(DBHelper().tableWordLists,
                {'word_id': wordId, 'list_name': 'Todo'});
          }

          final existsInCurrentCategory =
              await WordRepository.getWordsByIdAndList(wordId, actualFilter);
          if (existsInCurrentCategory.isEmpty) {
            await db.insert(DBHelper().tableWordLists,
                {'word_id': wordId, 'list_name': actualFilter});
          }

          processedCount++;
          if (mounted) {
            setState(() {
              _uploadProgress = processedCount / totalWords;
            });
          }
        }

        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadProgress = 1.0; // Asegurar que llegue a 100% al final
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Archivo subido y procesado')),
          );
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selección de archivo cancelada')),
        );
      }
    }
    // Asegurar que el indicador desaparezca incluso si hay un error
    if (mounted && _isUploading) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
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
              onPressed: _isUploading
                  ? null
                  : () => _uploadAndProcessFile(context, _actualFilter),
            )
        ],
        bottom: _isUploading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4.0),
                child: LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
            : null,
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
