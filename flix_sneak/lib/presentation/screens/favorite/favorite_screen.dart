import 'package:flutter/material.dart';
import 'package:flixsneak/config/helpers/browser_tools.dart';
import 'package:flixsneak/infrastructure/models/category_model.dart';
import 'package:flixsneak/presentation/providers/app_provider.dart';

class FavoriteView extends StatefulWidget {
  //final int actualIndex;
  final AppProvider appProvider;

  const FavoriteView(this.appProvider, {super.key});

  @override
  State<FavoriteView> createState() => _FavoriteViewState();
}

class _FavoriteViewState extends State<FavoriteView> {
  @override
  void initState() {
    super.initState();
    widget.appProvider.scrollCurrentController = ScrollController(initialScrollOffset: 0);
  }

  @override
  Widget build(BuildContext context) {
    //final AppProvider = context.watch<AppProvider>();
    //if (actualIndex != 0) return const SizedBox.shrink();
    widget.appProvider.favoritePage = true;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            Expanded(
                child: FutureBuilder<void>(
              future: widget.appProvider.getCategories(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.expand(
                    // Toma el espacio completo de la pantalla
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                } else if (snapshot.hasError) {
                  print("Error: $snapshot.error");
                  return Text("Error: ${snapshot.error}");
                }
                List<CategoryModel> data = widget.appProvider.actualViewList;
                if (data.isNotEmpty) {
                  print("Con datos: $data.length");
                  return GridView.builder(
                      controller: widget.appProvider.scrollCurrentController,
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
                        return _cardMovie(index, widget.appProvider, context);
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

Card _cardMovie(int index, AppProvider appProvider, BuildContext context) {
  //final AppProvider = context.watch<AppProvider>();
  return Card(
    clipBehavior: Clip.antiAlias,
    child: Stack(
      fit: StackFit.expand,
      children: [
        InkWell(
          onTap: () {
            BrowserTools.launchURL(appProvider.actualViewList[index].url);
          },
          child: Image(
            image: AssetImage(appProvider.actualViewList[index].imageUrl),
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
                        appProvider.actualViewList[index].name,
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
                            appProvider.actualViewList[index].url);
                      },
                      child: const Icon(
                        Icons.open_in_new,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        appProvider.switchFavorite(
                            appProvider.actualViewList[index].name);
                      },
                      child: Icon(
                        appProvider.actualViewList[index].favorite
                            ? Icons.favorite
                            : Icons.favorite_border,
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
}
