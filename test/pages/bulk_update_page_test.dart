import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fps_admin/core/api.dart';
import 'package:fps_admin/shared/app_ui.dart';

import '../support/ui_harness.dart';

/// Overflow regression tests for `features/stock/bulk_update_page.dart`.
///
/// Compositions covered (faithful copies of the real subtrees):
///   * Info card `ListTile` header (title + long subtitle + "Add row" button).
///   * `_RowCard`: the product picker field (read-only `TextField` with a
///     tooltip info icon showing "ID x • Stock y • ₹z") beside a delete button,
///     plus the stock/price number fields.
///   * `_ProductSearchSheet` `ListTile`s (AppText title + AppText subtitle).
///
/// Stress data: long product names, huge prices, large stock, across every
/// device/text-scale in `kDeviceMatrix`.

/// Faithful copy of the `_RowCard.build` subtree. The real widget reads the
/// selected product's name into the field controller and shows an info tooltip.
Widget _rowCardRepro(ProductLite? p) {
  final searchText = p?.name ?? '';
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {},
                  child: IgnorePointer(
                    child: TextField(
                      controller: TextEditingController(text: searchText),
                      decoration: InputDecoration(
                        labelText: 'Product',
                        hintText: 'Tap to search',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: p == null
                            ? null
                            : Tooltip(
                                message:
                                    'ID ${p.id} • Stock ${p.stock} • ₹${p.price}',
                                child: const Icon(Icons.info_outline),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove row',
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: '${p?.stock ?? ''}'),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'New stock (optional)',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: '${p?.price ?? ''}'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'New price (optional)',
                    prefixText: '₹ ',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Faithful copy of the info-card header `ListTile`.
Widget _infoCardRepro(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Card(
    color: cs.primaryContainer.withValues(alpha: 0.25),
    child: ListTile(
      title: const Text('Make multiple edits to stock/price'),
      subtitle: const Text(
          'Tap product to choose via search • Leave a field empty to skip updating it'),
      trailing: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Add row'),
      ),
    ),
  );
}

/// Faithful copy of the `_ProductSearchSheet` list tile.
Widget _searchTileRepro(ProductLite p) {
  return ListTile(
    title: AppText(p.name),
    subtitle: AppText('ID ${p.id} • Stock ${p.stock} • ₹${p.price}'),
    onTap: () {},
  );
}

final _stressProduct = ProductLite(
  id: 1029384,
  name: 'Radhasoami Premium Cold-Pressed Groundnut Cooking Oil 5 Litre Tin',
  stock: 999999,
  price: 1234567.89,
);

final _stressProducts = <ProductLite>[
  _stressProduct,
  ProductLite(id: 7, name: 'Milk', stock: 2, price: 42.5),
];

void main() {
  group('BulkUpdatePage rows + info card hold up across the matrix', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('info card + row card do not overflow on $cfg',
          (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          Builder(
            builder: (context) => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _infoCardRepro(context),
                const SizedBox(height: 12),
                _rowCardRepro(_stressProduct),
                _rowCardRepro(null), // empty row
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('BulkUpdatePage product-search sheet holds up across the matrix', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('search ListTiles do not collapse on $cfg', (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          ListView(children: _stressProducts.map(_searchTileRepro).toList()),
        );

        expect(tester.takeException(), isNull);
        expectNotCollapsed(
          tester,
          find.textContaining('Radhasoami'),
          fontSize: 14,
          textScale: cfg.textScale,
          maxLines: 1,
          label: 'search tile title',
        );
      });
    }
  });
}
