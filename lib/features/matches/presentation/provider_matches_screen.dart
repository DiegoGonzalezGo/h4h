import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Importante para la navegación al chat

import '../../chat/presentation/chat_screen.dart';
import '../data/matches_repository.dart';
import '../data/match_model.dart';
import '../../services/data/services_repository.dart';
import '../../users/data/user_repository.dart';

class ProviderMatchesScreen extends ConsumerStatefulWidget {
  const ProviderMatchesScreen({super.key});

  @override
  ConsumerState<ProviderMatchesScreen> createState() =>
      _ProviderMatchesScreenState();
}

class _ProviderMatchesScreenState extends ConsumerState<ProviderMatchesScreen> {
  int selectedTabIndex = 0;

  Widget _tabButton(String label, int index) {
    final isSelected = selectedTabIndex == index;

    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: index == 0 ? 8 : 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => selectedTabIndex = index),
          child: Container(
            height: 46,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos la lista de solicitudes en tiempo real
    final matchesAsync = ref.watch(providerActiveMatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes Recibidas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _tabButton('Por Responder', 0),
                _tabButton('Aceptadas', 1),
              ],
            ),
          ),
          Expanded(
            child: matchesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
              data: (matches) {
                final selectedStatus = selectedTabIndex == 0
                    ? 'pending'
                    : 'accepted';
                final visibleMatches = matches
                    .where((match) => match.status == selectedStatus)
                    .toList();

                if (visibleMatches.isEmpty) {
                  return Center(
                    child: Text(
                      selectedTabIndex == 0
                          ? 'No tienes solicitudes por responder.'
                          : 'No tienes solicitudes aceptadas.',
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: visibleMatches.length,
                  itemBuilder: (context, index) {
                    final match = visibleMatches[index];
                    return _ProviderRequestCard(
                      match: match,
                      isPending: selectedTabIndex == 0,
                      onAccept: () {
                        ref
                            .read(matchesRepositoryProvider)
                            .updateMatchStatus(match.id, 'accepted');
                      },
                      onReject: () async {
                        try {
                          await ref
                              .read(matchesRepositoryProvider)
                              .cancelAndRefundService(
                                requestId: match.id,
                                clientId: match.clientId,
                                amount: match.servicePrice ?? 0,
                                providerRejected: true,
                              );
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'No se pudo rechazar la solicitud: $error',
                                ),
                              ),
                            );
                          }
                        }
                      },
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

class _ProviderRequestCard extends ConsumerWidget {
  const _ProviderRequestCard({
    required this.match,
    required this.isPending,
    required this.onAccept,
    required this.onReject,
  });

  final MatchModel match;
  final bool isPending;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileStreamProvider(match.clientId)).value;
    final serviceAsync = ref.watch(singleServiceProvider(match.serviceId));
    final clientName = profile?['name']?.toString() ?? match.clientName;
    final photoUrl = profile?['photoUrl']?.toString();
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return serviceAsync.when(
      loading: () => _buildCard(
        context,
        clientName: clientName,
        photoUrl: hasPhoto ? photoUrl : null,
        serviceTitle: 'Cargando servicio...',
      ),
      error: (error, stack) => _buildCard(
        context,
        clientName: clientName,
        photoUrl: hasPhoto ? photoUrl : null,
        serviceTitle: 'Servicio no disponible',
      ),
      data: (service) => _buildCard(
        context,
        clientName: clientName,
        photoUrl: hasPhoto ? photoUrl : null,
        serviceTitle: service?.title ?? 'Servicio no disponible',
        price: service?.price,
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String clientName,
    required String? photoUrl,
    required String serviceTitle,
    double? price,
  }) {
    final avatar = CircleAvatar(
      backgroundColor: const Color(0xFF303030),
      backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
      child: photoUrl == null
          ? const Icon(Icons.person, color: Colors.white70)
          : null,
    );

    if (!isPending) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: avatar,
          title: Text(
            clientName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            serviceTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70),
          ),
          trailing: IconButton(
            tooltip: 'Abrir chat',
            icon: const Icon(Icons.chat_bubble, color: Color(0xFF00B4DB)),
            onPressed: () => context.push('/chat/${match.id}'),
          ),
        ),
      );
    }

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
              avatar,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
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
                  color: Colors.orange.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Pendiente',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(serviceTitle, style: const TextStyle(color: Colors.white70)),
          if (price != null) ...[
            const SizedBox(height: 4),
            Text(
              '\$${price.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFF00B4DB),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _GradientActionButton(
                  label: 'Aceptar',
                  onPressed: onAccept,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: onReject,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.2),
                      foregroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Rechazar'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => ChatScreen(matchId: match.id),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Abrir Chat'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.cyanAccent,
                side: const BorderSide(color: Colors.cyanAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
