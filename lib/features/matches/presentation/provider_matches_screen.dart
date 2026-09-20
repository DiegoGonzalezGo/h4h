import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/matches_repository.dart';

class ProviderMatchesScreen extends ConsumerWidget {
  const ProviderMatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchamos la lista de solicitudes en tiempo real
    final matchesAsync = ref.watch(providerMatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes Recibidas')),
      body: matchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
        data: (matches) {
          if (matches.isEmpty) {
            return const Center(child: Text('No tienes solicitudes por el momento.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              
              // Cambiamos colores y textos dependiendo del estado del Match
              Color statusColor = Colors.orange;
              String statusText = 'Pendiente';
              
              if (match.status == 'accepted') {
                statusColor = Colors.green;
                statusText = 'Aceptada';
              } else if (match.status == 'rejected') {
                statusColor = Colors.red;
                statusText = 'Rechazada';
              }

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.handshake)),
                  // Como no tenemos el nombre del cliente en esta colección, mostramos una parte de su ID como referencia
                 // SOLUCIÓN #3: Mostramos el nombre real del cliente
                  title: Text('Cliente: ${match.clientName}'),
                  subtitle: Text(
                    'Estado: $statusText',
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                  // Solo mostramos los botones si la solicitud sigue pendiente
                  trailing: match.status == 'pending'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              tooltip: 'Aceptar',
                              onPressed: () {
                                ref.read(matchesRepositoryProvider).updateMatchStatus(match.id, 'accepted');
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              tooltip: 'Rechazar',
                              onPressed: () {
                                ref.read(matchesRepositoryProvider).updateMatchStatus(match.id, 'rejected');
                              },
                            ),
                          ],
                        )
                      : null, // Si ya se aceptó/rechazó, ocultamos los botones
                ),
              );
            },
          );
        },
      ),
    );
  }
}