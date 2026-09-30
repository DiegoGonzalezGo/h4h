// Modelo de datos para una dirección guardada del usuario
class AddressModel {
  final String id;
  final String label;
  final String street;
  final String city;
  final String? reference;

  AddressModel({
    required this.id,
    required this.label,
    required this.street,
    required this.city,
    this.reference,
  });

  String get fullAddress => city.isEmpty ? street : '$street, $city';

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: map['id'] ?? '',
      label: map['label'] ?? '',
      street: map['street'] ?? '',
      city: map['city'] ?? '',
      reference: map['reference'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'street': street,
      'city': city,
      'reference': reference,
    };
  }
}
