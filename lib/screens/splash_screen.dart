import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Animated launch screen for Bahi.
///
/// Timeline (2.4 s, then a short hold):
///   gold tile pops in -> ripple ring -> receipt draws itself -> two text
///   lines are written -> "Bahi" rises in -> tagline fades in.
///
/// Tap anywhere to skip. If the system has animations turned off, the finished
/// frame is shown briefly instead.
///
/// The colours are fixed brand colours (same as the app icon), so the splash
/// looks the same in light and dark mode.
class BahiSplash extends StatefulWidget {
  const BahiSplash({super.key, required this.onFinished});

  /// Called once, when the animation (plus hold) ends or the user taps to skip.
  final VoidCallback onFinished;

  @override
  State<BahiSplash> createState() => _BahiSplashState();
}

class _BahiSplashState extends State<BahiSplash> with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF2743C4);
  static const _gold = Color(0xFFF3AB00);
  static const _tagline = 'Bills, stock and deliveries for shop-to-shop businesses.';

  static const _total = Duration(milliseconds: 2400);
  static const _hold = Duration(milliseconds: 350);

  late final AnimationController _c = AnimationController(vsync: this, duration: _total);
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(_hold, _finish);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _c.value = 1; // jump to the final frame
      } else {
        _c.forward();
      }
    });
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Progress (0..1) of the slice [a, b] of the whole timeline, with a curve.
  double _t(double a, double b, [Curve curve = Curves.easeOut]) =>
      Interval(a, b, curve: curve).transform(_c.value);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _blue,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _finish,
          child: SizedBox.expand(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final pop = _t(0.00, 0.30, Curves.easeOutBack); // may overshoot 1.0
                final popFade = _t(0.00, 0.12);
                final ripple = _t(0.22, 0.60, Curves.easeOutCubic);
                final outline = _t(0.22, 0.56, Curves.easeInOut);
                final line1 = _t(0.50, 0.62);
                final line2 = _t(0.56, 0.68);
                final word = _t(0.60, 0.80, Curves.easeOutCubic);
                final tag = _t(0.74, 0.94);

                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(size: const Size(220, 220), painter: _RipplePainter(ripple)),
                            Opacity(
                              opacity: popFade.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 0.5 + 0.5 * pop,
                                child: Container(
                                  width: 132,
                                  height: 132,
                                  decoration: BoxDecoration(
                                    color: _gold,
                                    borderRadius: BorderRadius.circular(38),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color.fromRGBO(0, 0, 0, 0.25),
                                        blurRadius: 30,
                                        offset: Offset(0, 14),
                                      ),
                                    ],
                                  ),
                                  child: CustomPaint(
                                    painter: _ReceiptPainter(outline: outline, line1: line1, line2: line2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Opacity(
                        opacity: word,
                        child: Transform.translate(
                          offset: Offset(0, (1 - word) * 16),
                          child: Text(
                            'Bahi',
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                              height: 1.0,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Opacity(
                        opacity: tag,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            _tagline,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.figtree(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                              color: const Color.fromRGBO(255, 255, 255, 0.82),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The receipt glyph from the app icon, drawn stroke by stroke.
/// Geometry is the 24x24 receipt shape scaled to 104/180 of the tile.
class _ReceiptPainter extends CustomPainter {
  _ReceiptPainter({required this.outline, required this.line1, required this.line2});

  final double outline, line1, line2; // each 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final box = size.width * 104 / 180;
    canvas.save();
    canvas.translate((size.width - box) / 2, (size.height - box) / 2);
    canvas.scale(box / 24);

    final paint = Paint()
      ..color = const Color(0xFF2B2000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final body = Path()
      ..moveTo(6, 3)
      ..relativeLineTo(12, 0)
      ..relativeLineTo(0, 18)
      ..relativeLineTo(-3, -2)
      ..relativeLineTo(-3, 2)
      ..relativeLineTo(-3, -2)
      ..relativeLineTo(-3, 2)
      ..close();
    final l1 = Path()
      ..moveTo(9, 8)
      ..lineTo(15, 8);
    final l2 = Path()
      ..moveTo(9, 12)
      ..lineTo(15, 12);

    _drawPartial(canvas, body, outline, paint);
    _drawPartial(canvas, l1, line1, paint);
    _drawPartial(canvas, l2, line2, paint);
    canvas.restore();
  }

  void _drawPartial(Canvas canvas, Path path, double t, Paint paint) {
    if (t <= 0) return;
    if (t >= 1) {
      // Full path keeps the corner joins clean (a partial extract would cap them).
      canvas.drawPath(path, paint);
      return;
    }
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t), paint);
    }
  }

  @override
  bool shouldRepaint(_ReceiptPainter old) =>
      old.outline != outline || old.line1 != line1 || old.line2 != line2;
}

/// One soft ring that expands from behind the tile and fades out.
class _RipplePainter extends CustomPainter {
  _RipplePainter(this.t);

  final double t; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final radius = 66 + (110 - 66) * t;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Color.fromRGBO(255, 255, 255, 0.45 * (1 - t));
    canvas.drawCircle(size.center(Offset.zero), radius, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t;
}
