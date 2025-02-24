import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:food_scanner/services/ocr_service.dart';
import 'package:food_scanner/screens/results_screen.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:food_scanner/utils/permissions_handler.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;
  bool _isProcessing = false;
  bool _isCameraReady = false; // Nuevo estado: cámara lista
  String? _errorMessage;      // Nuevo estado: mensaje de error

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
      // Inicializa _initializeControllerFuture *antes* de cualquier otra cosa
      _initializeControllerFuture = _initCameraController(); // Llama a un método separado

      // No es necesario el await aquí; el FutureBuilder se encargará de esperar.
  }

  Future<void> _initCameraController() async {
    try {
      bool hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        setState(() {
          _errorMessage = "Se necesita permiso de cámara para usar la app.";
        });
        return;
      }

      final cameras = await availableCameras();
      final firstCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

        await _controller!.initialize(); // Ahora si el await!
        setState(() {
            _isCameraReady = true;  // La cámara está lista
        });

    } catch (e) {
      setState(() {
        _errorMessage = "Error al inicializar la cámara: $e";
      });
    }
  }



  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Escanear Etiqueta'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: _buildCameraPreview(), // Usa un método para construir la vista
      floatingActionButton: FloatingActionButton(
        onPressed: (_isProcessing || !_isCameraReady) ? null : _takePicture,
        child: Icon(Icons.camera),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    if (!_isCameraReady) {
        return Center(child: CircularProgressIndicator());
    }

    //Ahora se construye solo si la camara esta lista.
    return Stack(
        children: [
            CameraPreview(_controller!),
            if (_isProcessing)
                Center(child: SpinKitCircle(color: Colors.blue)),
        ],
    );


  }


  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
        // Mostrar mensaje si la cámara no está lista
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("La cámara no está lista."))
        );
        return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Ya no necesitas await _initializeControllerFuture;  ya está inicializada
      final image = await _controller!.takePicture();
      final recognizedText = await OCRService.recognizeText(image.path);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(recognizedText: recognizedText),
        ),
      );
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al procesar la imagen.")),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
}