import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Asegúrate de que esta ruta coincida con la ubicación de tu repositorio
import '../data/auth_repository.dart'; 

// Cambiamos a ConsumerStatefulWidget para poder usar Riverpod (ref) y manejar estados locales (setState)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Controladores para capturar el texto de los inputs
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(); 
  
  bool _isLogin = true; // Variable para alternar visualmente entre Login y Registro
  bool _isLoading = false; // Variable para mostrar la rueda de carga

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // 1. Ocultar teclado y mostrar indicador de carga
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      // 2. Accedemos al repositorio que creamos usando ref.read
      final authRepo = ref.read(authRepositoryProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // 3. Ejecutamos la acción correspondiente
      if (_isLogin) {
        await authRepo.signIn(email, password);
      } else {
        final name = _nameController.text.trim();
        if (name.isEmpty) throw Exception('El nombre es obligatorio para registrarse');
        await authRepo.signUp(email, password, name);
      }
      
      // 4. Si Firebase responde con éxito, navegamos al feed
      if (mounted) {
        context.go('/feed');
      }
    } catch (e) {
      // 5. Si hay error (ej. contraseña corta, correo inválido), mostramos un SnackBar rojo
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      // 6. Apagamos el indicador de carga pase lo que pase
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Iniciar Sesión' : 'Crear Cuenta'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Solo mostramos el campo de nombre si estamos en modo "Registro"
              if (!_isLogin) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
                obscureText: true, // Oculta el texto de la contraseña
              ),
              const SizedBox(height: 24),
              
              // Botón principal o rueda de carga
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(_isLogin ? 'Entrar' : 'Registrarse'),
                ),
              
              const SizedBox(height: 16),
              
              // Botón para alternar entre pantallas
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(_isLogin
                    ? '¿No tienes cuenta? Regístrate aquí'
                    : '¿Ya tienes cuenta? Inicia sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}