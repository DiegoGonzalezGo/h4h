import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/ad_mob_service.dart';
import '../../../core/widgets/glassmorphism.dart';
import '../../../core/widgets/cached_app_image.dart';
import '../../auth/data/auth_repository.dart';
import '../data/user_repository.dart';
import '../data/provider_mode.dart';
import '../data/subscription_repository.dart';
import 'earnings_statistics_screen.dart';
import 'portfolio_screen.dart';
import 'subscription_plans_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isTogglingMode = false;

  Future<void> _toggleMode(bool newValue) async {
    if (_isTogglingMode || newValue == ref.read(providerModeProvider)) return;

    setState(() => _isTogglingMode = true);
    var waitingForAd = false;
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

      final subscriptionExpired = await SubscriptionRepository()
          .checkSubscriptionStatus(userId: user.uid);
      if (!mounted) return;
      if (subscriptionExpired) {
        ref.read(providerModeProvider.notifier).setMode(false);
      }

      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      if (!userSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró tu perfil.')),
        );
        return;
      }

      final userData = userSnapshot.data()!;
      final plan = userData['plan']?.toString().toLowerCase();
      final hasProviderPlan =
          plan == 'pro' ||
          plan == 'elite' ||
          userData['isPro'] == true ||
          userData['isElite'] == true ||
          userData['isPremium'] == true;
      if (newValue && !hasProviderPlan) {
        final shouldViewPlans = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Plan requerido'),
            content: const Text(
              'El Modo Proveedor requiere el Plan Pro o Élite',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Ahora no'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Ver Planes'),
              ),
            ],
          ),
        );
        if (shouldViewPlans == true && mounted) {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (context) => const SubscriptionPlansScreen(),
            ),
          );
        }
        return;
      }

      if (newValue && !_hasProfessionalProfile(userData)) {
        final setupSuccess = await _showProviderSetupModal(context, userData);
        if (setupSuccess != true || !mounted) return;
      }

      void applyModeChange() {
        unawaited(_completeModeChange(user.uid, newValue));
      }

      if (AdMobService.shouldShowAds(userData)) {
        waitingForAd = true;
        AdMobService.instance.showInterstitialAd(applyModeChange);
      } else {
        applyModeChange();
      }
    } catch (error, stackTrace) {
      debugPrint('No se pudo validar el plan antes de cambiar de modo: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo validar tu plan. Inténtalo nuevamente.'),
          ),
        );
      }
    } finally {
      if (!waitingForAd && mounted) {
        setState(() => _isTogglingMode = false);
      }
    }
  }

  bool _hasProfessionalProfile(Map<String, dynamic> userData) {
    if (userData['hasCompletedProviderProfile'] == true ||
        userData['isProviderSetupComplete'] == true) {
      return true;
    }

    final bio = userData['bio']?.toString().trim() ?? '';
    final rawSpecialties = userData['specialties'] ?? userData['skills'];
    final specialties = rawSpecialties is Iterable
        ? rawSpecialties
              .map((specialty) => specialty.toString().trim())
              .where((specialty) => specialty.isNotEmpty)
        : (rawSpecialties is String && rawSpecialties.trim().isNotEmpty)
        ? [rawSpecialties.trim()]
        : const <String>[];
    return bio.isNotEmpty && specialties.isNotEmpty;
  }

  Future<void> _completeModeChange(String userId, bool newValue) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isProviderMode': newValue,
      });
      if (!mounted) return;
      ref.read(providerModeProvider.notifier).toggleMode(newValue);
    } catch (error, stackTrace) {
      debugPrint('No se pudo guardar el modo del usuario: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo actualizar el modo de tu cuenta.'),
          ),
        );
      }
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
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Usuario no encontrado',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    // Escuchamos los datos del perfil (Nombre y foto) en tiempo real
    final userProfileAsync = ref.watch(userProfileStreamProvider(userId));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go('/login');
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudo cerrar sesión: $error')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: GlowBackground(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),

              // --- SECCIÓN DE ENCABEZADO (FOTO, NOMBRE Y BOTÓN DE EDITAR) ---
              GlassCard(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                child: userProfileAsync.when(
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
                          child: CachedAppAvatar(
                            imageUrl: photoUrl,
                            radius: 50,
                            backgroundColor: Colors.blue.shade100,
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
                                color: Colors.white70,
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
              ),
              // --- FIN DEL ENCABEZADO ---

              const SizedBox(height: 24),

              GlassCard(
                margin: const EdgeInsets.symmetric(horizontal: 16),
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

              const SizedBox(height: 20),

              // Renderizamos los menús dependiendo del modo
              GlassCard(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.zero,
                child: isProviderMode
                    ? _buildProviderView(context)
                    : _buildClientView(context),
              ),
              const SizedBox(height: 12),
              GlassCard(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: _brandIcon(Icons.workspace_premium),
                      title: const Text('Planes SkillMatch'),
                      subtitle: const Text(
                        'Gratis, Pro y Élite',
                        style: TextStyle(color: Colors.white60),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (context) =>
                                const SubscriptionPlansScreen(),
                          ),
                        );
                      },
                    ),
                    userProfileAsync.maybeWhen(
                      data: (userData) {
                        final isElite =
                            userData['isElite'] == true ||
                            userData['isPremium'] == true ||
                            userData['plan'] == 'elite';
                        if (!isElite) return const SizedBox.shrink();
                        return ListTile(
                          leading: _brandIcon(Icons.support_agent),
                          title: const Text(
                            'Soporte Técnico VIP / Prioritario',
                          ),
                          subtitle: const Text(
                            'Atención directa para usuarios Élite',
                            style: TextStyle(color: Colors.white60),
                          ),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: _openVipSupport,
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openVipSupport() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para contactar soporte.')),
      );
      return;
    }

    final message = Uri.encodeComponent(
      'Hola, soy usuario Élite de SkillMatch y necesito soporte técnico '
      'prioritario con mi cuenta UID $userId.',
    );
    final uri = Uri.parse('https://wa.me/529192705197?text=$message');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir WhatsApp. Inténtalo nuevamente.'),
        ),
      );
    }
  }

  Future<bool> _showProviderSetupModal(
    BuildContext context,
    Map<String, dynamic> userData,
  ) async {
    final rawSpecialties = userData['specialties'] ?? userData['skills'];
    final specialties = rawSpecialties is Iterable
        ? rawSpecialties.map((specialty) => specialty.toString()).toList()
        : rawSpecialties is String
        ? rawSpecialties.split(',')
        : <String>[];
    final bioController = TextEditingController(
      text: userData['bio']?.toString() ?? '',
    );
    final skillsController = TextEditingController(
      text: specialties.join(', '),
    );
    final formKey = GlobalKey<FormState>();
    File? selectedImage;
    final existingPhotoUrl =
        [userData['photoUrl'], userData['profilePictureUrl']]
            .map((url) => url?.toString().trim() ?? '')
            .firstWhere((url) => url.isNotEmpty, orElse: () => '');

    try {
      final setup = await showDialog<(String, List<String>, File?)>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: 480,
                    maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Configura tu perfil profesional',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                const Text(
                                  'Cuéntales a tus clientes qué servicios '
                                  'ofreces y cuál es tu experiencia.',
                                  style: TextStyle(color: Colors.white70),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                FormField<File>(
                                  validator: (_) =>
                                      selectedImage == null &&
                                          existingPhotoUrl.isEmpty
                                      ? 'Selecciona una foto de perfil para continuar.'
                                      : null,
                                  builder: (field) => Column(
                                    children: [
                                      if (selectedImage != null)
                                        CircleAvatar(
                                          radius: 44,
                                          backgroundColor: const Color(
                                            0xFF303030,
                                          ),
                                          backgroundImage: FileImage(
                                            selectedImage!,
                                          ),
                                        )
                                      else
                                        CachedAppAvatar(
                                          imageUrl: existingPhotoUrl,
                                          radius: 44,
                                          backgroundColor: const Color(
                                            0xFF303030,
                                          ),
                                        ),
                                      TextButton.icon(
                                        onPressed: () async {
                                          final image = await ImagePicker()
                                              .pickImage(
                                                source: ImageSource.gallery,
                                                imageQuality: 70,
                                              );
                                          if (image == null ||
                                              !dialogContext.mounted) {
                                            return;
                                          }

                                          selectedImage = File(image.path);
                                          field.didChange(selectedImage);
                                          setDialogState(() {});
                                        },
                                        icon: const Icon(
                                          Icons.photo_library_outlined,
                                        ),
                                        label: Text(
                                          selectedImage == null &&
                                                  existingPhotoUrl.isEmpty
                                              ? 'Seleccionar foto de perfil *'
                                              : 'Cambiar foto de perfil',
                                        ),
                                      ),
                                      if (field.errorText != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            field.errorText!,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: bioController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _providerProfileInputDecoration(
                                    label: 'Biografía profesional',
                                    hint: 'Describe tu experiencia y servicios',
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
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _providerProfileInputDecoration(
                                    label: 'Especialidades',
                                    hint: 'Ej. Plomería, pintura, electricidad',
                                    helper: 'Separa cada especialidad con una coma.',
                                  ),
                                  validator: (value) {
                                    final skills =
                                        value
                                            ?.split(',')
                                            .map((skill) => skill.trim()) ??
                                        [];
                                    if (skills
                                        .where((skill) => skill.isNotEmpty)
                                        .isEmpty) {
                                      return 'Agrega al menos una especialidad.';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Ahora no'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () {
                                if (!formKey.currentState!.validate()) return;
                                final skills = skillsController.text
                                    .split(',')
                                    .map((skill) => skill.trim())
                                    .where((skill) => skill.isNotEmpty)
                                    .toSet()
                                    .toList();
                                Navigator.pop(dialogContext, (
                                  bioController.text.trim(),
                                  skills,
                                  selectedImage,
                                ));
                              },
                              child: const Text('Guardar y activar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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

  InputDecoration _providerProfileInputDecoration({
    required String label,
    required String hint,
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      helperStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.cyanAccent),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
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
          leading: _brandIcon(Icons.work_history_rounded),
          title: const Text('Mi Portafolio / Certificados'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const PortfolioScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: _brandIcon(Icons.bar_chart),
          title: const Text('Mis Ganancias / Estadísticas'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.red,
                    content: Text('Inicia sesión para continuar.'),
                  ),
                );
              return;
            }

            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

            if (!context.mounted) return;
            final profileData = userDoc.data();
            final isPremium =
                profileData?['isElite'] == true ||
                profileData?['isPremium'] == true ||
                profileData?['plan'] == 'elite';

            if (isPremium) {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const EarningsStatisticsScreen(),
                ),
              );
              return;
            }

            showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (modalContext) {
                return SafeArea(
                  top: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const Icon(
                          Icons.workspace_premium,
                          color: Color(0xFFFFB74D),
                          size: 72,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Desbloquea SkillMatch Premium',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Accede a métricas avanzadas, historial detallado de ganancias y herramientas exclusivas para potenciar tus servicios.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          r'$599.00 MXN',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFC107),
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF9800), Color(0xFFFFC107)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66FF9800),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.black,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () async {
                                const premiumPrice = 599.0;
                                final user = FirebaseAuth.instance.currentUser;

                                if (user == null) {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Colors.red,
                                        content: Text(
                                          'Inicia sesión para comprar Premium.',
                                        ),
                                      ),
                                    );
                                  return;
                                }

                                final userRef = FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid);

                                try {
                                  final userDoc = await userRef.get();
                                  final data = userDoc.data();
                                  final saldoActual = data?['balance'] is num
                                      ? (data!['balance'] as num).toDouble()
                                      : 10000.0;

                                  if (saldoActual < premiumPrice) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        const SnackBar(
                                          backgroundColor: Colors.red,
                                          content: Text(
                                            'Saldo insuficiente. Recarga tu billetera en la sección de pagos.',
                                          ),
                                        ),
                                      );
                                    return;
                                  }

                                  final earningRef = FirebaseFirestore.instance
                                      .collection('platform_earnings')
                                      .doc();
                                  await FirebaseFirestore.instance
                                      .runTransaction<void>((
                                        transaction,
                                      ) async {
                                        final snapshot = await transaction.get(
                                          userRef,
                                        );
                                        if (!snapshot.exists) {
                                          throw StateError(
                                            'No se encontró el perfil del usuario.',
                                          );
                                        }
                                        final transactionData = snapshot.data();
                                        if (transactionData?['isElite'] ==
                                                true ||
                                            transactionData?['isPremium'] ==
                                                true ||
                                            transactionData?['plan'] ==
                                                'elite') {
                                          throw StateError(
                                            'Tu cuenta ya tiene el plan Élite.',
                                          );
                                        }
                                        final currentBalance =
                                            transactionData?['balance'] is num
                                            ? (transactionData!['balance']
                                                      as num)
                                                  .toDouble()
                                            : 10000.0;

                                        if (currentBalance < premiumPrice) {
                                          throw StateError(
                                            'Saldo insuficiente',
                                          );
                                        }

                                        transaction.update(userRef, {
                                          'balance':
                                              currentBalance - premiumPrice,
                                          'plan': 'elite',
                                          'isPro': true,
                                          'isElite': true,
                                          'isPremium': true,
                                          'adsDisabled': true,
                                          'eliteActivatedAt':
                                              FieldValue.serverTimestamp(),
                                          'premiumActivatedAt':
                                              FieldValue.serverTimestamp(),
                                        });

                                        final paymentRef = userRef
                                            .collection('transactions')
                                            .doc();
                                        transaction.set(paymentRef, {
                                          'title':
                                              'Suscripción SkillMatch Élite',
                                          'amount': premiumPrice,
                                          'isPositive': false,
                                          'requestId': 'subscription_elite',
                                          'plan': 'elite',
                                          'createdAt':
                                              FieldValue.serverTimestamp(),
                                        });
                                        transaction.set(earningRef, {
                                          'userId': user.uid,
                                          'type': 'subscription',
                                          'plan': 'elite',
                                          'amount': premiumPrice,
                                          'createdAt':
                                              FieldValue.serverTimestamp(),
                                        });
                                      });

                                  if (!modalContext.mounted) return;
                                  Navigator.pop(modalContext);
                                  if (!context.mounted) return;

                                  showDialog<void>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (dialogContext) {
                                      return Dialog(
                                        backgroundColor: const Color(
                                          0xFF1E1E1E,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 28,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TweenAnimationBuilder<double>(
                                                tween: Tween<double>(
                                                  begin: 0,
                                                  end: 1,
                                                ),
                                                duration: const Duration(
                                                  milliseconds: 800,
                                                ),
                                                curve: Curves.elasticOut,
                                                builder:
                                                    (context, scale, child) {
                                                      return Transform.scale(
                                                        scale: scale,
                                                        child: child,
                                                      );
                                                    },
                                                child: const Icon(
                                                  Icons.check_circle,
                                                  color: Colors.greenAccent,
                                                  size: 80,
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              const Text(
                                                '¡Suscripción Exitosa!',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              const Text(
                                                'Ahora tienes acceso a todas las estadísticas y herramientas premium.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  height: 1.4,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              ElevatedButton(
                                                onPressed: () {
                                                  Navigator.pop(dialogContext);
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFFFFB74D,
                                                  ),
                                                  foregroundColor: Colors.black,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 32,
                                                        vertical: 14,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Continuar',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                } on StateError catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        backgroundColor: Colors.red,
                                        content: Text(error.toString()),
                                      ),
                                    );
                                } catch (_) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Colors.red,
                                        content: Text(
                                          'No se pudo procesar el pago. Inténtalo nuevamente.',
                                        ),
                                      ),
                                    );
                                }
                              },
                              child: const Text(
                                r'Pagar $599.00 y Mejorar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
      ],
    );
  }
}
