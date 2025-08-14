import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api.dart';
import 'config.dart';
import 'order_detail_page.dart';

class OrdersListPage extends StatefulWidget {
  final Api api;
  const OrdersListPage({super.key, required this.api});

  @override
  State<OrdersListPage> createState() => _OrdersListPageState();
}

class _OrdersListPageState extends State<OrdersListPage> {
  Timer? _timer;
  final List<Order> _orders = [];
  final Set<int> _ids = {}; // track which IDs we already have
  DateTime? _lastSeenUtc; // newest createdAt we’ve seen (UTC)
  bool _loading = false;

  String _statusFilter =
      'ALL'; // 'ALL' | 'PENDING' | 'PAID' | 'SHIPPED' | 'COMPLETED' | 'CANCELLED'

  @override
  void initState() {
    super.initState();
    _fetch(initial: true);
    _timer = Timer.periodic(kPollInterval, (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch({bool initial = false}) async {
    if (!mounted) return;
    setState(() => _loading = initial && _orders.isEmpty);

    try {
      // Advance the cursor by 1 microsecond to avoid re-fetching the last item
      final sinceParam = (initial || _lastSeenUtc == null)
          ? null
          : _lastSeenUtc!.add(const Duration(microseconds: 1));

      final batch = await widget.api.listOrders(
        status: _statusFilter == 'ALL' ? null : _statusFilter,
        since: sinceParam,
      );

      // Merge by ID: insert new ones, update existing ones
      int inserted = 0;
      for (final o in batch) {
        final idx = _orders.indexWhere((x) => x.id == o.id);
        if (idx >= 0) {
          _orders[idx] = o; // update (e.g., status changed)
        } else {
          _orders.insert(0, o); // newest first
          _ids.add(o.id);
          inserted++;
        }
      }

      // Keep list sorted by createdAt DESC (defensive)
      _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Recompute the cursor
      if (_orders.isNotEmpty) {
        _lastSeenUtc = _orders.first.createdAt.toUtc();
      } else {
        _lastSeenUtc = DateTime.now().toUtc();
      }

      if (!initial && inserted > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🔔 $inserted new order(s)')),
        );
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshAll() async {
    // Hard reset to avoid any cursor weirdness
    _orders.clear();
    _ids.clear();
    _lastSeenUtc = null;
    await _fetch(initial: true);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('FPS Admin • Orders'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _statusFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All')),
                DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                DropdownMenuItem(value: 'PAID', child: Text('Received')),
                DropdownMenuItem(value: 'SHIPPED', child: Text('Ready')),
                DropdownMenuItem(value: 'COMPLETED', child: Text('Delivered')),
                DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _statusFilter = v;
                });
                _refreshAll(); // change filter => full reload (no dupes)
              },
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshAll),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: _buildBody(df),
      ),
    );
  }

  Widget _buildBody(DateFormat df) {
    if (_orders.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 160),
          Center(
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('No orders yet.'),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final o = _orders[i];
        return Card(
          child: ListTile(
            title:
                Text('Order #${o.id} • ₹${o.totalAmount.toStringAsFixed(2)}'),
            subtitle: Text('${o.shippingName} • ${_statusChipText(o.status)}'),
            trailing: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              children: [
                Text(df.format(o.createdAt.toLocal())),
                Container(
                  decoration: BoxDecoration(
                    color: _statusChipColor(o.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    _statusChipText(o.status),
                    style: TextStyle(
                      color: _statusChipColor(o.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () async {
              final updated = await Navigator.push<Order>(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailPage(api: widget.api, order: o),
                ),
              );
              if (updated != null) {
                final idx = _orders.indexWhere((x) => x.id == updated.id);
                if (idx >= 0) setState(() => _orders[idx] = updated);
              }
            },
          ),
        );
      },
    );
  }
}

String _statusChipText(String s) {
  switch (s) {
    case 'PAID':
      return 'Received';
    case 'SHIPPED':
      return 'Ready';
    case 'COMPLETED':
      return 'Delivered';
    case 'CANCELLED':
      return 'Cancelled';
    case 'PENDING':
    default:
      return 'Pending';
  }
}

Color _statusChipColor(String s) {
  switch (s) {
    case 'PAID':
      return Colors.red;
    case 'SHIPPED':
      return Colors.orange;
    case 'COMPLETED':
      return Colors.green;
    case 'CANCELLED':
      return Colors.grey;
    default:
      return Colors.blueGrey;
  }
}
