import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/data/auth_repository.dart';
import '../data/user_repository.dart';

// 1. CORRECCIÓN: Usamos la estructura moderna NotifierProvider
class ProviderMode extends Notifier<bool> {
  @override
  bool build() => false; 

  void toggleMode(bool isProvider) {
    state = isProvider;
  }
}

final providerModeProvider = NotifierProvider<ProviderMode, bool>(ProviderMode.new);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          )
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
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null 
                          ? const Icon(Icons.person, size: 50, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    if (userData['bio'] != null && userData['bio'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 24, right: 24),
                        child: Text(
                          userData['bio'],
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 8),
                    TextButton.icon(
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
            const Divider(),
            
            // --- SWITCH DE MODO ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: SwitchListTile(
                title: const Text('Modo Proveedor'),
                subtitle: const Text('Activa para ofrecer servicios'),
                value: isProviderMode,
                onChanged: (value) {
                  // 2. CORRECCIÓN: Llamamos a la nueva función toggleMode
                  ref.read(providerModeProvider.notifier).toggleMode(value);
                },
              ),
            ),
            const Divider(),
            
            // Renderizamos los menús dependiendo del modo
            isProviderMode ? _buildProviderView(context) : _buildClientView(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderView(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: const Text('Publicar nuevo servicio'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            context.push('/create-service');
          },
        ),
        ListTile(
          leading: const Icon(Icons.list_alt),
          title: const Text('Mis servicios publicados'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            context.push('/my-services');
          },
        ),
        ListTile(
          leading: const Icon(Icons.notifications_active),
          title: const Text('Solicitudes entrantes'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            context.push('/provider-matches');
          },
        ),
      ],
    );
  }

  Widget _buildClientView(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text('Buscar servicios'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            context.go('/feed');
          },
        ),
        ListTile(
          leading: const Icon(Icons.handshake),
          title: const Text('Mis solicitudes enviadas'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            context.push('/client-matches');
          },
        ),
        ListTile(
          leading: const Icon(Icons.check_circle_outline),
          title: const Text('Historial de servicios'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            context.push('/client-history'); 
          },
        ),
      ],
    );
  }
}