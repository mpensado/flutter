import 'package:firebase_auth/firebase_auth.dart';
import 'package:lighthouse_map/data/models/user_model.dart';
import 'package:lighthouse_map/data/repositories/user_repository.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final UserRepository _userRepository = UserRepository();

  Future<UserModel?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential result = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = result.user;
      if (user != null) {
        final newUser = UserModel(userId: user.uid, email: email);
        await _userRepository.createUser(newUser);
        return newUser;
      }
      return null;
    } catch (e) {
      print('Error signing up: $e');
      return null;
    }
  }

  Future<UserModel?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential result = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = result.user;
      if (user != null) {
        return await _userRepository.getUser(user.uid);
      }
      return null;
    } catch (e) {
      print('Error signing in: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
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
}