import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart'; // 1. Agregamos el import de GoRouter para poder navegar
import '../data/user_model.dart';
import '../../auth/data/auth_repository.dart';

// 1. Proveedor que consulta Firestore para traer el perfil completo del usuario logueado
// 1. Proveedor que consulta Firestore para traer el perfil completo del usuario logueado
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  // En lugar de leer FirebaseAuth directamente, ESCUCHAMOS el estado de la sesión
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) return null;
  
  final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  if (doc.exists) {
    return UserModel.fromMap(doc.data()!, doc.id);
  }
  return null;
});

// 2. Proveedor moderno (Notifier) que controla el estado visual del rol
class ClientModeNotifier extends Notifier<bool> {
  @override
  bool build() => true; // Valor inicial: true (Modo Cliente)

  void setMode(bool value) {
    state = value;
  }
}

final isClientModeProvider = NotifierProvider<ClientModeNotifier, bool>(ClientModeNotifier.new);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchamos los datos del usuario y el estado del interruptor
    final userAsync = ref.watch(currentUserProvider);
    final isClientMode = ref.watch(isClientModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authRepositoryProvider).signOut();
            },
          )
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (user) {
          if (user == null) return const Center(child: Text('Usuario no encontrado'));

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 50,
                  child: Icon(Icons.person, size: 50),
                ),
                const SizedBox(height: 16),
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                
                // 3. El componente clave: El interruptor de roles
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isClientMode ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isClientMode ? 'Modo Cliente' : 'Modo Proveedor',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isClientMode ? Colors.blue : Colors.green,
                        ),
                      ),
                      Switch(
                        value: isClientMode,
                        activeColor: Colors.blue, 
                        inactiveThumbColor: Colors.green, 
                        inactiveTrackColor: Colors.green.withOpacity(0.5),
                        onChanged: (value) {
                          ref.read(isClientModeProvider.notifier).setMode(value);
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // 4. Interfaz dinámica dependiendo del rol seleccionado
                Expanded(
                  child: isClientMode 
                    ? _buildClientView() // Restauramos la vista de cliente
                    : _buildProviderView(context), // 2. Le pasamos el context a la vista de proveedor
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Vista restaurada: cuando el usuario quiere contratar servicios
  Widget _buildClientView() {
    return ListView(
      children: const [
        ListTile(
          leading: Icon(Icons.search),
          title: Text('Buscar nuevos servicios'),
          trailing: Icon(Icons.chevron_right),
        ),
        ListTile(
          leading: Icon(Icons.history),
          title: Text('Mis solicitudes (Match)'),
          trailing: Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  // Vista unificada: cuando el usuario quiere ofrecer sus servicios
  // 3. Recibimos el BuildContext como parámetro
  Widget _buildProviderView(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: const Text('Publicar un nuevo servicio'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // 4. Como ahora tenemos el context directamente, la navegación es muy limpia
            context.push('/create-service');
          },
        ),
        ListTile(
          leading: const Icon(Icons.list_alt),
          title: const Text('Solicitudes recibidas'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            context.push('/provider-matches'); // Navegamos a la nueva pantalla
          },
        ),
      ],
    );
  }
}