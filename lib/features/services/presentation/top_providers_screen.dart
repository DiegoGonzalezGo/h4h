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
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
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
              final double rating = (provider['averageRating'] ?? 0.0).toDouble();
              final int reviews = provider['totalReviews'] ?? 0;
              final String name = provider['name'] ?? 'Usuario Anónimo'; // O el campo que uses para el nombre
              
              // Lógica visual para los 3 primeros lugares
              Color medalColor = Colors.blueGrey.shade100;
              IconData medalIcon = Icons.military_tech;
              
              if (index == 0) {
                medalColor = Colors.amber; // Oro
                medalIcon = Icons.emoji_events;
              } else if (index == 1) {
                medalColor = Colors.grey.shade400; // Plata
              } else if (index == 2) {
                medalColor = Colors.orange.shade300; // Bronce
              }

              return Card(
                elevation: index < 3 ? 4 : 1, // Más sombra a los primeros lugares
                margin: const EdgeInsets.only(bottom: 12),
                
                child: ListTile(
                  onTap: () {
                    // Usamos provider['id'] porque así lo guardamos en el repositorio del Top 10
                    context.push('/user/${provider['id']}');
                  },
                  leading: CircleAvatar(
                    backgroundColor: medalColor,
                    child: index == 0 
                        ? Icon(medalIcon, color: Colors.white)
                        : Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$reviews trabajos completados'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 24),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      
                    ],
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