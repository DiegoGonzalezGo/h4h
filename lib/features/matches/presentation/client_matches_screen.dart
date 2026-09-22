import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Importante para poder navegar al chat
import '../data/matches_repository.dart';
import '../../services/data/services_repository.dart';

class ClientMatchesScreen extends ConsumerWidget {
  const ClientMatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchamos el proveedor de solicitudes del cliente
    final matchesAsync = ref.watch(clientMatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Solicitudes Enviadas')),
      body: matchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
        data: (matches) {
          if (matches.isEmpty) {
            return const Center(child: Text('No has solicitado ningún servicio aún.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];

              Color statusColor = Colors.orange;
              String statusText = 'Pendiente';
              IconData statusIcon = Icons.access_time;
              
              if (match.status == 'accepted') {
                statusColor = Colors.green;
                statusText = '¡Solicitud Aceptada!';
                statusIcon = Icons.check_circle;
              } else if (match.status == 'rejected') {
                statusColor = Colors.red;
                statusText = 'Solicitud Rechazada';
                statusIcon = Icons.cancel;
              } else if (match.status == 'completed') {
                statusColor = Colors.blue;
                statusText = 'Servicio Completado';
                statusIcon = Icons.verified;
              }

              // Usamos Consumer para obtener el nombre del servicio en lugar de su ID
              return Consumer(
                builder: (context, ref, child) {
                  final serviceAsync = ref.watch(singleServiceProvider(match.serviceId));

                  return serviceAsync.when(
                    loading: () => const Card(child: ListTile(title: Text('Cargando...'))),
                    error: (e, stack) => const Card(child: ListTile(title: Text('Error'))),
                    data: (service) {
                      final serviceName = service?.title ?? 'Servicio no disponible';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withOpacity(0.2),
                            child: Icon(statusIcon, color: statusColor),
                          ),
                          title: Text(serviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                          ),
                          // ... Aquí va toda tu lógica actual de los botones (trailing) ...
                          trailing: match.status == 'accepted'
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chat_bubble, color: Colors.blue),
                                      tooltip: 'Abrir Chat',
                                      onPressed: () => context.push('/chat/${match.id}'),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.star, color: Colors.amber),
                                      tooltip: 'Finalizar y Calificar',
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => RatingDialog(
                                            onSubmit: (rating) {
                                              ref.read(matchesRepositoryProvider).completeMatchAndRate(
                                                match.id, 
                                                match.providerId, 
                                                rating,
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                )
                              : (match.status == 'rejected' || match.status == 'completed')
                                  ? IconButton(
                                      icon: const Icon(Icons.close, color: Colors.grey),
                                      tooltip: 'Limpiar registro',
                                      onPressed: () {
                                        ref.read(matchesRepositoryProvider).deleteMatch(match.id);
                                      },
                                    )
                                  : null,
                        ),
                      );
                    },
                  );
                }
              );
            },        );
        },
      ),
    );
  }
} 

// Widget personalizado para mostrar las 5 estrellas interactivas
class RatingDialog extends StatefulWidget {
  final Function(double) onSubmit;

  const RatingDialog({super.key, required this.onSubmit});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 5; // Empezamos con 5 estrellas por defecto

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Califica el servicio', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('¿Qué te pareció el trabajo del proveedor?'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 36,
                ),
                onPressed: () {
                  setState(() {
                    _rating = index + 1;
                  });
                },
              );
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        FilledButton(
          onPressed: () {
            widget.onSubmit(_rating.toDouble());
            Navigator.pop(context);
          },
          child: const Text('Enviar Calificación'),
        ),
      ],
    );
  }
}

