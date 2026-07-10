import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A single device configuration to exercise: logical size + text scale.
class DeviceConfig {
  final String name;
  final double width;
  final double height;
  final double textScale;
  const DeviceConfig(this.name, this.width, this.height, this.textScale);

  @override
  String toString() => '$name (${width.toInt()}x${height.toInt()} @${textScale}x)';
}

/// The stress matrix: narrow/normal/wide phones × normal/large/huge font scale.
/// The huge (1.5x) column is deliberately ABOVE the app's production clamp
/// (1.3x) so we prove the widgets themselves are robust, not just the clamp.
const kDeviceMatrix = <DeviceConfig>[
  DeviceConfig('small-phone', 320, 640, 1.0),
  DeviceConfig('small-phone-large-font', 320, 640, 1.3),
  DeviceConfig('small-phone-huge-font', 320, 640, 1.5),
  DeviceConfig('normal-phone', 360, 800, 1.0),
  DeviceConfig('normal-phone-large-font', 360, 800, 1.3),
  DeviceConfig('normal-phone-huge-font', 360, 800, 1.5),
  DeviceConfig('big-phone', 411, 900, 1.0),
  DeviceConfig('big-phone-huge-font', 411, 900, 1.5),
];

/// Pumps [child] as if it were on a device of the given [cfg], injecting the
/// text scale below MaterialApp so it reaches the widget under test.
Future<void> pumpOnDevice(
  WidgetTester tester,
  DeviceConfig cfg,
  Widget child,
) async {
  const dpr = 2.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(cfg.width * dpr, cfg.height * dpr);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(cfg.textScale)),
            child: Scaffold(body: SafeArea(child: child)),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Asserts the rendered [finder] did not collapse into a tall stack of
/// per-character lines. We allow up to [maxLines] lines of text (plus slack);
/// the per-character-wrap bug produces heights many times larger than this.
void expectNotCollapsed(
  WidgetTester tester,
  Finder finder, {
  required double fontSize,
  required double textScale,
  int maxLines = 2,
  String? label,
}) {
  final size = tester.getSize(finder);
  // Generous per-line height estimate: font size × scale × 1.6 line-height.
  final perLine = fontSize * textScale * 1.6;
  final ceiling = perLine * (maxLines + 0.5);
  expect(
    size.height,
    lessThan(ceiling),
    reason:
        '${label ?? finder.description} collapsed: height ${size.height.toStringAsFixed(1)}px '
        'exceeds $maxLines-line ceiling ${ceiling.toStringAsFixed(1)}px '
        '(font $fontSize @${textScale}x). Likely per-character wrapping.',
  );
}
