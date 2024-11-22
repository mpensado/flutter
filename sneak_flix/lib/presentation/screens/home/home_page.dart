import 'package:flutter/material.dart';
import 'package:sneak_flix/config/helpers/tools.dart';
import 'package:sneak_flix/infrastructure/models/category_model';
import 'package:sneak_flix/presentation/screens/widgets/shared/card_box.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool showReturnStatus = false;

  late ScrollController scrollCurrentController =
      ScrollController(initialScrollOffset: 0);

      void _handleCategoriaSelected(CategoryModel category) {
    Tools.actualName = category.name;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    //if (actualIndex != 0) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            Expanded(
                child: FutureBuilder<void>(
              future: Tools.getCategories(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.expand(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                } else if (snapshot.hasError) {
                  print("Error: $snapshot.error");
                  return Text("Error: ${snapshot.error}");
                }
                if (Tools.actualViewList.isNotEmpty) {
                  return MaterialApp(
                    debugShowCheckedModeBanner: false,
                    home: Scaffold(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                        appBar: Tools.actualName != 'home'? AppBar(
                        title: Text(Tools.actualName),
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            setState(() {
                            Tools.actualName = "home";
                          });
                          },
                        ),
                      ): null,
                      body: GridView.builder(
                              controller: scrollCurrentController,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.0,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              padding: const EdgeInsets.all(10),
                              itemCount: Tools.actualViewList.length,
                              itemBuilder: (context, index) {
                                print("Con datos: $index");
                                return CardMovie(
                                  category: Tools.actualViewList[index],
                                  onCategoriaSelected: _handleCategoriaSelected,
                                );
                              }
                            )
                    ),
                  );
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
