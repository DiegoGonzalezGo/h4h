import 'package:flutter/material.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Métodos de Pago'),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.credit_card_outlined,
                color: Color(0xFF424242),
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'Próximamente: Integración de pagos',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
