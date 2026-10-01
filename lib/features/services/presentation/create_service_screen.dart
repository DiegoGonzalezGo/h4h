import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/services_repository.dart';

class CreateServiceScreen extends ConsumerStatefulWidget {
  const CreateServiceScreen({super.key});

  @override
  ConsumerState<CreateServiceScreen> createState() =>
      _CreateServiceScreenState();
}

class _CreateServiceScreenState extends ConsumerState<CreateServiceScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();

  String _selectedCategory = 'Tecnología';
  bool _isLoading = false;

  // 1. FALTABA: La lista de categorías disponibles
  final List<String> _categories = [
    'Tecnología',
    'Educación',
    'Hogar',
    'Salud',
    'General',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _priceController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final price = double.tryParse(_priceController.text) ?? 0.0;

      // 2. FALTABA: Enviar la categoría seleccionada al repositorio
      // Nota: Si tu repositorio usa parámetros posicionales, quita los nombres (title:, description:, etc.)
      await ref
          .read(servicesRepositoryProvider)
          .createService(
            _titleController.text.trim(),
            _descController.text.trim(),
            price,
            _selectedCategory, // <-- Pasamos la categoría
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Servicio publicado con éxito ✅'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _fieldDecoration(
    String label,
    IconData icon, {
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey[400]),
      prefixText: prefixText,
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF6A11CB), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicar Servicio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: _fieldDecoration(
                'Título del servicio (ej. Clases de Guitarra)',
                Icons.title,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: _fieldDecoration(
                'Descripción detallada',
                Icons.description,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: _fieldDecoration(
                'Precio (ej. 150.00)',
                Icons.attach_money,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: _fieldDecoration('Categoría', Icons.category),
              items: _categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue!;
                });
              },
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        onTap: _submit,
                        borderRadius: BorderRadius.circular(24),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Center(
                            child: Text(
                              'Publicar Oferta',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
