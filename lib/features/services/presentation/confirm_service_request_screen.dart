import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../matches/data/matches_repository.dart';
import '../../users/data/address_model.dart';
import '../data/service_model.dart';
import '../data/services_repository.dart';

class ServiceCheckoutArgs {
  const ServiceCheckoutArgs({required this.service, required this.address});

  final ServiceModel service;
  final AddressModel address;
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({
    required this.service,
    required this.selectedAddress,
    super.key,
  });

  final ServiceModel service;
  final AddressModel selectedAddress;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _isSubmitting = false;

  Future<void> _simulatePayment(BuildContext context) async {
    setState(() => _isSubmitting = true);
    final loadingDialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.cyanAccent),
                SizedBox(height: 20),
                Text(
                  'Procesando pago seguro...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await Future<void>.delayed(const Duration(seconds: 3));

    try {
      await ref
          .read(matchesRepositoryProvider)
          .requestService(
            widget.service.id,
            widget.service.providerId,
            serviceAddress: widget.selectedAddress,
          );
      ref.invalidate(clientActiveMatchesProvider);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await loadingDialog;
      if (!context.mounted) return;
      await _showSuccessBottomSheet(context);
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await loadingDialog;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la solicitud: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showSuccessBottomSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E).withValues(alpha: 0.94),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent,
                    size: 80,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '¡Solicitud Enviada y Pagada!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'El proveedor ha sido notificado. El dinero está retenido de forma segura hasta que se complete el trabajo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, height: 1.45),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        if (context.mounted) {
                          context.go('/client-matches');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.cyanAccent,
                        side: const BorderSide(color: Colors.cyanAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Ir a Mis Solicitudes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final address = widget.selectedAddress;
    final providerProfileAsync = ref.watch(
      providerProfileProvider(service.providerId),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Confirmar Solicitud'),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CheckoutSection(
              title: 'Resumen del servicio',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  providerProfileAsync.when(
                    data: (profile) => Text(
                      'Proveedor: ${profile['name'] ?? 'Proveedor'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    loading: () => const Text(
                      'Cargando proveedor...',
                      style: TextStyle(color: Colors.white70),
                    ),
                    error: (error, stack) => const Text(
                      'Proveedor no disponible',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        '\$${service.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _CheckoutSection(
              title: 'Dirección del servicio',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.location_on_outlined,
                  color: Colors.cyanAccent,
                ),
                title: Text(
                  address.alias,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  [
                    address.street,
                    address.reference,
                  ].where((value) => value.trim().isNotEmpty).join('\n'),
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Cambiar'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _CheckoutSection(
              title: 'Método de pago',
              child: Row(
                children: [
                  const SizedBox(
                    width: 44,
                    height: 32,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 4,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Color(0xFFEB001B),
                          ),
                        ),
                        Positioned(
                          left: 15,
                          top: 4,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Color(0xFFF79E1B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '**** 1234',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(onPressed: () {}, child: const Text('Cambiar')),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: FilledButton(
              onPressed: _isSubmitting ? null : () => _simulatePayment(context),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Pagar y Solicitar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckoutSection extends StatelessWidget {
  const _CheckoutSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
