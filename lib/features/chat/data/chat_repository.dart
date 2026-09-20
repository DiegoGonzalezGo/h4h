import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'message_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Enviar un mensaje
  Future<void> sendMessage(String matchId, String text) async {
    final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return;

    // Guardamos los mensajes dentro del documento del match específico
    final docRef = _firestore.collection('matches').doc(matchId).collection('messages').doc();

    final newMessage = MessageModel(
      id: docRef.id,
      senderId: user.uid,
      text: text.trim(),
      createdAt: DateTime.now(), // Se sobrescribe en Firebase con serverTimestamp
    );

    await docRef.set(newMessage.toMap());
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository());

// Proveedor que escucha los mensajes de un match específico ordenados por fecha
final chatMessagesProvider = StreamProvider.family<List<MessageModel>, String>((ref, matchId) {
  return FirebaseFirestore.instance
      .collection('matches')
      .doc(matchId)
      .collection('messages')
      .orderBy('createdAt', descending: true) // Los más recientes abajo
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
          .toList());
});