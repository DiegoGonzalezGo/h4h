import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Agregamos Firestore
import '../data/user_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  File? _selectedImage;
  String? _existingPhotoUrl; // Variable para guardar la URL de la foto que ya tiene en la base de datos
  bool _isLoading = false;
  final _userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadExistingProfileData(); // Cargamos los datos al abrir la pantalla
  }

  // Función para descargar los datos actuales y ponerlos en las cajas de texto
  Future<void> _loadExistingProfileData() async {
    if (_userId == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_userId).get();
      
      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          // Asignamos los valores a los controladores (ajusta 'realName' o 'name' según como lo guardes)
          _nameController.text = data['realName'] ?? data['name'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _existingPhotoUrl = data['photoUrl'];
        });
      }
    } catch (e) {
      debugPrint('Error al cargar perfil existente: $e');
    }
  }

  // Abre la galería y guarda el archivo temporalmente
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // Envía los datos al repositorio
  Future<void> _saveProfile() async {
    if (_userId == null || _nameController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(userRepositoryProvider).updateProfile(
        _userId!, 
        _nameController.text, 
        _bioController.text,
        _selectedImage,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado con éxito'), backgroundColor: Colors.green),
        );
        context.pop(); // Regresamos a la pantalla anterior
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.blue.shade50,
                // Lógica de imagen: Si hay una nueva seleccionada, la muestra. Si no, muestra la de la base de datos si existe.
                backgroundImage: _selectedImage != null 
                    ? FileImage(_selectedImage!) 
                    : (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty 
                        ? NetworkImage(_existingPhotoUrl!) as ImageProvider 
                        : null),
                child: _selectedImage == null && (_existingPhotoUrl == null || _existingPhotoUrl!.isEmpty)
                    ? const Icon(Icons.add_a_photo, size: 40, color: Colors.blue)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _pickImage, 
              child: const Text('Seleccionar Foto'),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre Completo',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Biografía (Cuéntanos sobre ti, experiencia...)',
                prefixIcon: Icon(Icons.info_outline),
                border: OutlineInputBorder(),
              ),
              maxLines: 3, 
            ),
            const SizedBox(height: 40),
            _isLoading 
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saveProfile,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text('Guardar Cambios', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  )
          ],
        ),
      ),
    );
  }
}