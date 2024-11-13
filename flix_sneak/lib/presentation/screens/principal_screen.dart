import 'package:flixsneak/presentation/screens/favorite/favorite_screen.dart';
import 'package:flixsneak/presentation/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixsneak/presentation/providers/app_provider.dart';

class PrincipalScreen extends StatefulWidget {
  const PrincipalScreen({super.key});

  @override
  State<PrincipalScreen> createState() => _PrincipalScreenState();
}

class _PrincipalScreenState extends State<PrincipalScreen> {
  int _selectedIndex = 0;
  bool showReturnAction = false;

  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    appProvider.scrollCurrentController = ScrollController(initialScrollOffset: 0);

    Future<void> onItemTapped(int index) async {
      appProvider.setNameCategories("home");
      appProvider.getCategories();
      _selectedIndex = index;

      _pageController.jumpToPage(index);

      //setState(() {});
    }

    bool getShowReturnStatus(AppProvider appProvider) {
      return appProvider.getShowReturnStatus();
    }

    return Scaffold(
      appBar: AppBar(
        actions: const [
          Padding(
            padding: EdgeInsets.all(4.0),
            child: CircleAvatar(
                foregroundImage: AssetImage('assets/images/icon.jpg')),
          )
        ],
        leading: getShowReturnStatus(appProvider)
            ? IconButton(
                onPressed: () {
                  setState(() {
                    appProvider.setNameCategories('home');
                  });
                },
                icon: const Icon(Icons.arrow_back_outlined),
              )
            : null,
        title: appProvider.getIsHome()
            ? const Text('FlixSneak')
            : Text(appProvider.actualName),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [
          HomeView(appProvider),
          FavoriteView(appProvider),
          FavoriteView(appProvider),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Buscar',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: onItemTapped,
      ),
    );
  }
}