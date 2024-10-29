import 'package:flutter/material.dart';

class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  int clickCounter = 0;
  String clickText = "clicks";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Counter Screen Title'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("$clickCounter",
                  style: const TextStyle(
                      fontSize: 100, fontWeight: FontWeight.w100)),
              Text(clickText,
                  style: const TextStyle(
                    fontSize: 25,
                  )),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              clickCounter++;
              if (clickCounter == 1) {
                clickText = "click";
              } else {
                clickText = "clicks";
              }
              
            });
          },
          child: const Icon(Icons.plus_one),
        ),
      ),
    );
  }
}
