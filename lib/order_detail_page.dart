import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import 'api.dart';

const _statusOptions = ['PENDING', 'PAID', 'SHIPPED', 'COMPLETED', 'CANCELLED'];

String _statusNice(String s) {
  switch (s) {
    case 'PENDING':
      return 'Pending';
    case 'PAID':
      return 'Received';
    case 'SHIPPED':
      return 'Ready';
    case 'COMPLETED':
      return 'Delivered';
    case 'CANCELLED':
      return 'Cancelled';
    default:
      return s;
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'PAID':
      return Colors.red; // Received
    case 'SHIPPED':
      return Colors.orange; // Ready
    case 'COMPLETED':
      return Colors.green; // Delivered
    case 'CANCELLED':
      return Colors.grey;
    default:
      return Colors.blueGrey; // Pending/default
  }
}

class OrderDetailPage extends StatefulWidget {
  final Api api;
  final Order order;
  const OrderDetailPage({super.key, required this.api, required this.order});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late Order _order;
  final _dfMoney = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _updateStatus(String status) async {
    try {
      final updated = await widget.api.setStatus(_order.id, status);
      if (!mounted) return;
      setState(() => _order = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Status updated: ${_statusNice(updated.status)}')),
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final msg = e.response?.data is Map
          ? ((e.response!.data['detail'] ??
                  e.response!.data['error'] ??
                  e.message)
              .toString())
          : e.message;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed ($code): $msg')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _onSelectFromDropdown(String? v) async {
    if (v == null || v == _order.status) return;
    await _updateStatus(v);
  }

  Future<void> _onReceived() => _updateStatus('PAID');
  Future<void> _onReady() => _updateStatus('SHIPPED');
  Future<void> _onDelivered() => _updateStatus('COMPLETED');

  @override
  Widget build(BuildContext context) {
    final created =
        DateFormat('yyyy-MM-dd HH:mm').format(_order.createdAt.toLocal());

    return PopScope(
      canPop: false, // intercept so we can return the updated order
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.mounted) Navigator.of(context).pop(_order);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Order #${_order.id}'),
          leading:
              BackButton(onPressed: () => Navigator.of(context).pop(_order)),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _statusColor(_order.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    _statusNice(_order.status),
                    style: TextStyle(
                      color: _statusColor(_order.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _order.status,
                items: _statusOptions
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text(_statusNice(s))))
                    .toList(),
                onChanged: _onSelectFromDropdown,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Shipping & total
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                child: ListTile(
                  title:
                      Text('${_order.shippingName} • ${_order.shippingPhone}'),
                  subtitle: Text(
                    '${_order.addressLine1}\n'
                    '${_order.addressLine2.isNotEmpty ? "${_order.addressLine2}\n" : ""}'
                    '${_order.city}, ${_order.state} ${_order.pincode}\n'
                    'Placed: $created',
                  ),
                  trailing: Text(
                    _dfMoney.format(_order.totalAmount),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),

            // Items
            Expanded(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: _order.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final it = _order.items[i];
                  return Card(
                    child: ListTile(
                      leading: (it.imageUrl != null)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(it.imageUrl!,
                                  width: 52, height: 52, fit: BoxFit.cover),
                            )
                          : const Icon(Icons.inventory_2_outlined),
                      title: Text(it.productName),
                      subtitle: Text(
                          'Qty: ${it.quantity}  •  ${_dfMoney.format(it.unitPrice)} each'),
                      trailing: Text(
                        _dfMoney.format(it.lineTotal),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Action buttons
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: _onReceived,
                        child: const Text('Received'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange),
                        onPressed: _onReady,
                        child: const Text('Ready'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        onPressed: _onDelivered,
                        child: const Text('Delivered'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
