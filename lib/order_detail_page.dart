
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

  Future<void> _addItem() async {
    final product = await showDialog<ProductLite>(
      context: context,
      builder: (ctx) => ProductSearchDialog(api: widget.api),
    );
    if (product == null) return;
    
    // ignore: use_build_context_synchronously
    if (!mounted) return;

    // Ask quantity
    int quantity = 1;
    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) {
        int q = 1;
        return AlertDialog(
          title: Text('Add ${product.name}'),
          content: StatefulBuilder(
            builder: (context, setInner) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    onPressed: () =>
                        setInner(() => q = (q > 1) ? q - 1 : 1),
                    icon: const Icon(Icons.remove)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('$q', style: const TextStyle(fontSize: 20)),
                ),
                IconButton(
                    onPressed: () => setInner(() => q++),
                    icon: const Icon(Icons.add)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, q),
                child: const Text('Add')),
          ],
        );
      },
    );

    if (qty == null) return;
    _performUpdate(() => widget.api.addItem(_order.id, product.id, qty));
  }

  Future<void> _updateItemQty(OrderItem item, int delta) async {
    final newQty = item.quantity + delta;
    if (newQty < 1) {
       // Ask to remove?
       final confirm = await showDialog<bool>(
         context: context,
         builder: (ctx) => AlertDialog(
           title: const Text('Remove Item?'),
           content: Text('Remove ${item.productName} from order?'),
           actions: [
             TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text('No')),
             TextButton(onPressed: ()=> Navigator.pop(ctx, true), child: const Text('Yes')),
           ],
         )
       );
       if (confirm == true) {
         _performUpdate(() => widget.api.removeItem(_order.id, item.id));
       }
       return;
    }
    _performUpdate(() => widget.api.updateItemQuantity(_order.id, item.id, newQty));
  }

  Future<void> _confirmOrder() async {
     final priceController = TextEditingController(text: _order.totalAmount.toStringAsFixed(2));
     final confirmed = await showDialog<bool>(
       context: context,
       builder: (ctx) => AlertDialog(
         title: const Text('Confirm Order'),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Text('Verify contents and set final price.'),
             const SizedBox(height: 10),
             TextField(
               controller: priceController,
               keyboardType: const TextInputType.numberWithOptions(decimal: true),
               decoration: const InputDecoration(labelText: 'Total Amount (₹)'),
             )
           ],
         ),
         actions: [
           TextButton(onPressed: ()=> Navigator.pop(ctx, false), child: const Text('Cancel')),
           FilledButton(onPressed: ()=> Navigator.pop(ctx, true), child: const Text('Confirm')),
         ],
       )
     );

     if (confirmed == true) {
        final amount = double.tryParse(priceController.text) ?? _order.totalAmount;
        _performUpdate(() => widget.api.confirmOrder(_order.id, amount));
     }
  }

  Future<void> _performUpdate(Future<Order> Function() action) async {
    if (_pendingStatus != null) return;
    setState(() => _pendingStatus = 'Updating...');
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _order = updated;
        _pendingStatus = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.response?.data['detail'] ?? e.message}')));
      setState(() => _pendingStatus = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _pendingStatus = null);
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
    final canEdit = (_order.status == 'PENDING' || _order.status == 'CONFIRMED'); // Allow edit in confirmed too?
    // Let's stick to PENDING mainly, but user asked to modify orders. 
    // Backend says PENDING. 

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
            if (_order.status == 'PENDING')
               IconButton(onPressed: _addItem, icon: const Icon(Icons.add_shopping_cart)),
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
             // ... status dropdown (only for advanced states if needed, but Confirm logic replaces mostly)
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _dfMoney.format(it.lineTotal),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                           if (_order.status == 'PENDING') ...[
                             const SizedBox(width: 8),
                             IconButton(
                               icon: const Icon(Icons.remove_circle_outline, color: Colors.blueGrey),
                               onPressed: () => _updateItemQty(it, -1),
                               padding: EdgeInsets.zero,
                               constraints: const BoxConstraints(),
                             ),
                             const SizedBox(width: 8),
                             IconButton(
                               icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                               onPressed: () => _updateItemQty(it, 1),
                               padding: EdgeInsets.zero,
                               constraints: const BoxConstraints(),
                             ),
                           ]
                        ],
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
                        onPressed: _pendingStatus == null ? _confirmOrder : null,
                         style: FilledButton.styleFrom(
                           backgroundColor: Colors.green.shade700,
                           foregroundColor: Colors.white,
                         ),
                        child: _buttonChild(
                          'Confirm Order',
                          _pendingStatus == 'Updating...',
                          Colors.white,
                        ),
                      ),
                    );
                     // Allow cancelling too?
                     addButton(
                         OutlinedButton(
                             onPressed: () => _performUpdate(() => widget.api.cancel(_order.id)),
                             child: const Text('Cancel')
                         )
                     );
                    break;
                    
                  case 'CONFIRMED': // Waiting for customer payment
                    addButton(
                      FilledButton(
                        onPressed:
                            _pendingStatus == null ? _onReceived : null,
                        child: _buttonChild(
                          'Mark Received (Paid)',
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

class ProductSearchDialog extends StatefulWidget {
  final Api api;
  const ProductSearchDialog({super.key, required this.api});

  @override
  State<ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<ProductSearchDialog> {
  List<ProductLite> _results = [];
  bool _loading = false;
  final _searchCtrl = TextEditingController();
  
  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await widget.api.searchProducts(query);
      if (!mounted) return;
      setState(() {
        _results = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search Product'),
      content: SizedBox(
        width: 400, // Fixed width for web/tablet
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Product Name',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _search(_searchCtrl.text),
                ),
              ),
              onSubmitted: _search,
            ),
            const SizedBox(height: 10),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 10),
            Flexible(
              child: SizedBox(
                height: 300,
                child: _results.isEmpty 
                    ? const Center(child: Text('No results'))
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        separatorBuilder: (_,__) => const Divider(),
                        itemBuilder: (context, index) {
                          final p = _results[index];
                          return ListTile(
                            title: Text(p.name),
                            subtitle: Text('Stock: ${p.stock} • ₹${p.price}'),
                            onTap: () => Navigator.pop(context, p),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

