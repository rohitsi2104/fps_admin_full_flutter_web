import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fps_admin/core/api.dart';
import 'package:fps_admin/shared/app_ui.dart';
import 'package:intl/intl.dart';

import '../support/ui_harness.dart';

/// Overflow regression tests for `features/products/product_list_page.dart`.
///
/// The page renders a 2-column grid of product cards. Each card is a faithful
/// re-creation of the private `_ProductCard` widget below: a header row with the
/// product name (plain `Text`, maxLines 1 + ellipsis), an image area, and an
/// info `Row` holding an `Expanded` price (`AppText`) and a trailing quantity
/// wrapped in `Flexible(child: AppText(..., textAlign: TextAlign.right))`. The
/// quick-edit bottom sheet header (name + close button) is also exercised.
///
/// These are strict regression guards: the `Qty:` label is now `Flexible`, so it
/// truncates instead of forcing a horizontal `RenderFlex` overflow. Every config
/// in `kDeviceMatrix` must build with NO tolerated exception.
///
/// Stress data: very long product names, huge prices (1234567.89) and large
/// stock counts, at every device/text-scale in `kDeviceMatrix`.

final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

/// Faithful copy of the private `_ProductCard.build` subtree, minus the
/// network image (we pass `imageUrl == null` so the placeholder icon renders,
/// keeping the test hermetic).
class _ProductCardRepro extends StatelessWidget {
  final ProductLite product;
  final NumberFormat money;
  const _ProductCardRepro({required this.product, required this.money});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOutOfStock = product.stock <= 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: Product Name
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                border: Border(
                  bottom: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.3)),
                ),
              ),
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: cs.surfaceContainerHighest,
                child: const Icon(Icons.inventory_2_outlined,
                    size: 40, color: Colors.grey),
              ),
            ),
            // Info Section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: AppText(
                      money.format(product.price),
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: AppText(
                      'Qty: ${product.stock}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: isOutOfStock ? Colors.red : cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faithful copy of the header Row of the private `_QuickEditSheet`.
Widget _quickEditHeaderRepro(ProductLite p) {
  return Row(
    children: [
      Expanded(
        child: AppText(
          p.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      IconButton(onPressed: () {}, icon: const Icon(Icons.close)),
    ],
  );
}

final _stressProducts = <ProductLite>[
  ProductLite(
    id: 101,
    name: 'Radhasoami Premium Cold-Pressed Groundnut Cooking Oil 5 Litre Tin',
    stock: 999999,
    price: 1234567.89,
  ),
  ProductLite(
    id: 102,
    name: 'Supercalifragilisticexpialidociousproductnamewithnospaces1234567890',
    stock: 0, // out of stock badge
    price: 999999.99,
  ),
  ProductLite(id: 103, name: 'Milk', stock: 3, price: 42.5), // low stock
];

void main() {
  // REGRESSION GUARD (fixed): in `_ProductCard` the info `Row`'s trailing
  // quantity is now `Flexible(child: AppText('Qty: ...', textAlign:
  // TextAlign.right))`, mirroring the `Expanded` price beside it. A wide
  // quantity string now truncates instead of forcing a horizontal RenderFlex
  // overflow. We reproduce faithfully and assert STRICTLY (no tolerated
  // exception) at every config, plus the price never per-character collapses.
  group('ProductListPage product-card grid (Qty overflow fixed)', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('cards build + price never collapses on $cfg', (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // phones use 2 columns (width <= 600)
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _stressProducts.length,
            itemBuilder: (context, i) =>
                _ProductCardRepro(product: _stressProducts[i], money: _money),
          ),
        );

        // Strict: the Flexible `Qty:` label truncates, so there must be NO
        // RenderFlex overflow at any device/text-scale.
        expect(tester.takeException(), isNull);

        // Mission property: price (Expanded AppText) stays one line, no
        // per-character vertical stacking.
        final prices = find.textContaining('₹');
        expect(prices, findsWidgets);
        for (var i = 0; i < prices.evaluate().length; i++) {
          expectNotCollapsed(
            tester,
            prices.at(i),
            fontSize: 15,
            textScale: cfg.textScale,
            maxLines: 1,
            label: 'card price #$i',
          );
        }
      });
    }
  });

  group('ProductListPage quick-edit sheet header holds up', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('sheet header name stays one line on $cfg', (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [_quickEditHeaderRepro(_stressProducts.first)],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expectNotCollapsed(
          tester,
          find.textContaining('Radhasoami'),
          fontSize: 18,
          textScale: cfg.textScale,
          maxLines: 1,
          label: 'quick-edit title',
        );
      });
    }
  });
}
