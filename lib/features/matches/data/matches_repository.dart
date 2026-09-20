import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'match_model.dart';
import '../../auth/data/auth_repository.dart';

class MatchesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Actualiza el estado del match en Firebase
  Future<void> updateMatchStatus(String matchId, String newStatus) async {
    await _firestore.collection('matches').doc(matchId).update({'status': newStatus});
  }

  // Crea una nueva solicitud de servicio
Future<void> requestService(String serviceId, String providerId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Debes iniciar sesión para solicitar un servicio');

    if (user.uid == providerId) throw Exception('No puedes solicitar tu propio servicio');

    // SOLUCIÓN #4: Validar en Firebase si ya existe un match de este usuario para este servicio
    final existingMatch = await _firestore
        .collection('matches')
        .where('clientId', isEqualTo: user.uid)
        .where('serviceId', isEqualTo: serviceId)
        .get();

    if (existingMatch.docs.isNotEmpty) {
      throw Exception('Ya has solicitado este servicio previamente.');
    }

    // SOLUCIÓN #3: Obtener el nombre del cliente desde su perfil
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final clientName = userDoc.data()?['name'] ?? 'Usuario Desconocido';

    final docRef = _firestore.collection('matches').doc();

    final newMatch = MatchModel(
      id: docRef.id,
      serviceId: serviceId,
      clientId: user.uid,
      clientName: clientName, // Guardamos el nombre en el Match
      providerId: providerId,
    );

    await docRef.set(newMatch.toMap());
  }
} // <--- Aquí cierra correctamente la clase MatchesRepository

// Exponemos el repositorio para usarlo en la UI
final matchesRepositoryProvider = Provider<MatchesRepository>((ref) => MatchesRepository());

// Este proveedor escucha en tiempo real las solicitudes donde YO soy el proveedor
final providerMatchesProvider = StreamProvider<List<MatchModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) return const Stream.empty(); 

  return FirebaseFirestore.instance
      .collection('matches')
      .where('providerId', isEqualTo: user.uid)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => MatchModel.fromMap(doc.data(), doc.id))
          .toList());
});

// Este proveedor escucha en tiempo real las solicitudes donde YO soy el cliente
final clientMatchesProvider = StreamProvider<List<MatchModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('matches')
      .where('clientId', isEqualTo: user.uid)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => MatchModel.fromMap(doc.data(), doc.id))
          .toList());
});