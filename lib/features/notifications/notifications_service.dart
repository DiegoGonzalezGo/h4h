import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Proveedor para acceder fácilmente a este servicio desde cualquier parte
final notificationsServiceProvider = Provider((ref) => NotificationsService());

class NotificationsService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Función principal para inicializar las notificaciones
  Future<void> initialize() async {
    // 1. Pedir permiso al usuario (necesario en iOS y Android 13+)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print(' Permiso de notificaciones concedido');
      await _saveDeviceToken();
    } else {
      print(' Permiso de notificaciones denegado');
    }

    // 2. Escuchar cuando la app está abierta y llega un mensaje
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(' Notificación recibida en primer plano: ${message.notification?.title}');
      // Aquí más adelante podemos mostrar una alerta visual dentro de la app
    });
  }

  // Función para obtener el Token del teléfono y guardarlo en el perfil del usuario
  Future<void> _saveDeviceToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Obtenemos el token único de este dispositivo
      String? token = await _messaging.getToken();
      
      if (token != null) {
        // Lo guardamos en el documento del usuario en Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print(' Token guardado en Firestore: $token');
      }

      // Si el token cambia (por ejemplo, al reinstalar la app), lo actualizamos
      _messaging.onTokenRefresh.listen((newToken) {
        _firestore.collection('users').doc(user.uid).update({
          'fcmToken': newToken,
        });
      });
    } catch (e) {
      print('Error al guardar el token: $e');
    }
  }
}