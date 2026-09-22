import 'package:cloud_firestore/cloud_firestore.dart';

// variables de Modelo de datos para un match entre cliente y proveedor
class MatchModel {
  final String id;
  final String serviceId;
  final String clientId;
  final String clientName; // <-- NUEVO: Guardaremos el nombre real
  final String providerId;
  final String status;
  final DateTime? completedAt;

// Constructor
  MatchModel({
    required this.id,
    required this.serviceId,
    required this.clientId,
    required this.clientName, // <-- NUEVO
    required this.providerId,
    this.status = 'pending',
    this.completedAt,
  });

  factory MatchModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MatchModel(
      id: documentId,
      serviceId: map['serviceId'] ?? '',
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'] ?? 'Cliente', // <-- NUEVO (con valor por defecto)
      providerId: map['providerId'] ?? '',
      status: map['status'] ?? 'pending',
      completedAt: map['completedAt'] != null 
          ? (map['completedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serviceId': serviceId,
      'clientId': clientId,
      'clientName': clientName, // <-- NUEVO
      'providerId': providerId,
      'status': status,
    };
  }
}