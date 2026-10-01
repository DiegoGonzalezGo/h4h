import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/data/services_repository.dart';
import '../../users/data/provider_mode.dart';
import '../data/matches_repository.dart';
import '../data/match_model.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _selectedFilter = 0;

  @override
  Widget build(BuildContext context) {
    final isProviderMode = ref.watch(providerModeProvider);
    final matchesAsync = ref.watch(
      isProviderMode
          ? providerHistoryMatchesProvider
          : clientHistoryMatchesProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de servicios')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: List.generate(3, (index) {
                const labels = ['Todos', 'Completados', 'Cancelados'];
                final isSelected = _selectedFilter == index;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedFilter = index),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? null : const Color(0xFF1E1E1E),
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF6A11CB),
                                    Color(0xFF2575FC),
                                  ],
                                )
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          labels[index],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: matchesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
              data: (matches) {
                if (matches.isEmpty) {
                  return const Center(
                    child: Text('Aún no tienes servicios en tu historial.'),
                  );
                }

                final filteredMatches = switch (_selectedFilter) {
                  1 =>
                    matches
                        .where((match) => match.status == 'completed')
                        .toList(),
                  2 =>
                    matches
                        .where((match) => match.status == 'cancelled')
                        .toList(),
                  _ => matches,
                };

                if (filteredMatches.isEmpty) {
                  return const Center(
                    child: Text('No hay servicios para este filtro.'),
                  );
                }

                final groupedMatches = <DateTime?, List<MatchModel>>{};
                for (final match in filteredMatches) {
                  final completedAt = match.completedAt;
                  final period = completedAt == null
                      ? null
                      : DateTime(completedAt.year, completedAt.month);
                  groupedMatches.putIfAbsent(period, () => []).add(match);
                }

                final periods = groupedMatches.keys.toList()
                  ..sort((a, b) {
                    if (a == null) return 1;
                    if (b == null) return -1;
                    return b.compareTo(a);
                  });

                for (final periodMatches in groupedMatches.values) {
                  periodMatches.sort((a, b) {
                    final aDate = a.completedAt;
                    final bDate = b.completedAt;
                    if (aDate == null) return bDate == null ? 0 : 1;
                    if (bDate == null) return -1;
                    return bDate.compareTo(aDate);
                  });
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  children: [
                    for (final period in periods) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                        child: Text(
                          period == null
                              ? 'Fecha no disponible'
                              : _formatHistoryMonth(period),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      for (final match in groupedMatches[period]!)
                        _HistoryMatchCard(match: match),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _formatHistoryMonth(DateTime date) {
  const monthNames = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  return '${monthNames[date.month - 1]} ${date.year}';
}

class _HistoryMatchCard extends ConsumerWidget {
  final MatchModel match;

  const _HistoryMatchCard({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(singleServiceProvider(match.serviceId));

    return Card(
      color: const Color(0xFF1E1E1E),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              ),
            ),
            child: Icon(status.icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        serviceTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: status.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.label,
                        style: TextStyle(
                          color: status.color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (rating != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 5),
                      Text(
                        'Calificación: ${rating.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
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
        color: Colors.greenAccent,
        icon: Icons.check_circle,
      );
    case 'cancelled':
      return (
        label: 'Cancelado',
        color: Colors.deepOrangeAccent,
        icon: Icons.cancel,
      );
    case 'rejected':
      return (label: 'Rechazado', color: Colors.redAccent, icon: Icons.block);
    default:
      return (label: status, color: Colors.grey, icon: Icons.history);
  }
}
