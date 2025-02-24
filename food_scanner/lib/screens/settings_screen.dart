import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:food_scanner/providers/allergy_provider.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _allergyController = TextEditingController();

  @override
  void dispose() {
    _allergyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allergyProvider = Provider.of<AllergyProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Configuración de Alergias')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mis Alergias:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Wrap( // Muestra las alergias como chips
              spacing: 8.0,
              children: allergyProvider.allergies.map((allergy) {
                return Chip(
                  label: Text(allergy),
                  onDeleted: () => allergyProvider.removeAllergy(allergy),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _allergyController,
              decoration: InputDecoration(
                labelText: 'Agregar Alergia',
                suffixIcon: IconButton( // Botón para agregar
                  icon: Icon(Icons.add),
                  onPressed: () {
                    if (_allergyController.text.trim().isNotEmpty) {
                      allergyProvider.addAllergy(_allergyController.text.trim());
                      _allergyController.clear();
                    }
                  },
                ),
              ),
              onSubmitted: (value){
                //Para agregar tambien presionando enter
                 if (_allergyController.text.trim().isNotEmpty) {
                      allergyProvider.addAllergy(_allergyController.text.trim());
                      _allergyController.clear();
                    }
              }
            ),
          ],
        ),
      ),
    );
  }
}