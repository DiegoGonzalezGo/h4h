import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import 'address_model.dart';
import 'user_model.dart';

final userRepositoryProvider = Provider((ref) => UserRepository());

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

final currentUserControllerProvider =
    StreamNotifierProvider<CurrentUserController, UserModel?>(
      CurrentUserController.new,
    );

class CurrentUserController extends StreamNotifier<UserModel?> {
  @override
  Stream<UserModel?> build() {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return Stream.value(null);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          return data == null ? null : UserModel.fromMap(data, snapshot.id);
        });
  }

  Future<void> toggleSavedService(String serviceId) async {
    final currentUser = state.value;
    if (currentUser == null) {
      throw StateError('No hay un usuario cargado para guardar servicios.');
    }

    final wasSaved = currentUser.savedServices.contains(serviceId);
    final updatedServices = List<String>.from(currentUser.savedServices);
    if (wasSaved) {
      updatedServices.remove(serviceId);
    } else {
      updatedServices.add(serviceId);
    }

    state = AsyncData(currentUser.copyWith(savedServices: updatedServices));

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
            'savedServices': wasSaved
                ? FieldValue.arrayRemove([serviceId])
                : FieldValue.arrayUnion([serviceId]),
          });
    } catch (error, stackTrace) {
      state = AsyncData(currentUser);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> addAddress(AddressModel newAddress) async {
    final currentUser = state.value;
    if (currentUser == null) {
      throw StateError('No hay un usuario cargado para agregar direcciones.');
    }

    final previousAddresses = currentUser.addresses;
    final updatedAddresses = [...previousAddresses, newAddress];
    state = AsyncData(currentUser.copyWith(addresses: updatedAddresses));

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
            'addresses': FieldValue.arrayUnion([newAddress.toMap()]),
          });
    } catch (error, stackTrace) {
      state = AsyncData(currentUser);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> removeAddress(String addressId) async {
    final currentUser = state.value;
    if (currentUser == null) {
      throw StateError('No hay un usuario cargado para quitar direcciones.');
    }

    final addressToRemove = currentUser.addresses
        .where((address) => address.id == addressId)
        .firstOrNull;
    if (addressToRemove == null) return;

    final previousAddresses = currentUser.addresses;
    final updatedAddresses = previousAddresses
        .where((address) => address.id != addressId)
        .toList();
    state = AsyncData(currentUser.copyWith(addresses: updatedAddresses));

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
            'addresses': FieldValue.arrayRemove([addressToRemove.toMap()]),
          });
    } catch (error, stackTrace) {
      state = AsyncData(currentUser);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

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
