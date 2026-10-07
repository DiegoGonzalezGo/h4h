import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/user_repository.dart';

class EarningsStatisticsScreen extends ConsumerWidget {
  const EarningsStatisticsScreen({super.key});

  static const _backgroundColor = Color(0xFF000000);
  static const _cardColor = Color(0xFF1E1E1E);
  static const _earningsColor = Color(0xFF6A11CB);
  static const _expensesColor = Color(0xFFFF7043);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'es_MX',
      name: 'MXN',
      symbol: r'$',
    );

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Mis Ganancias / Estadísticas'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudieron cargar las estadísticas: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
        data: (transactions) {
          final totalGanado = transactions
              .where((transaction) => transaction.isPositive)
              .fold<double>(
                0,
                (total, transaction) => total + transaction.amount,
              );
          final totalGastado = transactions
              .where((transaction) => !transaction.isPositive)
              .fold<double>(
                0,
                (total, transaction) => total + transaction.amount,
              );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total Ganancias',
                      formattedAmount: currencyFormat.format(totalGanado),
                      colors: const [_earningsColor, Color(0xFF2575FC)],
                      icon: Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total Gastos',
                      formattedAmount: currencyFormat.format(totalGastado),
                      colors: const [Color(0xFFEF5350), _expensesColor],
                      icon: Icons.trending_down,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ganancias vs. gastos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Comparativo de tus movimientos',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    if (transactions.isEmpty)
                      const SizedBox(
                        height: 220,
                        child: Center(
                          child: Text(
                            'Aún no hay movimientos para mostrar',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 220,
                        child: _EarningsBarChart(
                          totalGanado: totalGanado,
                          totalGastado: totalGastado,
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ChartLegendItem(
                          color: _earningsColor,
                          label: 'Ganancias',
                        ),
                        SizedBox(width: 24),
                        _ChartLegendItem(
                          color: _expensesColor,
                          label: 'Gastos',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.formattedAmount,
    required this.colors,
    required this.icon,
  });

  final String title;
  final String formattedAmount;
  final List<Color> colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(minHeight: 152),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formattedAmount,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningsBarChart extends StatelessWidget {
  const _EarningsBarChart({
    required this.totalGanado,
    required this.totalGastado,
  });

  final double totalGanado;
  final double totalGastado;

  @override
  Widget build(BuildContext context) {
    final lowerValue = totalGanado < totalGastado ? totalGanado : totalGastado;
    final higherValue = totalGanado > totalGastado ? totalGanado : totalGastado;
    final minY = lowerValue < 0 ? lowerValue * 1.2 : 0.0;
    final maxY = higherValue > 0 ? higherValue * 1.2 : 1.0;

    return BarChart(
      BarChartData(
        minY: minY,
        maxY: maxY,
        alignment: BarChartAlignment.spaceEvenly,
        barTouchData: const BarTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final label = switch (value.toInt()) {
                  0 => 'Ganancias',
                  1 => 'Gastos',
                  _ => '',
                };
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          _barGroup(0, totalGanado, EarningsStatisticsScreen._earningsColor),
          _barGroup(1, totalGastado, EarningsStatisticsScreen._expensesColor),
        ],
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double amount, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: amount,
          color: color,
          width: 44,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
