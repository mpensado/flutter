import 'package:permission_handler/permission_handler.dart';

Future<bool> requestCameraPermission() async {
  PermissionStatus status = await Permission.camera.request();
  if (status.isGranted) {
    return true;
  } else if (status.isPermanentlyDenied) {
    openAppSettings(); // Abre la configuración de la app para permisos.
    return false;
  }
  return false;
}