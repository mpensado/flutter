import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
//import 'package:spelling_bee_practice/presentation/screens/home/spelling_bee_view.dart';
import 'package:spelling_bee_practice/presentation/screens/home/words_tab.dart';
import 'package:spelling_bee_practice/presentation/screens/home/practice_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();

}


class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  // Se movió el diálogo a un widget separado para mayor claridad y evitar referencias a _HomePageState
  void showAddWordDialog(BuildContext context, VoidCallback onWordAdded,
      {Word? wordToEdit}) {
          //Llamada a la funcion en wordTab
      final wordsTabState = context.findAncestorStateOfType<WordsTabState>();
      if(wordsTabState != null){
        wordsTabState.showAddWordDialog(context, onWordAdded, wordToEdit: wordToEdit);
      }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spelling Bee'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Implementar configuración
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController, // Usa el TabController
          tabs: const [
            Tab(text: 'Vocabulario', icon: Icon(Icons.book)),
            Tab(text: 'Práctica', icon: Icon(Icons.edit)),
            //Tab(text: 'SpellingBee', icon: Icon(Icons.bug_report_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController, // Usa el TabController
        children: [
          WordsTab(onWordAdded: (){
            //Se actualiza la vista de la tab de practica
            final practiceTabState = context.findAncestorStateOfType<PracticeTabState>();
            if(practiceTabState != null){
              practiceTabState.loadPracticeSessions();
            }
          }),
          const PracticeTab(),
          //const SpellingBeeView(),
        ],
      ),
    );
  }
}