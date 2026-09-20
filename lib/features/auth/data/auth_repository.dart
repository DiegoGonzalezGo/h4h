import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../users/data/user_model.dart'; // Importamos el modelo que definimos antes

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Registro de nuevo usuario
  Future<void> signUp(String email, String password, String name) async {
    try {
      // Crea el usuario en Firebase Auth
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Prepara los datos para Firestore
      UserModel newUser = UserModel(
        uid: credential.user!.uid, // Obtenemos el ID único generado por Auth
        name: name,
        email: email,
        roles: ['client'], // Todo usuario nuevo empieza siendo cliente por defecto
      );

      // Guarda el perfil en la colección 'users'
      await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap());
      
    } catch (e) {
      throw Exception('Error al registrar: $e');
    }
  }

  // 2. Inicio de sesión
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      throw Exception('Error al iniciar sesión: $e');
    }
  }
  
  // 3. Cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

// Exponemos el repositorio usando Riverpod para poder llamarlo desde la Interfaz
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
// Este provider emitirá eventos automáticos cuando el usuario inicie o cierre sesión
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});