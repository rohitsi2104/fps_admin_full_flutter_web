// lib/stock/bulk_update_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';

class BulkUpdatePage extends StatefulWidget {
  final Api api;
  const BulkUpdatePage({super.key, required this.api});

  @override
  State<BulkUpdatePage> createState() => _BulkUpdatePageState();
}

class _BulkUpdatePageState extends State<BulkUpdatePage> {
  final _rows = <_EditRow>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _rows.add(_EditRow()); // start with one row
  }

  Future<void> _submit() async {
    final items = <BulkPatch>[];
    for (final r in _rows) {
      final p = r.product;
      final stock = int.tryParse(r.stockCtrl.text.trim());
      final price = double.tryParse(r.priceCtrl.text.trim());
      if (p == null) continue; // skip empty row
      if (stock == null && price == null) continue;
      items.add(BulkPatch(id: p.id, stock: stock, price: price));
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one valid update')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final res = await widget.api.updateProductsBulk(items);
      if (!mounted) return;
      final msg = res.errors.isEmpty
          ? 'Updated ${res.updated} products'
          : 'Updated ${res.updated}, ${res.errors.length} errors';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (res.errors.isNotEmpty) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Errors'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Text(res.errors.take(100).join('\n')),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bulk update failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _addRow() => setState(() => _rows.add(_EditRow()));

  void _removeRow(int i) => setState(() => _rows.removeAt(i));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Update'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _submit,
        icon: const Icon(Icons.cloud_upload),
        label: const Text('Submit'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: cs.primaryContainer.withValues(alpha: 0.25),
            child: ListTile(
              title: const Text('Make multiple edits to stock/price'),
              subtitle: const Text(
                  'Tap product to choose via search • Leave a field empty to skip updating it'),
              trailing: OutlinedButton.icon(
                onPressed: _busy ? null : _addRow,
                icon: const Icon(Icons.add),
                label: const Text('Add row'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._rows.indexed.map((e) {
            final i = e.$1;
            final row = e.$2;
            return _RowCard(
              index: i,
              row: row,
              api: widget.api,
              onRemove: () => _removeRow(i),
            );
          }),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _RowCard extends StatefulWidget {
  final int index;
  final _EditRow row;
  final Api api;
  final VoidCallback onRemove;

  const _RowCard({
    required this.index,
    required this.row,
    required this.api,
    required this.onRemove,
  });

  @override
  State<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<_RowCard> {
  final _searchCtrl = TextEditingController();
  Timer? _deb;

  @override
  void initState() {
    super.initState();
    if (widget.row.product != null) {
      _searchCtrl.text = widget.row.product!.name;
    }
  }

  @override
  void dispose() {
    _deb?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openSearch() async {
    final chosen = await showModalBottomSheet<ProductLite>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProductSearchSheet(api: widget.api),
    );
    if (chosen != null) {
      setState(() {
        widget.row.product = chosen;
        _searchCtrl.text = chosen.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.row.product;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _openSearch,
                    child: IgnorePointer(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          labelText: 'Product',
                          hintText: 'Tap to search',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: p == null
                              ? null
                              : Tooltip(
                                  message:
                                      'ID ${p.id} • Stock ${p.stock} • ₹${p.price}',
                                  child: const Icon(Icons.info_outline),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove row',
                )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.row.stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'New stock (optional)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: widget.row.priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'New price (optional)',
                      prefixText: '₹ ',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductSearchSheet extends StatefulWidget {
  final Api api;
  const _ProductSearchSheet({required this.api});

  @override
  State<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<_ProductSearchSheet> {
  final _q = TextEditingController();
  List<ProductLite> _results = [];
  bool _loading = false;
  Timer? _deb;

  @override
  void dispose() {
    _q.dispose();
    _deb?.cancel();
    super.dispose();
  }

  void _search(String s) {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _loading = true);
      try {
        final r = await widget.api.searchProducts(s, limit: 30);
        if (!mounted) return;
        setState(() => _results = r);
      } catch (_) {
        if (!mounted) return;
        setState(() => _results = []);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _q,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Search products',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _search,
                ),
              ),
              const SizedBox(height: 8),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final p = _results[i];
                    return ListTile(
                      title: Text(p.name),
                      subtitle:
                          Text('ID ${p.id} • Stock ${p.stock} • ₹${p.price}'),
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditRow {
  ProductLite? product;
  final stockCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
}
