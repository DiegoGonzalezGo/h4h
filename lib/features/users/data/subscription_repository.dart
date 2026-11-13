import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionRepository {
  SubscriptionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> purchasePlan({
    required String userId,
    required String plan,
  }) async {
    final price = switch (plan) {
      'pro' => 349.0,
      'elite' => 599.0,
      _ => throw ArgumentError.value(plan, 'plan', 'Plan no comprable.'),
    };
    final userRef = _firestore.collection('users').doc(userId);
    final paymentRef = userRef.collection('transactions').doc();
    final earningRef = _firestore.collection('platform_earnings').doc();

    await _firestore.runTransaction<void>((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) {
        throw StateError('No se encontró el perfil del usuario.');
      }

      final userData = userSnapshot.data()!;
      final currentPlan = _currentPlan(userData);
      if (currentPlan == plan || (currentPlan == 'elite' && plan == 'pro')) {
        throw StateError('Ya tienes un plan igual o superior.');
      }

      final rawBalance = userData['balance'];
      final balance = rawBalance is num ? rawBalance.toDouble() : 10000.0;
      if (balance < price) {
        throw StateError('Saldo insuficiente en tu billetera.');
      }

      final activatedAt = FieldValue.serverTimestamp();
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      );
      transaction.update(userRef, {
        'balance': balance - price,
        'plan': plan,
        'isPro': true,
        'isElite': plan == 'elite',
        'isPremium': plan == 'elite',
        'adsDisabled': true,
        'autoRenew': true,
        'canceledAt': null,
        '${plan}ActivatedAt': activatedAt,
        if (plan == 'elite') 'premiumActivatedAt': activatedAt,
        'planExpiresAt': expiresAt,
        'lastRenewalNotice': null,
      });
      transaction.set(paymentRef, {
        'title': 'Suscripción SkillMatch ${plan == 'elite' ? 'Élite' : 'Pro'}',
        'amount': price,
        'isPositive': false,
        'requestId': 'subscription_$plan',
        'plan': plan,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (plan == 'elite') {
        transaction.set(earningRef, {
          'userId': userId,
          'type': 'subscription',
          'plan': 'elite',
          'amount': price,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<bool> checkSubscriptionStatus({required String userId}) async {
    final userRef = _firestore.collection('users').doc(userId);
    final notificationRef = userRef.collection('notificaciones').doc();
    final snapshot = await userRef.get();
    if (!snapshot.exists) {
      throw StateError('No se encontró el perfil del usuario.');
    }

    final data = snapshot.data()!;
    final expiresAt = _dateTimeFrom(data['planExpiresAt']);
    final plan = _currentPlan(data);
    if (expiresAt == null || plan == 'free') return false;

    final now = DateTime.now();
    if (!now.isBefore(expiresAt)) {
      final autoRenew = data['autoRenew'] != false;
      final price = plan == 'elite' ? 599.0 : 349.0;
      if (autoRenew) {
        final renewed = await _renewExpiredPlan(
          userRef: userRef,
          expectedPlan: plan,
          price: price,
        );
        if (renewed) return false;

        final latestSnapshot = await userRef.get();
        final latestData = latestSnapshot.data();
        final latestExpiry = latestData == null
            ? null
            : _dateTimeFrom(latestData['planExpiresAt']);
        final latestBalance = (latestData?['balance'] as num?)?.toDouble() ?? 0;
        if (latestData != null &&
            latestData['autoRenew'] != false &&
            _currentPlan(latestData) != 'free' &&
            latestExpiry != null &&
            !DateTime.now().isBefore(latestExpiry) &&
            latestBalance >= price) {
          final retriedRenewal = await _renewExpiredPlan(
            userRef: userRef,
            expectedPlan: plan,
            price: price,
          );
          if (retriedRenewal) return false;
        }

        final finalSnapshot = await userRef.get();
        final finalData = finalSnapshot.data();
        final finalExpiry = finalData == null
            ? null
            : _dateTimeFrom(finalData['planExpiresAt']);
        if (finalData != null &&
            _currentPlan(finalData) != 'free' &&
            finalExpiry != null &&
            DateTime.now().isBefore(finalExpiry)) {
          return false;
        }
      }

      await _deactivateExpiredPlan(userRef);
      return true;
    }

    final remaining = expiresAt.difference(now);
    if (remaining > const Duration(days: 3)) return false;

    final lastNotice = _dateTimeFrom(data['lastRenewalNotice']);
    if (lastNotice != null && _isSameDate(lastNotice, now)) return false;

    final daysRemaining = (remaining.inSeconds / Duration.secondsPerDay)
        .ceil();
    final displayPlan = plan == 'elite' ? 'Élite' : 'Pro';
    final renewalNotice = data['autoRenew'] == false
        ? 'Tu plan $displayPlan vencerá en $daysRemaining días. '
              'Reactivarlo antes del vencimiento para conservar tus beneficios.'
        : 'Tu plan $displayPlan vencerá en $daysRemaining días. '
              'Asegúrate de tener saldo en tu billetera';
    final notificationData = {
      'titulo': 'Vencimiento de tu plan',
      'mensaje': renewalNotice,
      'leida': false,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'subscription_renewal',
    };

    await _firestore.runTransaction<void>((transaction) async {
      final currentSnapshot = await transaction.get(userRef);
      if (!currentSnapshot.exists) {
        throw StateError('No se encontró el perfil del usuario.');
      }
      final currentData = currentSnapshot.data()!;
      final currentExpiry = _dateTimeFrom(currentData['planExpiresAt']);
      final currentLastNotice = _dateTimeFrom(currentData['lastRenewalNotice']);
      if (currentExpiry == null ||
          !DateTime.now().isBefore(currentExpiry) ||
          (currentLastNotice != null && _isSameDate(currentLastNotice, now))) {
        return;
      }

      transaction.set(notificationRef, notificationData);
      transaction.set(
        userRef.collection('notifications').doc(notificationRef.id),
        notificationData,
      );
      transaction.update(userRef, {
        'lastRenewalNotice': Timestamp.fromDate(
          DateTime(now.year, now.month, now.day),
        ),
      });
    });

    return false;
  }

  Future<void> cancelSubscription(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'autoRenew': false,
      'canceledAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reactivateSubscription(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'autoRenew': true,
      'canceledAt': null,
    });
  }

  Future<bool> _renewExpiredPlan({
    required DocumentReference<Map<String, dynamic>> userRef,
    required String expectedPlan,
    required double price,
  }) async {
    final paymentRef = userRef.collection('transactions').doc();
    final earningRef = _firestore.collection('platform_earnings').doc();

    return _firestore.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) {
        throw StateError('No se encontró el perfil del usuario.');
      }

      final data = snapshot.data()!;
      final currentPlan = _currentPlan(data);
      final expiresAt = _dateTimeFrom(data['planExpiresAt']);
      final balance = (data['balance'] as num?)?.toDouble() ?? 0;
      if (currentPlan != expectedPlan ||
          expiresAt == null ||
          DateTime.now().isBefore(expiresAt) ||
          data['autoRenew'] == false ||
          balance < price) {
        return false;
      }

      final newExpiry = DateTime.now().add(const Duration(days: 30));
      transaction.update(userRef, {
        'balance': balance - price,
        'planExpiresAt': Timestamp.fromDate(newExpiry),
        'lastRenewalNotice': null,
        'autoRenew': true,
        'canceledAt': null,
      });
      transaction.set(paymentRef, {
        'title':
            'Renovación automática SkillMatch ${expectedPlan == 'elite' ? 'Élite' : 'Pro'}',
        'amount': price,
        'isPositive': false,
        'requestId': 'subscription_renewal_$expectedPlan',
        'plan': expectedPlan,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(earningRef, {
        'userId': userRef.id,
        'type': 'subscription_renewal',
        'plan': expectedPlan,
        'amount': price,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Future<void> _deactivateExpiredPlan(
    DocumentReference<Map<String, dynamic>> userRef,
  ) async {
    final serviceQueries = await Future.wait([
      _firestore
          .collection('services')
          .where('providerId', isEqualTo: userRef.id)
          .get(),
      _firestore
          .collection('services')
          .where('userId', isEqualTo: userRef.id)
          .get(),
    ]);
    final serviceRefs = <String, DocumentReference<Map<String, dynamic>>>{};
    for (final query in serviceQueries) {
      for (final doc in query.docs) {
        serviceRefs[doc.reference.path] = doc.reference;
      }
    }

    final serviceList = serviceRefs.values.toList();
    final expiredPlanUpdates = <String, dynamic>{
      'plan': 'gratis',
      'adsDisabled': false,
      'isPro': false,
      'isElite': false,
      'isPremium': false,
      'isProviderMode': false,
      'autoRenew': false,
      'planExpiresAt': null,
      'lastRenewalNotice': null,
    };

    for (var start = 0; start < serviceList.length; start += 450) {
      final batch = _firestore.batch();
      if (start == 0) {
        batch.update(userRef, expiredPlanUpdates);
      }
      final end = (start + 450 < serviceList.length)
          ? start + 450
          : serviceList.length;
      for (final serviceRef in serviceList.sublist(start, end)) {
        batch.update(serviceRef, {
          'isActive': false,
          'inactiveReason': 'subscription_expired',
        });
      }
      await batch.commit();
    }

    if (serviceList.isEmpty) {
      final batch = _firestore.batch();
      batch.update(userRef, expiredPlanUpdates);
      await batch.commit();
    }
  }

  String _currentPlan(Map<String, dynamic> data) {
    final plan = data['plan']?.toString().toLowerCase();
    if (plan == 'elite' ||
        data['isElite'] == true ||
        data['isPremium'] == true) {
      return 'elite';
    }
    if (plan == 'pro' || data['isPro'] == true) return 'pro';
    return 'free';
  }

  DateTime? _dateTimeFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  bool _isSameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
