import 'package:brothers_coffee_pos/core/money.dart';
import 'package:brothers_coffee_pos/domain/entities/catalog.dart';
import 'package:brothers_coffee_pos/features/pos/presentation/basket_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('basket keeps exact millime total while quantities change', () {
    final product = Product(
      id: 'coffee',
      categoryId: 'hot',
      name: 'Café',
      price: Money(1750),
      isActive: true,
      sortOrder: 0,
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
      revision: 1,
    );
    final basket = BasketController()
      ..add(product)
      ..add(product);
    expect(basket.lines.single.quantity, 2);
    expect(basket.total.millimes, 3500);
    basket.decrement(product);
    expect(basket.total.millimes, 1750);
    basket.remove(product.id);
    expect(basket.total, const Money.zero());
  });
}
