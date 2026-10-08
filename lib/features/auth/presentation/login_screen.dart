import 'package:flutter/gestures.dart';
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
  final _phoneController = TextEditingController();
  late final TapGestureRecognizer _termsTapRecognizer;

  bool _isLogin =
      true; // Variable para alternar visualmente entre Login y Registro
  bool _isLoading = false; // Variable para mostrar la rueda de carga
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _termsTapRecognizer = TapGestureRecognizer()
      ..onTap = () => _showTermsDialog(context);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _termsTapRecognizer.dispose();
    super.dispose();
  }

  Future<void> _showTermsDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Términos y Condiciones'),
        content: const SingleChildScrollView(
          child: Text(
            'Última actualización: 7 de octubre de 2026\n\n'
            '1. Uso de la plataforma\n'
            'Hand4Hand conecta a clientes con proveedores de servicios. '
            'Al crear una cuenta, te comprometes a proporcionar información '
            'veraz y a usar la plataforma de forma legal y respetuosa.\n\n'
            '2. Pagos y saldo\n'
            'Los pagos de servicios se procesan mediante el flujo disponible '
            'en la aplicación. El saldo usado para solicitar un servicio '
            'puede quedar retenido mientras se completa la solicitud y se '
            'confirma el servicio. Revisa el monto y los detalles antes de '
            'confirmar cada solicitud.\n\n'
            '3. Comisiones\n'
            'La plataforma puede aplicar una comisión a determinadas '
            'transacciones. Cualquier cargo aplicable debe mostrarse antes '
            'de confirmar la operación correspondiente.\n\n'
            '4. Solicitudes, cancelaciones y reembolsos\n'
            'Las solicitudes dependen de la disponibilidad y aceptación del '
            'proveedor. Las cancelaciones, reembolsos y liberación de pagos '
            'se gestionan de acuerdo con el estado de la solicitud y las '
            'opciones disponibles en la aplicación.\n\n'
            '5. Responsabilidades de clientes y proveedores\n'
            'Cada usuario es responsable de la información que publica, de '
            'coordinar los detalles del servicio y de cumplir los acuerdos '
            'realizados con la otra parte. Hand4Hand no debe utilizarse para '
            'publicar servicios ilegales, engañosos o que pongan en riesgo a '
            'otras personas.\n\n'
            '6. Conducta y seguridad\n'
            'Se requiere un trato respetuoso. No se permite el acoso, la '
            'discriminación, el fraude ni el uso de la plataforma para '
            'perjudicar a otras personas. Puedes reportar problemas a través '
            'de los canales de soporte disponibles.\n\n'
            '7. Edad y aceptación\n'
            'Al aceptar estos términos, confirmas que eres mayor de edad y '
            'que la información proporcionada durante el registro es '
            'correcta. Si no estás de acuerdo, no completes el registro.\n\n'
            'Este texto es informativo y debe revisarse con asesoría legal '
            'antes de utilizarse como contrato definitivo.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    // 1. Ocultar teclado y mostrar indicador de carga
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      // 2. Accedemos al repositorio que creamos usando ref.read
      final authRepo = ref.read(authRepositoryProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // 3. Ejecutamos la acción correspondiente
      if (_isLogin) {
        await authRepo.signIn(email, password);
      } else {
        if (!_acceptedTerms) {
          throw Exception(
            'Acepta los términos y confirma que eres mayor de edad.',
          );
        }
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          throw Exception('El nombre es obligatorio para registrarse');
        }
        final phone = _phoneController.text.trim();
        if (phone.isEmpty) {
          throw Exception('El teléfono es obligatorio para registrarse');
        }
        await authRepo.signUp(email, password, name, phone);
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
      appBar: AppBar(title: Text(_isLogin ? 'Iniciar Sesión' : 'Crear Cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0).toDouble(),
                      child: child,
                    ),
                  );
                },
                child: AnimatedScale(
                  scale: _isLoading ? 0.85 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              if (!_isLogin) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
                obscureText: true, // Oculta el texto de la contraseña
              ),
              if (!_isLogin)
                CheckboxListTile(
                  value: _acceptedTerms,
                  onChanged: (accepted) {
                    setState(() => _acceptedTerms = accepted ?? false);
                  },
                  title: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: [
                        const TextSpan(text: 'Acepto los '),
                        TextSpan(
                          text: 'términos y condiciones',
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: _termsTapRecognizer,
                        ),
                        const TextSpan(text: ' y confirmo ser mayor de edad'),
                      ],
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              const SizedBox(height: 24),

              // Botón principal o rueda de carga
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                FilledButton(
                  onPressed: !_isLogin && !_acceptedTerms ? null : _submit,
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
                    _acceptedTerms = false;
                  });
                },
                child: Text(
                  _isLogin
                      ? '¿No tienes cuenta? Regístrate aquí'
                      : '¿Ya tienes cuenta? Inicia sesión',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
