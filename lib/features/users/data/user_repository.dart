import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import 'address_model.dart';
import 'transaction_model.dart';
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

final transactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('transactions')
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (doc) => TransactionModel.fromMap(
                doc.data(),
                documentId: doc.id,
              ),
            )
            .toList(),
      );
});

class CurrentUserController extends StreamNotifier<UserModel?> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> deductBalance(
    double amount, {
    required String description,
    required String requestId,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Debe ser mayor que cero.');
    }

    final currentUser = state.value;
    if (currentUser == null) {
      throw StateError('No hay un usuario cargado para descontar saldo.');
    }

    final userRef = _firestore.collection('users').doc(currentUser.uid);
    final updatedUser = currentUser.copyWith(
      balance: currentUser.balance - amount,
    );
    state = AsyncData(updatedUser);

    try {
      final updatedBalance = await _firestore.runTransaction<double>((
        transaction,
      ) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) {
          throw StateError('No se encontró el perfil del usuario.');
        }

        final data = snapshot.data()!;
        final storedBalance = data['balance'];
        final balance = storedBalance is num
            ? storedBalance.toDouble()
            : UserModel.defaultBalance;
        if (balance < amount) {
          throw StateError('Saldo insuficiente en tu billetera.');
        }

        final nextBalance = balance - amount;
        if (storedBalance is num) {
          transaction.set(
            userRef,
            {'balance': FieldValue.increment(-amount)},
            SetOptions(merge: true),
          );
        } else {
          transaction.set(userRef, {
            'balance': nextBalance,
          }, SetOptions(merge: true));
        }
        final transactionRef = userRef.collection('transactions').doc();
        transaction.set(transactionRef, {
          'title': description,
          'amount': amount,
          'isPositive': false,
          'requestId': requestId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return nextBalance;
      });

      state = AsyncData(currentUser.copyWith(balance: updatedBalance));
    } catch (error, stackTrace) {
      state = AsyncData(currentUser);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> refundBalanceAfterFailedRequest(double amount) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Debe ser mayor que cero.');
    }

    final currentUser = state.value;
    if (currentUser == null) {
      throw StateError('No hay un usuario cargado para reembolsar el saldo.');
    }

    final userRef = _firestore.collection('users').doc(currentUser.uid);
    final updatedUser = currentUser.copyWith(
      balance: currentUser.balance + amount,
    );
    state = AsyncData(updatedUser);

    try {
      await _firestore.runTransaction<void>((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw StateError('No se encontró el perfil del usuario.');
        }

        transaction.update(userRef, {'balance': FieldValue.increment(amount)});
        final transactionRef = userRef.collection('transactions').doc();
        transaction.set(transactionRef, {
          'title': 'Reembolso por solicitud no completada',
          'amount': amount,
          'isPositive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (error, stackTrace) {
      state = AsyncData(currentUser);
      Error.throwWithStackTrace(error, stackTrace);
    }
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
