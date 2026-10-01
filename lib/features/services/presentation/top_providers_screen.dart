import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/services_repository.dart';

class TopProvidersScreen extends ConsumerWidget {
  const TopProvidersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topProvidersAsync = ref.watch(topProvidersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Proveedores'),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: topProvidersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
        data: (providers) {
          if (providers.isEmpty) {
            return const Center(
              child: Text('Aún no hay proveedores con calificaciones.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final provider = providers[index];
              final double rating = (provider['averageRating'] ?? 0.0)
                  .toDouble();
              final int reviews = provider['totalReviews'] ?? 0;
              final String name = provider['name'] ?? 'Usuario Anónimo';
              final String specialty =
                  (provider['specialty'] ??
                          provider['category'] ??
                          'Proveedor de servicios')
                      .toString();
              final String? photoUrl = provider['photoUrl'] as String?;
              final isTopThree = index < 3;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(isTopThree ? 1 : 0),
                decoration: BoxDecoration(
                  color: isTopThree ? null : const Color(0xFF1E1E1E),
                  gradient: isTopThree
                      ? const LinearGradient(
                          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Material(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () {
                      context.push('/user/${provider['id']}');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFF303030),
                                backgroundImage:
                                    photoUrl == null || photoUrl.isEmpty
                                    ? null
                                    : NetworkImage(photoUrl),
                                child: photoUrl == null || photoUrl.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.white70,
                                        size: 28,
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: -5,
                                bottom: -4,
                                child: Container(
                                  width: 23,
                                  height: 23,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isTopThree
                                        ? const Color(0xFF121212)
                                        : const Color(0xFF383838),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isTopThree
                                          ? const Color(0xFF2575FC)
                                          : const Color(0xFF1E1E1E),
                                    ),
                                  ),
                                  child: Text(
                                    '#${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  specialty,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.work_outline,
                                          size: 14,
                                          color: Colors.white54,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$reviews trabajos',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          size: 15,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          rating.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white60,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
