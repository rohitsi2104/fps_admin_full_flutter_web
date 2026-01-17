// // lib/pos/pos_screen.dart
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';

// import 'billing_service.dart';

// class PosScreen extends StatefulWidget {
//   final BillingService service;
//   const PosScreen({super.key, required this.service});

//   @override
//   State<PosScreen> createState() => _PosScreenState();
// }

// class _PosScreenState extends State<PosScreen> {
//   final _searchCtrl = TextEditingController();
//   final _custNameCtrl = TextEditingController();
//   final _custPhoneCtrl = TextEditingController();

//   final List<CartLine> _cart = <CartLine>[];
//   List<Product> _suggestions = <Product>[];
//   Timer? _debounce;

//   bool _warming = true;
//   bool _submitting = false;

//   final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

//   @override
//   void initState() {
//     super.initState();
//     _warm();
//   }

//   Future<void> _warm() async {
//     try {
//       await widget.service.warmProducts();
//     } finally {
//       if (mounted) setState(() => _warming = false);
//     }
//   }

//   @override
//   void dispose() {
//     _debounce?.cancel();
//     _searchCtrl.dispose();
//     _custNameCtrl.dispose();
//     _custPhoneCtrl.dispose();
//     super.dispose();
//   }

//   double get _subtotal =>
//       _cart.fold<double>(0.0, (sum, l) => sum + l.lineTotal);

//   void _queueSuggest(String text) {
//     _debounce?.cancel();
//     _debounce = Timer(const Duration(milliseconds: 120), () async {
//       if (!mounted) return;
//       final q = text.trim();
//       if (q.isEmpty) {
//         setState(() => _suggestions = <Product>[]);
//         return;
//       }
//       final res = await widget.service.suggest(q, limit: 40);
//       if (mounted) setState(() => _suggestions = res);
//     });
//   }

//   void _add(Product p) {
//     final i = _cart.indexWhere((l) => l.product.id == p.id);
//     if (i >= 0) {
//       setState(() => _cart[i].qty += 1);
//     } else {
//       setState(() => _cart.add(CartLine(product: p, qty: 1)));
//     }
//     _searchCtrl.clear();
//     setState(() => _suggestions = <Product>[]);
//   }

//   void _inc(int i) => setState(() => _cart[i].qty += 1);
//   void _dec(int i) => setState(() {
//         final l = _cart[i];
//         if (l.qty > 1)
//           l.qty -= 1;
//         else
//           _cart.removeAt(i);
//       });
//   void _remove(int i) => setState(() => _cart.removeAt(i));

//   Future<void> _createInvoice() async {
//     if (_cart.isEmpty) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Add at least one item')),
//       );
//       return;
//     }
//     setState(() => _submitting = true);
//     try {
//       final res = await widget.service.createManualInvoice(
//         lines: _cart,
//         customerName: _custNameCtrl.text.trim().isEmpty
//             ? null
//             : _custNameCtrl.text.trim(),
//         customerPhone: _custPhoneCtrl.text.trim().isEmpty
//             ? null
//             : _custPhoneCtrl.text.trim(),
//         paid: true,
//         paymentMethod: 'CASH',
//       );

//       if (!mounted) return;

//       if (res.ok) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               'Invoice created • Order #${res.invoiceId ?? '-'}'
//               '${res.invoiceNumber != null ? ' • Inv ${res.invoiceNumber}' : ''}',
//             ),
//           ),
//         );
//         setState(() {
//           _cart.clear();
//           _custNameCtrl.clear();
//           _custPhoneCtrl.clear();
//         });
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(res.message ?? 'Failed to create invoice')),
//         );
//       }
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $e')),
//       );
//     } finally {
//       if (mounted) setState(() => _submitting = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Manual Billing (POS)'),
//         actions: [
//           IconButton(
//             tooltip: 'Reload products',
//             onPressed: () async {
//               setState(() => _warming = true);
//               await widget.service.warmProducts(force: true);
//               if (mounted) setState(() => _warming = false);
//             },
//             icon: const Icon(Icons.refresh),
//           ),
//         ],
//       ),

//       body: SafeArea(
//         child: ListView(
//           padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
//           children: [
//             // Search
//             TextField(
//               controller: _searchCtrl,
//               onChanged: _queueSuggest,
//               enabled: !_warming,
//               decoration: InputDecoration(
//                 hintText: _warming
//                     ? 'Loading products...'
//                     : 'Search products (type ≥ 1 letter)',
//                 prefixIcon: const Icon(Icons.search),
//                 filled: true,
//                 fillColor: theme.colorScheme.surface.withValues(alpha: 0.95),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//             ),

//             const SizedBox(height: 8),

