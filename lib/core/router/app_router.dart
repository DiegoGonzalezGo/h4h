import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/services/presentation/services_feed_screen.dart';
import '../../features/auth/data/auth_repository.dart'; // Importamos el espía que acabamos de crear
import '../../features/users/presentation/profile_screen.dart';
import '../../features/services/presentation/create_service_screen.dart';
import '../../features/matches/presentation/provider_matches_screen.dart';
import '../../features/services/presentation/my_services_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/matches/presentation/client_matches_screen.dart';
// Convertimos el enrutador en un Provider
final goRouterProvider = Provider<GoRouter>((ref) {
  
  // 1. Riverpod vigila el estado de Firebase Auth en tiempo real
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    
    // 2. El redirect se ejecuta mágicamente CADA VEZ que el authState cambia
    redirect: (context, state) {
      // Si Firebase todavía está pensando, no hacemos nada
      if (authState.isLoading || authState.hasError) return null;

      final isAuthenticated = authState.value != null;
      final isGoingToLogin = state.matchedLocation == '/login';

      // Regla A: Si NO está logueado y trata de entrar al feed (o a otra ruta) -> Bloquear y enviar al Login
      if (!isAuthenticated && !isGoingToLogin) {
        return '/login';
      }
      
      // Regla B: Si SÍ está logueado y por error abre la pantalla de Login -> Enviar directo al Feed
      if (isAuthenticated && isGoingToLogin) {
        return '/feed';
      }

      // Todo está en orden, permitir el paso a la ruta original
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/feed',
        builder: (context, state) => const ServicesFeedScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/create-service',
        builder: (context, state) => const CreateServiceScreen(),
      ),
      GoRoute(
        path: '/provider-matches',
        builder: (context, state) => const ProviderMatchesScreen(),
      ),
      GoRoute(
        path: '/my-services',
        builder: (context, state) => const MyServicesScreen(),
      ),
      GoRoute(
        path: '/chat/:matchId', // Los dos puntos indican que es un parámetro dinámico
        builder: (context, state) {
          final matchId = state.pathParameters['matchId']!;
          return ChatScreen(matchId: matchId);
        },
      ),
      GoRoute(
        path: '/client-matches',
        builder: (context, state) => const ClientMatchesScreen(),
      ),
      GoRoute(
        path: '/',
        redirect: (context, state) => '/feed',
      ),
      // Tus rutas actuales se quedan exactamente igual
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/feed',
        builder: (context, state) => const ServicesFeedScreen(),
      ),
    ],
  );
});