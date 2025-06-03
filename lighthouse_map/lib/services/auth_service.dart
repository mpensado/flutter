import 'dart:io';
import 'package:uuid/uuid.dart'; // Importa el paquete Uuid

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Importa Firebase Messaging
import 'package:flutter/material.dart';
import 'package:lighthouse_map/data/models/device_model.dart';
import 'package:lighthouse_map/data/models/user_model.dart';
import 'package:lighthouse_map/data/repositories/device_repository.dart';
import 'package:lighthouse_map/data/repositories/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Importa SharedPreferences

//import '../../data/models/user_model.dart';
//import '../../data/models/device_model.dart'; // Importa DeviceModel
//import '../../data/repositories/user_repository.dart';
//import '../../data/repositories/device_repository.dart'; // Importa DeviceRepository

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final UserRepository _userRepository = UserRepository();
  final DeviceRepository _deviceRepository =
      DeviceRepository(); // Instancia del DeviceRepository
  final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance; // Instancia de Firebase Messaging
  final Uuid _uuid = Uuid(); // Instancia para generar UUIDs

  // --- Métodos existentes (signUpWithEmailAndPassword, signInWithEmailAndPassword, etc.) ---

  Future<UserModel?> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential result = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);
      final User? firebaseUser = result.user;
      if (firebaseUser != null) {
        final newUser = UserModel(userId: firebaseUser.uid, email: email);
        await _userRepository.createUser(newUser);

        // REGISTRAR O ACTUALIZAR DISPOSITIVO DESPUÉS DEL REGISTRO
        await _registerOrUpdateDevice(firebaseUser.uid);

        return newUser;
      }
      return null;
    } catch (e) {
      debugPrint('[MYLOG]Error signing up: $e');
      return null;
    }
  }

  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential result = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);
      final User? firebaseUser = result.user;
      if (firebaseUser != null) {
        UserModel? userModel = await _userRepository.getUser(firebaseUser.uid);
        if (userModel == null) {
          userModel = UserModel(
            userId: firebaseUser.uid,
            email: firebaseUser.email,
            nombre: firebaseUser.displayName,
          );
          await _userRepository.createUser(userModel);
        }

        // REGISTRAR O ACTUALIZAR DISPOSITIVO DESPUÉS DEL INICIO DE SESIÓN
        await _registerOrUpdateDevice(firebaseUser.uid);

        return userModel;
      }
      return null;
    } catch (e) {
      debugPrint('[MYLOG]Error signing in: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    // Opcional: limpiar el device_id local si el dispositivo no debe permanecer registrado sin sesión
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.remove('device_id');
  }

  Future<bool> isSignedIn() async {
    final User? currentUser = _firebaseAuth.currentUser;
    return currentUser != null;
  }

  Future<String?> getCurrentUserId() async {
    return _firebaseAuth.currentUser?.uid;
  }

  Future<UserModel?> getCurrentUser() async {
    final String? userId = await getCurrentUserId();
    if (userId != null) {
      return await _userRepository.getUser(userId);
    }
    return null;
  }

  // --- NUEVO MÉTODO PRIVADO PARA REGISTRAR/ACTUALIZAR EL DISPOSITIVO ---
  Future<void> _registerOrUpdateDevice(String userId) async {
    try {
      String? fcmToken = "";
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null) {
        deviceId = _uuid.v4(); // Genera un UUID
        await prefs.setString('device_id', deviceId);
        await Future.delayed(const Duration(milliseconds: 100)); // Pequeña espera para persistencia
      }
      final String actualDeviceId = deviceId; // Asigna a una variable final no-nula


      try {
        String? fcmToken = await _firebaseMessaging.getToken();
      } catch (e) {
        debugPrint('[MYLOG]Error al obtener el FCM token: $e');
        throw Exception('$e');  
      }

      final deviceModel = DeviceModel(
        deviceId: actualDeviceId,
        userId: userId,
        fcmToken: fcmToken,
        platform:
            Platform.isAndroid
                ? 'Android'
                : Platform.isIOS
                ? 'iOS'
                : 'Web/Other',
        createdAt: DateTime.now(),
      );

      final existingDevice = await _deviceRepository.getDevice(actualDeviceId);
      if (existingDevice == null) {
        await _deviceRepository.createDevice(deviceModel);
        debugPrint('[MYLOG]Dispositivo registrado en Firestore: $actualDeviceId');
      } else {
        // Si ya existe, solo actualizamos el fcmToken (y quizás el last_active)
        final updatedDevice = DeviceModel(
          deviceId:
              deviceModel
                  .deviceId, // <--- deviceId se usa aquí para la actualización
          userId: deviceModel.userId,
          fcmToken: deviceModel.fcmToken,
          platform: deviceModel.platform,
          model: deviceModel.model,
          createdAt: existingDevice.createdAt,
        );
        await _deviceRepository.updateDevice(
          updatedDevice,
        ); // <--- deviceId se usa como ID del documento
        debugPrint('[MYLOG]Dispositivo actualizado en Firestore: $actualDeviceId');
      }
    } catch (e) {
      debugPrint('[MYLOG]Error al registrar o actualizar el dispositivo: $e');
    }
  }
}
