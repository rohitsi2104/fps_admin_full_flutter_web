import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whole-app screen magnifier for low-vision users.
///
/// Double-tap anywhere toggles magnification: first double-tap zooms in, the
/// next double-tap returns to normal. While zoomed you can drag to pan around
/// the magnified view. The state is remembered across app restarts.
///
/// Implementation notes:
///  - Double-tap is detected with a passive [Listener] (raw pointer events) so
///    it NEVER competes in the gesture arena — normal taps, buttons and
///    scrolling keep working untouched at 1x.
///  - The [InteractiveViewer] is only mounted while zoomed (or animating out),
///    so at 1x the app tree is completely unwrapped and behaves exactly as
///    before (no gesture interference with scrolling).
class ScreenMagnifier extends StatefulWidget {
  final Widget child;
  const ScreenMagnifier({super.key, required this.child});

  @override
  State<ScreenMagnifier> createState() => _ScreenMagnifierState();
}

class _ScreenMagnifierState extends State<ScreenMagnifier>
    with SingleTickerProviderStateMixin {
  // Two states only: normal and magnified. Double-tap toggles between them.
  static const List<double> _levels = [1.0, 1.6];
  static const String _prefsKey = 'screen_zoom_level';

  final TransformationController _tc = TransformationController();
  late final AnimationController _anim;
  Animation<Matrix4>? _matrixAnim;

  int _levelIndex = 0;
  bool _ivMounted = false; // is the InteractiveViewer currently in the tree?
  Size _viewport = Size.zero;

  // Passive double-tap detection state.
  int? _lastTapMs;
  Offset? _lastTapPos;

  // Transient on-screen level indicator.
  String? _indicatorText;
  Timer? _indicatorTimer;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        final a = _matrixAnim;
        if (a != null) _tc.value = a.value;
      });
    _restore();
  }

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    _anim.dispose();
    _tc.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getInt(_prefsKey) ?? 0).clamp(0, _levels.length - 1);
    if (!mounted || saved == 0) return;
    setState(() {
      _levelIndex = saved;
      _ivMounted = true;
    });
    // Apply the restored zoom (centered) once we know the viewport size.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _viewport == Size.zero) return;
      _tc.value = _matrixFor(_levels[_levelIndex], _viewport.center(Offset.zero));
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, _levelIndex);
  }

  /// Transform that scales by [scale] keeping the point [focal] fixed on screen.
  Matrix4 _matrixFor(double scale, Offset focal) {
    if (scale == 1.0) return Matrix4.identity();
    return Matrix4.identity()
      ..translate(-focal.dx * (scale - 1), -focal.dy * (scale - 1))
      ..scale(scale);
  }

  void _animateTo(Matrix4 end, {VoidCallback? onDone}) {
    _matrixAnim = Matrix4Tween(begin: _tc.value, end: end).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    _anim.forward(from: 0).whenComplete(() {
      if (onDone != null) onDone();
    });
  }

  void _cycle(Offset focal) {
    final next = (_levelIndex + 1) % _levels.length;
    final targetScale = _levels[next];

    setState(() {
      _levelIndex = next;
      _ivMounted = true; // ensure the viewer is present to render the zoom
    });

    _animateTo(
      _matrixFor(targetScale, focal),
      onDone: () {
        // Fully un-mount the viewer once we're back to 1x so the app is
        // completely gesture-transparent again. Guard on the *current* level so
        // a stale animation from a rapid double-tap can't unmount while zoomed.
        if (targetScale == 1.0 && mounted && _levelIndex == 0) {
          setState(() => _ivMounted = false);
        }
      },
    );

    _persist();
    _showIndicator(targetScale);
  }

  void _showIndicator(double scale) {
    final label = scale == 1.0
        ? 'Zoom off'
        : '${scale.toStringAsFixed(1).replaceAll('.0', '')}×';
    setState(() => _indicatorText = label);
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _indicatorText = null);
    });
  }

  void _onPointerDown(PointerDownEvent e) {
    final now = e.timeStamp.inMilliseconds;
    final pos = e.position;
    final last = _lastTapMs;
    final lastPos = _lastTapPos;

    if (last != null &&
        lastPos != null &&
        now - last < 300 &&
        (pos - lastPos).distance < 40) {
      _lastTapMs = null;
      _lastTapPos = null;
      _cycle(pos);
    } else {
      _lastTapMs = now;
      _lastTapPos = pos;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);

        final Widget content = _ivMounted
            ? InteractiveViewer(
                transformationController: _tc,
                panEnabled: _levelIndex > 0,
                scaleEnabled: false,
                minScale: _levels.first,
                maxScale: _levels.last,
                clipBehavior: Clip.hardEdge,
                child: widget.child,
              )
            : widget.child;

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          child: Stack(
            children: [
              content,
              if (_indicatorText != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.zoom_in_rounded,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    _indicatorText!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
