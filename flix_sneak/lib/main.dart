import 'package:flixsneak/presentation/screens/principal_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

//import 'package:flixsneak/config/theme/app_theme.dart';
import 'package:flixsneak/presentation/providers/app_provider.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider() )
      ],
      child: MaterialApp(
        title: 'FlixSneak',
        debugShowCheckedModeBanner: false,
        //theme: AppTheme( selectedColor: 7 ).theme(),
        theme: ThemeData.dark(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.system,
        home: const PrincipalScreen()
      ),
    );
  }
}


