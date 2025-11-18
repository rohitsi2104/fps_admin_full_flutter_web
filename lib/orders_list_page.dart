
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api.dart';
import 'order_detail_page.dart';

class OrdersListPage extends StatefulWidget {
  final Api api;
  const OrdersListPage({super.key, required this.api});

  @override
  State<OrdersListPage> createState() => _OrdersListPageState();
}

class _OrdersListPageState extends State<OrdersListPage>
    with AutomaticKeepAliveClientMixin {
  Timer? _timer;
  final List<Order> _orders = [];
  DateTime? _lastSeenUtc;
  bool _loading = false;

  // 'ALL' | 'PENDING' | 'PAID' | 'SHIPPED' | 'COMPLETED' | 'CANCELLED'
  String _statusFilter = 'ALL';

  static const Duration _pollInterval = Duration(seconds: 10);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch(initial: true);
    _timer = Timer.periodic(_pollInterval, (_) => _fetch());
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
      final sinceParam = (initial || _lastSeenUtc == null)
          ? null
          : _lastSeenUtc!.add(const Duration(microseconds: 1));

      final batch = await widget.api.listOrders(
        status: _statusFilter == 'ALL' ? null : _statusFilter,
        since: sinceParam,
      );

      if (!mounted) return;

      // Merge: replace by id or insert new
      int inserted = 0;
      for (final o in batch) {
        final idx = _orders.indexWhere((x) => x.id == o.id);
        if (idx >= 0) {
          _orders[idx] = o;
        } else {
          _orders.insert(0, o);
          inserted++;
        }
      }

      _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _lastSeenUtc = _orders.isNotEmpty
          ? _orders.first.createdAt.toUtc()
          : DateTime.now().toUtc();

      if (!initial && inserted > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('🔔 $inserted new order(s)')),
        );
      }

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshAll() async {
    _orders.clear();
    _lastSeenUtc = null;
    await _fetch(initial: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                setState(() => _statusFilter = v);
                _refreshAll();
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
        final cs = Theme.of(context).colorScheme;
        final chipColor = _statusChipColor(context, o.status);
        return Card(
          elevation: 1,
          child: ListTile(
            title:
                Text('Order #${o.id} • ₹${o.totalAmount.toStringAsFixed(2)}'),
            subtitle: Text('${o.shippingName} • ${_statusChipText(o.status)}'),
            trailing: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              children: [
                Text(df.format(o.createdAt.toLocal()),
                    style: TextStyle(color: cs.onSurfaceVariant)),
                Container(
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    _statusChipText(o.status),
                    style: TextStyle(
                      color: chipColor,
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
              if (!mounted) return;
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
    case 'RECEIVED':
      return 'Received';
    case 'READY':
      return 'Ready';
    case 'DELIVERED':
      return 'Delivered';
    case 'CANCELLED':
      return 'Cancelled';
    case 'PENDING':
    default:
      return 'Pending';
  }
}


Color _statusChipColor(BuildContext ctx, String s) {
  switch (s) {
    case 'RECEIVED': // Received
      return const Color(0xFF0B8A00); // deep green
    case 'READY': // Ready
      return const Color(0xFF0067C0); // strong blue
    case 'DELIVERED': // Delivered
      return const Color(0xFF006D5B); // deep teal
    case 'CANCELLED':
      return const Color(0xFFB3261E); // M3 error (high contrast red)
    default: // Pending / fallback
      return const Color(0xFF4E5969); // slate/blue-grey
  }
}
