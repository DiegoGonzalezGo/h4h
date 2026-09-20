class UserModel {
  final String uid;
  final String name;
  final String email;
  final List<String> roles; // ej: ['client', 'provider']
  final List<String>? skills; 
  final double rating;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.roles,
    this.skills,
    this.rating = 0.0,
  });

  // Convierte el mapa de Firebase a un objeto Dart
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      roles: List<String>.from(map['roles'] ?? []),
      skills: map['skills'] != null ? List<String>.from(map['skills']) : [],
      rating: (map['rating'] ?? 0.0).toDouble(),
    );
  }

  // Convierte el objeto Dart a un formato que Firebase entienda
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'roles': roles,
      'skills': skills,
      'rating': rating,
    };
  }
}