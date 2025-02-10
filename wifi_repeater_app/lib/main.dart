// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Repetidor WiFi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: Colors.red,
        ),
      ),
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      home: const WiFiRepeaterApp(),
    );
  }
}

class WiFiRepeaterApp extends StatefulWidget {
  const WiFiRepeaterApp({super.key});

  @override
  _WiFiRepeaterAppState createState() => _WiFiRepeaterAppState();
}
class _WiFiRepeaterAppState extends State<WiFiRepeaterApp> {
  // Variables de estado
  bool _isHotspotActive = false;
  bool _isSecure = true;
  String _ssid = 'MiRepetidorWiFi';
  String _password = 'password123';
  List<String?> _connectedDevices = [];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  // Verificación de permisos
  Future<void> _checkPermissions() async {
    // Solicitar permisos necesarios
    await [
      Permission.location,
      Permission.storage,
      //Permission.manageWifiHotspot,
    ].request();
  }

  // Método para iniciar punto de acceso
  Future<void> _toggleHotspot() async {
    try {
      if (!_isHotspotActive) {
        // Configurar y iniciar punto de acceso
        await WiFiForIoTPlugin.setWiFiAPEnabled(
          !_isHotspotActive
        );

        setState(() {
          _isHotspotActive = true;
        });
      } else {
        // Detener punto de acceso
        await WiFiForIoTPlugin.setWiFiAPEnabled(false);
        
        setState(() {
          _isHotspotActive = false;
          _connectedDevices.clear();
        });
      }
    } catch (e) {
      _mostrarError('Error al configurar hotspot: $e');
    }
  }

  // Verificar dispositivos conectados
  Future<void> _checkConnectedDevices() async {
    try {
      final devices = await WiFiForIoTPlugin.getClientList(
        false, 
        13
      );

      setState(() {
        _connectedDevices = devices.map((device) => device.ipAddr).toList();
      });
    } catch (e) {
      _mostrarError('Error al obtener dispositivos conectados');
    }
  }

  // Método para mostrar errores
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Repetidor WiFi'),
        ),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Configuración de red
              TextField(
                decoration: InputDecoration(
                  labelText: 'Nombre de Red (SSID)',
                  hintText: 'Ingrese nombre de red'
                ),
                onChanged: (value) {
                  setState(() {
                    _ssid = value;
                  });
                },
              ),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  hintText: 'Ingrese contraseña'
                ),
                onChanged: (value) {
                  setState(() {
                    _password = value;
                  });
                },
              ),
              SwitchListTile(
                title: Text('Red Segura'),
                value: _isSecure,
                onChanged: (bool value) {
                  setState(() {
                    _isSecure = value;
                  });
                },
              ),
              SizedBox(height: 20),
              
              // Botón de activación
              ElevatedButton(
                onPressed: _toggleHotspot,
                child: Text(_isHotspotActive 
                  ? 'Detener Repetidor' 
                  : 'Iniciar Repetidor'
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isHotspotActive 
                    ? Colors.red 
                    : Colors.green,
                ),
              ),
              
              // Estado del repetidor
              SizedBox(height: 20),
              Text(
                _isHotspotActive 
                  ? 'Repetidor Activo' 
                  : 'Repetidor Inactivo',
                style: TextStyle(
                  color: _isHotspotActive 
                    ? Colors.green 
                    : Colors.red,
                  fontSize: 18,
                ),
              ),
              
              // Dispositivos conectados
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkConnectedDevices,
                child: Text('Verificar Dispositivos'),
              ),
              
              // Lista de dispositivos
              Expanded(
                child: ListView.builder(
                  itemCount: _connectedDevices.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text('Dispositivo: ${_connectedDevices[index]}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class DeviceCompatibilityChecker {
  Future<bool> isWiFiRepeaterSupported() async {
    try {
      // Método de canal para verificar capacidades específicas del dispositivo
      final bool isSupported = await MethodChannel('device_compatibility')
          .invokeMethod('checkWiFiRepeaterSupport');
      
      return isSupported;
    } on PlatformException {
      // Manejar errores de verificación
      return false;
    }
  }

  Future<void> showCompatibilityDialog(BuildContext context) async {
    final bool isCompatible = await isWiFiRepeaterSupported();
    
    if (!isCompatible) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Dispositivo No Compatible'),
            content: Text(
              'Su dispositivo no soporta la funcionalidad de repetidor WiFi. '
              'Algunas características pueden estar limitadas o no funcionar.'
            ),
            actions: [
              TextButton(
                child: Text('Entendido'),
                onPressed: () => Navigator.of(context).pop(),
              )
            ],
          );
        }
      );
    }
  }
}

