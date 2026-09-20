class MatchModel {
  final String id;
  final String serviceId; // El servicio que se solicitó
  final String clientId; // Quien pide el servicio
  final String providerId; // Quien dará el servicio
  final String status; // 'pending', 'accepted', 'rejected', 'completed'

  MatchModel({
    required this.id,
    required this.serviceId,
    required this.clientId,
    required this.providerId,
    this.status = 'pending', // Por defecto inicia pendiente
  });

  factory MatchModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MatchModel(
      id: documentId,
      serviceId: map['serviceId'] ?? '',
      clientId: map['clientId'] ?? '',
      providerId: map['providerId'] ?? '',
      status: map['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serviceId': serviceId,
      'clientId': clientId,
      'providerId': providerId,
      'status': status,
    };
  }
}