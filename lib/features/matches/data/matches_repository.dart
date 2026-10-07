import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'match_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../services/data/service_model.dart';
import '../../users/data/address_model.dart';
import '../../users/data/user_model.dart';

class MatchesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String createRequestId() => _firestore.collection('matches').doc().id;

  // Actualiza el estado del match en Firebase
  Future<void> updateMatchStatus(String matchId, String newStatus) async {
    await _firestore.collection('matches').doc(matchId).update({
      'status': newStatus,
    });
  }

  // Elimina un match de la base de datos (para limpiar el historial)
  Future<void> deleteMatch(String matchId) async {
    await _firestore.collection('matches').doc(matchId).delete();
  }

  Future<void> completeServiceRequest({
    required String requestId,
    required String providerId,
    required double rating,
  }) async {
    final requestRef = _firestore.collection('matches').doc(requestId);
    final providerRef = _firestore.collection('users').doc(providerId);
    final earningRef = _firestore.collection('platform_earnings').doc();
    final providerTransactionRef = providerRef.collection('transactions').doc();
    final initialRequestSnapshot = await requestRef.get();
    final clientId = initialRequestSnapshot.data()?['clientId']?.toString();
    if (!initialRequestSnapshot.exists || clientId == null || clientId.isEmpty) {
      throw StateError('No se encontró el cliente de la solicitud.');
    }
    final clientTransactions = await _firestore
        .collection('users')
        .doc(clientId)
        .collection('transactions')
        .where('requestId', isEqualTo: requestId)
        .limit(1)
        .get();
    final clientReceiptRef = clientTransactions.docs.isEmpty
        ? null
        : clientTransactions.docs.first.reference;

    await _firestore.runTransaction<void>((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      if (!requestSnapshot.exists) {
        throw StateError('No se encontró la solicitud.');
      }

      final requestData = requestSnapshot.data()!;
      final requestClientId = requestData['clientId']?.toString();
      if (requestClientId == null ||
          requestClientId.isEmpty ||
          requestClientId != clientId) {
        throw StateError('La solicitud no contiene el ID del cliente.');
      }
      final status = requestData['status']?.toString();
      if (status == 'completed') {
        throw StateError('La solicitud ya fue completada y liquidada.');
      }
      if (status != 'accepted') {
        throw StateError('Solo se pueden completar solicitudes aceptadas.');
      }

      final requestProviderId = requestData['providerId']?.toString();
      if (requestProviderId != providerId) {
        throw StateError('El proveedor no corresponde a esta solicitud.');
      }

      final providerSnapshot = await transaction.get(providerRef);
      if (!providerSnapshot.exists) {
        throw StateError('No se encontró el perfil del proveedor.');
      }
      if (clientReceiptRef != null) {
        await transaction.get(clientReceiptRef);
      }

      final rawPrice = requestData['servicePrice'];
      double servicePrice;
      if (rawPrice is num) {
        servicePrice = rawPrice.toDouble();
      } else {
        final serviceId = requestData['serviceId']?.toString();
        if (serviceId == null || serviceId.isEmpty) {
          throw StateError('La solicitud no contiene el precio del servicio.');
        }
        final serviceSnapshot = await transaction.get(
          _firestore.collection('services').doc(serviceId),
        );
        final servicePriceValue = serviceSnapshot.data()?['price'];
        if (servicePriceValue is! num) {
          throw StateError('No se pudo determinar el precio del servicio.');
        }
        servicePrice = servicePriceValue.toDouble();
      }

      if (!servicePrice.isFinite || servicePrice <= 0) {
        throw StateError('El precio del servicio no es válido.');
      }
      if (!rating.isFinite || rating < 0 || rating > 5) {
        throw ArgumentError.value(rating, 'rating', 'Debe estar entre 0 y 5.');
      }

      final platformFee = servicePrice * 0.05;
      final providerEarnings = servicePrice - platformFee;

      final providerData = providerSnapshot.data()!;
      final currentTotal = (providerData['totalReviews'] as num?)?.toInt() ?? 0;
      final currentAverage =
          (providerData['averageRating'] as num?)?.toDouble() ?? 0.0;
      final newTotal = currentTotal + 1;
      final newAverage = ((currentAverage * currentTotal) + rating) / newTotal;
      final currentBalance = providerData['balance'];
      final providerUpdate = <String, dynamic>{
        'totalReviews': newTotal,
        'averageRating': newAverage,
        'balance': currentBalance is num
            ? FieldValue.increment(providerEarnings)
            : UserModel.defaultBalance + providerEarnings,
      };

      transaction.set(providerRef, providerUpdate, SetOptions(merge: true));
      transaction.set(providerTransactionRef, {
        'title': 'Ganancia por servicio',
        'amount': providerEarnings,
        'isPositive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (clientReceiptRef != null) {
        transaction.update(clientReceiptRef, {
          'title': 'Pago completado - Servicio',
        });
      }
      transaction.set(earningRef, {
        'requestId': requestId,
        'providerId': providerId,
        'amount': platformFee,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(requestRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'rating': rating,
        'platformFee': platformFee,
        'providerEarnings': providerEarnings,
        'payoutReleased': true,
      });
    });
  }

  Future<void> completeMatchAndRate(
    String matchId,
    String providerId,
    double rating,
  ) async {
    await completeServiceRequest(
      requestId: matchId,
      providerId: providerId,
      rating: rating,
    );
  }

  Future<void> requestService({
    required String requestId,
    required ServiceModel service,
    required AddressModel serviceAddress,
    required String paymentMethod,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para solicitar un servicio');
    }
    if (user.uid == service.providerId) {
      throw Exception('No puedes solicitar tu propio servicio');
    }

    final existingMatches = await _firestore
        .collection('matches')
        .where('clientId', isEqualTo: user.uid)
        .where('serviceId', isEqualTo: service.id)
        .get();
    if (existingMatches.docs.any(
      (doc) => doc.data()['status'] != 'cancelled',
    )) {
      throw Exception('Ya has solicitado este servicio previamente.');
    }

    final userSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
    final docRef = _firestore.collection('matches').doc(requestId);
    final request = MatchModel(
      id: docRef.id,
      serviceId: service.id,
      clientId: user.uid,
      clientName: userSnapshot.data()?['name']?.toString() ?? 'Cliente',
      providerId: service.providerId,
      serviceAddress: serviceAddress,
      serviceTitle: service.title,
      serviceDescription: service.description,
      servicePrice: service.price,
      serviceCategory: service.category,
      paymentMethod: paymentMethod,
    );

    await docRef.set(request.toMap());
  }

  Future<void> cancelAndRefundService({
    required String requestId,
    required String clientId,
    required double amount,
    bool providerRejected = false,
  }) async {
    if (!amount.isFinite || amount < 0) {
      throw ArgumentError.value(amount, 'amount', 'Debe ser válido.');
    }

    final requestRef = _firestore.collection('matches').doc(requestId);
    final clientRef = _firestore.collection('users').doc(clientId);
    final refundTransactionRef = clientRef.collection('transactions').doc();

    await _firestore.runTransaction<void>((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      if (!requestSnapshot.exists) {
        throw StateError('No se encontró la solicitud.');
      }

      final requestData = requestSnapshot.data()!;
      if (requestData['status']?.toString() != 'pending') {
        throw StateError('Solo se pueden cancelar solicitudes pendientes.');
      }
      if (requestData['clientId']?.toString() != clientId) {
        throw StateError('El cliente no corresponde a esta solicitud.');
      }

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final expectedActorId = providerRejected
          ? requestData['providerId']?.toString()
          : clientId;
      if (currentUserId == null || currentUserId != expectedActorId) {
        throw StateError('No tienes permiso para cancelar esta solicitud.');
      }

      final clientSnapshot = await transaction.get(clientRef);
      if (!clientSnapshot.exists) {
        throw StateError('No se encontró el perfil del cliente.');
      }

      final rawPrice = requestData['servicePrice'];
      final requestAmount = rawPrice is num ? rawPrice.toDouble() : null;
      if (requestAmount == null ||
          !requestAmount.isFinite ||
          requestAmount <= 0) {
        throw StateError('La solicitud no contiene un precio válido.');
      }
      if (amount > 0 && (amount - requestAmount).abs() > 0.005) {
        throw StateError('El monto del reembolso no coincide con la solicitud.');
      }

      transaction.set(clientRef, {
        'balance': FieldValue.increment(requestAmount),
      }, SetOptions(merge: true));
      transaction.set(refundTransactionRef, {
        'title': 'Reembolso por cancelación',
        'amount': requestAmount,
        'isPositive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(requestRef, {
        'status': providerRejected ? 'rejected' : 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'refunded': true,
      });
    });
  }
} // <--- Aquí cierra correctamente la clase MatchesRepository

// Exponemos el repositorio para usarlo en la UI
final matchesRepositoryProvider = Provider<MatchesRepository>(
  (ref) => MatchesRepository(),
);

// Este proveedor escucha en tiempo real las solicitudes donde YO soy el proveedor
Stream<List<MatchModel>> _matchesForUser(
  String field,
  String userId,
  List<String> statuses,
) {
  return FirebaseFirestore.instance
      .collection('matches')
      .where(field, isEqualTo: userId)
      .where('status', whereIn: statuses)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => MatchModel.fromMap(doc.data(), doc.id))
            .toList(),
      );
}

