import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fps_admin/shared/app_ui.dart';

import 'support/ui_harness.dart';

/// Reproduces the exact order-card composition used in
/// features/orders/orders_list_page.dart, so the test exercises the real
/// production layout. Uses deliberately long/large data to stress it.
Widget orderCard({
  required int id,
  required double amount,
  required String shippingName,
  required String status,
  required Color statusColor,
  required String dateText,
}) {
  return Padding(
    padding: const EdgeInsets.all(14),
    child: AppListCard(
      onTap: () {},
      title: AppText(
        'Order #$id • ₹${amount.toStringAsFixed(2)}',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      subtitle: AppText(
        '$shippingName • $status',
        style: const TextStyle(fontSize: 16),
      ),
      trailing: [
        AppText(dateText, style: const TextStyle(fontSize: 15)),
        StatusChip(text: status, color: statusColor, fontSize: 15),
      ],
    ),
  );
}

void main() {
  group('Order card holds up across the device/text-scale matrix', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('no overflow + title not collapsed on $cfg', (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          ListView(
            children: [
              // The screenshot case.
              orderCard(
                id: 928,
                amount: 140.0,
                shippingName: 'V Soami Dayal',
                status: 'Confirmed',
                statusColor: const Color(0xFFB58105),
                dateText: '2026-04-30 09:33',
              ),
              // Worst case: long name + big amount.
              orderCard(
                id: 1029384,
                amount: 1234567.89,
                shippingName: 'Radhasoami Satsang Sabha Dayalbagh Agra Branch',
                status: 'Delivered',
                statusColor: const Color(0xFF006D5B),
                dateText: '2026-12-31 23:59',
              ),
            ],
          ),
        );

        // 1) Hard failure: any RenderFlex overflow throws.
        expect(tester.takeException(), isNull);

        // 2) Soft failure: the bold title must stay ~1 line, not collapse.
        final titles = find.textContaining('Order #');
        for (var i = 0; i < titles.evaluate().length; i++) {
          expectNotCollapsed(
            tester,
            titles.at(i),
            fontSize: 20,
            textScale: cfg.textScale,
            maxLines: 1,
            label: 'order title #$i',
          );
        }
      });
    }
  });

  group('Shared primitives are overflow-safe', () {
    testWidgets('AppText truncates a very long word instead of stacking',
        (tester) async {
      await pumpOnDevice(
        tester,
        const DeviceConfig('narrow', 200, 400, 1.5),
        const Row(
          children: [
            Icon(Icons.tag),
            Expanded(
              child: AppText(
                'Supercalifragilisticexpialidociousproductname1234567890',
                style: TextStyle(fontSize: 20),
              ),
            ),
            Icon(Icons.chevron_right),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expectNotCollapsed(
        tester,
        find.byType(Text),
        fontSize: 20,
        textScale: 1.5,
        maxLines: 1,
      );
    });

    testWidgets('LabeledRow value truncates on a narrow row', (tester) async {
      await pumpOnDevice(
        tester,
        const DeviceConfig('narrow', 240, 400, 1.5),
        const LabeledRow(
          label: 'Deliver to',
          value: 'V Soami Dayal, Radhasoami Satsang Sabha, Dayalbagh, Agra 282005',
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppListCard title survives an extreme trailing block',
        (tester) async {
      await pumpOnDevice(
        tester,
        const DeviceConfig('narrow', 260, 500, 1.5),
        const AppListCard(
          title: AppText('Order #928 • ₹140.00',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          subtitle: AppText('V Soami Dayal • Confirmed'),
          trailing: [
            AppText('2026-04-30 09:33', style: TextStyle(fontSize: 15)),
            StatusChip(
                text: 'Confirmed',
                color: Color(0xFFB58105),
                fontSize: 15),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expectNotCollapsed(
        tester,
        find.textContaining('Order #'),
        fontSize: 20,
        textScale: 1.5,
        maxLines: 1,
      );
    });
  });
}
