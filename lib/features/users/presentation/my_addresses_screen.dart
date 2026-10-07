import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/address_model.dart';
import '../data/user_repository.dart';

class MyAddressesScreen extends ConsumerWidget {
  const MyAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Mis Direcciones'),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const Center(
          child: Text(
            'No se pudieron cargar tus direcciones.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        data: (user) {
          final addresses = user?.addresses ?? const <AddressModel>[];
          if (addresses.isEmpty) {
            return const _EmptyAddressesState();
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final address = addresses[index];
              final icon = switch (address.alias.toLowerCase()) {
                'casa' => Icons.home,
                'trabajo' => Icons.work,
                _ => Icons.location_on,
              };

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Colors.cyanAccent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            address.alias,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            address.street,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          if (address.reference.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              address.reference,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Eliminar dirección',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () async {
                        try {
                          await ref
                              .read(currentUserControllerProvider.notifier)
                              .removeAddress(address.id);
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'No se pudo eliminar la dirección: $error',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _GradientAddButton(
        onPressed: () => _showAddAddressModal(context),
      ),
    );
  }
}

class _EmptyAddressesState extends StatelessWidget {
  const _EmptyAddressesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 72, color: Color(0xFF424242)),
            const SizedBox(height: 16),
            Text(
              'Aún no tienes direcciones guardadas',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientAddButton extends StatelessWidget {
  const _GradientAddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Agregar nueva dirección'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    );
  }
}

Future<void> _showAddAddressModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const AddAddressModal(),
  );
}

class AddAddressModal extends ConsumerStatefulWidget {
  const AddAddressModal({super.key});

  @override
  ConsumerState<AddAddressModal> createState() => _AddAddressModalState();
}

class _AddAddressModalState extends ConsumerState<AddAddressModal> {
  final _aliasController = TextEditingController();
  final _streetController = TextEditingController();
  final _referenceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _aliasController.dispose();
    _streetController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.white54),
      filled: true,
      fillColor: const Color(0xFF151515),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    final alias = _aliasController.text.trim();
    final street = _streetController.text.trim();
    final reference = _referenceController.text.trim();
    final address = AddressModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      alias: alias,
      street: street,
      reference: reference,
    );
    final scaffold = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await ref
          .read(currentUserControllerProvider.notifier)
          .addAddress(address);

      if (!mounted) return;

      scaffold
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Dirección guardada correctamente')),
        );
      navigator.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = 'No se pudo guardar: $error';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Nueva Dirección',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _aliasController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration(
                        'Alias (Ej. Casa, Oficina)',
                        Icons.label_outline,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Escribe un alias'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _streetController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration(
                        'Dirección completa (Calle y número)',
                        Icons.location_on_outlined,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Escribe la dirección completa'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _referenceController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration(
                        'Referencias (Ej. Portón negro)',
                        Icons.info_outline,
                      ),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorText!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: FilledButton(
                          onPressed: _isSaving ? null : _saveAddress,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Guardar Dirección',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
