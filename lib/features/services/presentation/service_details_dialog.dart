import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../matches/data/matches_repository.dart';
import '../../users/data/address_model.dart';
import '../../users/data/user_repository.dart';
import 'checkout_screen.dart';
import '../data/service_model.dart';
import '../data/services_repository.dart';

Future<void> showServiceDetailsDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ServiceModel service,
}) async {
  final navigationContext = context;
  AddressModel? selectedAddress;

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) => BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Consumer(
          builder: (context, dialogRef, child) {
            final requestStatusAsync = dialogRef.watch(
              requestStatusProvider(service.id),
            );
            final existingMatch = requestStatusAsync.value;
            final isRequested = existingMatch != null;
            final isCheckingRequest =
                requestStatusAsync.isLoading && existingMatch == null;
            final addresses =
                dialogRef
                    .watch(currentUserControllerProvider)
                    .value
                    ?.addresses ??
                const <AddressModel>[];
            final providerProfileAsync = dialogRef.watch(
              providerProfileProvider(service.providerId),
            );

            final statusLabel = switch (existingMatch?.status) {
              'pending' => 'Pendiente',
              'accepted' => 'Aceptada',
              'rejected' => 'Rechazada',
              'completed' => 'Completada',
              _ => 'Solicitar Servicio',
            };

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
                          service.title,
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
                          service.description,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '\$${service.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF00B4DB),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!isRequested) ...[
                          const SizedBox(height: 22),
                          const Text(
                            'Selecciona una dirección para el servicio',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (addresses.isEmpty)
                            const Text(
                              'Aún no tienes direcciones guardadas.',
                              style: TextStyle(color: Colors.white60),
                            )
                          else
                            SizedBox(
                              height: 82,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: addresses.length,
                                itemBuilder: (context, index) {
                                  final address = addresses[index];
                                  final isSelected =
                                      selectedAddress?.id == address.id;

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      selected: isSelected,
                                      onSelected: (_) => setModalState(
                                        () => selectedAddress = address,
                                      ),
                                      backgroundColor: const Color(0xFF1E1E1E),
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
                        ],
                        const SizedBox(height: 24),
                        if (isRequested && existingMatch.status == 'pending')
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Pendiente',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _cancelPendingRequest(
                                  context,
                                  dialogRef,
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
                        else if (existingMatch?.status == 'accepted')
                          _GradientRequestButton(
                            label: 'Ir al Chat',
                            onPressed: () =>
                                context.push('/chat/${existingMatch!.id}'),
                          )
                        else
                          _GradientRequestButton(
                            label: statusLabel,
                            onPressed: isRequested || isCheckingRequest
                                ? null
                                : () {
                                    if (selectedAddress == null) {
                                      ScaffoldMessenger.of(navigationContext)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Selecciona una dirección',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      return;
                                    }

                                    final address = selectedAddress!;
                                    Navigator.pop(dialogContext);
                                    Navigator.push(
                                      navigationContext,
                                      MaterialPageRoute<void>(
                                        builder: (context) => CheckoutScreen(
                                          servicio: service,
                                          selectedAddress: address,
                                        ),
                                      ),
                                    );
                                  },
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

Future<void> _cancelPendingRequest(
  BuildContext context,
  WidgetRef ref,
  String matchId,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Cancelar solicitud'),
      content: const Text('¿Seguro que quieres cancelar esta solicitud?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('No'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Sí, cancelar'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await ref.read(matchesRepositoryProvider).cancelMatch(matchId);
    ref.invalidate(clientActiveMatchesProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cancelar la solicitud: $error')),
      );
    }
  }
}

class _GradientRequestButton extends StatelessWidget {
  const _GradientRequestButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              gradient: onPressed == null
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                    ),
              color: onPressed == null ? const Color(0xFF303030) : null,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
