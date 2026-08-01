import 'package:flutter/foundation.dart';

import '../../../core/money.dart';
import '../../../domain/entities/catalog.dart';

class BasketLine {
  const BasketLine({required this.product, required this.quantity});
  final Product product;
  final int quantity;
  Money get total => product.price * quantity;
}

class BasketController extends ChangeNotifier {
  final Map<String, BasketLine> _lines = {};
  List<BasketLine> get lines => _lines.values.toList(growable: false);
  Money get total => sumMoney(lines.map((line) => line.total));
  void add(Product product) {
    final line = _lines[product.id];
    _lines[product.id] = BasketLine(
      product: product,
      quantity: (line?.quantity ?? 0) + 1,
    );
    notifyListeners();
  }

  void decrement(Product product) {
    final line = _lines[product.id];
    if (line == null) return;
    if (line.quantity == 1) {
      _lines.remove(product.id);
    } else {
      _lines[product.id] = BasketLine(
        product: product,
        quantity: line.quantity - 1,
      );
    }
    notifyListeners();
  }

  void remove(String id) {
    _lines.remove(id);
    notifyListeners();
  }
}
