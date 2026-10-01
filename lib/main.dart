import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 1. Importación para el gestor de estado

import 'firebase_options.dart';
import 'core/router/app_router.dart'; // 2. Importación para que reconozca "appRouter"
import 'features/notifications/notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  final notificationsService = NotificationsService();
  await notificationsService.initialize();

  // 3. Envolvemos MyApp en ProviderScope para poder usar Riverpod en toda la aplicación
  runApp(
    ProviderScope(
      overrides: [
        notificationsServiceProvider.overrideWithValue(notificationsService),
      ],
      child: const MyApp(),
    ),
  );
}

// Cambiamos StatelessWidget por ConsumerWidget para que pueda leer a Riverpod
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // Agregamos el parámetro WidgetRef
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    
    // Obtenemos nuestro enrutador protegido
    final router = ref.watch(goRouterProvider); 

    return MaterialApp.router(
      title: 'Directorio de Servicios',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        colorScheme: ThemeData.dark().colorScheme.copyWith(
          primary: const Color(0xFF00B4DB),
          secondary: const Color(0xFF6A11CB),
        ),
      ),
      routerConfig: router, // Usamos la variable en lugar del import directo
      debugShowCheckedModeBanner: false,
    );
  }
}