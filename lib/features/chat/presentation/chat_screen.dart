import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/chat_repository.dart';
import '../../matches/data/matches_repository.dart';
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
      ref.read(chatRepositoryProvider).sendMessage(widget.matchId, _controller.text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos los mensajes de este match en particular
    final messagesAsync = ref.watch(chatMessagesProvider(widget.matchId));

    // ASUMIENDO QUE TIENES ESTAS VARIABLES EN TU BUILD:
    final matchAsync = ref.watch(matchDetailsProvider(widget.matchId)); // Reemplaza widget.matchId con tu variable
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
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
          error: (_, __) => const Text('Chat'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, stack) => Center(child: Text('Error: $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('Escribe el primer mensaje...'));
                }

                return ListView.builder(
                  reverse: true, // Para que los mensajes salgan desde abajo
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUserId; // Verificamos si yo lo envié

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isMe ? const Radius.circular(0) : null,
                            bottomLeft: !isMe ? const Radius.circular(0) : null,
                          ),
                        ),
                        child: Text(msg.text),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Barra inferior para escribir
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}