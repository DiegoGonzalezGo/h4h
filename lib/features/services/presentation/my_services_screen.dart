import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/service_model.dart';
import '../data/services_repository.dart';

class MyServicesScreen extends ConsumerStatefulWidget {
  const MyServicesScreen({super.key});

  @override
  ConsumerState<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends ConsumerState<MyServicesScreen> {
  InputDecoration _modalFieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey[400]),
      filled: true,
      fillColor: const Color(0xFF292929),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6A11CB)),
      ),
    );
  }

  Future<void> _showEditServiceModal(
    BuildContext context,
    ServiceModel service,
  ) async {
    final titleController = TextEditingController(text: service.title);
    final descriptionController = TextEditingController(
      text: service.description,
    );
    final priceController = TextEditingController(
      text: service.price.toStringAsFixed(2),
    );
    final categories = ['Tecnología', 'Educación', 'Hogar', 'Salud', 'General'];
    var selectedCategory = service.category;
    if (!categories.contains(selectedCategory)) {
      categories.insert(0, selectedCategory);
    }
    var isSaving = false;
    String? formError;

    try {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.85,
                  maxWidth: 520,
                ),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6A11CB).withValues(alpha: 0.6),
                      offset: const Offset(-5, -5),
                      blurRadius: 26,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFF2575FC).withValues(alpha: 0.6),
                      offset: const Offset(5, 5),
                      blurRadius: 26,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Editar servicio',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: titleController,
                        decoration: _modalFieldDecoration(
                          'Título',
                          Icons.title,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descriptionController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: _modalFieldDecoration(
                          'Descripción',
                          Icons.description,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _modalFieldDecoration(
                          'Precio',
                          Icons.attach_money,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: _modalFieldDecoration(
                          'Categoría',
                          Icons.category,
                        ),
                        items: categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (category) {
                          if (category != null) {
                            setDialogState(() => selectedCategory = category);
                          }
                        },
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          formError!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(dialogContext),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final title = titleController.text.trim();
                                    final price = double.tryParse(
                                      priceController.text.trim(),
                                    );
                                    if (title.isEmpty ||
                                        price == null ||
                                        price < 0) {
                                      setDialogState(() {
                                        formError = 'Ingresa un título y un precio válido.';
                                      });
                                      return;
                                    }

                                    setDialogState(() {
                                      isSaving = true;
                                      formError = null;
                                    });
                                    try {
                                      await ref
                                          .read(servicesRepositoryProvider)
                                          .updateService(
                                            serviceId: service.id,
                                            title: title,
                                            description:
                                                descriptionController.text,
                                            price: price,
                                            category: selectedCategory,
                                          );
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext);
                                      }
                                    } catch (error) {
                                      if (dialogContext.mounted) {
                                        setDialogState(() {
                                          formError =
                                              'No se pudo guardar: $error';
                                        });
                                      }
                                    } finally {
                                      if (dialogContext.mounted) {
                                        setDialogState(() => isSaving = false);
                                      }
                                    }
                                  },
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Guardar Cambios'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      titleController.dispose();
      descriptionController.dispose();
      priceController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos los servicios del proveedor logueado
    final myServicesAsync = ref.watch(myServicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Servicios Publicados')),
      body: myServicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
        data: (services) {
          if (services.isEmpty) {
            return const Center(
              child: Text('Aún no has publicado ningún servicio.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];

              return Dismissible(
                key: ValueKey(service.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  ref
                      .read(servicesRepositoryProvider)
                      .deleteService(service.id);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              service.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                decoration: service.isActive
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                          const Spacer(),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white60,
                            ),
                            onSelected: (action) {
                              if (action == 'editar') {
                                _showEditServiceModal(context, service);
                              } else if (action == 'delete') {
                                ref
                                    .read(servicesRepositoryProvider)
                                    .deleteService(service.id);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem<String>(
                                value: 'editar',
                                child: Text(
                                  'Editar',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text(
                                  'Eliminar',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '\$${service.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF00B4DB),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            '• 0 vistas',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Estado del servicio:',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          Switch(
                            value: service.isActive,
                            activeThumbColor: const Color(0xFF2575FC),
                            inactiveThumbColor: const Color(0xFF424242),
                            inactiveTrackColor: const Color(0xFF616161),
                            onChanged: (newValue) {
                              ref
                                  .read(servicesRepositoryProvider)
                                  .toggleServiceStatus(
                                    service.id,
                                    service.isActive,
                                  );
                            },
                          ),
                          Text(
                            service.isActive ? 'Activo' : 'Inactivo',
                            style: TextStyle(
                              color: service.isActive
                                  ? Colors.greenAccent
                                  : Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
