import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services_repository.dart';

class MyServicesScreen extends ConsumerWidget {
  const MyServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchamos los servicios del proveedor logueado
    final myServicesAsync = ref.watch(myServicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Servicios Publicados')),
      body: myServicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
        data: (services) {
          if (services.isEmpty) {
            return const Center(
              child: Text('Aún no has publicado ningún servicio.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text(
                      service.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        // Si está inactivo, lo tachamos ligeramente para dar efecto visual
                        decoration: service.isActive ? null : TextDecoration.lineThrough,
                        color: service.isActive ? Colors.black : Colors.grey,
                      ),
                    ),
                    subtitle: Text('\$${service.price.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Interruptor para encender/apagar el servicio
                        Switch(
                          value: service.isActive,
                          activeColor: Colors.green,
                          onChanged: (newValue) {
                            ref.read(servicesRepositoryProvider).toggleServiceStatus(service.id, service.isActive);
                          },
                        ),
                        // Botón de eliminar
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            // Cuadro de diálogo para confirmar antes de borrar
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Eliminar servicio'),
                                content: const Text('¿Estás seguro de que deseas borrar este servicio de forma permanente?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      ref.read(servicesRepositoryProvider).deleteService(service.id);
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
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