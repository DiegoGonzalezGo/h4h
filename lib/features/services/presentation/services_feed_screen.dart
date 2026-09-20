import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/services_repository.dart';

// Cambiamos a ConsumerWidget para poder leer los datos en tiempo real
class ServicesFeedScreen extends ConsumerWidget {
  const ServicesFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchamos el stream de servicios
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
      // Usamos .when para manejar los 3 estados: Cargando, Error y Datos listos
      body: servicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Ocurrió un error: $error')),
        data: (services) {
          // Si la lista está vacía
          if (services.isEmpty) {
            return const Center(
              child: Text('Aún no hay servicios publicados. ¡Sé el primero!'),
            );
          }

          // Si hay datos, mostramos una lista de tarjetas
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: () {
                            // Aquí irá la lógica para solicitar el servicio (Match)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Solicitando "${service.title}"...')),
                            );
                          },
                          child: const Text('Solicitar Servicio'),
                        ),
                      )
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