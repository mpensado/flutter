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
      elevation: 4,
      color: Colors.black.withOpacity(0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          child: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                child: ClipOval(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.8), // Efecto de transparencia
                      BlendMode.dstATop,
                    ),
                    child: Image.asset('assets/icon/SneakFlix.png',
                      fit: BoxFit.cover,
                      width: 100,
                      height: 100,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16), // Separación entre imagen y detalles
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Ajusta la columna al contenido
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.category.name,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12), // Espaciado entre título y botones
                    // Botones distribuidos equitativamente
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        InkWell(
                          onTap: () {
                            Tools.launchURL(widget.category.url);
                          },
                          child: Icon(
                            Icons.open_in_new,
                            color: Colors.white.withOpacity(0.4),
                            size: 20,
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
                            color: Colors.white.withOpacity(0.4),
                            size: 20,
                          ),
                        ),
                        if (Tools.actualViewName == 'home' && widget.category.dependencia == 'home') ...[
                          InkWell(
                            onTap: () =>
                                widget.onCategoriaSelected(widget.category),
                            child: Icon(
                              Icons.info_outline,
                              color: Colors.white.withOpacity(0.4),
                              size: 20,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}