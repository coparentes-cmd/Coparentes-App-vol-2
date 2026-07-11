import 'package:flutter/material.dart';

import 'enums.dart';

class Expense {
  final String id;
  final String title;
  final double amount;
  final String currency;
  final String category;
  final String? childId;
  final String paidBy;
  final double splitRatio;
  final DateTime date;
  final String? receiptUrl;
  final bool hasReceipt;
  final ExpenseStatus status;
  final String? note;
  final String hash;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    this.currency = 'PLN',
    required this.category,
    this.childId,
    required this.paidBy,
    required this.splitRatio,
    required this.date,
    this.receiptUrl,
    this.hasReceipt = false,
    required this.status,
    this.note,
    required this.hash,
  });

  double get amountDue => amount * splitRatio;

  Color get statusColor {
    switch (status) {
      case ExpenseStatus.pending:
        return const Color(0xFFF57C00);
      case ExpenseStatus.accepted:
        return const Color(0xFF388E3C);
      case ExpenseStatus.disputed:
        return const Color(0xFFD32F2F);
      case ExpenseStatus.settled:
        return const Color(0xFF546E7A);
    }
  }

  String get statusLabel {
    switch (status) {
      case ExpenseStatus.pending:
        return 'Oczekuje';
      case ExpenseStatus.accepted:
        return 'Zaakceptowany';
      case ExpenseStatus.disputed:
        return 'Sporny';
      case ExpenseStatus.settled:
        return 'Rozliczony';
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case 'Szkoła':
        return Icons.school;
      case 'Zdrowie':
        return Icons.medical_services;
      case 'Zajęcia':
        return Icons.sports;
      case 'Ubrania':
        return Icons.checkroom;
      case 'Jedzenie':
        return Icons.restaurant;
      case 'Transport':
        return Icons.directions_car;
      default:
        return Icons.receipt_long;
    }
  }
}
