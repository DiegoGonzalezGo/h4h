import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 1. Importación para el gestor de estado

import 'firebase_options.dart';
import 'core/router/app_router.dart'; // 2. Importación para que reconozca "appRouter"

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 3. Envolvemos MyApp en ProviderScope para poder usar Riverpod en toda la aplicación
  runApp(const ProviderScope(child: MyApp()));
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: router, // Usamos la variable en lugar del import directo
      debugShowCheckedModeBanner: false,
    );
  }
}