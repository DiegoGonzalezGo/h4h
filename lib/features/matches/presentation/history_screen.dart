import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/data/services_repository.dart';
import '../../users/data/provider_mode.dart';
import '../data/matches_repository.dart';
import '../data/match_model.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isProviderMode = ref.watch(providerModeProvider);
    final matchesAsync = ref.watch(
      isProviderMode
          ? providerHistoryMatchesProvider
          : clientHistoryMatchesProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de servicios')),
      body: matchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (matches) {
          if (matches.isEmpty) {
            return const Center(
              child: Text('Aún no tienes servicios en tu historial.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              return _HistoryMatchCard(match: matches[index]);
            },
          );
        },
      ),
    );
  }
}

class _HistoryMatchCard extends ConsumerWidget {
  final MatchModel match;

  const _HistoryMatchCard({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(singleServiceProvider(match.serviceId));

    return Card(
      color: Colors.grey.shade100,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: serviceAsync.when(
        loading: () => const ListTile(title: Text('Cargando servicio...')),
        error: (error, stack) => _buildTile('Servicio no disponible'),
        data: (service) =>
            _buildTile(service?.title ?? 'Servicio no disponible (eliminado)'),
      ),
    );
  }

  Widget _buildTile(String serviceTitle) {
    final status = _statusDetails(match.status);
    final rating = match.rating;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: status.color.withValues(alpha: 0.15),
        child: Icon(status.icon, color: status.color),
      ),
      title: Text(
        serviceTitle,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status.label, style: TextStyle(color: status.color)),
          if (rating != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text('Calificación otorgada: ${rating.toStringAsFixed(1)}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

({String label, Color color, IconData icon}) _statusDetails(String status) {
  switch (status) {
    case 'completed':
      return (
        label: 'Completado',
        color: Colors.green,
        icon: Icons.check_circle,
      );
    case 'cancelled':
      return (label: 'Cancelado', color: Colors.orange, icon: Icons.cancel);
    case 'rejected':
      return (label: 'Rechazado', color: Colors.red, icon: Icons.block);
    default:
      return (label: status, color: Colors.grey, icon: Icons.history);
  }
}
