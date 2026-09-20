import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'service_model.dart'; // El modelo que creamos en los primeros pasos

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
    // Esto genera un ID único automáticamente antes de guardar nada
    final docRef = _firestore.collection('services').doc();

    // 2. Construimos el objeto del servicio
    final newService = ServiceModel(
      id: docRef.id,
      providerId: user.uid, // Vinculamos el servicio al usuario actual
      title: title,
      description: description,
      price: price,
      isActive: true,
    );

    // 3. Guardamos los datos en Firestore
    await docRef.set(newService.toMap());
  }
}

// Exponemos el repositorio globalmente
final servicesRepositoryProvider = Provider<ServicesRepository>((ref) => ServicesRepository());
// Este proveedor lee la colección 'services' en tiempo real y la convierte en una lista de ServiceModel
final servicesFeedProvider = StreamProvider<List<ServiceModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('services')
      .where('isActive', isEqualTo: true) // Solo traemos los que estén activos
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => ServiceModel.fromMap(doc.data(), doc.id))
            .toList();
      });
});