//             // Suggestions list (compact)
//             if (_warming)
//               const Center(
//                   child: Padding(
//                 padding: EdgeInsets.all(8.0),
//                 child: CircularProgressIndicator(),
//               ))
//             else if (_suggestions.isNotEmpty)
//               Card(
//                 clipBehavior: Clip.antiAlias,
//                 elevation: 1.5,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: ConstrainedBox(
//                   constraints: const BoxConstraints(maxHeight: 320),
//                   child: ListView.separated(
//                     itemCount: _suggestions.length,
//                     separatorBuilder: (_, __) => const Divider(height: 1),
//                     itemBuilder: (_, i) {
//                       final p = _suggestions[i];
//                       return ListTile(
//                         onTap: () => _add(p),
//                         title: Text(
//                           p.name,
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         subtitle: Text(
//                           p.unit == null
//                               ? _money.format(p.price)
//                               : '${_money.format(p.price)} • ${p.unit}',
//                         ),
//                         trailing: const Icon(Icons.add),
//                         dense: true,
//                       );
//                     },
//                   ),
//                 ),
//               )
//             else
//               Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 6),
//                 child: Text(
//                   'Start typing to see suggestions',
//                   style: theme.textTheme.bodySmall,
//                 ),
//               ),

//             const SizedBox(height: 12),

//             // Customer row
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _custNameCtrl,
//                     decoration: InputDecoration(
//                       labelText: 'Customer name (optional)',
//                       filled: true,
//                       fillColor:
//                           theme.colorScheme.surface.withValues(alpha: 0.95),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 SizedBox(
//                   width: 200,
//                   child: TextField(
//                     controller: _custPhoneCtrl,
//                     keyboardType: TextInputType.phone,
//                     decoration: InputDecoration(
//                       labelText: 'Phone (optional)',
//                       filled: true,
//                       fillColor:
//                           theme.colorScheme.surface.withValues(alpha: 0.95),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 12),

//             // Cart
//             Card(
//               clipBehavior: Clip.antiAlias,
//               elevation: 1.5,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: _cart.isEmpty
//                   ? Padding(
//                       padding: const EdgeInsets.all(18),
//                       child: Center(
//                         child: Text('Cart is empty',
//                             style: theme.textTheme.bodyMedium),
//                       ),
//                     )
//                   : ListView.separated(
//                       shrinkWrap: true,
//                       physics: const NeverScrollableScrollPhysics(),
//                       itemCount: _cart.length,
//                       separatorBuilder: (_, __) => const Divider(height: 1),
//                       itemBuilder: (_, i) {
//                         final l = _cart[i];
//                         return ListTile(
//                           title: Text(
//                             l.product.name,
//                             maxLines: 2,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                           subtitle: Text(_money.format(l.unitPrice)),
//                           leading: CircleAvatar(
//                             backgroundColor: theme.colorScheme.primaryContainer,
//                             child: Text(
//                               '${i + 1}',
//                               style: TextStyle(
//                                 color: theme.colorScheme.onPrimaryContainer,
//                                 fontWeight: FontWeight.w700,
//                               ),
//                             ),
//                           ),
//                           trailing: SizedBox(
//                             width: 210,
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.end,
//                               children: [
//                                 IconButton(
//                                   tooltip: 'Decrease',
//                                   icon: const Icon(Icons.remove),
//                                   onPressed: () => _dec(i),
//                                 ),
//                                 Text(
//                                   '${l.qty}',
//                                   style: const TextStyle(
//                                     fontWeight: FontWeight.w700,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                                 IconButton(
//                                   tooltip: 'Increase',
//                                   icon: const Icon(Icons.add),
//                                   onPressed: () => _inc(i),
//                                 ),
//                                 const SizedBox(width: 8),
//                                 IconButton(
//                                   tooltip: 'Remove',
//                                   icon: const Icon(Icons.delete_outline),
//                                   onPressed: () => _remove(i),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//             ),

//             const SizedBox(height: 10),

//             Align(
//               alignment: Alignment.centerRight,
//               child: Text(
//                 'Subtotal: ${_money.format(_subtotal)}',
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),

//       // Bottom fixed action
//       bottomSheet: SafeArea(
//         child: Container(
//           padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
//           decoration: BoxDecoration(
//             color: theme.colorScheme.surface,
//             border: const Border(top: BorderSide(color: Colors.black12)),
//           ),
//           child: Row(
//             children: [
//               Expanded(
//                 child: Text(
//                   _cart.isEmpty
//                       ? 'Ready'
//                       : 'Items: ${_cart.length} • Total: ${_money.format(_subtotal)}',
//                   style: const TextStyle(fontWeight: FontWeight.w700),
//                 ),
//               ),
//               FilledButton.icon(
//                 onPressed: _submitting ? null : _createInvoice,
//                 icon: _submitting
//                     ? const SizedBox(
//                         width: 16,
//                         height: 16,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       )
//                     : const Icon(Icons.receipt_long),
//                 label: const Text('Create Invoice'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'billing_service.dart';

class PosScreen extends StatefulWidget {
  final BillingService service;
  const PosScreen({super.key, required this.service});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _custNameCtrl = TextEditingController();
  final _custPhoneCtrl = TextEditingController();

  final List<CartLine> _cart = <CartLine>[];
  List<Product> _suggestions = <Product>[];
  Timer? _debounce;

