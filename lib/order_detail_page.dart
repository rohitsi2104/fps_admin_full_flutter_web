import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'api.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
  Timer? _refreshTimer;
  DateTime _lastUpdateTime = DateTime.now();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshOrder());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshOrder() async {
    if (_pendingStatus != null || !mounted) return;
    // Don't refresh if we just updated something (allow 3s for backend consistency)
    if (DateTime.now().difference(_lastUpdateTime).inSeconds < 3) return;
    try {
      final updated = await widget.api.getOrder(_order.id);
      if (mounted) {
        setState(() {
          _order = updated;
        });
      }
    } catch (e) {
      // Background refresh failed, ignore or log silently to not disturb user
    }
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
    _performUpdate(
      () => widget.api.addItem(_order.id, product.id, qty),
      optimistic: (current) {
        // Find if item already exists
        final idx = current.items.indexWhere((it) => it.productId == product.id);
        final List<OrderItem> newItems;
        if (idx >= 0) {
          final existing = current.items[idx];
          final updated = OrderItem(
            id: existing.id,
            productId: existing.productId,
            productName: existing.productName,
            quantity: existing.quantity + qty,
            unitPrice: existing.unitPrice,
            lineTotal: (existing.quantity + qty) * existing.unitPrice,
            imageUrl: existing.imageUrl,
          );
          newItems = List<OrderItem>.from(current.items);
          newItems[idx] = updated;
        } else {
          // New item (we don't have its ID yet, use a temp one)
          final temp = OrderItem(
            id: -1, 
            productId: product.id,
            productName: product.name,
            quantity: qty,
            unitPrice: product.price,
            lineTotal: qty * product.price,
            imageUrl: product.imageUrl,
          );
          newItems = List<OrderItem>.from(current.items)..add(temp);
        }

        double newTotal = 0;
        for (final it in newItems) {
          newTotal += it.lineTotal;
        }

        return Order(
          id: current.id,
          status: current.status,
          statusDisplay: current.statusDisplay,
          shippingName: current.shippingName,
          shippingPhone: current.shippingPhone,
          addressLine1: current.addressLine1,
          addressLine2: current.addressLine2,
          city: current.city,
          state: current.state,
          pincode: current.pincode,
          totalAmount: newTotal,
          createdAt: current.createdAt,
          updatedAt: current.updatedAt,
          items: newItems,
          customerPhone: current.customerPhone,
        );
      },
      onInitialStateApplied: () {
         // Scroll to bottom after adding new item
         Future.delayed(const Duration(milliseconds: 150), () {
           if (_scrollCtrl.hasClients) {
             _scrollCtrl.animateTo(
               _scrollCtrl.position.maxScrollExtent,
               duration: const Duration(milliseconds: 400),
               curve: Curves.easeOut,
             );
           }
         });
      }
    );
  }

  Future<void> _updateItemQty(OrderItem item, int delta) async {
    final newQty = item.quantity + delta;
    if (newQty < 1) {
      _removeItem(item);
      return;
    }

    final newQtyVal = newQty;
    _performUpdate(
      () => widget.api.updateItemQuantity(_order.id, item.id, newQtyVal),
      optimistic: (current) {
        final newItems = current.items.map((it) {
          if (it.id == item.id) {
            final lineTotal = newQtyVal * it.unitPrice;
            return OrderItem(
              id: it.id,
              productId: it.productId,
              productName: it.productName,
              quantity: newQtyVal,
              unitPrice: it.unitPrice,
              lineTotal: lineTotal,
              imageUrl: it.imageUrl,
            );
          }
          return it;
        }).toList();

        double newTotal = 0;
        for (final it in newItems) {
          newTotal += it.lineTotal;
        }

        return Order(
          id: current.id,
          status: current.status,
          statusDisplay: current.statusDisplay,
          shippingName: current.shippingName,
          shippingPhone: current.shippingPhone,
          addressLine1: current.addressLine1,
          addressLine2: current.addressLine2,
          city: current.city,
          state: current.state,
          pincode: current.pincode,
          totalAmount: newTotal,
          createdAt: current.createdAt,
          updatedAt: current.updatedAt,
          items: newItems,
          customerPhone: current.customerPhone,
        );
      },
    );
  }

  Future<void> _removeItem(OrderItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Item?'),
        content: Text('Remove ${item.productName} from order?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes')),
        ],
      ),
    );
    if (confirm != true) return;

    _performUpdate(
      () => widget.api.removeItem(_order.id, item.id),
      optimistic: (current) {
        final newItems = current.items.where((it) => it.id != item.id).toList();
        double newTotal = 0;
        for (final it in newItems) {
          newTotal += it.lineTotal;
        }
        return Order(
          id: current.id,
          status: current.status,
          statusDisplay: current.statusDisplay,
          shippingName: current.shippingName,
          shippingPhone: current.shippingPhone,
          addressLine1: current.addressLine1,
          addressLine2: current.addressLine2,
          city: current.city,
          state: current.state,
          pincode: current.pincode,
          totalAmount: newTotal,
          createdAt: current.createdAt,
          updatedAt: current.updatedAt,
          items: newItems,
          customerPhone: current.customerPhone,
        );
      },
    );
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

  Future<void> _performUpdate(
    Future<Order> Function() action, {
    Order Function(Order)? optimistic,
    VoidCallback? onInitialStateApplied,
  }) async {
    if (_pendingStatus != null) return;

    Order? original;
    if (optimistic != null) {
      setState(() => _order = optimistic(_order));
      if (onInitialStateApplied != null) onInitialStateApplied();
    }

    setState(() {
       _pendingStatus = 'Updating...';
       _lastUpdateTime = DateTime.now();
    });
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _order = updated;
        _pendingStatus = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (original != null) setState(() => _order = original!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.response?.data['detail'] ?? e.message}')));
      setState(() => _pendingStatus = null);
    } catch (e) {
      if (!mounted) return;
      if (original != null) setState(() => _order = original!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _pendingStatus = null);
    }
  }

  void _call(String phone) {
    if (phone.isEmpty) return;
    String clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    launchUrlString('tel:$clean');
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
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.location_on, color: Colors.blueGrey),
                      title: Text(_order.shippingName),
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
                    const Divider(height: 1),
                    ListTile(
                      visualDensity: VisualDensity.compact,
                      title: Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text('Shipping: ${_order.shippingPhone}'),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.call, color: Colors.green),
                        onPressed: () => _call(_order.shippingPhone),
                      ),
                    ),
                    if (_order.customerPhone != null &&
                        _order.customerPhone != _order.shippingPhone)
                      ListTile(
                        visualDensity: VisualDensity.compact,
                        title: Row(
                          children: [
                            const Icon(Icons.account_circle_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text('Account: ${_order.customerPhone}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () => _call(_order.customerPhone!),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Items
            Expanded(
              child: ListView.separated(
                controller: _scrollCtrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: _order.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final it = _order.items[i];
                  return Card(
                    key: ValueKey(it.id == -1 ? 'temp-${it.productId}' : it.id),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      // Header: Product Name
                          Text(
                            it.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(height: 12),
                          Row(
                            children: [
                              // Image/Icon
                              (it.imageUrl != null)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        it.imageUrl!,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.inventory_2_outlined, size: 20, color: Colors.blueGrey),
                                    ),
                              const SizedBox(width: 12),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Qty: ${it.quantity}  •  ${_dfMoney.format(it.unitPrice)} ea',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Subtotal: ${_dfMoney.format(it.lineTotal)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Actions
                              if (_order.status == 'PENDING')
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                      onPressed: () => _removeItem(it),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.blueGrey, size: 22),
                                      onPressed: () => _updateItemQty(it, -1),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent, size: 22),
                                      onPressed: () => _updateItemQty(it, 1),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                            ],
                          ),
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

