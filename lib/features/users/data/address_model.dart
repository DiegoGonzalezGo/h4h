class AddressModel {
  const AddressModel({
    required this.id,
    required this.alias,
    required this.street,
    required this.reference,
  });

  final String id;
  final String alias;
  final String street;
  final String reference;

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: map['id']?.toString() ?? '',
      alias: map['alias']?.toString() ?? '',
      street: map['street']?.toString() ?? '',
      reference: map['reference']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'alias': alias,
    'street': street,
    'reference': reference,
  };
}
