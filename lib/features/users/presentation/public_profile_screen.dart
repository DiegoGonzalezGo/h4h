import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/user_repository.dart';

class PublicProfileScreen extends ConsumerWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reutilizamos el mismo proveedor que trae los datos en tiempo real
    final userAsync = ref.watch(userProfileStreamProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil del Usuario')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
        data: (userData) {
          final String name = userData['name'] ?? 'Usuario';
          final String? photoUrl = userData['photoUrl'];
          final String bio = userData['bio'] ?? 'Sin biografía.';
          final double rating = (userData['averageRating'] ?? 0.0).toDouble();
          final int reviews = userData['totalReviews'] ?? 0;

          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              Center(
                child: GestureDetector(
                  onTap: () {
                    // Verificamos si la URL de la foto existe y no está vacía
                    if (photoUrl != null && photoUrl.isNotEmpty) {
                      // Si tiene foto, abrimos el diálogo para verla en grande
                      _showZoomedImage(context, photoUrl, name);
                    } else {
                      // Si NO tiene foto, mostramos un mensaje flotante (SnackBar)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$name no ha subido una foto de perfil.'),
                          backgroundColor: Colors.blueGrey,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                    child: (photoUrl == null || photoUrl.isEmpty) 
                        ? const Icon(Icons.person, size: 60, color: Colors.white) 
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 28),
                  const SizedBox(width: 4),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    ' ($reviews reseñas)',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Sobre mí',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                bio,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ],
          );
        },
      ),
    );
  }
}
// Función para mostrar la foto en tamaño grande estilo visor
  void _showZoomedImage(BuildContext context, String imageUrl, String userName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Contenedor principal con la imagen ampliada
              InteractiveViewer( // Permite hacer zoom con los dedos (pellizcar)
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(child: Text('No se pudo cargar la imagen', style: TextStyle(color: Colors.white)));
                    },
                  ),
                ),
              ),
              // Botón flotante para cerrar arriba a la derecha
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ),
              // Título con el nombre en la parte inferior
              Positioned(
                bottom: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    userName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }