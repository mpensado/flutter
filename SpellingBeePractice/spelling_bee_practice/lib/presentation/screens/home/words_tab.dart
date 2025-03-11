import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/word_repository.dart';
import 'package:spelling_bee_practice/presentation/widgets/add_edit_word_dialog.dart';
import 'package:spelling_bee_practice/presentation/widgets/shared/word_card.dart';

class WordsTab extends StatefulWidget {
  final VoidCallback? onSessionCreated; // Callback

  const WordsTab({Key? key, this.onSessionCreated}) : super(key: key);

  @override
  State<WordsTab> createState() => WordsTabState();
}

class WordsTabState extends State<WordsTab> {
  String? _selectedList = "Todas"; // Filtro de lista
  String? _sortOrder = 'dateDesc'; // Criterio de ordenamiento
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Word>> _wordsFuture;

  @override
  void initState() {
    super.initState();
    _loadWords(); // Carga inicial de palabras
  }

    Future<void> _loadWords() async {
    if (_searchController.text.isNotEmpty) {
      _wordsFuture = WordRepository.searchWords(_searchController.text,
          sortOrder: _sortOrder);
    } else if (_selectedList == null || _selectedList == "Todas") {
      _wordsFuture = WordRepository.getAllWords(sortOrder: _sortOrder);
    } else {
      _wordsFuture =
          WordRepository.getWordsByLists([_selectedList!], sortOrder: _sortOrder);
    }
    setState(() {}); // Actualiza la UI después de cargar las palabras.
  }
  // Método para mostrar el diálogo de agregar/editar.
  Future<void> _showAddOrEditWordDialog({Word? word}) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AddEditWordDialog(
            wordToEdit: word,
            onWordSaved: (Word newWord) async {  //  Cambia el nombre y tipo
              if (word == null) {
                await WordRepository.insertWord(newWord);
              } else {
                await WordRepository.updateWord(newWord);
              }
              _loadWords(); // Recarga las palabras después de guardar.
              widget.onSessionCreated
                  ?.call(); // Notifica la creacion de palabra/lista
            });
      },
    );
  }

    //Metodo para refrescar luego de una busqueda
  Future<void> _refreshWordsAfterSearch() async {
    if (_searchController.text.isEmpty) {
      // Si el campo de búsqueda está vacío, recargar todas las palabras.
      _loadWords(); // Recarga todas las palabras con el filtro y orden actuales
    } else {
      // Si hay texto en el campo de búsqueda, realiza la búsqueda.
      _wordsFuture = WordRepository.searchWords(_searchController.text,
          sortOrder: _sortOrder);
      setState(
          () {}); // Asegúrate de llamar a setState para reconstruir el widget.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Barra de búsqueda y botones de filtro/orden.
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
                    onChanged: (value) {
                      // _loadWords(); // Carga con cada cambio (menos eficiente, pero más reactivo).
                      // _refreshWordsAfterSearch(); // <- Llama a esto en onChanged
                      // Mejor:  Llamar _refreshWordsAfterSearch CON debounce.
                      _refreshWordsAfterSearch();
                    },
                  ),
                ),
                // Botón para el menú de ordenamiento.
                PopupMenuButton<String>(
                  onSelected: (String sortOrder) {
                    setState(() {
                      _sortOrder = sortOrder;
                      _loadWords(); // Recargar con el nuevo orden.
                    });
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'az',
                      child: Text('A-Z'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'za',
                      child: Text('Z-A'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'dateAsc',
                      child: Text('Más antiguos'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'dateDesc',
                      child: Text('Más recientes'),
                    ),
                  ],
                  icon: const Icon(Icons.sort), // Icono de ordenamiento.
                ),
                // Botón para el filtro por lista
                _buildFilterButton(),
              ],
            ),
          ),
          // Lista de palabras.
          Expanded(
            child: FutureBuilder<List<Word>>(
              future: _wordsFuture,
              builder:
                  (BuildContext context, AsyncSnapshot<List<Word>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                      child: Text(
                          'Error al cargar las palabras: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay palabras.'));
                } else {
                  final words = snapshot.data!;
                  return ListView.builder(
                    itemCount: words.length,
                    itemBuilder: (BuildContext context, int index) {
                      final word = words[index];
                      return WordCard(
                        word: word,
                        onEdit: () => _showAddOrEditWordDialog(word: word),
                        onDelete: () async {
                          await WordRepository.deleteWord(word.id!);
                          _loadWords();
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrEditWordDialog(),
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

        final List<String> lists = snapshot.data ??
            []; // Usa una lista vacía como valor predeterminado

        return PopupMenuButton<String>(
            onSelected: (String listName) {
                setState(() {
                _selectedList = listName;
                 _loadWords();
                });
            },
          itemBuilder: (BuildContext context) {
            return [
                const PopupMenuItem<String>( //  "Todas"
                  value: "Todas",
                  child: Text("Todas"),
                ),
                ...lists.map((String listName) {
                  return CheckedPopupMenuItem<String>(
                    value: listName,
                    checked: _selectedList == listName,
                    child: Text(listName),
                  );
                }).toList()
            ];
          },
           child: Chip(
              label: Text(_selectedList ?? "Todas"),
               avatar: const Icon(Icons.filter_list), // Icono de filtro.
            ),
        );
      },
    );
  }
}