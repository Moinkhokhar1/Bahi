import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

// ------------------------------------------------------------------
// Public helpers
// ------------------------------------------------------------------

Future<void> showCelebration(
    BuildContext context, {
      required String title,
      String subtitle = '',
      String badge = '',
      IconData badgeIcon = Icons.local_shipping_rounded,
    }) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: title,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => _Celebration(
      title: title,
      subtitle: subtitle,
      badge: badge,
      badgeIcon: badgeIcon,
    ),
    transitionBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
  );
}

Future<void> showDeliveredCelebration(
    BuildContext context, {
      required String billNo,
      required String shopName,
    }) {
  return showCelebration(
    context,
    title: 'Delivered!',
    subtitle: _join(billNo, shopName),
    badge: 'Goods handed over',
    badgeIcon: Icons.local_shipping_rounded,
  );
}

Future<void> showBillSavedCelebration(
    BuildContext context, {
      required String billNo,
      required String shopName,
    }) {
  return showCelebration(
    context,
    title: 'Bill saved!',
    subtitle: _join(billNo, shopName),
    badge: 'Added to your books',
    badgeIcon: Icons.receipt_long_rounded,
  );
}

String _join(String a, String b) =>
    [a, b].where((s) => s.trim().isNotEmpty).join(' · ');

double _clamp(double v, [double lo = 0.0, double hi = 1.0]) =>
    math.max(lo, math.min(hi, v));

// ------------------------------------------------------------------
// Celebration screen
// ------------------------------------------------------------------

