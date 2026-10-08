import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/data/auth_repository.dart';
import '../data/user_repository.dart';
import '../data/provider_mode.dart';
import 'earnings_statistics_screen.dart';
import 'wallet_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isTogglingMode = false;

  Future<void> _toggleMode(bool newValue) async {
    if (_isTogglingMode || newValue == ref.read(providerModeProvider)) return;

    if (!newValue) {
      ref.read(providerModeProvider.notifier).toggleMode(false);
      return;
    }

    setState(() => _isTogglingMode = true);
    try {
      final user = ref.read(currentUserControllerProvider).value;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo cargar tu perfil.')),
          );
        }
        return;
      }

      if (!user.isProviderSetupComplete) {
        final setupSuccess = await _showProviderSetupModal(context);
        if (setupSuccess != true || !mounted) return;
      }

      ref.read(providerModeProvider.notifier).toggleMode(newValue);
    } finally {
      if (mounted) setState(() => _isTogglingMode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos el estado del proveedor (Modo Cliente o Modo Proveedor)
    final isProviderMode = ref.watch(providerModeProvider);

    // Obtenemos el ID del usuario actual para consultar sus datos
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Usuario no encontrado')));
    }

    // Escuchamos los datos del perfil (Nombre y foto) en tiempo real
    final userProfileAsync = ref.watch(userProfileStreamProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authRepositoryProvider).signOut();
              context.go('/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // --- SECCIÓN DE ENCABEZADO (FOTO, NOMBRE Y BOTÓN DE EDITAR) ---
            userProfileAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, stack) => const Icon(Icons.error),
              data: (userData) {
                final String name = userData['name'] ?? 'Usuario Hand4Hand';
                final String? photoUrl = userData['photoUrl'];

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blue.shade100,
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (userData['bio'] != null &&
                        userData['bio'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 8.0,
                          left: 24,
                          right: 24,
                        ),
                        child: Text(
                          userData['bio'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF2575FC)),
                      ),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar perfil'),
                      onPressed: () {
                        context.push('/edit-profile');
                      },
                    ),
                  ],
                );
              },
            ),
            // --- FIN DEL ENCABEZADO ---

            const SizedBox(height: 24),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isProviderMode ? 'Modo Proveedor' : 'Modo Cliente',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isProviderMode
                                ? 'Activa para ofrecer servicios'
                                : 'Activa para buscar y solicitar servicios',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildAnimatedModeToggle(
                      value: isProviderMode,
                      isLoading: _isTogglingMode,
                      onTap: () => _toggleMode(!isProviderMode),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Renderizamos los menús dependiendo del modo
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: isProviderMode
                  ? _buildProviderView(context)
                  : _buildClientView(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showProviderSetupModal(BuildContext context) async {
    final bioController = TextEditingController();
    final skillsController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    File? selectedImage;

    try {
      final setup = await showDialog<(String, List<String>, File)>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Configura tu perfil profesional'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Cuéntales a tus clientes qué servicios ofreces y cuál '
                      'es tu experiencia.',
                    ),
                    const SizedBox(height: 16),
                    FormField<File>(
                      validator: (_) => selectedImage == null
                          ? 'Selecciona una foto de perfil para continuar.'
                          : null,
                      builder: (field) => Column(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: const Color(0xFF303030),
                            backgroundImage: selectedImage == null
                                ? null
                                : FileImage(selectedImage!),
                            child: selectedImage == null
                                ? const Icon(
                                    Icons.add_a_photo,
                                    color: Colors.white70,
                                    size: 30,
                                  )
                                : null,
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final image = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 70,
                              );
                              if (image == null || !dialogContext.mounted) {
                                return;
                              }

                              selectedImage = File(image.path);
                              field.didChange(selectedImage);
                              setDialogState(() {});
                            },
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(
                              selectedImage == null
                                  ? 'Seleccionar foto de perfil *'
                                  : 'Cambiar foto de perfil',
                            ),
                          ),
                          if (field.errorText != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                field.errorText!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: bioController,
                      decoration: const InputDecoration(
                        labelText: 'Biografía profesional',
                        hintText: 'Describe tu experiencia y servicios',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 3,
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Escribe una breve biografía profesional.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: skillsController,
                      decoration: const InputDecoration(
                        labelText: 'Especialidades',
                        hintText: 'Ej. Plomería, pintura, electricidad',
                        helperText: 'Separa cada especialidad con una coma.',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final skills =
                            value?.split(',').map((skill) => skill.trim()) ??
                            [];
                        if (skills.where((skill) => skill.isNotEmpty).isEmpty) {
                          return 'Agrega al menos una especialidad.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Ahora no'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final image = selectedImage;
                  if (image == null) return;
                  final skills = skillsController.text
                      .split(',')
                      .map((skill) => skill.trim())
                      .where((skill) => skill.isNotEmpty)
                      .toSet()
                      .toList();
                  Navigator.pop(dialogContext, (
                    bioController.text.trim(),
                    skills,
                    image,
                  ));
                },
                child: const Text('Guardar y activar'),
              ),
            ],
          ),
        ),
      );

      if (setup == null) return false;

      await ref
          .read(currentUserControllerProvider.notifier)
          .completeProviderSetup(
            bio: setup.$1,
            skills: setup.$2,
            profilePhoto: setup.$3,
          );

      return true;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar el perfil profesional: $error'),
          ),
        );
      }
      return false;
    } finally {
      bioController.dispose();
      skillsController.dispose();
    }
  }

  Widget _buildAnimatedModeToggle({
    required bool value,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      toggled: value,
      label: 'Modo ${value ? 'Proveedor' : 'Cliente'}',
      hint: 'Toca para cambiar de modo',
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: 142,
          height: 54,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: value ? null : const Color(0xFF353535),
            gradient: value
                ? const LinearGradient(
                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  )
                : null,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: value ? Colors.transparent : Colors.white12,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          value ? Icons.work_outline : Icons.person_outline,
                          color: value
                              ? const Color(0xFF6A11CB)
                              : const Color(0xFF353535),
                        ),
                ),
              ),
              Positioned(
                left: value ? 10 : 54,
                right: value ? 54 : 10,
                child: IgnorePointer(
                  child: Text(
                    value ? 'PROVEEDOR' : 'CLIENTE',
                    textAlign: value ? TextAlign.left : TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brandIcon(IconData icon) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)])
              .createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, color: Colors.white),
    );
  }

  Widget _buildProviderView(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: _brandIcon(Icons.add_circle_outline),
          title: const Text('Publicar nuevo servicio'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            context.push('/create-service');
          },
        ),
        ListTile(
          leading: _brandIcon(Icons.list_alt),
          title: const Text('Mis servicios publicados'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            context.push('/my-services');
          },
        ),
        ListTile(
          leading: _brandIcon(Icons.notifications_active),
          title: const Text('Solicitudes entrantes'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            context.push('/provider-matches');
          },
        ),
        ListTile(
          leading: _brandIcon(Icons.bar_chart),
          title: const Text('Mis Ganancias / Estadísticas'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const EarningsStatisticsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildClientView(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: _brandIcon(Icons.handshake),
          title: const Text('Mis solicitudes enviadas'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            context.push('/client-matches');
          },
        ),
        ListTile(
          leading: _brandIcon(Icons.bookmark_border),
          title: const Text('Servicios Guardados'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            context.push('/saved-services');
          },
        ),
        ListTile(
          leading: _brandIcon(Icons.location_on_outlined),
          title: const Text('Mis Direcciones'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            context.push('/my-addresses');
          },
        ),
        ListTile(
          leading: _brandIcon(Icons.credit_card),
          title: const Text('Billetera y Pagos'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const WalletScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}
