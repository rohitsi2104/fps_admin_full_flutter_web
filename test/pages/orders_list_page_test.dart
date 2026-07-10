import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fps_admin/shared/app_ui.dart';

import '../support/ui_harness.dart';

/// Overflow regression tests for features/orders/orders_list_page.dart.
///
/// Every composition below is copied faithfully from the real page code so the
/// tests exercise the production layout, then fed deliberately long / large
/// stress data across the full device + text-scale matrix.

// ---- Stress data ---------------------------------------------------------
const _longName = 'Radhasoami Satsang Sabha Dayalbagh Agra Uttar Pradesh Branch';
const _bigId = 1029384756;
const _bigAmount = 1234567.89;
const _longDate = '2026-12-31 23:59';

// Mirrors _statusChipColor(...) in the page for the "Confirmed" case.
const _confirmedColor = Color(0xFFB58105);

/// Reproduces the exact `AppListCard` order tile from `itemBuilder`.
Widget _orderCard({
  required int id,
  required double amount,
  required String shippingName,
  required String statusText,
  required Color chipColor,
  required String dateText,
}) {
  return AppListCard(
    onTap: () {},
    title: AppText(
      'Order #$id • ₹${amount.toStringAsFixed(2)}',
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    ),
    subtitle: AppText(
      '$shippingName • $statusText',
      style: const TextStyle(fontSize: 16),
    ),
    trailing: [
      AppText(dateText, style: const TextStyle(fontSize: 15)),
      StatusChip(text: statusText, color: chipColor, fontSize: 15),
    ],
  );
}

/// Reproduces the AppBar (title + status dropdown + refresh action).
Widget _ordersScaffold() {
  return Scaffold(
    appBar: AppBar(
      title: const Text('FPS Admin • Orders'),
      actions: [
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: 'ALL',
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All')),
              DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
              DropdownMenuItem(value: 'CONFIRMED', child: Text('Confirmed')),
              DropdownMenuItem(value: 'RECEIVED', child: Text('Received')),
              DropdownMenuItem(value: 'READY', child: Text('Ready')),
              DropdownMenuItem(value: 'DELIVERED', child: Text('Delivered')),
              DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
            ],
            onChanged: (_) {},
          ),
        ),
        IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
      ],
    ),
    body: const Center(child: Text('No orders found.')),
  );
}

void main() {
  group('Orders list — order card', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('no overflow + title not collapsed on $cfg', (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          ListView(
            padding: const EdgeInsets.all(14),
            children: [
              // Screenshot case from the original bug report.
              _orderCard(
                id: 928,
                amount: 140.0,
                shippingName: 'V Soami Dayal',
                statusText: 'Confirmed',
                chipColor: _confirmedColor,
                dateText: '2026-04-30 09:33',
              ),
              const SizedBox(height: 12),
              // Worst case: huge id + big amount + very long name.
              _orderCard(
                id: _bigId,
                amount: _bigAmount,
                shippingName: _longName,
                statusText: 'Delivered',
                chipColor: const Color(0xFF006D5B),
                dateText: _longDate,
              ),
            ],
          ),
        );

        expect(tester.takeException(), isNull);

        final titles = find.textContaining('Order #');
        for (var i = 0; i < titles.evaluate().length; i++) {
          expectNotCollapsed(
            tester,
            titles.at(i),
            fontSize: 20,
            textScale: cfg.textScale,
            maxLines: 1,
            label: 'order title #$i on $cfg',
          );
        }
      });
    }
  });

  group('Orders list — AppBar + empty state', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('no overflow on $cfg', (tester) async {
        await pumpOnDevice(tester, cfg, _ordersScaffold());
        expect(tester.takeException(), isNull);
        // Plain (non-AppText) empty-state label may soft-wrap to 2 lines under
        // the fat test font; the point is it must not collapse per-character.
        expectNotCollapsed(
          tester,
          find.text('No orders found.'),
          fontSize: 14,
          textScale: cfg.textScale,
          maxLines: 2,
          label: 'empty state on $cfg',
        );
      });
    }
  });

  group('Orders list — date filter bar', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('horizontal scroll chips hold up on $cfg', (tester) async {
        // Faithful copy of the horizontally-scrolling filter Row.
        await pumpOnDevice(
          tester,
          cfg,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Today', style: TextStyle(fontSize: 12)),
                    selected: true,
                    onSelected: (_) {},
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label:
                        const Text('Yesterday', style: TextStyle(fontSize: 12)),
                    selected: false,
                    onSelected: (_) {},
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 10),
                  ActionChip(
                    avatar: const Icon(Icons.date_range, size: 16),
                    label: const Text('30 Dec – 31 Dec',
                        style: TextStyle(fontSize: 12)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
