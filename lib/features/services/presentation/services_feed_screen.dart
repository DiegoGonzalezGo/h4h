import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/services_repository.dart';
import '../../matches/data/matches_repository.dart';
import '../../users/data/address_model.dart';
import '../../users/data/user_repository.dart';
import 'service_card.dart';

// Lo convertimos a Stateful para manejar el texto de búsqueda y la categoría seleccionada
class ServicesFeedScreen extends ConsumerStatefulWidget {
  const ServicesFeedScreen({super.key});

  @override
  ConsumerState<ServicesFeedScreen> createState() => _ServicesFeedScreenState();
}

class _ServicesFeedScreenState extends ConsumerState<ServicesFeedScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Todas';
  final List<String> _categories = [
    'Todas',
    'Tecnología',
    'Educación',
    'Hogar',
    'Salud',
    'General',
  ];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _showCancelDialog(BuildContext context, String matchId) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar servicio'),
        content: const Text(
          '¿Estás seguro de que deseas cancelar este servicio?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;

    try {
      await ref.read(matchesRepositoryProvider).cancelMatch(matchId);
      ref.invalidate(clientActiveMatchesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servicio cancelado correctamente.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cancelar el servicio: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(activeServicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicios Disponibles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
            tooltip: 'Top Proveedores',
            onPressed: () {
              context.push('/ranking');
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, size: 28),
            tooltip: 'Mi Perfil',
            onPressed: () {
              context.push('/profile'); // Navega a la pantalla de perfil
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar servicios...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value.toLowerCase());
                      },
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Categorías',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = category);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Todos los servicios',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            servicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, stack) => Center(child: Text('Error: $e')),
              data: (services) {
                // AQUÍ APLICAMOS EL FILTRO EN TIEMPO REAL
                final filteredServices = services.where((service) {
                  // Filtro por texto
                  final matchesSearch =
                      service.title.toLowerCase().contains(_searchQuery) ||
                      service.description.toLowerCase().contains(_searchQuery);
                  // Filtro por categoría
                  final matchesCategory =
                      _selectedCategory == 'Todas' ||
                      service.category == _selectedCategory;

                  return matchesSearch && matchesCategory;
                }).toList();

                if (filteredServices.isEmpty) {
                  return const Center(
                    child: Text('No se encontraron servicios.'),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredServices.length,
                  itemBuilder: (context, index) {
                    final service = filteredServices[index];

                    return ServiceCard(
                      service: service,
                      onTap: () => _showServiceModal(context, service),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showServiceModal(BuildContext context, dynamic match) {
    AddressModel? selectedAddress;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Consumer(
            builder: (context, modalRef, child) {
              final activeMatches =
                  (modalRef.watch(clientActiveMatchesProvider).value ?? [])
                      .where((item) => item.status != 'cancelled')
                      .toList();
              final existingMatch = activeMatches
                  .where((item) => item.serviceId == match.id)
                  .firstOrNull;
              final isRequested = existingMatch != null;
              final savedAddresses =
                  modalRef
                      .watch(currentUserControllerProvider)
                      .value
                      ?.addresses ??
                  const <AddressModel>[];
              final providerProfileAsync = modalRef.watch(
                providerProfileProvider(match.providerId),
              );

              String buttonText = 'Solicitar Servicio';
              if (isRequested) {
                if (existingMatch.status == 'pending') {
                  buttonText = 'Pendiente';
                } else if (existingMatch.status == 'accepted') {
                  buttonText = 'Aceptada';
                } else if (existingMatch.status == 'rejected') {
                  buttonText = 'Rechazada';
                } else if (existingMatch.status == 'completed') {
                  buttonText = 'Completada';
                }
              }

              return StatefulBuilder(
                builder: (context, setModalState) => ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                    maxWidth: 520,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6A11CB).withValues(alpha: 0.6),
                          offset: const Offset(-6, -6),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: const Color(0xFF2575FC).withValues(alpha: 0.6),
                          offset: const Offset(6, 6),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: 'Cerrar',
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                          Text(
                            match.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          providerProfileAsync.when(
                            data: (data) => Text(
                              'Proveedor: ${data['name'] ?? 'Proveedor'}',
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
                          Text(
                            match.description,
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '\$${match.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF00B4DB),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (!isRequested) ...[
                            const Text(
                              'Selecciona una dirección para el servicio',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (savedAddresses.isEmpty)
                              const Text(
                                'Aún no tienes direcciones guardadas.',
                                style: TextStyle(color: Colors.white60),
                              )
                            else
                              SizedBox(
                                height: 82,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: savedAddresses.length,
                                  itemBuilder: (context, index) {
                                    final address = savedAddresses[index];
                                    final isSelected =
                                        selectedAddress?.id == address.id;

                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        selected: isSelected,
                                        onSelected: (_) {
                                          setModalState(() {
                                            selectedAddress = address;
                                          });
                                        },
                                        backgroundColor: const Color(
                                          0xFF1E1E1E,
                                        ),
                                        selectedColor: const Color(0xFF1E1E1E),
                                        side: BorderSide(
                                          color: isSelected
                                              ? Colors.cyanAccent
                                              : Colors.grey.shade700,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                        label: SizedBox(
                                          width: 130,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                address.alias,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? Colors.cyanAccent
                                                      : Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                address.street,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 24),
                          ],
                          if (isRequested && existingMatch.status == 'pending')
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF303030),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Pendiente',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                TextButton.icon(
                                  onPressed: () => _showCancelDialog(
                                    context,
                                    existingMatch.id,
                                  ),
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    color: Colors.redAccent,
                                  ),
                                  label: const Text(
                                    'Cancelar',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            )
                          else
                            InkWell(
                              onTap: isRequested || selectedAddress == null
                                  ? null
                                  : () async {
                                      try {
                                        await modalRef
                                            .read(matchesRepositoryProvider)
                                            .requestService(
                                              match.id,
                                              match.providerId,
                                              serviceAddress: selectedAddress,
                                            );
                                      } catch (error) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    error.toString().replaceAll(
                                                      'Exception: ',
                                                      '',
                                                    ),
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                        }
                                      }
                                    },
                              borderRadius: BorderRadius.circular(10),
                              child: Ink(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isRequested
                                      ? null
                                      : const LinearGradient(
                                          colors: [
                                            Color(0xFF6A11CB),
                                            Color(0xFF2575FC),
                                          ],
                                        ),
                                  color: isRequested
                                      ? const Color(0xFF303030)
                                      : null,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    buttonText,
                                    style: const TextStyle(
                                      color: Colors.white,
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
              );
            },
          ),
        ),
      ),
    );
  }
}
