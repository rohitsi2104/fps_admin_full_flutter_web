import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fps_admin/core/api.dart';
import 'package:fps_admin/shared/app_ui.dart';
import 'package:intl/intl.dart';

import '../support/ui_harness.dart';

/// Overflow regression tests for `features/stock/stock_page.dart`.
///
/// Compositions covered (all faithful copies of the real subtrees):
///   * Daily-sales header row: `AppText('Day: ...')` (Expanded) beside two
///     buttons.
///   * Stat tiles (Orders / Units / Revenue) laid out in a `Wrap`.
///   * Top-seller rows built with the shared `AppListCard`
///     (CircleAvatar qty leading, name title, "Product #id • category"
///     subtitle, money trailing).
///   * Product-search-sheet `ListTile`s (AppText title + AppText subtitle).
///
/// Stress data: long product names, huge revenue (1234567.89), large qty and
/// long category strings, across every device/text-scale in `kDeviceMatrix`.

final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

/// Faithful copy of the private `_statTile`.
Widget _statTileRepro(BuildContext context, String label, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: Theme.of(context)
          .colorScheme
          .primaryContainer
          .withValues(alpha: 0.35),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label),
      ],
    ),
  );
}

/// Faithful copy of a top-seller row from `_buildReport`.
Widget _topSellerRepro(ProductSales t) {
  return AppListCard(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    elevation: 0,
    leading: CircleAvatar(
      child: AppText(
        t.quantity.toString(),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    title: AppText(t.name),
    subtitle: AppText('Product #${t.productId} • ${t.category ?? "-"}'),
    trailing: [AppText(_money.format(t.amount))],
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

final _stressReport = DailySales(
  day: DateTime(2026, 12, 31),
  orders: 123456,
  unitsSold: 9876543,
  revenue: 1234567.89,
  byProduct: <ProductSales>[
    ProductSales(
      productId: 1029384,
      name: 'Radhasoami Premium Cold-Pressed Groundnut Cooking Oil 5 Litre Tin',
      category: 'Cooking Oils & Ghee — Cold Pressed Speciality',
      quantity: 999999,
      amount: 987654.32, // distinct from report revenue so we can target it
    ),
    ProductSales(
      productId: 7,
      name: 'Milk',
      category: null,
      quantity: 2,
      amount: 42.5,
    ),
  ],
  bySource: const {},
);

final _stressProducts = <ProductLite>[
  ProductLite(
    id: 1029384,
    name: 'Radhasoami Premium Cold-Pressed Groundnut Cooking Oil 5 Litre Tin',
    stock: 999999,
    price: 1234567.89,
  ),
  ProductLite(id: 7, name: 'Milk', stock: 2, price: 42.5),
];

void main() {
  group('StockPage daily-sales report holds up across the matrix', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('header + stat tiles + top-sellers on $cfg', (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          Builder(
            builder: (context) => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Header date label (the dynamic part — Expanded AppText).
                // The two action buttons that sit beside it are exercised in
                // the separate "documented finding" group below, because they
                // genuinely overflow at large text scale.
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        'Day: ${DateFormat('dd MMM yyyy').format(_stressReport.day)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _statTileRepro(
                        context, 'Orders', _stressReport.orders.toString()),
                    _statTileRepro(
                        context, 'Units', _stressReport.unitsSold.toString()),
                    _statTileRepro(context, 'Revenue',
                        _money.format(_stressReport.revenue)),
                  ],
                ),
                const SizedBox(height: 12),
                ..._stressReport.byProduct.map(_topSellerRepro),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // Top-seller name must not collapse (Expanded AppText in AppListCard).
        expectNotCollapsed(
          tester,
          find.textContaining('Radhasoami'),
          fontSize: 14, // AppText default body size
          textScale: cfg.textScale,
          maxLines: 1,
          label: 'top-seller name',
        );
        // Top-seller trailing amount (AppText, maxLines 1) must not collapse.
        // NOTE: the Revenue *stat tile* uses a plain `Text` (no maxLines) and
        // may wrap a long comma-number to ~2 lines — that is normal wrapping,
        // not the per-character collapse bug, so we do not assert on it here.
        expectNotCollapsed(
          tester,
          find.text(_money.format(987654.32)),
          fontSize: 14,
          textScale: cfg.textScale,
          maxLines: 1,
          label: 'top-seller amount',
        );
      });
    }
  });

  // REGRESSION GUARD (fixed): the daily-sales header is now a `Wrap`
  // (spaceBetween) holding the date `AppText` and an inner `Wrap` of the two
  // action buttons (`Pick Day`, `Load`). When their combined width no longer
  // fits a phone-width row (large accessibility text scale, or the em-width
  // test font), the button block wraps onto the next run instead of triggering
  // a horizontal RenderFlex overflow. We reproduce the fixed structure
  // faithfully — Card + padding included — and assert STRICTLY (no tolerated
  // exception), plus the date label never per-character collapses.
  group('StockPage daily-sales header (button-row overflow fixed)', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('header builds + date never collapses on $cfg',
          (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppText(
                    'Day: ${DateFormat('dd MMM yyyy').format(_stressReport.day)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.date_range),
                        label: const Text('Pick Day'),
                      ),
                      FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.bar_chart),
                        label: const Text('Load'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        // Strict: the Wrap reflows the button block, so there must be NO
        // RenderFlex overflow at any device/text-scale.
        expect(tester.takeException(), isNull);
        expectNotCollapsed(
          tester,
          find.textContaining('Day:'),
          fontSize: 14,
          textScale: cfg.textScale,
          maxLines: 1,
          label: 'sales header date',
        );
      });
    }
  });

  group('StockPage product-search sheet holds up across the matrix', () {
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
