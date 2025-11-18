
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import 'api.dart';

const _statusOptions = [
  'PENDING',
  'RECEIVED',
  'READY',
  'DELIVERED',
  'CANCELLED'
];
String _statusNice(String s) {
  switch (s) {
    case 'PENDING':
      return 'Pending';
    case 'RECEIVED':
      return 'Received';
    case 'READY':
      return 'Ready';
    case 'DELIVERED':
      return 'Delivered';
    case 'CANCELLED':
      return 'Cancelled';
    default:
      return s;
  }
}

Color _statusColor(BuildContext ctx, String s) {
  final cs = Theme.of(ctx).colorScheme;
  switch (s) {
    case 'RECEIVED':
      return cs.primary;
    case 'READY':
      return cs.tertiary;
    case 'DELIVERED':
      return cs.secondary;
    case 'CANCELLED':
      return cs.outline;
    default:
      return cs.primary;
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
  String? _pendingStatus;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _updateStatus(String status) async {
    if (_pendingStatus != null) return;
    setState(() => _pendingStatus = status);
    try {
      final updated = await widget.api.setStatus(_order.id, status);
      if (!mounted) return;
      setState(() {
        _order = updated;
        _pendingStatus = null;
      });
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
      setState(() => _pendingStatus = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed ($code): $msg')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _pendingStatus = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _onSelectFromDropdown(String? v) async {
    if (v == null || v == _order.status) return;
    await _updateStatus(v);
  }

  Future<void> _onReceived() => _updateStatus('RECEIVED');
  Future<void> _onReady() => _updateStatus('READY');
  Future<void> _onDelivered() => _updateStatus('DELIVERED');

  Widget _buttonChild(String label, bool isLoading, Color? progressColor) {
    if (!isLoading) return Text(label);
    return SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        valueColor:
            progressColor != null ? AlwaysStoppedAnimation(progressColor) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final created =
        DateFormat('yyyy-MM-dd HH:mm').format(_order.createdAt.toLocal());
    final chipColor = _statusColor(context, _order.status);

    return PopScope(
      canPop: false,
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
                  color: chipColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    _statusNice(_order.status),
                    style: TextStyle(
                      color: chipColor,
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
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(_statusNice(s)),
                        ))
                    .toList(),
                onChanged: _pendingStatus == null ? _onSelectFromDropdown : null,
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
                elevation: 1,
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
                    elevation: 1,
                    child: ListTile(
                      leading: (it.imageUrl != null)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                it.imageUrl!,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
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
            Builder(
              builder: (context) {
                final cs = Theme.of(context).colorScheme;
                final actions = <Widget>[];

                void addButton(Widget button) {
                  if (actions.isNotEmpty) {
                    actions.add(const SizedBox(width: 8));
                  }
                  actions.add(Expanded(child: button));
                }

                switch (_order.status) {
                  case 'PENDING':
                    addButton(
                      FilledButton(
                        onPressed:
                            _pendingStatus == null ? _onReceived : null,
                        child: _buttonChild(
                          'Mark Received',
                          _pendingStatus == 'RECEIVED',
                          cs.onPrimary,
                        ),
                      ),
                    );
                    break;
                  case 'RECEIVED':
                    addButton(
                      FilledButton.tonal(
                        onPressed: _pendingStatus == null ? _onReady : null,
                        child: _buttonChild(
                          'Mark Ready',
                          _pendingStatus == 'READY',
                          cs.onSecondaryContainer,
                        ),
                      ),
                    );
                    break;
                  case 'READY':
                    addButton(
                      OutlinedButton(
                        onPressed:
                            _pendingStatus == null ? _onDelivered : null,
                        child: _buttonChild(
                          'Mark Delivered',
                          _pendingStatus == 'DELIVERED',
                          cs.primary,
                        ),
                      ),
                    );
                    break;
                }

                if (actions.isEmpty) {
                  return const SizedBox.shrink();
                }

                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(children: actions),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
