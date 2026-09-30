import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import 'address_model.dart';

final userRepositoryProvider = Provider((ref) => UserRepository());

// Escucha en tiempo real las direcciones guardadas del usuario actual
final currentUserAddressesProvider = StreamProvider<List<AddressModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) {
    return Stream.value(const <AddressModel>[]);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => AddressModel.listFromUserData(doc.data()));
});

// Proveedor para escuchar los cambios del perfil en tiempo real (como la nueva foto)
final userProfileStreamProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, userId) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots()
          .map((doc) => doc.data() ?? {});
    });

final currentUserStreamProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data());
});

class UserRepository {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<void> reportUser(String reportedUserId, String reason) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw StateError('No hay un usuario autenticado.');
      }

      await _firestore.collection('reports').add({
        'reportedUserId': reportedUserId,
        'reporterId': currentUser.uid,
        'reason': reason.trim(),
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error al reportar al usuario: $e');
    }
  }

  // Agrega una dirección al arreglo 'addresses' del documento del usuario
  Future<void> addAddress(String userId, AddressModel address) async {
    await _firestore.collection('users').doc(userId).update({
      'addresses': FieldValue.arrayUnion([address.toMap()]),
    });
  }

  // 1. CORRECCIÓN: Agregamos "String bio" a los parámetros
  Future<void> updateProfile(
    String userId,
    String newName,
    String bio,
    File? imageFile,
  ) async {
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
