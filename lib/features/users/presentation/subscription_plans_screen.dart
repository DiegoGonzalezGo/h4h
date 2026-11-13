import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/ad_mob_service.dart';
import '../../../core/widgets/glassmorphism.dart';
import '../data/subscription_repository.dart';

class SubscriptionPlansScreen extends ConsumerStatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  ConsumerState<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState
    extends ConsumerState<SubscriptionPlansScreen> {
  String? _processingPlan;

  String _planFrom(Map<String, dynamic> data) {
    final plan = data['plan']?.toString();
    if (plan == 'elite' ||
        data['isElite'] == true ||
        data['isPremium'] == true) {
      return 'elite';
    }
    if (plan == 'pro' || data['isPro'] == true) return 'pro';
    return 'free';
  }

  Future<void> _purchase(String plan) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showMessage('Inicia sesión para elegir un plan.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar suscripción'),
        content: Text(
          '¿Estás seguro de suscribirte al Plan ${_label(plan)} por '
          '\$${plan == 'pro' ? '349' : '599'} MXN/mes? '
          'El monto se descontará de tu saldo disponible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingPlan = plan);
    try {
      await SubscriptionRepository().purchasePlan(userId: userId, plan: plan);
      AdMobService.instance.cancelAdTimers();
      if (!mounted) return;
      _showMessage(
        plan == 'elite'
            ? '¡Plan Élite activado! Ya tienes acceso a las estadísticas y soporte VIP.'
            : '¡Plan Pro activado! Los anuncios se han deshabilitado.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error is StateError
            ? error.message
            : 'No se pudo procesar la compra. Inténtalo nuevamente.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _processingPlan = null);
    }
  }

  Future<void> _cancelSubscription({required DateTime? planExpiresAt}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showMessage(
        'Inicia sesión para administrar tu suscripción.',
        isError: true,
      );
      return;
    }

    final formattedExpiry = planExpiresAt == null
        ? 'la fecha de vencimiento'
        : DateFormat('dd/MM/yyyy').format(planExpiresAt);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cancelar suscripción?'),
        content: Text(
          'Mantendrás tus beneficios hasta el $formattedExpiry, pero no se '
          'volverá a cobrar. ¿Deseas cancelar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Mantener plan'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingPlan = 'cancel');
    try {
      await SubscriptionRepository().cancelSubscription(userId);
      if (mounted) {
        _showMessage(
          'Se canceló la renovación; conservarás tus beneficios hasta su vencimiento.',
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          'No se pudo cancelar la suscripción: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _processingPlan = null);
    }
  }

  Future<void> _reactivateSubscription() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showMessage(
        'Inicia sesión para administrar tu suscripción.',
        isError: true,
      );
      return;
    }

    setState(() => _processingPlan = 'reactivate');
    try {
      await SubscriptionRepository().reactivateSubscription(userId);
      if (mounted) _showMessage('La renovación automática fue reactivada.');
    } catch (error) {
      if (mounted) {
        _showMessage(
          'No se pudo reactivar la renovación: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _processingPlan = null);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade800 : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Planes SkillMatch'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: userId == null
          ? const Center(
              child: Text(
                'Inicia sesión para consultar tus planes.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : StreamBuilder<Map<String, dynamic>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .snapshots()
                  .map((snapshot) => snapshot.data() ?? <String, dynamic>{}),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'No se pudo cargar tu plan actual.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userData = snapshot.data!;
                final currentPlan = _planFrom(userData);
                final autoRenew = userData['autoRenew'] != false;
                final expiresAt = _dateTimeFrom(userData['planExpiresAt']);
                final expiryLabel = expiresAt == null
                    ? 'fecha de vencimiento pendiente'
                    : DateFormat('dd/MM/yyyy').format(expiresAt);
                return GlowBackground(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Plan actual: ${_label(currentPlan)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (currentPlan != 'free' && !autoRenew)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Cancelado • Activo hasta $expiryLabel',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      _PlanCard(
                        title: 'Gratis',
                        price: r'$0 MXN/mes',
                        description: 'Acceso exclusivo como Cliente para buscar y solicitar servicios.',
                        features: const [
                          'Funciones esenciales',
                          'Se mantienen los anuncios',
                        ],
                        color: Colors.white70,
                        buttonLabel: currentPlan == 'free'
                            ? 'Plan actual'
                            : 'Incluido',
                        onPressed: null,
                      ),
                      const SizedBox(height: 14),
                      _PlanCard(
                        title: 'Pro',
                        price: r'$349 MXN/mes',
                        description: 'Una experiencia sin anuncios.',
                        features: const [
                          'Anuncios deshabilitados',
                          'Insignia PRO en tus servicios',
                          'Desbloquea el Modo Proveedor para publicar y ofrecer servicios.',
                        ],
                        color: Colors.cyanAccent,
                        statusLabel: currentPlan == 'pro' && !autoRenew
                            ? 'Cancelado • Activo hasta $expiryLabel'
                            : null,
                        buttonLabel: currentPlan == 'pro'
                            ? autoRenew
                                  ? 'Plan actual • Cancelar'
                                  : 'Reactivar renovación'
                            : currentPlan == 'elite'
                            ? 'Incluido en Élite'
                            : 'Activar Pro',
                        onPressed: _processingPlan != null
                            ? null
                            : currentPlan == 'pro'
                            ? autoRenew
                                  ? () => _cancelSubscription(
                                      planExpiresAt: expiresAt,
                                    )
                                  : _reactivateSubscription
                            : currentPlan == 'free'
                            ? () => _purchase('pro')
                            : null,
                        isLoading:
                            _processingPlan == 'pro' ||
                            (currentPlan == 'pro' &&
                                (_processingPlan == 'cancel' ||
                                    _processingPlan == 'reactivate')),
                      ),
                      const SizedBox(height: 14),
                      _PlanCard(
                        title: 'Élite',
                        price: r'$599 MXN/mes',
                        description:
                            'Herramientas avanzadas y asistencia prioritaria.',
                        features: const [
                          'Todo lo incluido en Pro',
                          'Acceso a ganancias y estadísticas',
                          'Insignia ÉLITE y soporte VIP',
                        ],
                        color: const Color(0xFFFFC107),
                        statusLabel: currentPlan == 'elite' && !autoRenew
                            ? 'Cancelado • Activo hasta $expiryLabel'
                            : null,
                        buttonLabel: currentPlan == 'elite'
                            ? autoRenew
                                  ? 'Plan actual • Cancelar'
                                  : 'Reactivar renovación'
                            : 'Activar Élite',
                        onPressed: _processingPlan != null
                            ? null
                            : currentPlan == 'elite'
                            ? autoRenew
                                  ? () => _cancelSubscription(
                                      planExpiresAt: expiresAt,
                                    )
                                  : _reactivateSubscription
                            : () => _purchase('elite'),
                        isLoading:
                            _processingPlan == 'elite' ||
                            (currentPlan == 'elite' &&
                                (_processingPlan == 'cancel' ||
                                    _processingPlan == 'reactivate')),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'El cobro es mensual desde tu billetera. Recibirás 1 notificación diaria durante los 3 días previos al vencimiento del plan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _label(String plan) => switch (plan) {
    'pro' => 'Pro',
    'elite' => 'Élite',
    _ => 'Gratis',
  };

  DateTime? _dateTimeFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.description,
    required this.features,
    required this.color,
    required this.buttonLabel,
    required this.onPressed,
    this.statusLabel,
    this.isLoading = false,
  });

  final String title;
  final String price;
  final String description;
  final List<String> features;
  final Color color;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final String? statusLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: Colors.white70)),
          if (statusLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              statusLabel!,
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: color, size: 17),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.black,
                disabledBackgroundColor: color.withValues(alpha: 0.25),
                disabledForegroundColor: Colors.white70,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