final providerActiveMatchesProvider = StreamProvider<List<MatchModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) return const Stream.empty();

  return _matchesForUser('providerId', user.uid, ['pending', 'accepted']);
});

final providerHistoryMatchesProvider = StreamProvider<List<MatchModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) return const Stream.empty();

  return _matchesForUser('providerId', user.uid, [
    'completed',
    'rejected',
    'cancelled',
  ]);
});

final clientActiveMatchesProvider = StreamProvider<List<MatchModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) return const Stream.empty();

  return _matchesForUser('clientId', user.uid, ['pending', 'accepted']);
});

final requestStatusProvider = StreamProvider.family<MatchModel?, String>((
  ref,
  serviceId,
) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('matches')
      .where('clientId', isEqualTo: user.uid)
      .where('serviceId', isEqualTo: serviceId)
      .snapshots()
      .map((snapshot) {
        final activeRequest = snapshot.docs
            .map((doc) => MatchModel.fromMap(doc.data(), doc.id))
            .where((request) => request.status != 'cancelled')
            .firstOrNull;
        return activeRequest;
      });
});

final clientHistoryMatchesProvider = StreamProvider<List<MatchModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) return const Stream.empty();

  return _matchesForUser('clientId', user.uid, [
    'completed',
    'rejected',
    'cancelled',
  ]);
});
// Proveedor para obtener los detalles de un match específico
final matchDetailsProvider = StreamProvider.family<MatchModel?, String>((
  ref,
  matchId,
) {
  return FirebaseFirestore.instance
      .collection('matches')
      .doc(matchId)
      .snapshots()
      .map(
        (doc) => doc.exists ? MatchModel.fromMap(doc.data()!, doc.id) : null,
      );
});
