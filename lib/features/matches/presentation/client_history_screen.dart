import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/matches_repository.dart';
import '../../services/data/services_repository.dart';

class ClientHistoryScreen extends ConsumerWidget {
  const ClientHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(clientMatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Servicios')),
      body: matchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
        data: (matches) {
          // Filtramos SOLO los que están completados
          final historyMatches = matches.where((m) => m.status == 'completed').toList();

          if (historyMatches.isEmpty) {
            return const Center(child: Text('Aún no tienes servicios finalizados en tu historial.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: historyMatches.length,
            itemBuilder: (context, index) {
              final match = historyMatches[index];
              
              String dateText = 'Fecha desconocida';
              if (match.completedAt != null) {
                final d = match.completedAt!;
                dateText = '${d.day}/${d.month}/${d.year} a las ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
              }

              // Usamos Consumer para escuchar los datos del servicio específico
              return Consumer(
                builder: (context, ref, child) {
                  final serviceAsync = ref.watch(singleServiceProvider(match.serviceId));

                  return serviceAsync.when(
                    loading: () => const Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: ListTile(title: Text('Cargando información del servicio...')),
                    ),
                    error: (e, stack) => const Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: ListTile(title: Text('Error al cargar servicio')),
                    ),
                    data: (service) {
                      // Si el servicio fue borrado por el proveedor, mostramos un texto por defecto
                      final serviceName = service?.title ?? 'Servicio no disponible (Eliminado)';
                      
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.verified, color: Colors.white),
                          ),
                          title: Text(serviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Completado exitosamente', style: TextStyle(color: Colors.green)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(dateText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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