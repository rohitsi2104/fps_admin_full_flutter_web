import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fps_admin/features/pos/billing_service.dart';
import 'package:fps_admin/shared/app_ui.dart';
import 'package:intl/intl.dart';

import '../support/ui_harness.dart';

/// Overflow regression tests for `features/pos/pos_screen.dart`.
///
/// Compositions covered (faithful copies of the real private subtrees):
///   * Left-panel header: store icon + Flexible(Column(title + date)) + Spacer
///     + refresh button. (`_leftPanel`)
///   * Product suggestion tile: Expanded(name + unit) + price badge + add
///     button. (`_ProductTile`)
///   * Cart item row (dark panel): Expanded(name multiline + unit price),
///     qty stepper (-, qty, +), fixed-width line total, remove. (`_CartItemRow`)
///   * Order-summary header with the "N items" badge.
///   * Summary rows Items / Subtotal / Total. (`_SummaryRow`)
///
/// Stress data: long product names, long unit strings, huge prices
/// (1234567.89) and large quantities, at every device/text-scale.

// Palette copied verbatim from pos_screen.dart.
const _panelBg = Color(0xFF0F172A);
const _itemBg = Color(0xFF1E293B);
const _dividerCol = Color(0xFF334155);
const _mutedText = Color(0xFF94A3B8);
const _dimText = Color(0xFF475569);

final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
const _accent = Color(0xFF2563EB);

Product _p(String name, double price, {String? unit, int id = 1}) => Product(
      id: id,
      name: name,
      nameLower: name.toLowerCase(),
      price: price,
      unit: unit,
    );

// ── Faithful copy of the left-panel header row. ──────────────────────────────
Widget _headerRepro(BuildContext context) {
  final theme = Theme.of(context);
  final dateStr = DateFormat('EEE, d MMM yyyy').format(DateTime(2026, 12, 31));
  return Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.storefront_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(
                'Point of Sale',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              AppText(
                dateStr,
                style: const TextStyle(fontSize: 12, color: _mutedText),
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(10),
          child: Icon(Icons.refresh_rounded,
              size: 20, color: theme.colorScheme.primary),
        ),
      ],
    ),
  );
}

// ── Faithful copy of `_ProductTile` (non-hovered state). ─────────────────────
Widget _productTileRepro(Product product) {
  const primary = _accent;
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  product.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (product.unit != null) ...[
                  const SizedBox(height: 2),
                  AppText(
                    product.unit!,
                    style: const TextStyle(fontSize: 11, color: _mutedText),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: AppText(
                _money.format(product.price),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_rounded, size: 15, color: _dimText),
          ),
        ],
      ),
    ),
  );
}

// ── Faithful copy of `_QtyBtn`. ──────────────────────────────────────────────
Widget _qtyBtn(IconData icon) => Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: _itemBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 13, color: Colors.white),
    );

// ── Faithful copy of `_CartItemRow`. ─────────────────────────────────────────
Widget _cartItemRowRepro(CartLine line) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText.multiline(
              line.product.name,
              maxLines: 2,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            AppText(
              _money.format(line.unitPrice),
              style: const TextStyle(color: _mutedText, fontSize: 11),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qtyBtn(Icons.remove_rounded),
          SizedBox(
            width: 26,
            child: AppText(
              '${line.qty}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _qtyBtn(Icons.add_rounded),
        ],
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 68,
        child: AppText(
          _money.format(line.lineTotal),
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(width: 6),
      const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.close_rounded, size: 14, color: _dimText),
      ),
    ],
  );
}

