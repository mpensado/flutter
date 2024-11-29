import 'package:flutter/material.dart';
import 'package:sneak_flix/presentation/screens/main/main_scaffold.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sneak Flix',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: Colors.red,
        ),
        // textTheme: TextTheme(
        //   headlineLarge: const TextStyle(
        //     fontSize: 32,
        //     fontWeight: FontWeight.bold,
        //     color: Colors.white,
        //   ),
        //   bodyLarge: const TextStyle(
        //     fontSize: 18,
        //     color: Colors.white,
        //   ),
        //   bodyMedium: TextStyle(
        //     fontSize: 16,
        //     color: Colors.grey[400],
        //   ),
        // ),
      ),
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      home: const MainScaffold(),
    );
  }
}