import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/presentation/screens/home/home_screen.dart'; // Importa HomePage

void main() {
  //DBHelper.copyTempDbToLaptop();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpellingBee',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(), // Usa HomePage
    );
  }
}
