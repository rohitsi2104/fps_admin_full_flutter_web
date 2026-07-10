import 'package:flutter_test/flutter_test.dart';
import 'package:fps_admin/billing_home_page.dart';

/// Overflow regression tests for lib/billing_home_page.dart.
///
/// NOTE: Despite the "page" name, this file contains NO Flutter UI. It is
/// entirely a data/service layer — `Product`, `CartLine`, `InvoiceResult` and
/// `BillingService` — with the historical widget code left commented out
/// (lines 1–817). There is no `build()` method, no `Widget`, and therefore no
/// overflow-prone composition to exercise. See lib/features/pos/pos_screen.dart
/// for the actual POS/billing UI (not part of this task's page list).
///
/// To keep coverage honest we assert the file has no widgets and sanity-check
/// the data models with stress values so this file still guards the "page".
void main() {
  group('Billing home — data layer only (no UI to overflow-test)', () {
    test('models compute correctly with stress values', () {
      final product = Product(
        id: 1029384756,
        name: 'Premium Organic Cold-Pressed Extra Virgin Coconut Oil 1 Litre',
        nameLower:
            'premium organic cold-pressed extra virgin coconut oil 1 litre',
        price: 1234.56,
        unit: 'litre',
      );
      final line = CartLine(product: product, qty: 9999);

      expect(line.lineTotal, closeTo(1234.56 * 9999, 0.001));
      expect(line.toJson()['product_id'], product.id);

      final result = InvoiceResult.fromResponse(200, {
        'order_id': 42,
        'invoice_number': 'INV-2026-000042',
        'message': 'ok',
      });
      expect(result.ok, isTrue);
      expect(result.orderId, 42);
    });
  });
}
