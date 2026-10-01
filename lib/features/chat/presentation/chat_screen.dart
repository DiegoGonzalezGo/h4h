import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/chat_repository.dart';
import '../../matches/data/matches_repository.dart';
import '../../services/data/services_repository.dart';
import '../../users/presentation/report_user_menu.dart';

import 'package:go_router/go_router.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String matchId; // Necesitamos saber de qué match es este chat

  const ChatScreen({super.key, required this.matchId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      ref
          .read(chatRepositoryProvider)
          .sendMessage(widget.matchId, _controller.text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos los mensajes de este match en particular
    final messagesAsync = ref.watch(chatMessagesProvider(widget.matchId));

    // ASUMIENDO QUE TIENES ESTAS VARIABLES EN TU BUILD:
    final matchAsync = ref.watch(
      matchDetailsProvider(widget.matchId),
    ); // Reemplaza widget.matchId con tu variable
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
        title: matchAsync.when(
          data: (match) {
            if (match == null || currentUserId == null) {
              return const Text('Chat del Servicio');
            }

            // Determina el ID del otro usuario
            final String otherUserId = match.clientId == currentUserId
                ? match.providerId
                : match.clientId;

            // Muestra el nombre genérico basado en el rol (opcionalmente podrías buscar el nombre real)
            final String otherUserName = match.clientId == currentUserId
                ? 'Proveedor'
                : match.clientName;

            // --- NUEVO: ENVOLVEMOS EL TÍTULO EN UN GestureDetector ---
            return GestureDetector(
              onTap: () {
                context.push('/user/$otherUserId');
              },
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    child: Icon(Icons.person, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(otherUserName, style: const TextStyle(fontSize: 16)),
                ],
              ),
            );
            // ---------------------------------------------------------
          },
          loading: () => const Text('Cargando...'),
          error: (_, _) => const Text('Chat'),
        ),
        actions: matchAsync.when(
          data: (match) {
            if (match == null || currentUserId == null) {
              return const <Widget>[];
            }

            final reportedUserId = match.clientId == currentUserId
                ? match.providerId
                : match.clientId;

            return [ReportUserMenu(reportedUserId: reportedUserId)];
          },
          loading: () => const <Widget>[],
          error: (_, _) => const <Widget>[],
        ),
      ),
      body: Column(
        children: [
          matchAsync.when(
            data: (match) {
              if (match == null) return const SizedBox.shrink();

              return Consumer(
                builder: (context, ref, child) {
                  final serviceAsync = ref.watch(
                    singleServiceProvider(match.serviceId),
                  );

                  return serviceAsync.when(
                    data: (service) => _ServiceContextBanner(
                      serviceName: service?.title ?? 'Servicio no disponible',
                    ),
                    loading: () => const _ServiceContextBanner(
                      serviceName: 'Cargando servicio...',
                    ),
                    error: (error, stack) => const _ServiceContextBanner(
                      serviceName: 'Servicio no disponible',
                    ),
                  );
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
          ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, stack) => Center(child: Text('Error: $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Escribe el primer mensaje...'),
                  );
                }

                return ListView.builder(
                  reverse: true, // Para que los mensajes salgan desde abajo
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe =
                        msg.senderId ==
                        currentUserId; // Verificamos si yo lo envié

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 12,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFF2575FC)
                              : const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isMe ? const Radius.circular(4) : null,
                            bottomLeft: !isMe ? const Radius.circular(4) : null,
                          ),
                        ),
                        child: Text(
                          msg.text,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Barra inferior para escribir
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF121212),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF00B4DB),
                  ),
                  child: IconButton(
                    tooltip: 'Enviar mensaje',
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceContextBanner extends StatelessWidget {
  const _ServiceContextBanner({required this.serviceName});

  final String serviceName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF00B4DB), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Acordando detalles para: $serviceName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
