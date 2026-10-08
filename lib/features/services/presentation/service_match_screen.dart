import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../users/data/address_model.dart';
import '../../users/data/user_repository.dart';
import '../data/service_model.dart';
import '../data/services_repository.dart';
import 'checkout_screen.dart';
import 'service_card.dart';

class ServiceMatchScreen extends ConsumerStatefulWidget {
  const ServiceMatchScreen({this.categoriaBuscada, super.key});

  final String? categoriaBuscada;

  @override
  ConsumerState<ServiceMatchScreen> createState() => _ServiceMatchScreenState();
}

class _ServiceMatchScreenState extends ConsumerState<ServiceMatchScreen> {
  bool isSearching = true;
  List<ServiceModel> _services = const [];
  int _currentIndex = 0;
  String? _selectedAddressId;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      isSearching = true;
      _loadError = null;
    });

    try {
      final services = await ref
          .read(servicesRepositoryProvider)
          .fetchAvailableServices(category: widget.categoriaBuscada);
      if (!mounted) return;
      setState(() {
        _services = services;
        _currentIndex = 0;
        isSearching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        isSearching = false;
      });
    }
  }

  void _showNextService() {
    setState(() => _currentIndex++);
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(currentUserControllerProvider);
    final addresses = addressesAsync.value?.addresses ?? const <AddressModel>[];
    AddressModel? selectedAddress;
    for (final address in addresses) {
      if (address.id == _selectedAddressId) {
        selectedAddress = address;
        break;
      }
    }
    selectedAddress ??= addresses.isEmpty ? null : addresses.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Match Inteligente')),
      body: SafeArea(
        child: isSearching
            ? _SearchingView(categoriaBuscada: widget.categoriaBuscada)
            : _loadError != null
            ? _ErrorView(error: _loadError!, onRetry: _loadServices)
            : _currentIndex >= _services.length
            ? const _NoServicesView()
            : _buildServiceView(
                context,
                _services[_currentIndex],
                addressesAsync.isLoading,
                addresses,
                selectedAddress,
              ),
      ),
    );
  }

  Widget _buildServiceView(
    BuildContext context,
    ServiceModel service,
    bool isLoadingAddresses,
    List<AddressModel> addresses,
    AddressModel? selectedAddress,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          shrinkWrap: true,
          children: [
            Text(
              'Opción ${_currentIndex + 1} de ${_services.length}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ServiceCard(service: service),
            const SizedBox(height: 8),
            if (isLoadingAddresses)
              const Center(child: CircularProgressIndicator())
            else if (addresses.isEmpty) ...[
              const Text(
                'Agrega una dirección para poder solicitar este servicio.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => context.push('/my-addresses'),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Agregar dirección'),
              ),
            ] else ...[
              const Text(
                '¿Dónde necesitas el servicio?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final address in addresses)
                    ChoiceChip(
                      label: Text(address.alias),
                      selected: selectedAddress?.id == address.id,
                      onSelected: (_) {
                        setState(() => _selectedAddressId = address.id);
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: _showNextService,
                      icon: const Icon(Icons.close),
                      label: const Text('Buscar otro'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF555555),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: selectedAddress == null
                          ? null
                          : () => context.push(
                              '/confirm-request',
                              extra: ServiceCheckoutArgs(
                                service: service,
                                address: selectedAddress,
                              ),
                            ),
                      icon: const Icon(Icons.check),
                      label: const Text(
                        'Aceptar y Solicitar',
                        textAlign: TextAlign.center,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3767D5),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchingView extends StatelessWidget {
  const _SearchingView({required this.categoriaBuscada});

  final String? categoriaBuscada;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              color: Colors.cyanAccent,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Buscando expertos en ${categoriaBuscada ?? 'todas las áreas'}...',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _NoServicesView extends StatelessWidget {
  const _NoServicesView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'No hay más proveedores por ahora',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/feed'),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Volver al Inicio'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'No se pudieron cargar los proveedores.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Intentar de nuevo'),
            ),
          ],
        ),
      ),
    );
  }
}
