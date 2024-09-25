import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
//import 'package:web_socket_channel/io.dart';
import 'package:network_info_plus/network_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(SecurityCameraApp(camera: cameras.first));
}

class SecurityCameraApp extends StatelessWidget {
  final CameraDescription camera;

  const SecurityCameraApp({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraScreen(camera: camera),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  HttpServer? _server;
  List<WebSocket> _clients = [];
  String _ipAddress = '';
  int _port = 8080;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();
    _startServer();
    _getIpAddress();
  }

  Future<void> _getIpAddress() async {
    final info = NetworkInfo();
    final ipAddress = await info.getWifiIP();
    setState(() {
      _ipAddress = ipAddress ?? 'No se pudo obtener la IP';
    });
  }

  Future<void> _startServer() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      print('Servidor iniciado en $_ipAddress:$_port');
      _server!.listen((HttpRequest request) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          WebSocketTransformer.upgrade(request).then((WebSocket ws) {
            _handleWebSocket(ws);
          });
        }
      });
    } catch (e) {
      print('Error al iniciar el servidor: $e');
    }
  }

  void _handleWebSocket(WebSocket ws) {
    print('Nuevo cliente conectado');
    _clients.add(ws);
    ws.listen(
      (message) {
        // Manejar mensajes del cliente si es necesario
      },
      onDone: () {
        print('Cliente desconectado');
        _clients.remove(ws);
      },
    );
  }

  void _startStreaming() async {
    await _initializeControllerFuture;
    _controller.startImageStream((CameraImage image) {
      // Aquí deberías convertir la imagen a un formato adecuado para streaming
      // Por ejemplo, podrías usar image.planes[0].bytes para obtener los datos de la imagen
      // Luego, envía estos datos a todos los clientes conectados
      for (var client in _clients) {
        client.add(image.planes[0].bytes);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cámara de Seguridad')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller);
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Dirección del servidor: $_ipAddress:$_port'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.videocam),
        onPressed: _startStreaming,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    for (var client in _clients) {
      client.close();
    }
    _server?.close();
    super.dispose();
  }
}