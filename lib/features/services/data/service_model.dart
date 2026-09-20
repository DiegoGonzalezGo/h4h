class ServiceModel {
  final String id;
  final String providerId; // El UID del usuario que ofrece el servicio
  final String title;
  final String description;
  final double price;
  final bool isActive;

  ServiceModel({
    required this.id,
    required this.providerId,
    required this.title,
    required this.description,
    required this.price,
    this.isActive = true,
  });

  factory ServiceModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ServiceModel(
      id: documentId,
      providerId: map['providerId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId,
      'title': title,
      'description': description,
      'price': price,
      'isActive': isActive,
    };
  }
}