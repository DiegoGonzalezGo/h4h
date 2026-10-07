import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.isPositive,
    required this.createdAt,
    this.requestId,
  });

  final String id;
  final String title;
  final double amount;
  final bool isPositive;
  final DateTime createdAt;
  final String? requestId;

  factory TransactionModel.fromMap(
    Map<String, dynamic> map, {
    required String documentId,
  }) {
    final rawCreatedAt = map['createdAt'];
    final createdAt = switch (rawCreatedAt) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime dateTime => dateTime,
      _ => DateTime.fromMillisecondsSinceEpoch(0),
    };
    final rawAmount = map['amount'];

    return TransactionModel(
      id: documentId,
      title: map['title']?.toString() ?? 'Movimiento de billetera',
      amount: rawAmount is num ? rawAmount.toDouble() : 0,
      isPositive: map['isPositive'] == true,
      createdAt: createdAt,
      requestId: map['requestId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'amount': amount,
    'isPositive': isPositive,
    'createdAt': Timestamp.fromDate(createdAt),
    if (requestId != null) 'requestId': requestId,
  };
}
