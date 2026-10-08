import 'address_model.dart';

class UserModel {
  static const double defaultBalance = 10000.0;

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? bio;
  final String? profilePictureUrl;
  final bool isProviderSetupComplete;
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
    this.phone = '',
    this.bio,
    this.profilePictureUrl,
    this.isProviderSetupComplete = false,
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
      phone: map['phone']?.toString() ?? '',
      bio: map['bio']?.toString(),
      profilePictureUrl: _profilePictureUrlFrom(map),
      isProviderSetupComplete: map['isProviderSetupComplete'] == true,
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
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'bio': bio ?? '',
      'profilePictureUrl': profilePictureUrl ?? '',
      'isProviderSetupComplete': isProviderSetupComplete,
      'roles': roles,
      'skills': skills,
      'savedServices': savedServices,
      'addresses': addresses.map((address) => address.toMap()).toList(),
      'rating': rating,
      'balance': balance,
    };
  }

  static String? _profilePictureUrlFrom(Map<String, dynamic> map) {
    final profilePictureUrl = map['profilePictureUrl']?.toString();
    if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
      return profilePictureUrl;
    }

    final legacyPhotoUrl = map['photoUrl']?.toString();
    return legacyPhotoUrl?.isEmpty == true ? null : legacyPhotoUrl;
  }

  UserModel copyWith({
    String? bio,
    String? profilePictureUrl,
    List<String>? skills,
    bool? isProviderSetupComplete,
    List<String>? savedServices,
    List<AddressModel>? addresses,
    double? balance,
  }) {
    return UserModel(
      uid: uid,
      name: name,
      email: email,
      phone: phone,
      bio: bio ?? this.bio,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      isProviderSetupComplete:
          isProviderSetupComplete ?? this.isProviderSetupComplete,
      roles: roles,
      skills: skills ?? this.skills,
      savedServices: savedServices ?? this.savedServices,
      addresses: addresses ?? this.addresses,
      rating: rating,
      balance: balance ?? this.balance,
    );
  }
}
