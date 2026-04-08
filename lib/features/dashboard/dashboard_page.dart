import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../orders/orders_list_page.dart';
import '../products/product_list_page.dart';
import '../stock/stock_page.dart';
import '../pos/pos_screen.dart';
import '../../providers/orders_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    OrdersListPage(),
    ProductListPage(),
    StockPage(),
    PosScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Watch for orders list to show badge if pending count > 0?
    // We'll just watch for the count.
    final ordersAsync = ref.watch(ordersProvider);

    int pendingCount = 0;
    if (ordersAsync.hasValue) {
      // Assuming 'status' is field in order.
      // Filter count of pending orders. (Requires knowing structure)
      // For now, let's just use the length or stick to badge 
      // if we have specific status data.
      // pendingCount = ordersAsync.value!.where((o) => o['status'] == 'pending').length;
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
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
}
