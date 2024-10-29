import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixsneak/config/theme/app_theme.dart';
import 'package:flixsneak/presentation/providers/movie_provider.dart';
import 'package:flixsneak/presentation/screens/home/home_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MovieProvider() )
      ],
      child: MaterialApp(
        title: 'FlixSneak',
        debugShowCheckedModeBanner: false,
        theme: AppTheme( selectedColor: 0 ).theme(),
        home: const HomeScreen()
      ),
    );
  }
}


