import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../users/data/user_repository.dart';
import '../data/services_repository.dart';
import 'service_details_dialog.dart';
import 'service_card.dart';

class SavedServicesScreen extends ConsumerWidget {
  const SavedServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Servicios Guardados'),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: currentUserAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'No se pudieron cargar tus servicios guardados.',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        data: (user) {
          final savedIds = user?.savedServices ?? const <String>[];
          if (savedIds.isEmpty) {
            return const _SavedServicesEmptyState();
          }

          final savedServicesAsync = ref.watch(
            savedServicesByIdsProvider(jsonEncode(savedIds)),
          );

          return savedServicesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => const Center(
              child: Text(
                'No se pudieron cargar los servicios guardados.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            data: (services) {
              if (services.isEmpty) {
                return const _SavedServicesEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final service = services[index];

                  void openServiceDetails() {
                    showServiceDetailsDialog(
                      context: context,
                      ref: ref,
                      service: service,
                    );
                  }

                  return ServiceCard(
                    service: service,
                    onTap: openServiceDetails,
                    onRequest: openServiceDetails,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SavedServicesEmptyState extends StatelessWidget {
  const _SavedServicesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.heart_broken_outlined,
              size: 72,
              color: Color(0xFF424242),
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no has guardado ningún servicio',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
