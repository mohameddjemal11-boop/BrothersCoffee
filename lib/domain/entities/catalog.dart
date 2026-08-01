import '../../core/money.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    this.imageRef,
  });

  final String id;
  final String name;
  final String? imageRef;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
}

class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    this.imageRef,
  });

  final String id;
  final String categoryId;
  final String name;
  final Money price;
  final String? imageRef;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
}
