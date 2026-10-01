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

Future<void> _showAddAddressModal(BuildContext context) async {
  final aliasController = TextEditingController();
  final streetController = TextEditingController();
  final referenceController = TextEditingController();
  var isSaving = false;
  String? errorText;
  final formKey = GlobalKey<FormState>();

  InputDecoration decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.white54),
      filled: true,
      fillColor: const Color(0xFF151515),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );
  }

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, child) => StatefulBuilder(
          builder: (context, setModalState) {
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
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
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
                              controller: aliasController,
                              style: const TextStyle(color: Colors.white),
                              decoration: decoration(
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
                              controller: streetController,
                              style: const TextStyle(color: Colors.white),
                              decoration: decoration(
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
                              controller: referenceController,
                              style: const TextStyle(color: Colors.white),
                              decoration: decoration(
                                'Referencias (Ej. Portón negro)',
                                Icons.info_outline,
                              ),
                            ),
                            if (errorText != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                errorText!,
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
                                    colors: [
                                      Color(0xFF6A11CB),
                                      Color(0xFF2575FC),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: FilledButton(
                                  onPressed: isSaving
                                      ? null
                                      : () async {
                                          if (!formKey.currentState!
                                              .validate()) {
                                            return;
                                          }

                                          setModalState(() {
                                            isSaving = true;
                                            errorText = null;
                                          });
                                          try {
                                            final address = AddressModel(
                                              id: DateTime.now()
                                                  .microsecondsSinceEpoch
                                                  .toString(),
                                              alias: aliasController.text
                                                  .trim(),
                                              street: streetController.text
                                                  .trim(),
                                              reference: referenceController
                                                  .text
                                                  .trim(),
                                            );
                                            await ref
                                                .read(
                                                  currentUserControllerProvider
                                                      .notifier,
                                                )
                                                .addAddress(address);
                                            if (sheetContext.mounted) {
                                              Navigator.pop(sheetContext);
                                            }
                                          } catch (error) {
                                            if (sheetContext.mounted) {
                                              setModalState(() {
                                                errorText =
                                                    'No se pudo guardar: $error';
                                                isSaving = false;
                                              });
                                            }
                                          }
                                        },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  child: isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Guardar Dirección',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
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
          },
        ),
      ),
    );
  } finally {
    aliasController.dispose();
    streetController.dispose();
    referenceController.dispose();
  }
}
