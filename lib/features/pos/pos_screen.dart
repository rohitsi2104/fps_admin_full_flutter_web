import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/api_provider.dart';
import 'billing_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design constants (dark cart panel palette)
// ─────────────────────────────────────────────────────────────────────────────
const _panelBg       = Color(0xFF0F172A);
const _itemBg        = Color(0xFF1E293B);
const _dividerCol    = Color(0xFF334155);
const _mutedText     = Color(0xFF94A3B8);
const _dimText       = Color(0xFF475569);
const _surfaceBg     = Color(0xFFF1F5F9);

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen>
    with TickerProviderStateMixin {
  final _searchCtrl   = TextEditingController();
  final _custNameCtrl = TextEditingController();
  final _custPhoneCtrl = TextEditingController();

  final List<CartLine> _cart       = <CartLine>[];
  List<Product>        _suggestions = <Product>[];
  Timer? _debounce;
  Timer? _autoRefreshTimer;

  bool _warming    = true;
  bool _submitting = false;

  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _warm();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted || _submitting) return;
      _warm();
    });
    _searchCtrl.addListener(() => setState(() {})); // trigger suffix icon rebuild
  }

  Future<void> _warm({bool force = false}) async {
    if (mounted) setState(() => _warming = true);
    try {
      await ref.read(billingServiceProvider).warmProducts(force: force);
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

  // ── cart helpers ──────────────────────────────────────────────────────────

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
      final res =
          await ref.read(billingServiceProvider).suggest(q, limit: 50);
      if (mounted) setState(() => _suggestions = res);
    });
  }

  void _add(Product p) {
    final i = _cart.indexWhere((l) => l.product.id == p.id);
    setState(() {
      if (i >= 0) {
        _cart[i].qty += 1;
      } else {
        _cart.add(CartLine(product: p, qty: 1));
      }
      _searchCtrl.clear();
      _suggestions = <Product>[];
    });
  }

  void _inc(int i)    => setState(() => _cart[i].qty += 1);
  void _dec(int i)    => setState(() {
    if (_cart[i].qty > 1) {
      _cart[i].qty -= 1;
    } else {
      _cart.removeAt(i);
    }
  });
  void _remove(int i) => setState(() => _cart.removeAt(i));

  // ── invoice ───────────────────────────────────────────────────────────────

  Future<void> _createInvoice() async {
    if (_cart.isEmpty) {
      if (!mounted) return;
      _showSnack('Add at least one item');
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await ref.read(billingServiceProvider).createManualInvoice(
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
        _showSnack(
          'Invoice created • Order #${res.invoiceId ?? '-'}'
          '${res.invoiceNumber != null ? ' • Inv ${res.invoiceNumber}' : ''}',
          success: true,
        );
        setState(() {
          _cart.clear();
          _custNameCtrl.clear();
          _custPhoneCtrl.clear();
        });
      } else {
        _showSnack(res.message ?? 'Failed to create invoice');
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? const Color(0xFF059669) : null,
        content: Text(msg),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            return isWide ? _wideLayout() : _narrowLayout();
          },
        ),
      ),
    );
  }

  // ── wide layout (side-by-side) ────────────────────────────────────────────

  Widget _wideLayout() {
    return Row(
      children: [
        Expanded(flex: 6, child: _leftPanel()),
        SizedBox(width: 360, child: _cartPanel(roundLeft: true)),
      ],
    );
  }

  // ── narrow layout (stacked) ───────────────────────────────────────────────

  Widget _narrowLayout() {
    return Column(
      children: [
        Expanded(child: _leftPanel()),
        SizedBox(height: 300, child: _cartPanel(roundLeft: false, roundTop: true)),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LEFT PANEL
  // ─────────────────────────────────────────────────────────────────────────

  Widget _leftPanel() {
    final theme = Theme.of(context);
    final dateStr = DateFormat('EEE, d MMM yyyy').format(DateTime.now());

    return Container(
      color: _surfaceBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                // Store icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Point of Sale',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 12, color: _mutedText),
                    ),
                  ],
                ),
                const Spacer(),
                // Refresh button
                Tooltip(
                  message: 'Reload products',
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    elevation: 0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _warm(force: true),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        child: AnimatedRotation(
                          turns: _warming ? 1 : 0,
                          duration: const Duration(milliseconds: 800),
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Search bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: _SearchBar(
              controller: _searchCtrl,
              warming: _warming,
              onChanged: _queueSuggest,
              onClear: () {
                _searchCtrl.clear();
                setState(() => _suggestions = []);
              },
              accentColor: theme.colorScheme.primary,
            ),
          ),

          // ── Suggestion list ───────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: _buildSuggestions(theme),
            ),
          ),

          // ── Customer info ─────────────────────────────────────────────────
          _CustomerCard(
            nameCtrl: _custNameCtrl,
            phoneCtrl: _custPhoneCtrl,
            accentColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(ThemeData theme) {
    if (_warming) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 12),
            Text('Loading products…', style: TextStyle(color: _mutedText, fontSize: 13)),
          ],
        ),
      );
    }

    if (_suggestions.isEmpty && _searchCtrl.text.isEmpty) {
      return _emptySearchPlaceholder();
    }

    if (_suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            const Text('No products found', style: TextStyle(color: _mutedText, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _ProductTile(
        product: _suggestions[i],
        money: _money,
        onTap: () => _add(_suggestions[i]),
        accentColor: theme.colorScheme.primary,
      ),
    );
  }

  Widget _emptySearchPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16),
              ],
            ),
            child: const Icon(Icons.inventory_2_outlined, size: 32, color: _dimText),
          ),
          const SizedBox(height: 16),
          const Text(
            'Search for a product',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _dimText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Type at least one character to see suggestions',
            style: TextStyle(fontSize: 12, color: _mutedText),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CART PANEL (dark)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _cartPanel({required bool roundLeft, bool roundTop = false}) {
    final theme   = Theme.of(context);
    final primary = theme.colorScheme.primary;

    BorderRadius radius = BorderRadius.zero;
    if (roundLeft) {
      radius = const BorderRadius.only(
        topLeft: Radius.circular(24),
        bottomLeft: Radius.circular(24),
      );
    } else if (roundTop) {
      radius = const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: radius,
      ),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
            child: Row(
              children: [
                const Text(
                  'Order Summary',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _cart.isNotEmpty
                      ? Container(
                          key: const ValueKey('badge'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_cart.length} item${_cart.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('nobadge')),
                ),
              ],
            ),
          ),

          const Divider(color: _dividerCol, height: 1),

          // ── Cart items ────────────────────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _cart.isEmpty
                  ? _emptyCart()
                  : ListView.separated(
                      key: const ValueKey('cart-list'),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      itemCount: _cart.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: _dividerCol, height: 18),
                      itemBuilder: (_, i) => _CartItemRow(
                        line: _cart[i],
                        money: _money,
                        onInc: () => _inc(i),
                        onDec: () => _dec(i),
                        onRemove: () => _remove(i),
                        accentColor: primary,
                      ),
                    ),
            ),
          ),

          // ── Summary + checkout ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _dividerCol)),
            ),
            child: Column(
              children: [
                _SummaryRow(
                  label: 'Items',
                  value: '${_cart.length}',
                  small: true,
                ),
                const SizedBox(height: 6),
                _SummaryRow(
                  label: 'Subtotal',
                  value: _money.format(_subtotal),
                  small: true,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: _dividerCol, height: 1),
                ),
                _SummaryRow(
                  label: 'Total',
                  value: _money.format(_subtotal),
                  valueColor: primary,
                  bold: true,
                ),
                const SizedBox(height: 16),
                // Checkout button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: (_submitting || _cart.isEmpty)
                        ? null
                        : _createInvoice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _itemBg,
                      disabledForegroundColor: _dimText,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.receipt_long_rounded, size: 18),
                    label: Text(
                      _submitting ? 'Processing…' : 'Create Invoice',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCart() {
    return Center(
      key: const ValueKey('empty-cart'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _itemBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 26,
              color: _dimText,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Cart is empty',
            style: TextStyle(
              color: _mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Search and add products',
            style: TextStyle(color: _dimText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.warming,
    required this.onChanged,
    required this.onClear,
    required this.accentColor,
  });

  final TextEditingController controller;
  final bool warming;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        enabled: !warming,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: warming ? 'Loading products…' : 'Search products…',
          hintStyle: const TextStyle(color: _mutedText, fontSize: 14),
          prefixIcon: warming
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentColor,
                    ),
                  ),
                )
              : const Icon(Icons.search_rounded, color: _mutedText, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: _dimText, size: 18),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
    );
  }
}

