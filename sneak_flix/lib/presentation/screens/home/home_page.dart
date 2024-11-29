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
  late ValueNotifier<List<CategoryModel>> filteredCategoriesNotifier;

  @override
  void initState() {
    super.initState();
    Tools.actualName = "home";
    Tools.actualViewName = "home";
    Tools.strFilter = "";
    filteredCategoriesNotifier = ValueNotifier(Tools.actualViewList);
  }

  @override
  void dispose() {
    searchController.dispose();
    filteredCategoriesNotifier.dispose(); // Liberamos el FocusNode
    super.dispose();
  }

  Future<void> filterCategories(String query) async {
    Tools.strFilter = query;
    await Tools.getCategories();
    filteredCategoriesNotifier.value = Tools.actualViewList.toList();
  }

  void _handleCategoriaSelected(CategoryModel category) {
    Tools.actualName = category.name;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
                  return MaterialApp(
                    debugShowCheckedModeBanner: false,
                    home: Scaffold(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        appBar: Tools.actualName != 'home'
                            ? AppBar(
                                backgroundColor: Colors.white.withOpacity(0.1),
                                foregroundColor: Colors.white.withOpacity(0.5),
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
                            child: ValueListenableBuilder<List<CategoryModel>>(
                                      valueListenable: filteredCategoriesNotifier,
                              builder: (context, filteredCategories, child) {
                                return ListView.builder(
                                    padding: const EdgeInsets.all(5),
                                    itemCount: Tools.actualViewList.length,
                                    itemBuilder: (context, index) {
                                      return CardMovie(
                                        category: Tools.actualViewList[index],
                                        onCategoriaSelected:
                                            _handleCategoriaSelected,
                                      );
                                    });
                              },
                            ),
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
