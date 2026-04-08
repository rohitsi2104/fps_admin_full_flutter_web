import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../providers/orders_provider.dart';
import 'order_detail_page.dart';

class OrdersListPage extends ConsumerStatefulWidget {
  const OrdersListPage({super.key});

  @override
  ConsumerState<OrdersListPage> createState() => _OrdersListPageState();
}

class _OrdersListPageState extends ConsumerState<OrdersListPage>
    with AutomaticKeepAliveClientMixin {
  String _statusFilter = 'ALL';

  @override
  bool get wantKeepAlive => true;

  Future<void> _pickDateRange() async {
    final current = ref.read(ordersDateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: current,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      ref.read(ordersDateRangeProvider.notifier).set(DateTimeRange(
        start: picked.start,
        end: picked.end,
      ));
    }
  }

  void _setQuickDate(String label) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    late final DateTimeRange range;
    switch (label) {
      case 'today':
        range = DateTimeRange(start: today, end: today);
      case 'yesterday':
        final yesterday = today.subtract(const Duration(days: 1));
        range = DateTimeRange(start: yesterday, end: yesterday);
      case 'week':
        range = DateTimeRange(
            start: today.subtract(const Duration(days: 7)), end: today);
      case 'month':
        range = DateTimeRange(
            start: today.subtract(const Duration(days: 30)), end: today);
      default:
        return;
    }
    ref.read(ordersDateRangeProvider.notifier).set(range);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final dfShort = DateFormat('dd MMM');
    final ordersAsync = ref.watch(ordersProvider);
    final dateRange = ref.watch(ordersDateRangeProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday =
        dateRange.start == today && dateRange.end == today;

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
                DropdownMenuItem(value: 'CONFIRMED', child: Text('Confirmed')),
                DropdownMenuItem(value: 'RECEIVED', child: Text('Received')),
                DropdownMenuItem(value: 'READY', child: Text('Ready')),
                DropdownMenuItem(value: 'DELIVERED', child: Text('Delivered')),
                DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _statusFilter = v);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(ordersProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date filter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: Row(
              children: [
                _QuickDateChip(
                  label: 'Today',
                  selected: isToday,
                  onTap: () => _setQuickDate('today'),
                ),
                const SizedBox(width: 6),
                _QuickDateChip(
                  label: 'Yesterday',
                  selected: false,
                  onTap: () => _setQuickDate('yesterday'),
                ),
                const SizedBox(width: 6),
                _QuickDateChip(
                  label: '7 Days',
                  selected: false,
                  onTap: () => _setQuickDate('week'),
                ),
                const SizedBox(width: 6),
                _QuickDateChip(
                  label: '30 Days',
                  selected: false,
                  onTap: () => _setQuickDate('month'),
                ),
                const Spacer(),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    dateRange.start == dateRange.end
                        ? dfShort.format(dateRange.start)
                        : '${dfShort.format(dateRange.start)} – ${dfShort.format(dateRange.end)}',
                  ),
                  onPressed: _pickDateRange,
                ),
              ],
            ),
          ),

          // Orders list
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                final filtered = _statusFilter == 'ALL'
                    ? orders
                    : orders.where((o) => o.status == _statusFilter).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No orders found.'));
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final o = filtered[i];
                      final cs = Theme.of(context).colorScheme;
                      final chipColor = _statusChipColor(context, o.status);
                      return Card(
                        elevation: 1,
                        child: ListTile(
                          title: Text(
                              'Order #${o.id} • ₹${o.totalAmount.toStringAsFixed(2)}'),
                          subtitle: Text(
                              '${o.shippingName} • ${_statusChipText(o.status)}'),
                          trailing: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 10,
                            children: [
                              Text(df.format(o.createdAt.toLocal()),
                                  style:
                                      TextStyle(color: cs.onSurfaceVariant)),
                              Container(
                                decoration: BoxDecoration(
                                  color: chipColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
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
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailPage(order: o),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _QuickDateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

String _statusChipText(String s) => OrderStatus.display(s);

Color _statusChipColor(BuildContext ctx, String s) {
  switch (s) {
    case OrderStatus.received:
      return const Color(0xFF0B8A00);
    case OrderStatus.ready:
      return const Color(0xFF0067C0);
    case OrderStatus.delivered:
      return const Color(0xFF006D5B);
    case OrderStatus.cancelled:
      return const Color(0xFFB3261E);
    default:
      return const Color(0xFF4E5969);
  }
}
