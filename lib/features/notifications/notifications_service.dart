import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';

final notificationsServiceProvider = Provider<NotificationsService>(
  (ref) => NotificationsService(),
);

const _androidChannel = AndroidNotificationChannel(
  'chat_messages',
  'Mensajes del chat',
  description: 'Notificaciones de nuevos mensajes del chat.',
  importance: Importance.max,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class NotificationsService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    final androidNotifications = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidNotifications?.createNotificationChannel(_androidChannel);
    await androidNotifications?.requestNotificationsPermission();

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Permiso de notificaciones concedido');
      await _saveDeviceToken(_auth.currentUser);
    } else {
      debugPrint('Permiso de notificaciones denegado');
    }

    _auth.authStateChanges().listen(_saveDeviceToken);
    _messaging.onTokenRefresh.listen((token) async {
      final user = _auth.currentUser;
      if (user != null) await _saveToken(user, token);
    });
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  Future<void> _saveDeviceToken(User? user) async {
    if (user == null) return;

    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(user, token);
    } catch (error) {
      debugPrint('Error al guardar el token FCM: $error');
    }
  }

  Future<void> _saveToken(User user, String token) async {
    await _firestore.collection('users').doc(user.uid).set({
      'fcmToken': token,
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('Token FCM guardado para ${user.uid}');
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return;

    await _localNotifications.show(
      message.messageId.hashCode,
      title ?? 'Hand4Hand',
      body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_messages',
          'Mensajes del chat',
          channelDescription: 'Notificaciones de nuevos mensajes del chat.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}