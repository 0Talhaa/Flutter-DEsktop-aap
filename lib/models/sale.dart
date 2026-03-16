import 'package:medical_app/models/sale_item.dart';

class Sale {
  final int? id;
  final DateTime dateTime;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String paymentMethod;
  final String? customerName;
  final List<SaleItem> items;

  Sale({
    this.id,
    required this.dateTime,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    this.customerName,
    required this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateTime': dateTime.toIso8601String(),
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'paymentMethod': paymentMethod,
      'customerName': customerName,
    };
  }
}