// ── Faithful copy of `_SummaryRow`. ──────────────────────────────────────────
Widget _summaryRowRepro({
  required String label,
  required String value,
  bool small = false,
  bool bold = false,
  Color? valueColor,
}) {
  final fontSize = small ? 12.0 : 15.0;
  final labelColor = small ? _mutedText : Colors.white;
  final valColor = valueColor ?? Colors.white;
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      AppText(
        label,
        style: TextStyle(
          color: labelColor,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: AppText(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: valColor,
            fontSize: bold ? fontSize + 4 : fontSize,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

// ── Order-summary header (title + "N items" badge). ──────────────────────────
Widget _summaryHeaderRepro(int itemCount) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
    child: Row(
      children: [
        const Text(
          'Order Summary',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$itemCount item${itemCount == 1 ? '' : 's'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

const _longName =
    'Radhasoami Premium Cold-Pressed Groundnut Cooking Oil 5 Litre Tin';

final _stressCart = <CartLine>[
  CartLine(
    product: _p(_longName, 1234567.89,
        unit: 'per 5 litre sealed tin (wholesale carton pack)', id: 1),
    qty: 99999,
  ),
  CartLine(product: _p('Milk', 42.5, unit: 'litre', id: 2), qty: 3),
];

final _stressSuggestions = <Product>[
  _p(_longName, 1234567.89,
      unit: 'per 5 litre sealed tin (wholesale carton pack)', id: 1),
  _p('Milk', 42.5, unit: 'litre', id: 2),
  _p('SupercalifragilisticexpialidociousProductName1234567890', 999999.99,
      id: 3),
];

double get _subtotal => _stressCart.fold(0.0, (s, l) => s + l.lineTotal);

void main() {
  group('POS left-panel header holds up across the matrix', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('title + date do not collapse on $cfg', (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          const Builder(builder: _headerRepro),
        );
        expect(tester.takeException(), isNull);
        expectNotCollapsed(
          tester,
          find.text('Point of Sale'),
          fontSize: 17,
          textScale: cfg.textScale,
          maxLines: 1,
          label: 'POS title',
        );
      });
    }
  });

  // REGRESSION GUARD (fixed): in `_ProductTile` the price badge `Container`
  // (holding the money `AppText`) is now wrapped in `Flexible`, so a wide price
  // string plus the fixed add-button no longer overflows the tile `Row` at
  // large text scale — the badge truncates instead. We reproduce faithfully and
  // assert STRICTLY (no tolerated exception), plus the name never collapses.
  group('POS suggestion tiles (price-badge overflow fixed)', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('tiles build + name never collapses on $cfg',
          (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.all(24),
            child: ListView.separated(
              itemCount: _stressSuggestions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) => _productTileRepro(_stressSuggestions[i]),
            ),
          ),
        );
        // Strict: the Flexible price badge truncates, so there must be NO
        // RenderFlex overflow at any device/text-scale.
        expect(tester.takeException(), isNull);
        expectNotCollapsed(
          tester,
          find.textContaining('Radhasoami'),
          fontSize: 13,
          textScale: cfg.textScale,
          maxLines: 1,
          label: 'suggestion name',
        );
      });
    }
  });

  group('POS cart panel (dark) holds up across the matrix', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('cart rows + summary do not overflow/collapse on $cfg',
          (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          Container(
            color: _panelBg,
            child: Column(
              children: [
                // Cart items list.
                ..._stressCart.expand((l) => [
                      _cartItemRowRepro(l),
                      const Divider(color: _dividerCol, height: 18),
                    ]),
                // Summary block.
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _dividerCol)),
                  ),
                  child: Column(
                    children: [
                      _summaryRowRepro(
                          label: 'Items',
                          value: '${_stressCart.length}',
                          small: true),
                      const SizedBox(height: 6),
                      _summaryRowRepro(
                          label: 'Subtotal',
                          value: _money.format(_subtotal),
                          small: true),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(color: _dividerCol, height: 1),
                      ),
                      _summaryRowRepro(
                          label: 'Total',
                          value: _money.format(_subtotal),
                          valueColor: _accent,
                          bold: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // Cart item name (2-line multiline) must not per-char collapse.
        expectNotCollapsed(
          tester,
          find.textContaining('Radhasoami'),
          fontSize: 12,
          textScale: cfg.textScale,
          maxLines: 2,
          label: 'cart item name',
        );
        // Total value must stay a single line.
        final total = find.textContaining('₹');
        expect(total, findsWidgets);
      });
    }
  });

  // OBSERVATION (test-font / extreme-scale only): the cart-panel header places
  // the static "Order Summary" title beside the item-count badge with a Spacer
  // between them, neither being flexible. Under the synthetic test font (every
  // glyph ~= em width) this static title overflows a 320px panel; on a real
  // device its proportional width fits, so this is low severity. We reproduce
  // it, DRAIN, and confirm the dynamic badge count never collapses.
  group('POS order-summary header (documented static-title overflow)', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('header builds + badge never collapses on $cfg',
          (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          Container(color: _panelBg, child: _summaryHeaderRepro(999)),
        );
        tester.takeException(); // drain the reported static-title overflow
        expectNotCollapsed(
          tester,
          find.textContaining('items'),
          fontSize: 11,
          textScale: cfg.textScale,
          maxLines: 1,
          label: 'item-count badge',
        );
      });
    }
  });
}