class WiFiRepeaterErrorHandler {
  String getErrorMessage(dynamic error) {
    if (error is PlatformException) {
      switch (error.code) {
        case 'PERMISSION_DENIED':
          return 'No se tienen permisos para configurar el repetidor WiFi. '
                 'Verifique la configuración de permisos de la aplicación.';
        
        case 'HOTSPOT_CONFIG_ERROR':
          return 'Error al configurar el punto de acceso. '
                 'Asegúrese de que la configuración sea correcta.';
        
        case 'NETWORK_INTERFACE_ERROR':
          return 'No se puede acceder a la interfaz de red. '
                 'Compruebe la conectividad WiFi.';
        
        case 'RADIO_STATE_ERROR':
          return 'El radio WiFi no está en un estado válido. '
                 'Intente reiniciar la conexión WiFi.';
        
        default:
          return 'Error desconocido al configurar el repetidor: ${error.message}';
      }
    }
    
    return 'Error inesperado al configurar el repetidor WiFi.';
  }

  void showErrorNotification(BuildContext context, dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(getErrorMessage(error)),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      )
    );
  }
}

class PowerSavingMode {
  bool _isPowerSavingEnabled = false;
  Timer? _powerSavingTimer;

  void enablePowerSaving() {
    _isPowerSavingEnabled = true;
    
    // Reducir potencia de transmisión
    _adjustTransmissionPower(low: true);
    
    // Implementar temporizador de apagado automático
    _powerSavingTimer = Timer.periodic(Duration(minutes: 30), (timer) {
      _checkAndDisableRepeater();
    });
  }

  void disablePowerSaving() {
    _isPowerSavingEnabled = false;
    _powerSavingTimer?.cancel();
    _adjustTransmissionPower(low: false);
  }

  void _adjustTransmissionPower({required bool low}) async {
    try {
      await MethodChannel('wifi_power_control').invokeMethod('setTransmissionPower', {
        'lowPower': low
      });
    } on PlatformException catch (e) {
      print('Error ajustando potencia: ${e.message}');
    }
  }

  void _checkAndDisableRepeater() async {
    // Verificar condiciones para apagar
    final bool noActiveConnections = await _checkActiveConnections();
    final bool batteryLow = await _checkBatteryLevel();

    if (noActiveConnections || batteryLow) {
      await MethodChannel('wifi_repeater').invokeMethod('stopRepeater');
    }
  }

  Future<bool> _checkActiveConnections() async {
    // Verificar número de dispositivos conectados
    return await MethodChannel('wifi_connections')
        .invokeMethod('getConnectedDevicesCount') == 0;
  }

  Future<bool> _checkBatteryLevel() async {
    // Verificar nivel de batería
    final int batteryLevel = await MethodChannel('battery_info')
        .invokeMethod('getBatteryLevel');
    return batteryLevel < 20; // Apagar si batería menor a 20%
  }
}

class SystemPermissionsHandler {
  Future<bool> requestWiFiPermissions() async {
    // Solicitar permisos de ubicación (necesarios para WiFi en Android)
    final locationStatus = await Permission.location.request();
    
    // Solicitar permisos de cambio de estado WiFi
    //final wifiStatus = await Permission.manageWifi.request();
    
    return locationStatus.isGranted ;//&& wifiStatus.isGranted;
  }

  Future<void> openAppSettings() async {
    // Abrir configuraciones de la aplicación para ajustar permisos
    await openAppSettings();
  }

  Future<void> checkAndRequestPermissions(BuildContext context) async {
    final bool permissionsGranted = await requestWiFiPermissions();
    
    if (!permissionsGranted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Permisos Requeridos'),
          content: Text(
            'La aplicación necesita permisos de ubicación y WiFi para funcionar. '
            'Por favor, conceda los permisos necesarios.'
          ),
          actions: [
            TextButton(
              child: Text('Abrir Configuraciones'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
            TextButton(
              child: Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        )
      );
    }
  }
}

