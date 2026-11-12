class AddressModel {
  const AddressModel({
    required this.id,
    required this.alias,
    required this.street,
    required this.reference,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String alias;
  final String street;
  final String reference;
  final double? latitude;
  final double? longitude;

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: map['id']?.toString() ?? '',
      alias: map['alias']?.toString() ?? '',
      street: map['street']?.toString() ?? '',
      reference: map['reference']?.toString() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'alias': alias,
    'street': street,
    'reference': reference,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };
}
