import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../matches/data/matches_repository.dart';
import '../../services/data/service_model.dart';
import '../../users/data/address_model.dart';

const _simulatedPaymentMethod = 'Mastercard **** 1234';

// Pantalla de confirmación con pago simulado (modo oscuro)
class CheckoutScreen extends ConsumerStatefulWidget {
  final ServiceModel service;
  final AddressModel selectedAddress;

  const CheckoutScreen({
    super.key,
    required this.service,
    required this.selectedAddress,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _isProcessing = false;

  Future<void> _simulatePayment() async {
    setState(() => _isProcessing = true);

    // Diálogo de progreso: no se puede cerrar manualmente
    final dialogNavigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Procesando pago seguro...')),
            ],
          ),
        ),
      ),
    );

    try {
      await Future.delayed(const Duration(seconds: 3));

      await ref
          .read(matchesRepositoryProvider)
          .requestPaidService(
            service: widget.service,
            address: widget.selectedAddress,
            paymentMethod: _simulatedPaymentMethod,
          );
    } catch (e) {
      dialogNavigator.pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isProcessing = false);
      return;
    }

    dialogNavigator.pop();
    if (!mounted) return;

    // Hoja de éxito: no se puede cerrar sin tocar el botón
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 72),
            const SizedBox(height: 16),
            const Text(
              '¡Solicitud Enviada y Pagada!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tu pago de \$${widget.service.price.toStringAsFixed(2)} fue procesado. El proveedor revisará tu solicitud.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Ver mis solicitudes'),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/client-matches');
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final address = widget.selectedAddress;

    // Envolvemos en un Theme oscuro; el Builder garantiza que los diálogos
    // y hojas usen un contexto debajo del Theme
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A11CB),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Confirmar Solicitud')),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Resumen del servicio
                      Card(
                        color: const Color(0xFF1E1E1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service.title,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Chip(
                                label: Text(
                                  service.category,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                service.description,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Precio
                      Card(
                        color: const Color(0xFF1E1E1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              '\$${service.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyanAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Dirección seleccionada
                      Card(
                        color: const Color(0xFF1E1E1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      address.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(address.fullAddress),
                                    if (address.reference != null &&
                                        address.reference!.isNotEmpty)
                                      Text(
                                        'Ref: ${address.reference}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Método de pago simulado
                      Card(
                        color: const Color(0xFF1E1E1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.credit_card),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _simulatedPaymentMethod,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text('Pago simulado'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Totales
                      Card(
                        color: const Color(0xFF1E1E1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '\$${service.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyanAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Botón de pago al final del body
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isProcessing ? null : _simulatePayment,
                      borderRadius: BorderRadius.circular(16),
                      child: Ink(
                        height: 56,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        child: const Center(
                          child: Text(
                            'Pagar y Solicitar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
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
}