// ── Product suggestion tile ───────────────────────────────────────────────────

class _ProductTile extends StatefulWidget {
  const _ProductTile({
    required this.product,
    required this.money,
    required this.onTap,
    required this.accentColor,
  });

  final Product product;
  final NumberFormat money;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  State<_ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<_ProductTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.accentColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hovered
              ? Color.alphaBlend(
                  primary.withValues(alpha: 0.06), Colors.white)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered
                ? primary.withValues(alpha: 0.25)
                : Colors.transparent,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                // Product name + unit
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.product.unit != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.product.unit!,
                          style: const TextStyle(
                              fontSize: 11, color: _mutedText),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Price badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.money.format(widget.product.price),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Add button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _hovered ? primary : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 15,
                    color: _hovered ? Colors.white : _dimText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Cart item row (inside dark panel) ────────────────────────────────────────

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({
    required this.line,
    required this.money,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
    required this.accentColor,
  });

  final CartLine line;
  final NumberFormat money;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Product info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                line.product.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                money.format(line.unitPrice),
                style: const TextStyle(color: _mutedText, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Qty control row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _QtyBtn(icon: Icons.remove_rounded, onTap: onDec),
            SizedBox(
              width: 26,
              child: Text(
                '${line.qty}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _QtyBtn(icon: Icons.add_rounded, onTap: onInc),
          ],
        ),
        const SizedBox(width: 10),
        // Line total
        SizedBox(
          width: 68,
          child: Text(
            money.format(line.lineTotal),
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Remove
        GestureDetector(
          onTap: onRemove,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close_rounded, size: 14, color: _dimText),
          ),
        ),
      ],
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: _itemBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 13, color: Colors.white),
      ),
    );
  }
}

// ── Summary row (inside dark panel) ──────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.small = false,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool small;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final fontSize = small ? 12.0 : 15.0;
    final labelColor = small ? _mutedText : Colors.white;
    final valColor = valueColor ?? Colors.white;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valColor,
            fontSize: bold ? fontSize + 4 : fontSize,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Customer card ─────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.accentColor,
  });

  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                'Customer  (optional)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InlineField(
                  controller: nameCtrl,
                  hint: 'Customer name',
                  icon: Icons.badge_outlined,
                  accentColor: accentColor,
                  inputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 170,
                child: _InlineField(
                  controller: phoneCtrl,
                  hint: 'Phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  accentColor: accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineField extends StatelessWidget {
  const _InlineField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.accentColor,
    this.keyboardType,
    this.inputAction,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final TextInputType? keyboardType;
  final TextInputAction? inputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: inputAction,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _mutedText, fontSize: 13),
        prefixIcon: Icon(icon, size: 15, color: _mutedText),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentColor),
        ),
      ),
    );
  }
}
