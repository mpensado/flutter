import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> _launchURL(String strUrl) async {
  final Uri url = Uri.parse(strUrl);

  if (!await launchUrl(url)) {
    throw 'Could not launch $url';
  }
}

class Category {
  final String name;
  final String imageUrl;
  final String url;
  final String tipo;
  final String dependencia;

  Category(
      {required this.name,
      required this.imageUrl,
      required this.url,
      required this.tipo,
      required this.dependencia});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
        name: json['name'],
        imageUrl: json['imageUrl'],
        url: json['url'],
        tipo: json['tipo'],
        dependencia: json['dependencia']);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'url': url,
      'tipo': tipo,
      'dependencia': dependencia,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Category) return false;
    return name == other.name &&
        imageUrl == other.imageUrl &&
        url == other.url &&
        tipo == other.tipo &&
        dependencia == other.dependencia;
  }

  @override
  int get hashCode =>
      name.hashCode ^
      imageUrl.hashCode ^
      url.hashCode ^
      tipo.hashCode ^
      dependencia.hashCode;
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Catalogo Netflix',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.grey[800],
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  List<Category> categories = [];
  List<Category> favorites = [];
  late Category current;

  void toggleFavorite(Category category) {
    current = category;
    if (favorites.contains(current)) {
      favorites.remove(current);
    } else {
      favorites.add(current);
    }
    saveFavoritesToJson();
    notifyListeners();
  }

  Future loadDB() async {
    await loadFavoritesFromJson();
    await loadCategories();
  }

  Future<void> loadCategories() async {
    List<Category> result = [];
    try {
      final String response =
          await rootBundle.loadString('assets/categories.json');
      final List<dynamic> data = json.decode(response);
      result = data.map((item) => Category.fromJson(item)).toList();
    } catch (e) {
      print('Error loading categories: $e');
    }
    categories = result;
  }

  Future<void> loadFavoritesFromJson() async {
    List<Category> result = [];
    try {
      final file = await _getFavoritesFile();
      if (await file.exists()) {
        String contents = await file.readAsString();
        List<dynamic> jsonData = json.decode(contents);
        result =
            jsonData.map((jsonItem) => Category.fromJson(jsonItem)).toList();
      }
    } catch (e) {
      print('Error loading favorites: $e');
    }
    favorites = result;
  }

  Future<File> _getFavoritesFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/favorites.json');
  }

  Future<void> saveFavoritesToJson() async {
    final file = await _getFavoritesFile();
    List<Map<String, dynamic>> favoritesJson =
        favorites.map((category) => category.toJson()).toList();
    await file.writeAsString(json.encode(favoritesJson));
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;

    switch (selectedIndex) {
      case 0:
        page = GeneratorPage();
        break;
      case 1:
        page = FavoritesPage();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return LayoutBuilder(builder: (context, constraints) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                extended: constraints.maxWidth >= 600, // ← Here.
                destinations: [
                  NavigationRailDestination(
                    icon: Icon(Icons.home),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.favorite),
                    label: Text('Favoritos'),
                  ),
                ],
                selectedIndex: selectedIndex,
                onDestinationSelected: (value) {
                  setState(() {
                    selectedIndex = value;
                  });
                },
              ),
            ),
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: page,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class GeneratorPage extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _GeneratorPageState createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  @override
  void initState() {
    super.initState();
    var appState = context.read<MyAppState>();
    appState.loadDB();
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    return FutureBuilder(
        future: appState.loadDB(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error al cargar datos'));
          } else {
            return Scaffold(
              appBar: AppBar(
                title: Text('Categorías Ocultas Netflix'),
              ),
              body: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                padding: EdgeInsets.all(10),
                itemCount: appState.categories.length,
                itemBuilder: (context, index) {
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        InkWell(
                          onTap: () {
                            _launchURL(appState.categories[index].url);
                          },
                          child: Image(
                            image:
                                AssetImage(appState.categories[index].imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black.withOpacity(0.5),
                            padding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment
                                  .start, // Alineación de las filas a la izquierda
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        appState.categories[index].name,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        _launchURL(
                                            appState.categories[index].url);
                                      },
                                      child: Icon(
                                        Icons.open_in_new,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        appState.toggleFavorite(
                                            appState.categories[index]);
                                      },
                                      child: Icon(
                                        appState.favorites.contains(
                                                appState.categories[index])
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => DetailPage(
                                                category:
                                                    appState.categories[index]),
                                          ),
                                        );
                                      },
                                      child: Icon(
                                        Icons.info_outline,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            );
          }
        }
      );
  }
}

class DetailPage extends StatelessWidget {
  final Category category;

  DetailPage({required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
      ),
      body: Center(
        child: Text('Detalles de ${category.name}'),
      ),
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.pair,
  });

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );
    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          pair.asLowerCase,
          style: style,
          semanticsLabel: "${pair.first} ${pair.second}",
        ),
      ),
    );
  }
}

// ...

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    if (appState.favorites.isEmpty) {
      return Center(
        child: Text('No favorites yet.'),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('You have '
              '${appState.favorites.length} favorites:'),
        ),
        for (var pair in appState.favorites)
          ListTile(
            leading: Icon(Icons.favorite),
            title: Text(pair.name),
          ),
      ],
    );
  }
}
