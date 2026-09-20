import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/services_repository.dart';
import '../../matches/data/matches_repository.dart';

class ServicesFeedScreen extends ConsumerWidget {
  const ServicesFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicios Disponibles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              context.push('/profile');
            },
          )
        ],
      ),
      body: servicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Ocurrió un error: $error')),
        data: (services) {
          if (services.isEmpty) {
            return const Center(
              child: Text('Aún no hay servicios publicados. ¡Sé el primero!'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
           itemBuilder: (context, index) {
              final service = services[index];
              
              // Leemos las solicitudes del usuario actual en tiempo real
              final myMatches = ref.watch(clientMatchesProvider).value ?? [];
              
              // Buscamos si ya pedimos ESTE servicio específico
              final existingMatch = myMatches.where((m) => m.serviceId == service.id).firstOrNull;
              final isRequested = existingMatch != null;

              // Cambiamos el texto dinámicamente según el estado
              String buttonText = 'Solicitar Servicio';
              if (isRequested) {
                if (existingMatch.status == 'pending') buttonText = 'Pendiente';
                else if (existingMatch.status == 'accepted') buttonText = 'Aceptada';
                else if (existingMatch.status == 'rejected') buttonText = 'Rechazada';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- AQUÍ ESTÁ EL CÓDIGO RESTAURADO DEL TÍTULO Y PRECIO ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              service.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '\$${service.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        service.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      // --- FIN DEL CÓDIGO RESTAURADO ---

                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          // Si ya está solicitado, el onPressed se vuelve null (Desactiva el botón)
                          onPressed: isRequested ? null : () async {
                            try {
                              await ref.read(matchesRepositoryProvider).requestService(
                                service.id,
                                service.providerId,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString().replaceAll('Exception: ', '')), 
                                    backgroundColor: Colors.red
                                  ),
                                );
                              }
                            }
                          },
                          child: Text(buttonText),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ); // Cierre de ListView.builder
        }, // Cierre de data
      ), // Cierre de body
    ); // Cierre de Scaffold
  }
}