import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ServicesFeedScreen extends StatelessWidget {
  const ServicesFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicios Disponibles'),
        actions: [
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                context.push('/profile');
              },
            )
          ],
      ),
      body: const Center(
        child: Text('Aquí irán las tarjetas de servicios'),
      ),
    );
  }
}