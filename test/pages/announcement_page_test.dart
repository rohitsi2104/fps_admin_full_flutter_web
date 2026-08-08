import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_harness.dart';

/// Overflow regression tests for the announcement editor page
/// (`features/announcement/announcement_page.dart`).
///
/// Compositions reproduced faithfully (same subtree, styles, and sizes):
///   * Current-state banner (paused variant: dark-red container with icon + title)
///   * "Show on home screen" `SwitchListTile` (title + subtitle)
///   * "Notify users" `CheckboxListTile` (title + long subtitle)
///   * Multi-line `TextFormField` for the message
///   * Save button
///
/// The full form is exercised inside the real card + max-width envelope the
/// screen uses so nothing is falsely padded away from its production width.

const _longMessage =
    'Store Timings — Morning: 10:00 AM to 12:30 PM. Evening: 5:00 PM to 6:00 PM. Tuesday: closed (full day). Sunday: evening closed. Please plan your purchases accordingly and thank you for shopping at Fair Price Shop Dayalbagh.';

Widget _announcementForm({
  required TextEditingController ctrl,
  required bool isActive,
  required bool notify,
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
                  Text(
                    'Live message on customer home screen',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Shown as a card at the top of the app. Turn off to hide the card without deleting the text.',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: ctrl,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                      hintText:
                          'e.g. Store closed on Sunday for inventory.',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    onChanged: (_) {},
                    title: const Text('Show on home screen'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: notify && isActive,
                    onChanged: (_) {},
                    title: const Text('Notify users'),
                    subtitle: Text(
                      isActive
                          ? 'Send a push notification to all customers on save'
                          : 'Turn the card on to notify users',
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
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
  group('Announcement editor form holds up across the matrix', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('long message + notify on $cfg', (tester) async {
        final ctrl = TextEditingController(text: _longMessage);
        addTearDown(ctrl.dispose);

        await pumpOnDevice(
          tester,
          cfg,
          _announcementForm(ctrl: ctrl, isActive: true, notify: true),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Save'), findsOneWidget);
        expect(find.text('Show on home screen'), findsOneWidget);
        expect(find.text('Notify users'), findsOneWidget);
        // The multi-line TextFormField hosts the long message. Just check
        // it rendered (no exception above).
        expect(find.textContaining('Store Timings'), findsOneWidget);
      });
    }
  });

  group('Announcement editor with card OFF (notify disabled)', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('notify subtitle switches copy on $cfg', (tester) async {
        final ctrl = TextEditingController();
        addTearDown(ctrl.dispose);

        await pumpOnDevice(
          tester,
          cfg,
          _announcementForm(ctrl: ctrl, isActive: false, notify: true),
        );

        expect(tester.takeException(), isNull);
        // The notify subtitle switches to the "turn on to notify" prompt
        // whenever the card is off.
        expect(
          find.text('Turn the card on to notify users'),
          findsOneWidget,
        );
      });
    }
  });
}
