import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sneak_flix/presentation/screens/busqueda/busqueda.dart';
import 'package:sneak_flix/presentation/screens/favorites/favoritos.dart';
import 'package:sneak_flix/presentation/screens/home/home_page.dart';
import 'package:sneak_flix/presentation/screens/imdb/imdb.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}


class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<String> _titulos = [
    'Home',
    'Favoritos',
    'Busqueda',
    'IMDB',
  ];

  final List<Widget> _vistas = [
    const HomePage(),
    const Favoritos(),
    const Busqueda(),
    const Imdb(),
  ];

  String get _fechaActual {
    return DateFormat('EEEE, d MMMM yyyy', 'es').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_currentIndex]),
        leading: IconButton(
          icon: _currentIndex == 0 ? const Icon(Icons.home): const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
            _currentIndex = 0;
          });
          },
        ),
      ),
      body: _vistas[_currentIndex],
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.red, // Color de ítem seleccionado
          unselectedItemColor: Colors.grey, // Color de ítems no seleccionados
          selectedIconTheme: const IconThemeData(size: 30), // Tamaño del ícono seleccionado
          unselectedIconTheme: const IconThemeData(size: 25), // Tamaño del ícono no seleccionado
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold), 
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'Favoritos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Busqueda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.movie_creation_outlined),
            label: 'IMDB',
          ),
        ],
      ),
    );
  }
}