  bool _warming = true;
  bool _submitting = false;

  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _warm();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted || _submitting) return;
      _warm();
    });
  }

  Future<void> _warm() async {
    try {
      await widget.service.warmProducts();
    } finally {
      if (mounted) setState(() => _warming = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _autoRefreshTimer?.cancel();
    _searchCtrl.dispose();
    _custNameCtrl.dispose();
    _custPhoneCtrl.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _cart.fold<double>(0.0, (sum, l) => sum + l.lineTotal);

  void _queueSuggest(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 140), () async {
      if (!mounted) return;
      final q = text.trim();
      if (q.isEmpty) {
        setState(() => _suggestions = <Product>[]);
        return;
      }
      final res = await widget.service.suggest(q, limit: 50);
      if (mounted) setState(() => _suggestions = res);
    });
  }

  void _add(Product p) {
    final i = _cart.indexWhere((l) => l.product.id == p.id);
    if (i >= 0) {
      setState(() => _cart[i].qty += 1);
    } else {
      setState(() => _cart.add(CartLine(product: p, qty: 1)));
    }
    _searchCtrl.clear();
    setState(() => _suggestions = <Product>[]);
  }

  void _inc(int i) => setState(() => _cart[i].qty += 1);
  void _dec(int i) => setState(() {
        final l = _cart[i];
        if (l.qty > 1) {
          l.qty -= 1;
        } else {
          _cart.removeAt(i);
        }
      });
  void _remove(int i) => setState(() => _cart.removeAt(i));

  Future<void> _createInvoice() async {
    if (_cart.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await widget.service.createManualInvoice(
        lines: _cart,
        customerName: _custNameCtrl.text.trim().isEmpty
            ? null
            : _custNameCtrl.text.trim(),
        customerPhone: _custPhoneCtrl.text.trim().isEmpty
            ? null
            : _custPhoneCtrl.text.trim(),
        paid: true,
        paymentMethod: 'cash',
      );

      if (!mounted) return;

      if (res.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Invoice created • Order #${res.invoiceId ?? '-'}'
              '${res.invoiceNumber != null ? ' • Inv ${res.invoiceNumber}' : ''}',
            ),
          ),
        );
        setState(() {
          _cart.clear();
          _custNameCtrl.clear();
          _custPhoneCtrl.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Failed to create invoice')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Billing (POS)'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Reload products',
            onPressed: () async {
              setState(() => _warming = true);
              await widget.service.warmProducts(force: true);
              if (mounted) setState(() => _warming = false);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
          children: [
            // Search
            TextField(
              controller: _searchCtrl,
              onChanged: _queueSuggest,
              enabled: !_warming,
              decoration: InputDecoration(
                hintText: _warming
                    ? 'Loading products...'
                    : 'Search products (type ≥ 1 letter)',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.colorScheme.surface.withValues(alpha: 0.98),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Suggestions list (compact)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _warming
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : (_suggestions.isNotEmpty
                      ? Card(
                          clipBehavior: Clip.antiAlias,
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 320),
                            child: ListView.separated(
                              cacheExtent: 400,
                              addAutomaticKeepAlives: false,
                              itemCount: _suggestions.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final p = _suggestions[i];
                                return ListTile(
                                  onTap: () => _add(p),
                                  title: Text(
                                    p.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    p.unit == null
                                        ? _money.format(p.price)
                                        : '${_money.format(p.price)} • ${p.unit}',
                                  ),
                                  trailing: const Icon(Icons.add),
                                  dense: true,
                                );
                              },
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'Start typing to see suggestions',
                            style: theme.textTheme.bodySmall,
                          ),
                        )),
            ),
            const SizedBox(height: 12),

            // Customer row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _custNameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Customer name (optional)',
                      filled: true,
                      fillColor:
                          theme.colorScheme.surface.withValues(alpha: 0.98),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _custPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone (optional)',
                      filled: true,
                      fillColor:
                          theme.colorScheme.surface.withValues(alpha: 0.98),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Cart
            Card(
              clipBehavior: Clip.antiAlias,
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 150),
                child: _cart.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(18),
                        child: Center(
                          child: Text('Cart is empty',
                              style: theme.textTheme.bodyMedium),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _cart.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final l = _cart[i];
                          return ListTile(
                            title: Text(
                              l.product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(_money.format(l.unitPrice)),
                            leading: CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            trailing: SizedBox(
                              width: 220,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: 'Decrease',
                                    icon: const Icon(Icons.remove),
                                    onPressed: () => _dec(i),
                                  ),
                                  Text(
                                    '${l.qty}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Increase',
                                    icon: const Icon(Icons.add),
                                    onPressed: () => _inc(i),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Remove',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _remove(i),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Subtotal: ${_money.format(_subtotal)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom fixed action
      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _cart.isEmpty
                      ? 'Ready'
                      : 'Items: ${_cart.length} • Total: ${_money.format(_subtotal)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: _submitting ? null : _createInvoice,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long),
                label: const Text('Create Invoice'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
