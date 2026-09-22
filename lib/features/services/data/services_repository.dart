import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'service_model.dart'; 
import '../../auth/data/auth_repository.dart';

class ServicesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Recibe la categoría como nuevo parámetro
  Future<void> createService(String title, String description, double price, String category) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final newService = ServiceModel(
      id: '',
      providerId: user.uid,
      title: title.trim(),
      description: description.trim(),
      price: price,
      category: category, // <-- Guarda la categoría
    );

    await _firestore.collection('services').add(newService.toMap());
  }
  // Cambia el estado de activo/inactivo
  Future<void> toggleServiceStatus(String serviceId, bool currentStatus) async {
    await _firestore.collection('services').doc(serviceId).update({
      'isActive': !currentStatus, // Invierte el estado actual
    });
  }

  // Elimina un servicio de la base de datos
  Future<void> deleteService(String serviceId) async {
    await _firestore.collection('services').doc(serviceId).delete();
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
// Este proveedor lee SOLO los servicios creados por el usuario actual (Proveedor)
final myServicesProvider = StreamProvider<List<ServiceModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('services')
      .where('providerId', isEqualTo: user.uid)
      // Nota: Aquí no filtramos por 'isActive' porque el dueño necesita ver TODOS sus servicios
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => ServiceModel.fromMap(doc.data(), doc.id))
            .toList();
      });
});

// Proveedor para consultar los datos públicos del perfil de un proveedor (como sus estrellas)
final providerProfileProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, providerId) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(providerId).get();
  return doc.data() ?? {};
});

// Proveedor actualizado que descarga los servicios y oculta los del propio usuario
final activeServicesProvider = StreamProvider<List<ServiceModel>>((ref) {
  // 1. Revisamos quién es el usuario actual
  final user = ref.watch(authStateProvider).value;

  // 2. Traemos los servicios desde Firestore
  return FirebaseFirestore.instance
      .collection('services')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        final services = snapshot.docs
            .map((doc) => ServiceModel.fromMap(doc.data(), doc.id))
            .toList();
        
        // 3. Si no hay usuario logueado, regresamos todo.
        // Si sí lo hay, quitamos de la lista los servicios que le pertenecen.
        if (user == null) return services;
        return services.where((s) => s.providerId != user.uid).toList();
      });
});

// Proveedor para consultar los datos de un solo servicio usando su ID
final singleServiceProvider = FutureProvider.family<ServiceModel?, String>((ref, serviceId) async {
  final doc = await FirebaseFirestore.instance.collection('services').doc(serviceId).get();
  if (doc.exists) {
    return ServiceModel.fromMap(doc.data()!, doc.id);
  }
  return null; // Si el proveedor borró el servicio, regresamos null
});

// Proveedor que trae a los 10 mejores proveedores ordenados por calificación
final topProvidersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .orderBy('averageRating', descending: true) // Los de mayor calificación primero
      .limit(10) // Solo traemos el Top 10 para no saturar la base de datos
      .get();

  // Mapeamos los datos y filtramos localmente para asegurar que tengan al menos 1 reseña
  final allTop = snapshot.docs.map((doc) {
    final data = doc.data();
    data['id'] = doc.id; // Guardamos el ID del documento por si se necesita
    return data;
  }).toList();

  return allTop.where((user) => (user['totalReviews'] ?? 0) > 0).toList();
});