import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/services_repository.dart';
import '../../matches/data/matches_repository.dart';
import '../../notifications/notifications_service.dart';

// Lo convertimos a Stateful para manejar el texto de búsqueda y la categoría seleccionada
class ServicesFeedScreen extends ConsumerStatefulWidget {
  const ServicesFeedScreen({super.key});

  @override
  ConsumerState<ServicesFeedScreen> createState() => _ServicesFeedScreenState();
}

class _ServicesFeedScreenState extends ConsumerState<ServicesFeedScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Todas';
  final List<String> _categories = ['Todas', 'Tecnología', 'Educación', 'Hogar', 'Salud', 'General'];

  @override
  void initState() {
    super.initState();
    // Ejecutamos la configuración de notificaciones justo después de dibujar la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsServiceProvider).initialize();
    });
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
      body: Column(
        children: [
          // 1. BARRA DE BÚSQUEDA
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar servicios...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),
          
          // 2. FILTRO DE CATEGORÍAS (Píldoras deslizables)
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
                      if (selected) setState(() => _selectedCategory = category);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // 3. LA LISTA DE SERVICIOS
          Expanded(
            child: servicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, stack) => Center(child: Text('Error: $e')),
              data: (services) {
                // AQUÍ APLICAMOS EL FILTRO EN TIEMPO REAL
                final filteredServices = services.where((service) {
                  // Filtro por texto
                  final matchesSearch = service.title.toLowerCase().contains(_searchQuery) ||
                                      service.description.toLowerCase().contains(_searchQuery);
                  // Filtro por categoría
                  final matchesCategory = _selectedCategory == 'Todas' || service.category == _selectedCategory;
                  
                  return matchesSearch && matchesCategory;
                }).toList();

                if (filteredServices.isEmpty) {
                  return const Center(child: Text('No se encontraron servicios.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredServices.length,
                  itemBuilder: (context, index) {
                    final service = filteredServices[index];
                    
                    return Consumer(
                      builder: (context, ref, child) {
                        final myMatches = ref.watch(clientMatchesProvider).value ?? [];
                        final existingMatch = myMatches.where((m) => m.serviceId == service.id).firstOrNull;
                        final isRequested = existingMatch != null;

                        String buttonText = 'Solicitar Servicio';
                        if (isRequested) {
                          if (existingMatch.status == 'pending') buttonText = 'Pendiente';
                          else if (existingMatch.status == 'accepted') buttonText = 'Aceptada';
                          else if (existingMatch.status == 'rejected') buttonText = 'Rechazada';
                          else if (existingMatch.status == 'completed') buttonText = 'Completada';
                        }

                        final providerProfileAsync = ref.watch(providerProfileProvider(service.providerId));

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        service.title,
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '\$${service.price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                providerProfileAsync.when(
                                  data: (data) {
                                    final int reviews = data['totalReviews'] ?? 0;
                                    final double rating = (data['averageRating'] ?? 0.0).toDouble();
                                    
                                    if (reviews == 0) {
                                      // ENVOLVEMOS EN InkWell EL CASO SIN RESEÑAS
                                      return InkWell(
                                        onTap: () {
                                          context.push('/user/${service.providerId}');
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 4.0),
                                          child: Text(
                                            'Nuevo proveedor (Sin calificaciones) - Toca para ver perfil', 
                                            style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontStyle: FontStyle.italic)
                                          ),
                                        ),
                                      );
                                    }

                                    // ENVOLVEMOS EN InkWell EL CASO CON ESTRELLAS
                                    return InkWell(
                                      onTap: () {
                                        context.push('/user/${service.providerId}');
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          children: [
                                            // Agregamos un pequeño ícono para indicar que es clickeable
                                            const Icon(Icons.account_circle, size: 16, color: Colors.blue),
                                            const SizedBox(width: 4),
                                            const Text('Ver perfil', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                                            const SizedBox(width: 12),
                                            
                                            // Tus estrellas originales
                                            const Icon(Icons.star, color: Colors.amber, size: 20),
                                            const SizedBox(width: 4),
                                            Text(
                                              rating.toStringAsFixed(1),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            Text(
                                              ' ($reviews reseñas)',
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  loading: () => const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4.0),
                                    child: SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                  error: (e, stack) => const SizedBox.shrink(),
                                ),

                                const SizedBox(height: 8),
                                Text(
                                  service.description,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Etiqueta visual de la categoría en la tarjeta
                                const SizedBox(height: 8),
                                Chip(
                                  label: Text(service.category, style: const TextStyle(fontSize: 10)),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: Colors.grey.shade200,
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.tonal(
                                    onPressed: isRequested ? null : () async {
                                      try {
                                        await ref.read(matchesRepositoryProvider).requestService(
                                          service.id,
                                          service.providerId,
                                        );
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString().replaceAll('Exception: ', '')), 
                                              backgroundColor: Colors.red
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: Text(buttonText),
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}