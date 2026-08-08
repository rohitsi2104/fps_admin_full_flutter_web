import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_harness.dart';

/// Overflow regression tests for the store-acceptance editor page
/// (`features/store/store_status_page.dart`).
///
/// Compositions reproduced faithfully:
///   * Current-state banner (green "Accepting orders" and red "Not
///     accepting orders" variants), leading icon + Expanded bold label.
///   * `SwitchListTile` "Accept new online orders" + explanatory subtitle.
///   * Multi-line `TextFormField` for the pause message.
///   * Save button.

const _longPauseMessage =
    'Temporarily closed for stock intake and store maintenance. We expect to be back at 5 PM today — thank you for your patience.';

Widget _stateBanner(BuildContext context, {required bool paused}) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: paused ? cs.errorContainer : cs.primaryContainer,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(
          paused ? Icons.pause_circle_filled : Icons.check_circle,
          color: paused ? cs.onErrorContainer : cs.onPrimaryContainer,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            paused ? 'Not accepting orders' : 'Accepting orders',
            style: TextStyle(
              color: paused ? cs.onErrorContainer : cs.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _storeStatusForm({
  required TextEditingController ctrl,
  required bool accepting,
}) {
  return Builder(builder: (context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _stateBanner(context, paused: !accepting),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: accepting,
                    onChanged: (_) {},
                    title: const Text('Accept new online orders'),
                    subtitle: Text(
                      accepting
                          ? 'Customers can place orders as normal'
                          : 'Customers see a pause message and cannot check out',
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: ctrl,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'Message shown to customers when paused',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                      hintText:
                          'e.g. Closed for stock intake. Back at 5 PM.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  });
}

void main() {
  group('Store status editor — paused variant across the matrix', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('paused banner + long pause message on $cfg',
          (tester) async {
        final ctrl = TextEditingController(text: _longPauseMessage);
        addTearDown(ctrl.dispose);

        await pumpOnDevice(
          tester,
          cfg,
          _storeStatusForm(ctrl: ctrl, accepting: false),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Not accepting orders'), findsOneWidget);
        expect(find.text('Accept new online orders'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
        expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);
        // The switch subtitle switches to the customer-facing warning copy
        // when the store is paused.
        expect(
          find.text('Customers see a pause message and cannot check out'),
          findsOneWidget,
        );
      });
    }
  });

  group('Store status editor — accepting variant across the matrix', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('accepting banner on $cfg', (tester) async {
        final ctrl = TextEditingController();
        addTearDown(ctrl.dispose);

        await pumpOnDevice(
          tester,
          cfg,
          _storeStatusForm(ctrl: ctrl, accepting: true),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Accepting orders'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(
          find.text('Customers can place orders as normal'),
          findsOneWidget,
        );
      });
    }
  });
}
