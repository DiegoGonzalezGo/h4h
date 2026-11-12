import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final _imagePicker = ImagePicker();
  bool _isUploading = false;

  Future<String?> _requestDescription() async {
    final controller = TextEditingController();
    final description = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text(
          'Describe esta evidencia',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Título o descripción',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return description;
  }

  Future<void> _uploadEvidence() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Inicia sesión para subir evidencias.');
      return;
    }

    setState(() => _isUploading = true);
    try {
      final portfolio = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('portafolio')
          .get();
      if (portfolio.docs.length >= 10) {
        _showMessage('Límite alcanzado: Máximo 10 evidencias permitidas');
        return;
      }

      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      final description = await _requestDescription();
      if (description == null || !mounted) return;

      final extension = image.name.contains('.')
          ? image.name.split('.').last
          : 'jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('portfolio_images/${user.uid}')
          .child('${DateTime.now().microsecondsSinceEpoch}.$extension');
      final uploadTask = await storageRef.putFile(File(image.path));
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('portafolio')
          .add({
            'imageUrl': downloadUrl,
            'description': description,
            'createdAt': Timestamp.now(),
          });

      if (mounted) _showMessage('Evidencia subida correctamente.');
    } catch (error) {
      if (mounted) _showMessage('No se pudo subir la evidencia: $error');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _confirmAndDeleteEvidence(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text(
          'Eliminar evidencia',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Estás seguro de eliminar esta evidencia?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final data = document.data();
      final downloadURL =
          data['downloadURL'] as String? ?? data['imageUrl'] as String?;
      if (downloadURL == null || downloadURL.isEmpty) {
        throw StateError('La evidencia no contiene una URL de descarga.');
      }

      await FirebaseStorage.instance.refFromURL(downloadURL).delete();
      await document.reference.delete();
      if (mounted) _showMessage('Evidencia eliminada correctamente.');
    } catch (error) {
      if (mounted) _showMessage('No se pudo eliminar la evidencia: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: message.startsWith('Límite alcanzado:')
              ? Colors.redAccent
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Mi Portafolio'),
        backgroundColor: const Color(0xFF121212),
      ),
      body: user == null
          ? const Center(
              child: Text(
                'Inicia sesión para ver tu portafolio.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('portafolio')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'No se pudo cargar el portafolio.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final documents = snapshot.data!.docs;
                if (documents.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_off_outlined,
                            size: 72,
                            color: Colors.white38,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Aún no tienes evidencias. Sube fotos de tus trabajos o certificados para generar confianza.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final document = documents[index];
                    final data = documents[index].data();
                    final imageUrl = data['imageUrl'] as String? ?? '';
                    final description = data['description'] as String? ?? '';

                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: imageUrl.isEmpty
                                    ? const Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white38,
                                        size: 48,
                                      )
                                    : Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Center(
                                                  child: Icon(
                                                    Icons.broken_image_outlined,
                                                    color: Colors.white38,
                                                    size: 48,
                                                  ),
                                                ),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  description.isEmpty
                                      ? 'Sin descripción'
                                      : description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            tooltip: 'Eliminar evidencia',
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.redAccent,
                            ),
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () =>
                                _confirmAndDeleteEvidence(document),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _uploadEvidence,
        icon: _isUploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.upload_rounded),
        label: Text(_isUploading ? 'Subiendo...' : 'Subir evidencia'),
      ),
    );
  }
}
