import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/address_model.dart';
import '../data/user_repository.dart';

class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({super.key});

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  static const _initialPosition = LatLng(19.4326, -99.1332);
  final _geocoding = Geocoding(locale: const Locale('es'));

  LatLng _currentCenter = _initialPosition;
  String _currentAddress = 'Buscando dirección...';
  bool _isResolvingAddress = true;
  bool _hasResolvedAddress = false;
  bool _isSaving = false;
  int _geocodeGeneration = 0;

  void _onCameraMove(CameraPosition position) {
    _geocodeGeneration++;
    setState(() {
      _currentCenter = position.target;
      _isResolvingAddress = true;
      _hasResolvedAddress = false;
      _currentAddress = 'Buscando dirección...';
    });
  }

  Future<void> _resolveAddress() async {
    final generation = ++_geocodeGeneration;
    final center = _currentCenter;

    setState(() {
      _isResolvingAddress = true;
      _hasResolvedAddress = false;
    });

    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        center.latitude,
        center.longitude,
      );
      if (!mounted || generation != _geocodeGeneration) return;

      if (placemarks.isEmpty) {
        setState(() {
          _currentAddress = 'No se encontró una dirección para esta ubicación.';
          _isResolvingAddress = false;
        });
        return;
      }

      final placemark = placemarks.first;
      final parts =
          [
                placemark.street,
                placemark.subLocality,
                placemark.locality,
                placemark.administrativeArea,
                placemark.country,
              ]
              .whereType<String>()
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty);
      final address = parts.join(', ');

      setState(() {
        _currentAddress = address.isEmpty
            ? 'Dirección no disponible para esta ubicación.'
            : address;
        _hasResolvedAddress = address.isNotEmpty;
        _isResolvingAddress = false;
      });
    } catch (error) {
      if (!mounted || generation != _geocodeGeneration) return;
      setState(() {
        _currentAddress = 'No se pudo determinar la dirección.';
        _isResolvingAddress = false;
        _hasResolvedAddress = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al buscar la dirección: $error')),
      );
    }
  }

  Future<List<String>?> _requestAddressDetails() async {
    final aliasController = TextEditingController();
    final referenceController = TextEditingController();

    try {
      return await showDialog<List<String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF252525),
          title: const Text(
            'Detalles de la dirección',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: aliasController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Alias (Casa, Oficina...)',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              TextField(
                controller: referenceController,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Referencia (Portón negro...)',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final alias = aliasController.text.trim();
                if (alias.isEmpty) return;
                Navigator.of(dialogContext)
                    .pop([alias, referenceController.text.trim()]);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
    } finally {
      aliasController.dispose();
      referenceController.dispose();
    }
  }

  Future<void> _confirmLocation() async {
    if (_isSaving || !_hasResolvedAddress) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Inicia sesión para guardar una dirección.');
      return;
    }

    final details = await _requestAddressDetails();
    if (details == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final address = AddressModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        alias: details[0],
        street: _currentAddress,
        reference: details[1],
        latitude: _currentCenter.latitude,
        longitude: _currentCenter.longitude,
      );
      await ref
          .read(currentUserControllerProvider.notifier)
          .addAddress(address);

      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('No se pudo guardar la dirección: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Selecciona tu ubicación'),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _initialPosition,
              zoom: 16,
            ),
            onCameraMove: _onCameraMove,
            onCameraIdle: () => unawaited(_resolveAddress()),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          const Align(
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.only(bottom: 42),
              child: Icon(Icons.location_on, size: 50, color: Colors.red),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (_isResolvingAddress) ...[
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            _currentAddress,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: !_hasResolvedAddress || _isSaving
                            ? null
                            : _confirmLocation,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6A11CB),
                          foregroundColor: Colors.white,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Confirmar esta ubicación'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
