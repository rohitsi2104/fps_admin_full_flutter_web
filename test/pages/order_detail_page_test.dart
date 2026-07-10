import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fps_admin/shared/app_ui.dart';
import 'package:intl/intl.dart';

import '../support/ui_harness.dart';

/// Overflow regression tests for features/orders/order_detail_page.dart.
///
/// The real page is a network-backed ConsumerStatefulWidget (starts refresh
/// timers, reads apiProvider), so we reproduce each overflow-prone subtree
/// faithfully — same widgets, same styles, same font sizes — and feed stress
/// data across the device/text-scale matrix.

// Same formatter the page uses.
final _dfMoney = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

const _bigId = 1029384756;
const _bigAmount = 1234567.89;
const _longName = 'Radhasoami Satsang Sabha Dayalbagh Agra Uttar Pradesh Branch';
const _longPhone = '+91 98765 43210 / +91 91234 56789 (Reception Desk)';
const _addr1 = 'House No 123, Radhasoami Satsang Sabha Marg, Near Prem Vidyalaya';
const _addr2 = 'Opposite Dayalbagh Educational Institute Main Gate, Block C Wing';
const _longProduct =
    'Premium Organic Cold-Pressed Extra Virgin Coconut Oil 1 Litre Glass Bottle';
const _created = '2026-12-31 23:59';
const _chipColor = Color(0xFFB58105); // confirmed

/// Reproduces the AppBar: dynamic title + add action + status dropdown chip.
Widget _detailScaffold() {
  return Scaffold(
    appBar: AppBar(
      title: const AppText('Order #$_bigId'),
      leading: const BackButton(),
      actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.add_shopping_cart)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _chipColor.withValues(alpha: 0.12),
              border: Border.all(color: _chipColor.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: 'CONFIRMED',
                isDense: true,
                icon: const Icon(Icons.swap_vert, size: 16, color: _chipColor),
                style: const TextStyle(
                  color: _chipColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                items: const [
                  DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                  DropdownMenuItem(
                      value: 'CONFIRMED', child: Text('Confirmed')),
                  DropdownMenuItem(value: 'RECEIVED', child: Text('Received')),
                  DropdownMenuItem(value: 'READY', child: Text('Ready')),
                  DropdownMenuItem(
                      value: 'DELIVERED', child: Text('Delivered')),
                  DropdownMenuItem(
                      value: 'CANCELLED', child: Text('Cancelled')),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: const SizedBox.shrink(),
  );
}

/// Reproduces the shipping/total header Card (address ListTile + phone rows).
Widget _shippingCard() {
  return Padding(
    padding: const EdgeInsets.all(12.0),
    child: Card(
      elevation: 1,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.location_on, color: Colors.blueGrey),
            title: const AppText(_longName),
            subtitle: AppText.multiline(
              '$_addr1\n$_addr2\nDayalbagh, Agra, Uttar Pradesh 282005\n'
              'Placed: $_created',
              maxLines: 5,
            ),
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: AppText(
                        _dfMoney.format(_bigAmount),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: 'Edit Amount',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            visualDensity: VisualDensity.compact,
            title: Row(
              children: [
                const Icon(Icons.phone_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    const TextSpan(
                      text: 'Shipping: ',
                      children: [
                        TextSpan(
                          text: _longPhone,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.indigo,
                            fontSize: 18,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.call, color: Colors.green),
              onPressed: () {},
            ),
          ),
          ListTile(
            visualDensity: VisualDensity.compact,
            title: Row(
              children: [
                const Icon(Icons.account_circle_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    const TextSpan(
                      text: 'Account: ',
                      children: [
                        TextSpan(
                          text: _longPhone,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.indigo,
                            fontSize: 18,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.call, color: Colors.green),
              onPressed: () {},
            ),
          ),
        ],
      ),
    ),
  );
}

/// Reproduces a single item Card from the items ListView (no-image branch).
Widget _itemCard() {
  return Card(
    elevation: 1,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText.multiline(
            _longProduct,
            maxLines: 2,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    size: 20, color: Colors.blueGrey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Qty: 9999  •  ${_dfMoney.format(1234.56)} ea',
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 13),
                    ),
                    AppText(
                      'Subtotal: ${_dfMoney.format(_bigAmount)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent, size: 22),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.blueGrey, size: 22),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.blueAccent, size: 22),
                    onPressed: () {},
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
}

/// Reproduces the bottom action-button Row (Row of Expanded buttons).
Widget _actionButtons() {
  return SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: () {},
              child: const Text('Mark Received (Paid)'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('Order detail — AppBar', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('no overflow + title not collapsed on $cfg', (tester) async {
        await pumpOnDevice(tester, cfg, _detailScaffold());
        expect(tester.takeException(), isNull);
        expectNotCollapsed(
          tester,
          find.textContaining('Order #'),
          fontSize: 20,
          textScale: cfg.textScale,
          maxLines: 1,
          label: 'appbar title on $cfg',
        );
      });
    }
  });

  group('Order detail — shipping/total header card', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('no overflow + name not collapsed on $cfg', (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          ListView(children: [_shippingCard()]),
        );
        expect(tester.takeException(), isNull);
        expectNotCollapsed(
          tester,
          find.text(_longName),
          fontSize: 16,
          textScale: cfg.textScale,
          maxLines: 1,
          label: 'shipping name on $cfg',
        );
      });
    }
  });

  group('Order detail — item card', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('no overflow + product not collapsed on $cfg',
          (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [_itemCard()],
          ),
        );
        expect(tester.takeException(), isNull);
        expectNotCollapsed(
          tester,
          find.text(_longProduct),
          fontSize: 16,
          textScale: cfg.textScale,
          maxLines: 2,
          label: 'product name on $cfg',
        );
      });
    }
  });

  group('Order detail — bottom action buttons', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('no overflow on $cfg', (tester) async {
        await pumpOnDevice(tester, cfg, _actionButtons());
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Order detail — dialogs', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('add-qty / remove-item / search dialog contents on $cfg',
          (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // _addItem() dialog title.
              const AppText.multiline('Add $_longProduct', maxLines: 2),
              const SizedBox(height: 12),
              // _removeItem() dialog content.
              const AppText.multiline(
                'Remove $_longProduct from order?',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              // ProductSearchDialog result tile.
              ListTile(
                title: const AppText(_longProduct),
                subtitle: AppText('Stock: 9999 • ₹${_bigAmount.toString()}'),
                onTap: () {},
              ),
            ],
          ),
        );
        expect(tester.takeException(), isNull);
        expectNotCollapsed(
          tester,
          find.text(_longProduct),
          fontSize: 14,
          textScale: cfg.textScale,
          maxLines: 1,
          label: 'search result tile on $cfg',
        );
      });
    }
  });
}