class _Celebration extends StatefulWidget {
  final String title;
  final String subtitle;
  final String badge;
  final IconData badgeIcon;
  const _Celebration({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeIcon,
  });

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration> with SingleTickerProviderStateMixin {
  static const double _totalSeconds = 4.2;
  static const double _cy = 0.38; // vertical centre of the check (fraction of height)

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_totalSeconds * 1000).round()),
  );
  late final List<_Particle> _particles = _makeParticles();
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _close();
    });
    _ctrl.forward();
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 350), HapticFeedback.heavyImpact);
    Future.delayed(const Duration(milliseconds: 650), HapticFeedback.lightImpact);
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _seg(double a, double b, Curve curve) =>
      curve.transform(_clamp((_ctrl.value - a) / (b - a)));

  @override
  Widget build(BuildContext context) {
    final c = context.bahi;
    final top = Color.lerp(c.green, Colors.white, 0.08)!;
    final bottom = Color.lerp(c.green, Colors.black, 0.45)!;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final bgFade = _seg(0.0, 0.08, Curves.easeOut);
            final outFade = 1.0 - _seg(0.94, 1.0, Curves.easeIn);
            final pop = _seg(0.02, 0.26, Curves.elasticOut);
            final checkDraw = _seg(0.14, 0.30, Curves.easeOutCubic);
            final title = _seg(0.26, 0.42, Curves.easeOutBack);
            final sub = _seg(0.34, 0.50, Curves.easeOut);
            final pill = _seg(0.42, 0.58, Curves.easeOutBack);
            final hint = _seg(0.62, 0.76, Curves.easeOut);
            final pulse = 1 + 0.03 * math.sin(_ctrl.value * _totalSeconds * 5);

            return Opacity(
              opacity: _clamp(bgFade * outFade),
              child: LayoutBuilder(builder: (context, box) {
                final cy = box.maxHeight * _cy;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // background
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [top, bottom],
                        ),
                      ),
                    ),
                    // soft glow behind the check
                    Positioned(
                      left: box.maxWidth / 2 - 200,
                      top: cy - 200,
                      child: Opacity(
                        opacity: _clamp(0.35 * pop, 0.0, 0.35),
                        child: Container(
                          width: 400,
                          height: 400,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [Colors.white, Colors.transparent]),
                          ),
                        ),
                      ),
                    ),
                    // rings + sparkles + confetti
                    CustomPaint(
                      painter: _CelebrationPainter(
                        ctrl: _ctrl,
                        totalSeconds: _totalSeconds,
                        cy: _cy,
                        particles: _particles,
                      ),
                    ),
                    // check circle
                    Positioned(
                      left: 0,
                      right: 0,
                      top: cy - 65,
                      child: Center(
                        child: Transform.scale(
                          scale: math.max(0.0, pop * pulse),
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 30,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: CustomPaint(
                              painter: _CheckPainter(progress: checkDraw, color: c.green),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // texts
                    Positioned(
                      left: 24,
                      right: 24,
                      top: cy + 100,
                      child: Column(
                        children: [
                          Opacity(
                            opacity: _clamp(title),
                            child: Transform.translate(
                              offset: Offset(0, 30 * (1 - title)),
                              child: Text(
                                widget.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          if (widget.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Opacity(
                              opacity: _clamp(sub),
                              child: Transform.translate(
                                offset: Offset(0, 16 * (1 - sub)),
                                child: Text(
                                  widget.subtitle,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (widget.badge.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Opacity(
                              opacity: _clamp(pill),
                              child: Transform.scale(
                                scale: _clamp(0.8 + 0.2 * pill, 0.0, 1.2),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(widget.badgeIcon, color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      Text(widget.badge,
                                          style: const TextStyle(
                                              color: Colors.white, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // tap hint
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 40,
                      child: SafeArea(
                        child: Opacity(
                          opacity: _clamp(hint * 0.7),
                          child: const Text('Tap anywhere to continue',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  decoration: TextDecoration.none)),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            );
          },
        ),
      ),
    );
  }

  // ---- confetti setup ----
  static List<_Particle> _makeParticles() {
    final r = math.Random();
    const colors = <Color>[
      Color(0xFFFFD54F), Color(0xFFFF7043), Color(0xFF42A5F5), Color(0xFFEC407A),
      Color(0xFFAB47BC), Color(0xFFFFFFFF), Color(0xFF26C6DA), Color(0xFFFFCA28),
      Color(0xFF9CCC65),
    ];
    Color col() => colors[r.nextInt(colors.length)];
    double rnd(double a, double b) => a + r.nextDouble() * (b - a);

    _Particle make({
      required double fx,
      required double fy,
      required double vx,
      required double vy,
      required double delay,
      required double life,
      required double drag,
      required double gravity,
      double sway = 0,
    }) {
      return _Particle(
        fx: fx, fy: fy, vx: vx, vy: vy, delay: delay, life: life, drag: drag, gravity: gravity,
        size: rnd(7, 15),
        rot0: rnd(0, math.pi * 2),
        rotSpeed: rnd(-9, 9),
        flip0: rnd(0, math.pi * 2),
        flipSpeed: rnd(4, 12),
        sway: sway,
        swayFreq: rnd(2, 5),
        color: col(),
        shape: r.nextInt(4),
      );
    }

    final list = <_Particle>[];

    // centre burst when the check pops
    for (var i = 0; i < 90; i++) {
      final a = rnd(0, math.pi * 2);
      final s = rnd(300, 900);
      list.add(make(
        fx: 0.5, fy: _cy,
        vx: math.cos(a) * s, vy: math.sin(a) * s - 250,
        delay: 0.3, life: rnd(2.0, 3.0), drag: 1.8, gravity: 800,
      ));
    }
    // side cannons
    for (var i = 0; i < 55; i++) {
      final a = -math.pi / 2 + rnd(0.25, 0.75);
      final s = rnd(900, 1600);
      list.add(make(
        fx: 0.0, fy: 1.0,
        vx: math.cos(a) * s, vy: math.sin(a) * s,
        delay: 0.55 + r.nextDouble() * 0.15, life: rnd(2.4, 3.2), drag: 0.9, gravity: 1100,
      ));
      list.add(make(
        fx: 1.0, fy: 1.0,
        vx: -math.cos(a) * s, vy: math.sin(a) * s,
        delay: 0.55 + r.nextDouble() * 0.15, life: rnd(2.4, 3.2), drag: 0.9, gravity: 1100,
      ));
    }
    // confetti rain
    for (var i = 0; i < 110; i++) {
      list.add(make(
        fx: r.nextDouble(), fy: -0.04,
        vx: rnd(-25, 25), vy: rnd(140, 300),
        delay: rnd(0.7, 2.2), life: 2.2, drag: 0.05, gravity: 60, sway: rnd(15, 40),
      ));
    }
    return list;
  }
}

class _Particle {
  final double fx, fy, vx, vy, delay, life, drag, gravity;
  final double size, rot0, rotSpeed, flip0, flipSpeed, sway, swayFreq;
  final Color color;
  final int shape;
  const _Particle({
    required this.fx, required this.fy, required this.vx, required this.vy,
    required this.delay, required this.life, required this.drag, required this.gravity,
    required this.size, required this.rot0, required this.rotSpeed,
    required this.flip0, required this.flipSpeed, required this.sway,
    required this.swayFreq, required this.color, required this.shape,
  });
}

class _CelebrationPainter extends CustomPainter {
  final AnimationController ctrl;
  final double totalSeconds;
  final double cy;
  final List<_Particle> particles;

  _CelebrationPainter({
    required this.ctrl,
    required this.totalSeconds,
    required this.cy,
    required this.particles,
  }) : super(repaint: ctrl);

  @override
  void paint(Canvas canvas, Size size) {
    final t = ctrl.value * totalSeconds;
    final center = Offset(size.width / 2, size.height * cy);

    // expanding ripple rings
    for (var k = 0; k < 3; k++) {
      final rt = (t - 0.3 - k * 0.28) / 1.5;
      if (rt <= 0 || rt >= 1) continue;
      final e = Curves.easeOut.transform(rt);
      canvas.drawCircle(
        center,
        65 + e * size.width * 0.75,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - rt) + 1
          ..color = Colors.white.withValues(alpha: _clamp((1 - rt) * 0.55)),
      );
    }

    // twinkling sparkles around the check
    final sparkleIn = _clamp((t - 0.5) / 0.4);
    if (sparkleIn > 0) {
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi * 2 / 12 + t * 0.4;
        final rad = 105 + 20 * math.sin(t * 2 + i);
        final tw = math.sin(t * 5 + i * 1.7) * 0.5 + 0.5;
        final p = center + Offset(math.cos(a) * rad, math.sin(a) * rad);
        _star(canvas, p, (4 + 8 * tw) * sparkleIn,
            Paint()..color = Colors.white.withValues(alpha: _clamp((0.3 + 0.7 * tw) * sparkleIn)));
      }
    }

    // confetti
    for (final p in particles) {
      final lt = t - p.delay;
      if (lt < 0 || lt > p.life) continue;
      final k = math.max(p.drag, 0.001);
      final decay = (1 - math.exp(-k * lt)) / k;
      final x = p.fx * size.width + p.vx * decay + p.sway * math.sin(p.swayFreq * lt);
      final y = p.fy * size.height + p.vy * decay + 0.5 * p.gravity * lt * lt;
      if (y > size.height + 40 || x < -60 || x > size.width + 60) continue;

      final fadeStart = p.life * 0.8;
      final alpha = lt < fadeStart ? 1.0 : 1 - (lt - fadeStart) / (p.life - fadeStart);
      final paint = Paint()..color = p.color.withValues(alpha: _clamp(alpha));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot0 + p.rotSpeed * lt);
      final flip = _clamp(math.cos(p.flip0 + p.flipSpeed * lt).abs(), 0.15, 1.0);
      canvas.scale(1, flip);
      switch (p.shape) {
        case 0:
          canvas.drawRect(
              Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55), paint);
          break;
        case 1:
          canvas.drawCircle(Offset.zero, p.size * 0.35, paint);
          break;
        case 2:
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(center: Offset.zero, width: p.size * 1.7, height: p.size * 0.28),
                  const Radius.circular(2)),
              paint);
          break;
        default:
          _star(canvas, Offset.zero, p.size * 0.6, paint);
      }
      canvas.restore();
    }
  }

  void _star(Canvas canvas, Offset o, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final rad = i.isEven ? r : r * 0.35;
      final pt = o + Offset(math.cos(a) * rad, math.sin(a) * rad);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter old) => false; // repaints via ctrl
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.27, size.height * 0.53)
      ..lineTo(size.width * 0.44, size.height * 0.69)
      ..lineTo(size.width * 0.75, size.height * 0.35);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * _clamp(progress)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.progress != progress;
}