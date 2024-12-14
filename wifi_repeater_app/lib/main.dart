// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(WiFiRepeaterApp());
}

class WiFiRepeaterApp extends StatefulWidget {
  const WiFiRepeaterApp({super.key});

  @override
  _WiFiRepeaterAppState createState() => _WiFiRepeaterAppState();
}

class _WiFiRepeaterAppState extends State<WiFiRepeaterApp> {
  // Variables para manejar la configuración del repetidor
  bool _isRepeaterActive = false;
  String _sourceNetworkName = '';
  String _repeaterNetworkName = '';
  String _repeaterPassword = '';

  // Método para activar el punto de acceso
  Future<void> _activateWiFiRepeater() async {
    try {
      // Implementación de la lógica de activación del punto de acceso
      // Esto requerirá método de canal para interactuar con código nativo
      await MethodChannel('wifi_repeater_channel').invokeMethod('startRepeater', {
        'sourceNetwork': _sourceNetworkName,
        'repeaterNetwork': _repeaterNetworkName,
        'repeaterPassword': _repeaterPassword
      });

      setState(() {
        _isRepeaterActive = true;
      });
    } on PlatformException catch (e) {
      // Manejo de errores
      print('Error activando repetidor: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WiFi Repeater'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Nombre de red original',
                hintText: 'Ingrese nombre de red WiFi original'
              ),
              onChanged: (value) {
                setState(() {
                  _sourceNetworkName = value;
                });
              },
            ),
            TextField(
              decoration: InputDecoration(
                labelText: 'Nombre de red repetidor',
                hintText: 'Ingrese nombre para nueva red'
              ),
              onChanged: (value) {
                setState(() {
                  _repeaterNetworkName = value;
                });
              },
            ),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Contraseña de red repetidor',
                hintText: 'Ingrese contraseña para nueva red'
              ),
              onChanged: (value) {
                setState(() {
                  _repeaterPassword = value;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRepeaterActive ? null : _activateWiFiRepeater,
              child: Text('Activar Repetidor WiFi'),
            ),
            SizedBox(height: 20),
            Text(
              _isRepeaterActive 
                ? 'Repetidor WiFi activo' 
                : 'Repetidor WiFi inactivo',
              style: TextStyle(
                color: _isRepeaterActive ? Colors.green : Colors.red
              ),
            )
          ],
        ),
      ),
    );
  }
}