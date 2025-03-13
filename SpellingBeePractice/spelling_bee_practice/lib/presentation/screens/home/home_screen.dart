import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/presentation/screens/home/practice_tab.dart';
import 'package:spelling_bee_practice/presentation/screens/home/words_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0; // Índice de la pestaña actual

  // Lista de pestañas (ahora solo 2).
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
      _tabs = [

      WordsTab(onSessionCreated: _refreshPracticeTab), //Pasa el callback
      const PracticeTab(),
    ];
  }

  //  Función para actualizar PracticeTab (usada como callback).
  void _refreshPracticeTab() {
    if (_currentIndex == 1) {
      // Solo actualiza si PracticeTab está activa.
      // Podrías necesitar un GlobalKey si necesitas forzar la actualización
      // incluso si la pestaña no está visible.  Pero, por ahora, esto es suficiente.

        setState(() {
        //Forzar una reconstruccion de PracticeTab
        _tabs[1] = const PracticeTab(); //Reconstruye el widget
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ListTile(
          leading: Image.asset('assets/icon/icon.png', width: 24, height: 24),
          title: Text('Spelling Bee'), // Titulo
          // subtitle: Text('Subtítulo'), //  Subtítulo (opcional)
        ),
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