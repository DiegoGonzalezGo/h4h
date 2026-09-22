import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userRepositoryProvider = Provider((ref) => UserRepository());

// Proveedor para escuchar los cambios del perfil en tiempo real (como la nueva foto)
final userProfileStreamProvider = StreamProvider.family<Map<String, dynamic>, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) => doc.data() ?? {});
});

class UserRepository {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // 1. CORRECCIÓN: Agregamos "String bio" a los parámetros
  Future<void> updateProfile(String userId, String newName, String bio, File? imageFile) async {
    String? photoUrl;

    if (imageFile != null) {
      final storageRef = _storage.ref().child('avatars').child('$userId.jpg');
      await storageRef.putFile(imageFile);
      photoUrl = await storageRef.getDownloadURL(); 
    }
    
    // 2. CORRECCIÓN: Unificamos el paquete de datos eliminando el código duplicado
    final dataToUpdate = <String, dynamic>{
      'name': newName.trim(),
      'bio': bio.trim(), 
    };
    
    if (photoUrl != null) {
      dataToUpdate['photoUrl'] = photoUrl;
    }

    await _firestore.collection('users').doc(userId).update(dataToUpdate);
  }
}