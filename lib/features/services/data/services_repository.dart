import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'service_model.dart'; 
import '../../auth/data/auth_repository.dart';

class ServicesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createService({
    required String title,
    required String description,
    required double price,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Debes iniciar sesión para publicar');

    // 1. Creamos una referencia a un nuevo documento vacío en 'services'
    final docRef = _firestore.collection('services').doc();

    // 2. Construimos el objeto del servicio
    final newService = ServiceModel(
      id: docRef.id,
      providerId: user.uid, 
      title: title,
      description: description,
      price: price,
      isActive: true,
    );

    // 3. Guardamos los datos en Firestore
    await docRef.set(newService.toMap());
  }
} // <-- Fin de la clase

// ¡ESTA ES LA LÍNEA QUE FALTABA! Exponemos el repositorio para que la interfaz lo pueda usar
final servicesRepositoryProvider = Provider<ServicesRepository>((ref) => ServicesRepository());

final servicesFeedProvider = StreamProvider<List<ServiceModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('services')
      .where('isActive', isEqualTo: true)
      .where('providerId', isNotEqualTo: user.uid) // Excluye mis servicios
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => ServiceModel.fromMap(doc.data(), doc.id))
            .toList();
      });
});