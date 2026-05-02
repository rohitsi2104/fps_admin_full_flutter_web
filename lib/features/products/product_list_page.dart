import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/api.dart';
import '../../providers/api_provider.dart';
import '../stock/stock_page.dart';

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _searchCtrl = TextEditingController();

  List<ProductLite> _products = [];
  bool _loading = true;
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() => _loading = true);
    try {
      final results = await ref.read(apiProvider).searchProducts(_query, limit: 100);
      if (mounted) {
        setState(() {
          _products = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load products: $e')),
        );
      }
    }
  }

  void _onSearchChanged(String s) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _query = s);
        _fetchProducts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: cs.surfaceVariant.withValues(alpha: 0.3),
      appBar: AppBar(
        title: const Text('Product Catalog'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Search Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or category...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
                filled: true,
                fillColor: cs.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          
          if (_loading && _products.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_products.isEmpty)
            const Expanded(child: Center(child: Text('No products found')))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchProducts,
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 4 : 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];
                    return _ProductCard(
                      product: p,
                      money: _money,
                      onTap: () => _openAdjust(p),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openAdjust(ProductLite p) async {
    // We can't directly call _quickAdjustDialog because it's private in StockPage
    // For now, let's navigate to a new small edit dialog or similar.
    // Actually, I'll implement a local version of it here for better UX.
    
    // For now, I'll just show a snackbar or implement the dialog.
    // I'll implement a clean bottom sheet for editing.
    _showEditBottomSheet(p);
  }

  void _showEditBottomSheet(ProductLite p) {
    // I'll create a simplified version of the stock adjust tool here
    // or better, I should move the logic to a helper or just duplicate it for speed.
    // I'll implement it as a semi-transparent bottom sheet.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuickEditSheet(product: p, onUpdated: _fetchProducts),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductLite product;
  final NumberFormat money;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.money,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLowStock = product.stock > 0 && product.stock <= 5;
    final isOutOfStock = product.stock <= 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: Product Name
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
              ),
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (product.displayImageUrl != null)
                    CachedNetworkImage(
                      imageUrl: product.displayImageUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      maxWidthDiskCache: 400,
                      errorWidget: (_, __, ___) => Container(
                        color: cs.surfaceVariant,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                      placeholder: (context, _) => Container(
                        color: cs.surfaceVariant,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    )
                  else
                    Container(
                      color: cs.surfaceVariant,
                      child: const Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey),
                    ),
                  
                  // Status Badges
                  if (isOutOfStock)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _Badge(label: 'OUT OF STOCK', color: Colors.red),
                    )
                  else if (isLowStock)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _Badge(label: 'LOW STOCK', color: Colors.orange),
                    ),
                ],
              ),
            ),
            
            // Info Section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    money.format(product.price),
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Qty: ${product.stock}',
                    style: TextStyle(
                      color: isOutOfStock ? Colors.red : cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }
}


class _QuickEditSheet extends ConsumerStatefulWidget {
  final ProductLite product;
  final VoidCallback onUpdated;
  const _QuickEditSheet({required this.product, required this.onUpdated});

  @override
  ConsumerState<_QuickEditSheet> createState() => _QuickEditSheetState();
}

class _QuickEditSheetState extends ConsumerState<_QuickEditSheet> {
  late ProductLite _product;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _priceCtrl;
  
  Uint8List? _newImageBytes;
  String? _newImagePath;
  String? _newImageName;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _stockCtrl = TextEditingController(text: _product.stock.toString());
    _priceCtrl = TextEditingController(text: _product.price.toString());
  }

  @override
  void dispose() {
    _stockCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true, // needed for web
      );
      if (res != null && res.files.isNotEmpty) {
        final f = res.files.first;
        setState(() {
          _newImageBytes = f.bytes;
          _newImagePath = f.path; // needed for mobile
          _newImageName = f.name;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _save() async {
    final s = int.tryParse(_stockCtrl.text);
    final p = double.tryParse(_priceCtrl.text);
    
    setState(() => _busy = true);
    try {
      final updated = await ref.read(apiProvider).updateProductFull(
        productId: _product.id,
        stock: s,
        price: p,
        imageBytes: _newImageBytes,
        imagePath: _newImagePath,
        imageName: _newImageName,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated successfully!')));
        widget.onUpdated();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _product.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            
            // Image Management
            const Text('Product Image', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _busy ? null : _pickImage,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(16),
                  color: cs.surfaceVariant.withValues(alpha: 0.3),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_newImageBytes != null)
                      Image.memory(_newImageBytes!, fit: BoxFit.contain)
                    else if (_product.imageUrl != null)
                      CachedNetworkImage(
                        imageUrl: _product.imageUrl!,
                        fit: BoxFit.contain,
                        memCacheWidth: 800,
                      )
                    else
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 32),
                          SizedBox(height: 4),
                          Text('Tap to select photo', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    if (_busy)
                      Container(
                        color: Colors.white70,
                        child: const CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            if (_newImageName != null)
               Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: Text('Selected: $_newImageName', style: const TextStyle(fontSize: 12, color: Colors.blue)),
               ),
      
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price (₹)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save All Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
