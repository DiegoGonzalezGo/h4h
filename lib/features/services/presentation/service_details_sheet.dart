import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../checkout/presentation/checkout_screen.dart';
import '../../users/data/address_model.dart';
import '../../users/data/user_repository.dart';
import '../data/service_model.dart';

// Hoja inferior con los detalles del servicio y la selección de dirección
class ServiceDetailsSheet extends ConsumerStatefulWidget {
  final ServiceModel service;

  const ServiceDetailsSheet({super.key, required this.service});

  @override
  ConsumerState<ServiceDetailsSheet> createState() =>
      _ServiceDetailsSheetState();
}

class _ServiceDetailsSheetState extends ConsumerState<ServiceDetailsSheet> {
  AddressModel? selectedAddress;
  bool _showAddressError = false;
  bool _addressSaveError = false;

  Future<void> _showAddAddressDialog() async {
    final labelController = TextEditingController();
    final streetController = TextEditingController();
    final cityController = TextEditingController();
    final referenceController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final newAddress = await showDialog<AddressModel>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Agregar dirección'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Etiqueta',
                    hintText: 'Ej. Casa',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresa una etiqueta'
                      : null,
                ),
                TextFormField(
                  controller: streetController,
                  decoration: const InputDecoration(
                    labelText: 'Calle y número',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresa la calle y número'
                      : null,
                ),
                TextFormField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'Ciudad'),
                ),
                TextFormField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Referencia (opcional)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(dialogContext).pop(
                AddressModel(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  label: labelController.text.trim(),
                  street: streetController.text.trim(),
                  city: cityController.text.trim(),
                  reference: referenceController.text.trim().isEmpty
                      ? null
                      : referenceController.text.trim(),
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newAddress == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await ref.read(userRepositoryProvider).addAddress(user.uid, newAddress);
    } catch (e) {
      if (mounted) {
        setState(() => _addressSaveError = true);
      }
      return;
    }

    if (mounted) {
      setState(() {
        selectedAddress = newAddress;
        _showAddressError = false;
        _addressSaveError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(currentUserAddressesProvider);
    final service = widget.service;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                service.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '\$${service.price.toStringAsFixed(2)}',
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
              const SizedBox(height: 12),
              Text(
                service.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Text(
                'Dirección del servicio',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              addressesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, stack) => const Text(
                  'No se pudieron cargar las direcciones.',
                  style: TextStyle(color: Colors.red),
                ),
                data: (addresses) {
                  if (addresses.isEmpty) {
                    return const Text('No tienes direcciones guardadas.');
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: addresses.map((address) {
                      final isSelected = selectedAddress?.id == address.id;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(address.label),
                        subtitle: Text(address.fullAddress),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            selectedAddress = address;
                            _showAddressError = false;
                            _addressSaveError = false;
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),
              TextButton.icon(
                onPressed: _showAddAddressDialog,
                icon: const Icon(Icons.add),
                label: const Text('Agregar dirección'),
              ),
              if (_addressSaveError)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'No se pudo guardar la dirección.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              if (_showAddressError)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Selecciona una dirección para continuar.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (selectedAddress == null) {
                      setState(() => _showAddressError = true);
                      return;
                    }
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(
                        builder: (context) => CheckoutScreen(
                          service: widget.service,
                          selectedAddress: selectedAddress!,
                        ),
                      ),
                    );
                  },
                  child: const Text('Solicitar Servicio'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
