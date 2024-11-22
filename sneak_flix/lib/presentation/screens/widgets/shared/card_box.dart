import 'package:flutter/material.dart';
import 'package:sneak_flix/config/helpers/tools.dart';
import 'package:sneak_flix/infrastructure/models/category_model';

class CardMovie extends StatefulWidget {
  final CategoryModel category;
  final Function(CategoryModel) onCategoriaSelected;

  const CardMovie({
    super.key,
    required this.category,
    required this.onCategoriaSelected,
  });

  @override
  State<CardMovie> createState() => _CardMovieState();
}

class _CardMovieState extends State<CardMovie> {
  void _toggleFavorite() {
    widget.category.favorite = !widget.category.favorite;
    Tools.escribirEnArchivo(Tools.categories);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InkWell(
            onTap: () {
              Tools.launchURL(widget.category.url);
            },
            child: Image(
              image: AssetImage(widget.category.imageUrl),
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.category.name,
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
                          Tools.launchURL(widget.category.url);
                        },
                        child: const Icon(
                          Icons.open_in_new,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          _toggleFavorite();
                        },
                        child: Icon(
                          widget.category.favorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      if (widget.category.dependencia == 'home') ...[
                        InkWell(
                          onTap: () =>
                              widget.onCategoriaSelected(widget.category),
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
}
