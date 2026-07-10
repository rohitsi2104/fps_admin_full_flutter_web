import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_harness.dart';

/// Overflow regression tests for features/dashboard/dashboard_page.dart.
///
/// The real DashboardPage is a shell: an IndexedStack of network-backed pages
/// plus a fixed BottomNavigationBar. It has no stat/metric cards. The only
/// overflow-prone composition it owns is the BottomNavigationBar (four labels
/// + a Badge), which must not collapse or overflow at large font scales on a
/// narrow phone. We reproduce it faithfully.

Widget _bottomNav({int pendingCount = 0}) {
  return Scaffold(
    body: const Center(child: Text('content')),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: 0,
      onTap: (_) {},
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: Badge(
            label: pendingCount > 0 ? Text('$pendingCount') : null,
            isLabelVisible: pendingCount > 0,
            child: const Icon(Icons.receipt_long_rounded),
          ),
          label: 'Orders',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.shopping_bag_rounded),
          label: 'Products',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_rounded),
          label: 'Stock',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.point_of_sale_rounded),
          label: 'POS',
        ),
      ],
    ),
  );
}

void main() {
  group('Dashboard — bottom navigation bar', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('no overflow on $cfg', (tester) async {
        await pumpOnDevice(tester, cfg, _bottomNav());
        expect(tester.takeException(), isNull);
      });

      testWidgets('no overflow with pending badge on $cfg', (tester) async {
        await pumpOnDevice(tester, cfg, _bottomNav(pendingCount: 999));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
