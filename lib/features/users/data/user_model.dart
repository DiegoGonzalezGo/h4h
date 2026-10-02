import 'address_model.dart';

class UserModel {
  static const double defaultBalance = 10000.0;

  final String uid;
  final String name;
  final String email;
  final List<String> roles; // ej: ['client', 'provider']
  final List<String>? skills;
  final List<String> savedServices;
  final List<AddressModel> addresses;
  final double rating;
  final double balance;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.roles,
    this.skills,
    this.savedServices = const [],
    this.addresses = const [],
    this.rating = 0.0,
    this.balance = defaultBalance,
  });

  // Convierte el mapa de Firebase a un objeto Dart
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    final rawAddresses = map['addresses'];

    return UserModel(
      uid: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      roles: List<String>.from(map['roles'] ?? []),
      skills: map['skills'] != null ? List<String>.from(map['skills']) : [],
      savedServices: map['savedServices'] is List
          ? List<String>.from(map['savedServices'])
          : const [],
      addresses: rawAddresses is List
          ? rawAddresses
                .whereType<Map>()
                .map(
                  (address) =>
                      AddressModel.fromMap(Map<String, dynamic>.from(address)),
                )
                .toList()
          : const [],
      rating: (map['rating'] ?? 0.0).toDouble(),
      balance: (map['balance'] as num?)?.toDouble() ?? defaultBalance,
    );
  }

  // Convierte el objeto Dart a un formato que Firebase entienda
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'roles': roles,
      'skills': skills,
      'savedServices': savedServices,
      'addresses': addresses.map((address) => address.toMap()).toList(),
      'rating': rating,
      'balance': balance,
    };
  }

  UserModel copyWith({
    List<String>? savedServices,
    List<AddressModel>? addresses,
    double? balance,
  }) {
    return UserModel(
      uid: uid,
      name: name,
      email: email,
      roles: roles,
      skills: skills,
      savedServices: savedServices ?? this.savedServices,
      addresses: addresses ?? this.addresses,
      rating: rating,
      balance: balance ?? this.balance,
    );
  }
}
