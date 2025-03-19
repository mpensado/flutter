import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/word_repository.dart';
import 'package:spelling_bee_practice/presentation/widgets/add_edit_word_dialog.dart';
import 'package:spelling_bee_practice/presentation/widgets/shared/word_card.dart';

class WordsTab extends StatefulWidget {
  const WordsTab({super.key});

  @override
  WordsTabState createState() => WordsTabState();
}

class WordsTabState extends State<WordsTab>
    with AutomaticKeepAliveClientMixin {
  Future<List<Word>>? _wordsFuture;
  String? _selectedList;
  String _sortOrder = 'dateDesc';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWords();
    _searchController.addListener(_refreshWordsAfterSearch);
  }

  Future<void> _loadWords() async {
    if (_searchController.text.isNotEmpty) {
      _wordsFuture = WordRepository.searchWords(_searchController.text,
          sortOrder: _sortOrder);
    } else if (_selectedList == null || _selectedList == "Todo") {
      _wordsFuture = WordRepository.getAllWords(sortOrder: _sortOrder);
    } else {
      _wordsFuture =
          WordRepository.getWordsByLists([_selectedList!], sortOrder: _sortOrder);
    }
    setState(() {});
  }

    Future<void> _refreshWordsAfterSearch() async {
      if (_searchController.text.isEmpty) {
        _loadWords();
      } else {
        _wordsFuture = WordRepository.searchWords(_searchController.text,
            sortOrder: _sortOrder);
      }
      setState(() {});
    }

  @override
  void dispose() {
    _searchController.removeListener(_refreshWordsAfterSearch);
    _searchController.dispose();
    super.dispose();
  }


  @override
  bool get wantKeepAlive => true;

 Future<void> _showDeleteConfirmationDialog(Word word) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: Text('¿Estás seguro de que quieres eliminar "${word.word}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await WordRepository.deleteWord(word.id!);
      _loadWords();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Palabra "${word.word}" eliminada')),
        );
      }
    }
  }
    Future<void> _showEditDialog(Word word) async {
     await showDialog<void>(
      context: context,
      builder: (context) {
        return AddEditWordDialog(
          wordToEdit: word,
          onWordSaved: (editedWord) async {
            await WordRepository.updateWord(editedWord);
            _loadWords();
            if(context.mounted){
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Palabra "${editedWord.word}" actualizada')),
                );
            }

          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Buscar',
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _loadWords(); // Recargar al limpiar
                              },
                            )
                          : const Icon(Icons.search),
                    ),
                    onChanged: (value){
                        _refreshWordsAfterSearch();
                    },
                  ),
                ),
                _buildSortButton(), // Ordenación en el medio
                const SizedBox(width: 8),
                _buildFilterButton(), // Filtro a la derecha
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Word>>(
              future: _wordsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay palabras'));
                }
                final words = snapshot.data!;
                return ListView.builder(
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    final word = words[index];
                    return WordCard(
                        word: word,
                        onDelete: () => _showDeleteConfirmationDialog(word),
                        onEdit: () => _showEditDialog(word));
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AddEditWordDialog(
                onWordSaved: (newWord) async {
                  await WordRepository.insertWord(newWord);
                  _loadWords();
                },
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
  Widget _buildFilterButton() {
    return FutureBuilder<List<String>>(
      future: WordRepository.getAllLists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(); // Muestra un indicador de carga
        }
        if (snapshot.hasError) {
          return const Icon(Icons.error); // Muestra un ícono de error
        }

        final List<String> lists = snapshot.data ?? []; // Usa una lista vacía como valor predeterminado
        lists.removeAt(1);

        return PopupMenuButton<String>(
          onSelected: (String newValue) {
            setState(() {
              //_selectedList = newValue; //  <--  ¡CORRECCIÓN!
              if(newValue == "Todo"){
                _selectedList = null;
              } else{
                _selectedList = newValue;
              }
              _loadWords(); // Recarga las palabras al cambiar el filtro.
            });
          },
          itemBuilder: (BuildContext context) {
            return lists.map<PopupMenuEntry<String>>((String listName) {
              return PopupMenuItem<String>(
                value: listName,
                // child: Text(listName),
                // enabled: listName != "Todas",
                child: Text(listName),
              );
            }).toList();
          },
          child: Chip(  // <-- Usamos Chip
            label: Text(_selectedList ?? "Todo"),  // <-- Mostramos "Todas" si es null
            avatar: const Icon(Icons.filter_list), // Icono de filtro.
          ),
        );
      },
    );
  }
  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort), // Icono de ordenación
      initialValue: _sortOrder,
      onSelected: (String newValue) {
        setState(() {
          _sortOrder = newValue;
          _loadWords(); // Recargar con el nuevo orden
        });
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'nameAsc',
          child: Text('Nombre (A-Z)'),
        ),
        const PopupMenuItem<String>(
          value: 'nameDesc',
          child: Text('Nombre (Z-A)'),
        ),
        const PopupMenuItem<String>(
          value: 'dateAsc',
          child: Text('Fecha (Antigua)'),
        ),
        const PopupMenuItem<String>(
          value: 'dateDesc',
          child: Text('Fecha (Reciente)'),
        ),
      ],
    );
  }
}