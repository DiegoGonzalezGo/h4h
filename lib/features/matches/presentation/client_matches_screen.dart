import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Importante para poder navegar al chat

import '../data/matches_repository.dart';
import '../data/match_model.dart';
import '../../services/data/services_repository.dart';

class ClientMatchesScreen extends ConsumerStatefulWidget {
  const ClientMatchesScreen({super.key});

  @override
  ConsumerState<ClientMatchesScreen> createState() =>
      _ClientMatchesScreenState();
}

class _ClientMatchesScreenState extends ConsumerState<ClientMatchesScreen> {
  int selectedTabIndex = 0;

  Widget _tab(String label, int index) {
    final isSelected = selectedTabIndex == index;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => selectedTabIndex = index),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? null : const Color(0xFF1E1E1E),
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos el proveedor de solicitudes del cliente
    final matchesAsync = ref.watch(clientActiveMatchesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
        title: const Text('Mis Solicitudes Enviadas'),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [_tab('En Espera', 0), _tab('Activas', 1)]),
          ),
          Expanded(
            child: matchesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
              data: (matches) {
                if (matches.isEmpty) {
                  return const Center(
                    child: Text('No has solicitado ningún servicio aún.'),
                  );
                }

                final status = selectedTabIndex == 0 ? 'pending' : 'accepted';
                final visibleMatches = matches
                    .where((match) => match.status == status)
                    .toList();

                if (visibleMatches.isEmpty) {
                  return Center(
                    child: Text(
                      selectedTabIndex == 0
                          ? 'No tienes solicitudes en espera.'
                          : 'No tienes solicitudes activas.',
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: visibleMatches.length,
                  itemBuilder: (context, index) {
                    final match = visibleMatches[index];
                    return _ClientRequestCard(
                      match: match,
                      isPending: selectedTabIndex == 0,
                      onCancel: () => _showCancelDialog(context, match, ref),
                      onRate: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => RatingDialog(
                            onSubmit: (rating) {
                              ref
                                  .read(matchesRepositoryProvider)
                                  .completeMatchAndRate(
                                    match.id,
                                    match.providerId,
                                    rating,
                                  );
                            },
                          ),
                        );
                      },
                      onChat: () => context.push('/chat/${match.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientRequestCard extends ConsumerWidget {
  const _ClientRequestCard({
    required this.match,
    required this.isPending,
    required this.onCancel,
    required this.onRate,
    required this.onChat,
  });

  final MatchModel match;
  final bool isPending;
  final VoidCallback onCancel;
  final VoidCallback onRate;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(singleServiceProvider(match.serviceId));

    return serviceAsync.when(
      loading: () => _buildCard(context, 'Cargando servicio...'),
      error: (error, stack) => _buildCard(context, 'Servicio no disponible'),
      data: (service) => _buildCard(
        context,
        service?.title ?? 'Servicio no disponible',
        description: service?.description,
        price: service?.price,
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    String serviceTitle, {
    String? description,
    double? price,
  }) {
    final accent = isPending ? Colors.orangeAccent : Colors.greenAccent;
    final label = isPending ? 'Pendiente' : 'Aceptada';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPending ? Icons.access_time : Icons.check_circle,
                color: accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  serviceTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.grey[800]),
          const SizedBox(height: 14),
          if (description != null && description.isNotEmpty) ...[
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
          ],
          if (price != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Precio del servicio',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF00B4DB),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (isPending)
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Cancelar Solicitud'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(color: Colors.red.shade900),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRate,
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Calificar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber,
                      side: const BorderSide(color: Colors.amber),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _GradientChatButton(onPressed: onChat)),
              ],
            ),
        ],
      ),
    );
  }
}

class _GradientChatButton extends StatelessWidget {
  const _GradientChatButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Abrir Chat'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

Future<void> _showCancelDialog(
  BuildContext context,
  MatchModel match,
  WidgetRef ref,
) async {
  final shouldCancel = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Cancelar solicitud'),
      content: const Text('¿Seguro que quieres cancelar esta solicitud?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('No'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sí, cancelar'),
        ),
      ],
    ),
  );

  if (shouldCancel == true) {
    try {
      await ref
          .read(matchesRepositoryProvider)
          .cancelAndRefundService(
            requestId: match.id,
            clientId: match.clientId,
            amount: match.servicePrice ?? 0,
          );
      ref.invalidate(clientActiveMatchesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Solicitud cancelada.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cancelar la solicitud: $error')),
        );
      }
    }
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
