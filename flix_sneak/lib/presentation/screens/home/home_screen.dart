import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixsneak/config/helpers/browser_tools.dart';
import 'package:flixsneak/infrastructure/models/category_model.dart';
import 'package:flixsneak/presentation/providers/movie_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool showReturnAction = false;

  Future<void> _onItemTapped(int index) async {
    Provider.of<MovieProvider>(context, listen: false)
        .setNameCategories("home");
    Provider.of<MovieProvider>(context, listen: false).getCategories();
    _selectedIndex = index;
    setState(() {});
  }

  bool getShowReturnStatus(MovieProvider movieProvider) {
    return  movieProvider.getShowReturnStatus();
  }

  @override
  Widget build(BuildContext context) {
    final movieProvider = context.watch<MovieProvider>();
    return Scaffold(
      appBar: AppBar(
        actions: const [
          Padding(
            padding: EdgeInsets.all(4.0),
            child: CircleAvatar(),
          )
        ],
        leading: getShowReturnStatus(movieProvider)
            ? IconButton(
                onPressed: () {
                  setState(() {
                    movieProvider.setNameCategories('home');
                  });
                },
                icon: const Icon(Icons.arrow_back_outlined),
              )
            : null,
        title: movieProvider.getIsHome()? const Text('FlixSneak') : Text(movieProvider.actualName),
        centerTitle: true,
      ),
      body: _HomeView(_selectedIndex),
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
        onTap: _onItemTapped,
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  final int actualIndex;

  const _HomeView(this.actualIndex);

  @override
  Widget build(BuildContext context) {
    final movieProvider = context.watch<MovieProvider>();
    if (actualIndex != 0) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            Expanded(
                child: FutureBuilder<void>(
              future: movieProvider.getCategories(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  print("Error: $snapshot.error");
                  return Text("Error: ${snapshot.error}");
                }
                List<CategoryModel> data = movieProvider.actualViewList;
                if (data.isNotEmpty) {
                  print("Con datos: $data.length");
                  return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      padding: const EdgeInsets.all(10),
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        return _cardMovie(index, context);
                      });
                } else {
                  return const Text("No hay datos disponibles");
                }
              },
            )),
          ],
        ),
      ),
    );
  }
}

Card _cardMovie(int index, BuildContext context) {
  final movieProvider = context.watch<MovieProvider>();
  return Card(
    clipBehavior: Clip.antiAlias,
    child: Stack(
      fit: StackFit.expand,
      children: [
        InkWell(
          onTap: () {
            BrowserTools.launchURL(movieProvider.actualViewList[index].url);
          },
          child: Image(
            image: AssetImage(movieProvider.actualViewList[index].imageUrl),
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        movieProvider.actualViewList[index].name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    InkWell(
                      onTap: () {
                        BrowserTools.launchURL(
                            movieProvider.actualViewList[index].url);
                      },
                      child: const Icon(
                        Icons.open_in_new,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        movieProvider.switchFavorite(
                            movieProvider.actualViewList[index].name);
                      },
                      child: Icon(
                        movieProvider.actualViewList[index].favorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    if (movieProvider.getIsHome()) ...[
                      InkWell(
                        onTap: () {
                          movieProvider.updateStatus(
                              movieProvider.actualViewList[index].name);
                        },
                        child: const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        )
      ],
    ),
  );
}
