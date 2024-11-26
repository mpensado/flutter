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
  TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  // @override
  // void initState() {
  //   super.initState();
  //   Tools.actualViewList = Tools.categories;
  // }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose(); // Liberamos el FocusNode
    super.dispose();
  }

  void filterCategories(String query) {
    Tools.strFilter = query;
    setState(() {});
  }

  late ScrollController scrollCurrentController =
      ScrollController(initialScrollOffset: 0);

  void _handleCategoriaSelected(CategoryModel category) {
    Tools.actualName = category.name;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      searchFocusNode.requestFocus();
    });
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
                //if (Tools.actualViewList.isNotEmpty) {
                  return MaterialApp(
                    debugShowCheckedModeBanner: false,
                    home: Scaffold(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        appBar: Tools.actualName != 'home'
                            ? AppBar(
                                title: Text(Tools.actualName),
                                leading: IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () {
                                    setState(() {
                                      Tools.actualName = "home";
                                    });
                                  },
                                ),
                              )
                            : null,
                        body: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                  focusNode: searchFocusNode, 
                                  style: const TextStyle(color: Colors.white),
                                  controller: searchController,
                                  onChanged: filterCategories,
                                  decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  hintText: 'Buscar categorias...',
                                ),
                              ),
                            ),
                            Expanded(
                              child: Tools.actualViewList.isEmpty
                                  ? const Center(
                                      child: Text(
                                        "No hay datos disponibles",
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 18),
                                      ),
                                    )
                                  :
                                  GridView.builder(
                                        controller: scrollCurrentController,
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 1,
                                          childAspectRatio: 2.0,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                        ),
                                        padding: const EdgeInsets.all(5),
                                        itemCount: Tools.actualViewList.length,
                                        itemBuilder: (context, index) {
                                          return CardMovie(
                                            category: Tools.actualViewList[index],
                                            onCategoriaSelected:
                                                _handleCategoriaSelected,
                                          );
                                        }),
                            )
                          ],
                        )),
                  );
                // } else {
                //   return const Text("No hay datos disponibles");
                // }
              },
            )),
          ],
        ),
      ),
    );
  }
}
