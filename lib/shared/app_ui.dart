import 'package:flutter/material.dart';

/// Shared, overflow-safe UI primitives for the FPS Admin app.
///
/// These components exist to eliminate the class of layout bug where a `Text`
/// with dynamic content gets squeezed to near-zero width inside a `Row` /
/// `ListTile.trailing` and collapses into per-character vertical wrapping
/// (e.g. "Order #928" rendering as "Ord / er / #92 / 8").
///
/// The rules encoded here — enforced once, reused everywhere:
///   1. Every dynamic `Text` has `maxLines` + `TextOverflow.ellipsis`.
///   2. The flexible text region always lives inside an `Expanded`, so it can
///      never be starved of width by a sibling.
///   3. Trailing content is bounded and never competes with the title for space.
///
/// Combined with the global `MediaQuery.withClampedTextScaling` guard in
/// `main.dart`, these keep the UI consistent across devices and font-scale
/// accessibility settings.

/// A [Text] that is safe by default: it truncates with an ellipsis instead of
/// wrapping unbounded. Use this everywhere dynamic/user data is shown.
class AppText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;
  final TextOverflow overflow;
  final bool softWrap;

  const AppText(
    this.data, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.textAlign,
    this.overflow = TextOverflow.ellipsis,
    this.softWrap = false,
  });

  /// A variant that allows a bounded number of wrapped lines before truncating.
  const AppText.multiline(
    this.data, {
    super.key,
    this.style,
    this.maxLines = 2,
    this.textAlign,
    this.overflow = TextOverflow.ellipsis,
  }) : softWrap = true;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: style,
      maxLines: maxLines,
      textAlign: textAlign,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}

/// A compact, coloured status pill (e.g. "Confirmed", "Delivered").
///
/// Bounded in width and single-line, so it is safe to place in a card's
/// trailing slot without starving the title.
class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;

  const StatusChip({
    super.key,
    required this.text,
    required this.color,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: AppText(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

/// An overflow-safe list card.
///
/// Layout contract:
///   [ leading? ] [ Expanded( title / subtitle ) ] [ trailing? ]
///
/// The title/subtitle column is always `Expanded`, guaranteeing it a real,
/// non-collapsing width regardless of how wide the trailing content is or how
/// large the device font scale is. Trailing widgets are laid out at their
/// intrinsic size and simply share the remaining space — they can never push
/// the title to zero width.
class AppListCard extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;

  /// Optional trailing widgets, stacked vertically and right-aligned
  /// (e.g. a date on top and a [StatusChip] below).
  final List<Widget> trailing;

  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double elevation;

  const AppListCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing = const [],
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    this.elevation = 2,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Cap the trailing block so it can never consume the whole row and
          // starve the title. Trailing text truncates within this cap instead
          // of forcing a RenderFlex overflow — robust at any text scale.
          final maxTrailingWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth * 0.45
              : 160.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    title,
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      subtitle!,
                    ],
                  ],
                ),
              ),
              if (trailing.isNotEmpty) ...[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxTrailingWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < trailing.length; i++) ...[
                        if (i > 0) const SizedBox(height: 6),
                        trailing[i],
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    return Card(
      elevation: elevation,
      child: onTap == null
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: content,
            ),
    );
  }
}

/// An overflow-safe label/value row for detail screens.
///
/// The label sits at its natural width; the value takes the remaining space in
/// an `Expanded` and truncates rather than wrapping character-by-character.
class LabeledRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final int valueMaxLines;

  const LabeledRow({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
    this.valueMaxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: AppText(
              label,
              style: labelStyle ??
                  TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppText(
              value,
              maxLines: valueMaxLines,
              softWrap: valueMaxLines > 1,
              textAlign: TextAlign.right,
              style: valueStyle ?? const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
