import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_harness.dart';

/// Overflow regression tests for features/auth/login_page.dart.
///
/// The real LoginPage is a network/plugin-backed ConsumerStatefulWidget whose
/// error text (`_error`) is private state only set after a failed submit, so we
/// reproduce the login Card/Form column faithfully — same widgets, styles and
/// sizes — and stress it with a very long error message (an exception string is
/// exactly what lands there) across the device/text-scale matrix.

// A realistic long exception string, which is what `e.toString()` produces.
const _longError =
    'DioException [connection error]: The connection errored: Failed host '
    'lookup: fps-dayalbagh-backend.vercel.app (OS Error: No address associated '
    'with hostname, errno = 7)';

Widget _loginCard(BuildContext context, {String? error}) {
  final cs = Theme.of(context).colorScheme;
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Welcome back',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  const TextField(
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (error != null)
                    Text(error,
                        style: TextStyle(color: cs.error, fontSize: 13)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.login),
                      label: const Text('Login'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Login — form card', () {
    for (final cfg in kDeviceMatrix) {
      testWidgets('no overflow (no error) on $cfg', (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          Builder(builder: (context) => _loginCard(context)),
        );
        expect(tester.takeException(), isNull);
        // 'Welcome back' is a plain (non-AppText) header that legitimately
        // soft-wraps; allow up to 2 lines. The goal here is proving it does
        // not collapse into a per-character stack.
        expectNotCollapsed(
          tester,
          find.text('Welcome back'),
          fontSize: 22,
          textScale: cfg.textScale,
          maxLines: 2,
          label: 'welcome header on $cfg',
        );
      });

      testWidgets('no overflow with long error on $cfg', (tester) async {
        await pumpOnDevice(
          tester,
          cfg,
          // Scroll wrapper mirrors that the card lives in a scrollable Center
          // region; keeps a genuinely tall error from being a false positive.
          SingleChildScrollView(
            child: Builder(
              builder: (context) => _loginCard(context, error: _longError),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
