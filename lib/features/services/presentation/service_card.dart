import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../chat/presentation/chat_screen.dart';
import '../../matches/data/matches_repository.dart';
import '../../users/data/user_repository.dart';
import '../data/service_model.dart';
import '../data/services_repository.dart';

class ServiceCard extends ConsumerWidget {
  const ServiceCard({
    required this.service,
    this.onTap,
    this.onRequest,
    super.key,
  });

  final ServiceModel service;
  final VoidCallback? onTap;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedServices =
        ref.watch(currentUserControllerProvider).value?.savedServices ??
        const <String>[];
    final isSaved = savedServices.contains(service.id);
    final requestStatusAsync = ref.watch(requestStatusProvider(service.id));
    final request = requestStatusAsync.value;
    final providerProfileAsync = ref.watch(
      providerProfileProvider(service.providerId),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 80,
                child: InkWell(
                  onTap: () => context.push('/user/${service.providerId}'),
                  borderRadius: BorderRadius.circular(12),
                  child: providerProfileAsync.when(
                    data: (data) {
                      final providerName =
                          data['name']?.toString() ?? 'Proveedor';
                      final photoUrl = data['photoUrl']?.toString();
                      final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: const Color(0xFF303030),
                            backgroundImage: hasPhoto
                                ? NetworkImage(photoUrl)
                                : null,
                            child: hasPhoto
                                ? null
                                : const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            providerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 80),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF121212),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              service.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const _ProviderPlaceholder(label: 'Cargando...'),
                    error: (error, stack) =>
                        const _ProviderPlaceholder(label: 'Proveedor'),
                  ),
                ),
              ),
              VerticalDivider(width: 20, thickness: 1, color: Colors.grey[800]),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            service.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: isSaved
                              ? 'Quitar de guardados'
                              : 'Guardar servicio',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 40,
                          ),
                          icon: Icon(
                            isSaved ? Icons.favorite : Icons.favorite_border,
                            color: isSaved ? Colors.cyanAccent : Colors.white60,
                          ),
                          onPressed: () async {
                            try {
                              await ref
                                  .read(currentUserControllerProvider.notifier)
                                  .toggleSavedService(service.id);
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No se pudo actualizar guardados: $error',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      service.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${service.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (requestStatusAsync.isLoading && request == null)
                          const _RequestStatusBadge(label: 'Comprobando...')
                        else if (request?.status == 'pending')
                          _PendingRequestButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (context) => ChatScreen(
                                    matchId: request!.id,
                                  ),
                                ),
                              );
                            },
                          )
                        else if (request?.status == 'accepted')
                          _GradientRequestButton(
                            label: 'Abrir Chat',
                            onPressed: () =>
                                context.push('/chat/${request!.id}'),
                          )
                        else if (request?.status == 'rejected')
                          const _RequestStatusBadge(label: 'Rechazada')
                        else if (request?.status == 'completed')
                          const _RequestStatusBadge(label: 'Completada')
                        else
                          _GradientRequestButton(
                            label: 'Solicitar',
                            onPressed: onRequest ?? onTap,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientRequestButton extends StatelessWidget {
  const _GradientRequestButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _RequestStatusBadge extends StatelessWidget {
  const _RequestStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PendingRequestButton extends StatelessWidget {
  const _PendingRequestButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4A3B2A),
        foregroundColor: const Color(0xFFFFD180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: const Text(
        'Chat (Pendiente)',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ProviderPlaceholder extends StatelessWidget {
  const _ProviderPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 30,
          backgroundColor: Color(0xFF303030),
          child: Icon(Icons.person, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }
}
