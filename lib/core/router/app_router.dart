import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/navigation/presentation/main_navigation_scaffold.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/services/presentation/services_feed_screen.dart';
import '../../features/services/presentation/saved_services_screen.dart';
import '../../features/services/presentation/checkout_screen.dart';
import '../../features/services/presentation/service_match_screen.dart';
import '../../features/users/presentation/my_addresses_screen.dart';
import '../../features/auth/data/auth_repository.dart'; // Importamos el espía que acabamos de crear
import '../../features/users/presentation/profile_screen.dart';
import '../../features/services/presentation/create_service_screen.dart';
import '../../features/matches/presentation/provider_matches_screen.dart';
import '../../features/services/presentation/my_services_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/matches/presentation/client_matches_screen.dart';
import '../../features/matches/presentation/history_screen.dart';
import '../../features/services/presentation/top_providers_screen.dart';
import '../../features/users/presentation/edit_profile_screen.dart';
import '../../features/users/presentation/public_profile_screen.dart';
import '../../features/auth/presentation/banned_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  var authState = ref.read(authStateProvider);

  late final GoRouter router;
  router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      if (authState.isLoading || authState.hasError) return null;

      final isAuthenticated = authState.value != null;
      final isGoingToLogin = state.matchedLocation == '/login';

      if (!isAuthenticated && !isGoingToLogin) {
        return '/login';
      }

      if (isAuthenticated && isGoingToLogin) {
        return '/feed';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/banned',
        builder: (context, state) => const BannedScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainNavigationScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                builder: (context, state) => const ServicesFeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => const HistoryScreen(),
              ),
              GoRoute(
                path: '/client-history',
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
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
        path: '/saved-services',
        builder: (context, state) => const SavedServicesScreen(),
      ),
      GoRoute(
        path: '/service-match',
        builder: (context, state) => ServiceMatchScreen(
          categoriaBuscada: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/confirm-request',
        builder: (context, state) {
          final checkout = state.extra! as ServiceCheckoutArgs;
          return CheckoutScreen(
            servicio: checkout.service,
            selectedAddress: checkout.address,
          );
        },
      ),
      GoRoute(
        path: '/my-addresses',
        builder: (context, state) => const MyAddressesScreen(),
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
      GoRoute(path: '/', redirect: (context, state) => '/feed'),
      GoRoute(
        path: '/ranking',
        builder: (context, state) => const TopProvidersScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/user/:id',
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          return PublicProfileScreen(userId: userId);
        },
      ),
    ],
  );

  ref.listen(authStateProvider, (previous, next) {
    authState = next;
    router.refresh();
  });
  ref.onDispose(router.dispose);

  return router;
});
