import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fps_admin/shared/app_ui.dart';

import 'support/ui_harness.dart';

/// Renders the order card (the screenshot case) to PNG snapshots at a normal
/// config and a worst-case narrow + huge-font config, for visual inspection
/// and regression capture. Run with:  flutter test --update-goldens
void main() {
  Widget card() => Container(
        color: const Color(0xFFF3F5F4),
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: AppListCard(
                onTap: () {},
                title: const AppText('Order #928 • ₹140.00',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                subtitle: const AppText('V Soami Dayal • Confirmed',
                    style: TextStyle(fontSize: 16)),
                trailing: const [
                  AppText('2026-04-30 09:33',
                      style: TextStyle(fontSize: 15)),
                  StatusChip(
                      text: 'Confirmed',
                      color: Color(0xFFB58105),
                      fontSize: 15),
                ],
              ),
            ),
          ],
        ),
      );

  testWidgets('golden: order card normal 360@1.0x', (tester) async {
    await pumpOnDevice(
        tester, const DeviceConfig('normal', 360, 300, 1.0), card());
    await expectLater(
      find.byType(AppListCard),
      matchesGoldenFile('goldens/order_card_360_1.0x.png'),
    );
  });

  testWidgets('golden: order card stress 320@1.5x', (tester) async {
    await pumpOnDevice(
        tester, const DeviceConfig('stress', 320, 300, 1.5), card());
    await expectLater(
      find.byType(AppListCard),
      matchesGoldenFile('goldens/order_card_320_1.5x.png'),
    );
  });
}
