import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/user_repository.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$feature estará disponible próximamente.')),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserControllerProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'es_MX',
      name: 'MXN',
      symbol: r'$',
    );

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: const Text('Billetera y Pagos'),
        backgroundColor: const Color(0xFF000000),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo Disponible',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                userAsync.when(
                  data: (user) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      user == null
                          ? 'Saldo no disponible'
                          : '${currencyFormat.format(user.balance)} MXN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  loading: () => const Text(
                    'Cargando saldo...',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  error: (error, stackTrace) => const Text(
                    'No se pudo cargar el saldo',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => _showComingSoon(context, 'La recarga'),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Recargar Saldo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Mis Tarjetas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 48,
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
                    '**** **** **** 4242',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Text(
                  '12/28',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showComingSoon(context, 'Agregar tarjetas'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.cyanAccent,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Agregar método de pago'),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Movimientos Recientes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const _WalletMovements(),
        ],
      ),
    );
  }
}

class _WalletMovements extends ConsumerWidget {
  const _WalletMovements();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(walletTransactionsProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'es_MX',
      name: 'MXN',
      symbol: r'$',
    );

    return transactionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No se pudieron cargar los movimientos: $error',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
      data: (transactions) {
        if (transactions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Aún no tienes movimientos.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return Column(
          children: [
            for (var index = 0; index < transactions.length; index++) ...[
              if (index > 0) const Divider(color: Color(0xFF2C2C2C), height: 1),
              _WalletMovementTile(
                icon: (transactions[index]['amount'] as num).toDouble() < 0
                    ? Icons.lock_outline
                    : Icons.account_balance_wallet_outlined,
                title:
                    transactions[index]['description']?.toString() ??
                    'Movimiento de billetera',
                subtitle: _formatDate(transactions[index]['createdAt']),
                amount: currencyFormat.format(
                  (transactions[index]['amount'] as num).toDouble().abs(),
                ),
                isDebit:
                    (transactions[index]['amount'] as num).toDouble() < 0,
              ),
            ],
          ],
        );
      },
    );
  }

  String _formatDate(Object? value) {
    if (value is! Timestamp) return 'Fecha pendiente';
    final date = value.toDate();
    final today = DateTime.now();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final todayOnly = DateTime(today.year, today.month, today.day);

    if (dateOnly == todayOnly) return 'Hoy';
    if (dateOnly == todayOnly.subtract(const Duration(days: 1))) return 'Ayer';
    return DateFormat.yMMMd('es_MX').format(date);
  }
}

class _WalletMovementTile extends StatelessWidget {
  const _WalletMovementTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isDebit,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final bool isDebit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF1E1E1E),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
      trailing: Text(
        '${isDebit ? '- ' : '+ '}$amount',
        style: TextStyle(
          color: isDebit ? Colors.orangeAccent : Colors.greenAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
