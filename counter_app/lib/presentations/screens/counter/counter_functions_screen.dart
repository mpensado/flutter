import 'package:flutter/material.dart';

class CounterFunctionsScreen extends StatefulWidget {
  const CounterFunctionsScreen({super.key});

  @override
  State<CounterFunctionsScreen> createState() => _CounterFunctionsScreenState();
}

class _CounterFunctionsScreenState extends State<CounterFunctionsScreen> {
  int clickCounter = 0;
  String clickText = "clicks";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                onPressed: () {
                  setState(() {
                    clickCounter = 0;
                  });
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
            // leading: IconButton(
            //   onPressed: (){},
            //   icon: const Icon(Icons.refresh_rounded),
            // ),
            centerTitle: true,
            title: const Text('Counter Functions'),
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
          floatingActionButton:
              Column(mainAxisAlignment: MainAxisAlignment.end, children:
              [
                CustomButton(
                  icon: Icons.refresh_rounded,
                  onPressed: () {
                    clickCounter = 0;
                    setState(() {});
                  },
                ),
                const SizedBox(height: 10),
                CustomButton(
                  icon: Icons.exposure_minus_1,
                  onPressed: () {
                    if (clickCounter > 0) clickCounter--;
                    if (clickCounter == 1) {
                      clickText = "click";
                    } else {
                      clickText = "clicks";
                    }
                    setState(() {});
                  },
                ),
                const SizedBox(height: 10),
                CustomButton(
                  icon: Icons.plus_one_rounded,
                  onPressed: () {
                    clickCounter++;
                    if (clickCounter == 1) {
                      clickText = "click";
                    } else {
                      clickText = "clicks";
                    }
                    setState(() {});
                  },
                ),
          ])),
    );
  }
}

class CustomButton extends StatelessWidget {
  final IconData? icon;
  final VoidCallback? onPressed;

  const CustomButton({
    super.key,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      shape: const StadiumBorder(),
      onPressed: onPressed,
      // setState(() {
      //   clickCounter++;
      //   if (clickCounter == 1) {
      //     clickText = "click";
      //   } else {
      //     clickText = "clicks";
      //   }
      // });
      child: Icon(icon),
    );
  }
}
