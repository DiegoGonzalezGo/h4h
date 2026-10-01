import 'package:cloud_firestore/cloud_firestore.dart';

import '../../users/data/address_model.dart';

// variables de Modelo de datos para un match entre cliente y proveedor
class MatchModel {
  final String id;
  final String serviceId;
  final String clientId;
  final String clientName; // <-- NUEVO: Guardaremos el nombre real
  final String providerId;
  final String status;
  final DateTime? completedAt;
  final double? rating;
  final AddressModel? serviceAddress;
  final String? serviceTitle;
  final String? serviceDescription;
  final double? servicePrice;
  final String? serviceCategory;
  final String? paymentMethod;

  // Constructor
  MatchModel({
    required this.id,
    required this.serviceId,
    required this.clientId,
    required this.clientName, // <-- NUEVO
    required this.providerId,
    this.status = 'pending',
    this.completedAt,
    this.rating,
    this.serviceAddress,
    this.serviceTitle,
    this.serviceDescription,
    this.servicePrice,
    this.serviceCategory,
    this.paymentMethod,
  });

  factory MatchModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MatchModel(
      id: documentId,
      serviceId: map['serviceId'] ?? '',
      clientId: map['clientId'] ?? '',
      clientName:
          map['clientName'] ?? 'Cliente', // <-- NUEVO (con valor por defecto)
      providerId: map['providerId'] ?? '',
      status: map['status'] ?? 'pending',
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      rating: (map['rating'] as num?)?.toDouble(),
      serviceAddress: map['serviceAddress'] is Map
          ? AddressModel.fromMap(
              Map<String, dynamic>.from(map['serviceAddress'] as Map),
            )
          : null,
      serviceTitle: map['serviceTitle'] as String?,
      serviceDescription: map['serviceDescription'] as String?,
      servicePrice: (map['servicePrice'] as num?)?.toDouble(),
      serviceCategory: map['serviceCategory'] as String?,
      paymentMethod: map['paymentMethod'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serviceId': serviceId,
      'clientId': clientId,
      'clientName': clientName, // <-- NUEVO
      'providerId': providerId,
      'status': status,
      if (rating != null) 'rating': rating,
      if (serviceAddress != null) 'serviceAddress': serviceAddress!.toMap(),
      if (serviceTitle != null) 'serviceTitle': serviceTitle,
      if (serviceDescription != null) 'serviceDescription': serviceDescription,
      if (servicePrice != null) 'servicePrice': servicePrice,
      if (serviceCategory != null) 'serviceCategory': serviceCategory,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
    };
  }
}
