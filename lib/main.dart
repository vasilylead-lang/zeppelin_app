import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const ZeppelinApp());
}

// ─── Ticket-to-Ride palette ─────────────────────────────────────────────────
class TTR {
  static const cream = Color(0xFFF4E8C9);
  static const parchment = Color(0xFFE8D5A8);
  static const aged = Color(0xFFD4B775);
  static const ink = Color(0xFF3D2817);
  static const inkLight = Color(0xFF6B4423);
  static const red = Color(0xFFC8362D);
  static const green = Color(0xFF2F5233);
  static const navy = Color(0xFF1F3A5F);
  static const mustard = Color(0xFFD4A02A);
  static const brass = Color(0xFFB8860B);
  static const brassLight = Color(0xFFE6B84A);
  static const wood = Color(0xFF5C3A21);
  static const woodLight = Color(0xFF8B5A2B);
}

class ZeppelinApp extends StatelessWidget {
  const ZeppelinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zeppelin Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: TTR.cream,
        textTheme: const TextTheme().apply(
          fontFamily: 'Georgia',
          bodyColor: TTR.ink,
          displayColor: TTR.ink,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: TTR.red,
          brightness: Brightness.light,
        ),
      ),
      home: const ZeppelinControlPage(),
    );
  }
}

class ZeppelinControlPage extends StatefulWidget {
  const ZeppelinControlPage({super.key});

  @override
  State<ZeppelinControlPage> createState() => _ZeppelinControlPageState();
}

class _ZeppelinControlPageState extends State<ZeppelinControlPage>
    with TickerProviderStateMixin {
  double _altitude = 0.5;
  double _throttle = 0.4;
  double _heading = 0;
  bool _engineOn = true;

  final List<_Plane> _planes = [];
  final Random _rng = Random();

  late final AnimationController _ticker;
  late final AnimationController _zeppelinBob;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _zeppelinBob = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    for (int i = 0; i < 4; i++) {
      _planes.add(_spawnPlane(initial: true));
    }
    _ticker.addListener(_tick);
  }

  _Plane _spawnPlane({bool initial = false}) {
    final goingRight = _rng.nextBool();
    return _Plane(
      x: initial ? _rng.nextDouble() : (goingRight ? -0.15 : 1.15),
      y: 0.08 + _rng.nextDouble() * 0.55,
      speed: 0.0008 + _rng.nextDouble() * 0.0018,
      goingRight: goingRight,
      scale: 0.7 + _rng.nextDouble() * 0.6,
    );
  }

  void _tick() {
    setState(() {
      for (final p in _planes) {
        p.x += p.goingRight ? p.speed : -p.speed;
      }
      _planes.removeWhere((p) => p.x < -0.2 || p.x > 1.2);
      if (_planes.length < 5 && _rng.nextDouble() < 0.02) {
        _planes.add(_spawnPlane());
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _zeppelinBob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                // Sky scene
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: TTR.ink, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: TTR.ink.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Vintage sky gradient
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFC9B98A),
                                Color(0xFFE8D5A8),
                                Color(0xFFE0A878),
                              ],
                              stops: [0.0, 0.55, 1.0],
                            ),
                          ),
                        ),
                        const _PaperGrain(),
                        ..._buildClouds(constraints),
                        ..._planes.map((p) => _buildPlane(p, constraints)),
                        AnimatedBuilder(
                          animation: _zeppelinBob,
                          builder: (context, child) {
                            final bob = sin(_zeppelinBob.value * 2 * pi) * 8;
                            final yPos = (1 - _altitude) *
                                    (constraints.maxHeight - 140) +
                                bob;
                            final xPos = (0.5 + _heading * 0.25) *
                                (constraints.maxWidth - 180);
                            return Positioned(
                              left: xPos,
                              top: yPos,
                              child: _ZeppelinWidget(
                                engineOn: _engineOn,
                                throttle: _throttle,
                              ),
                            );
                          },
                        ),
                        const Positioned(
                          right: 14,
                          top: 14,
                          child: _CompassRose(),
                        ),
                        const Positioned(
                          top: 12,
                          left: 0,
                          right: 0,
                          child: Center(child: _TitleBanner()),
                        ),
                        Positioned(
                          left: 14,
                          bottom: 14,
                          child: _Hud(
                            altitude: _altitude,
                            throttle: _throttle,
                            heading: _heading,
                            engineOn: _engineOn,
                            planes: _planes.length,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _ControlPanel(
                  altitude: _altitude,
                  throttle: _throttle,
                  heading: _heading,
                  engineOn: _engineOn,
                  onAltitude: (v) => setState(() => _altitude = v),
                  onThrottle: (v) => setState(() => _throttle = v),
                  onHeading: (v) => setState(() => _heading = v),
                  onEngine: (v) => setState(() => _engineOn = v),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildClouds(BoxConstraints c) {
    const cloudOffsets = [
      [0.05, 0.18, 1.0],
      [0.38, 0.28, 1.3],
      [0.72, 0.12, 0.95],
      [0.55, 0.45, 1.15],
      [0.12, 0.58, 1.05],
    ];
    return List.generate(cloudOffsets.length, (i) {
      final o = cloudOffsets[i];
      return Positioned(
        left: o[0] * c.maxWidth,
        top: o[1] * c.maxHeight,
        child: Opacity(opacity: 0.85, child: _Cloud(scale: o[2], seed: i * 17)),
      );
    });
  }

  Widget _buildPlane(_Plane p, BoxConstraints c) {
    return Positioned(
      left: p.x * c.maxWidth,
      top: p.y * c.maxHeight,
      child: Transform.scale(
        scale: p.scale,
        child: Transform.flip(
          flipX: !p.goingRight,
          child: const _Biplane(),
        ),
      ),
    );
  }
}

class _Plane {
  double x, y, speed, scale;
  bool goingRight;
  _Plane({
    required this.x,
    required this.y,
    required this.speed,
    required this.goingRight,
    required this.scale,
  });
}

// ─── Title banner ───────────────────────────────────────────────────────────

class _TitleBanner extends StatelessWidget {
  const _TitleBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
      decoration: BoxDecoration(
        color: TTR.red,
        border: Border.all(color: TTR.ink, width: 2),
        boxShadow: [
          BoxShadow(
            color: TTR.ink.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: const Text(
        '✦  Z E P P E L I N    C O M M A N D  ✦',
        style: TextStyle(
          color: TTR.cream,
          fontFamily: 'Georgia',
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 1.5,
          shadows: [Shadow(color: TTR.ink, offset: Offset(1, 1))],
        ),
      ),
    );
  }
}

// ─── Paper grain ────────────────────────────────────────────────────────────

class _PaperGrain extends StatelessWidget {
  const _PaperGrain();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(child: CustomPaint(painter: _PaperGrainPainter())),
    );
  }
}

class _PaperGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = TTR.inkLight.withValues(alpha: 0.04);
    final rng = Random(42);
    for (int i = 0; i < 80; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Compass rose ───────────────────────────────────────────────────────────

class _CompassRose extends StatelessWidget {
  const _CompassRose();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(painter: _CompassPainter()),
    );
  }
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    final outline = Paint()
      ..color = TTR.ink
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(c, r, Paint()..color = TTR.cream.withValues(alpha: 0.85));
    canvas.drawCircle(c, r, outline);
    canvas.drawCircle(
      c,
      r - 4,
      Paint()
        ..color = TTR.ink
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );

    final dirOutline = Paint()
      ..color = TTR.ink
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 4; i++) {
      final a = i * pi / 2;
      final tip = Offset(c.dx + sin(a) * r, c.dy - cos(a) * r);
      final lb = Offset(c.dx + sin(a + pi / 2) * 5, c.dy - cos(a + pi / 2) * 5);
      final rb = Offset(c.dx + sin(a - pi / 2) * 5, c.dy - cos(a - pi / 2) * 5);
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(lb.dx, lb.dy)
        ..lineTo(rb.dx, rb.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = i == 0 ? TTR.red : TTR.ink);
      canvas.drawPath(path, dirOutline);
    }
    for (int i = 0; i < 4; i++) {
      final a = pi / 4 + i * pi / 2;
      final tip = Offset(c.dx + sin(a) * (r - 8), c.dy - cos(a) * (r - 8));
      final lb = Offset(c.dx + sin(a + pi / 2) * 3, c.dy - cos(a + pi / 2) * 3);
      final rb = Offset(c.dx + sin(a - pi / 2) * 3, c.dy - cos(a - pi / 2) * 3);
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(lb.dx, lb.dy)
        ..lineTo(rb.dx, rb.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = TTR.parchment);
      canvas.drawPath(path, dirOutline);
    }
    canvas.drawCircle(c, 2.5, Paint()..color = TTR.brass);
    canvas.drawCircle(c, 2.5, dirOutline);

    final tp = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: TTR.cream,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          fontFamily: 'Georgia',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - r + 0.5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Zeppelin ───────────────────────────────────────────────────────────────

class _ZeppelinWidget extends StatelessWidget {
  final bool engineOn;
  final double throttle;
  const _ZeppelinWidget({required this.engineOn, required this.throttle});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 100,
      child: CustomPaint(
        painter: _ZeppelinPainter(engineOn: engineOn, throttle: throttle),
      ),
    );
  }
}

class _ZeppelinPainter extends CustomPainter {
  final bool engineOn;
  final double throttle;
  _ZeppelinPainter({required this.engineOn, required this.throttle});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final envelopeRect = Rect.fromLTWH(w * 0.05, h * 0.15, w * 0.85, h * 0.5);
    final envelopeRR =
        RRect.fromRectAndRadius(envelopeRect, Radius.circular(h * 0.25));
    canvas.drawRRect(
      envelopeRR,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF4E8C9), Color(0xFFB89968)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(envelopeRect),
    );
    canvas.drawRRect(
      envelopeRR,
      Paint()
        ..color = TTR.ink
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Decorative stripes
    canvas.drawRect(
      Rect.fromLTWH(w * 0.05, h * 0.32, w * 0.85, h * 0.04),
      Paint()..color = TTR.red,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.05, h * 0.44, w * 0.85, h * 0.025),
      Paint()..color = TTR.brass,
    );

    // Star emblem
    _drawStar(canvas, Offset(w * 0.48, h * 0.38), 6, TTR.cream, TTR.ink);

    // Tail fin
    final fin = Path()
      ..moveTo(w * 0.1, h * 0.4)
      ..lineTo(w * 0.0, h * 0.12)
      ..lineTo(w * 0.0, h * 0.72)
      ..close();
    canvas.drawPath(fin, Paint()..color = TTR.wood);
    canvas.drawPath(
      fin,
      Paint()
        ..color = TTR.ink
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    // Gondola
    final gondolaRect = Rect.fromLTWH(w * 0.32, h * 0.68, w * 0.36, h * 0.18);
    final gondolaRR =
        RRect.fromRectAndRadius(gondolaRect, Radius.circular(h * 0.06));
    canvas.drawRRect(gondolaRR, Paint()..color = TTR.wood);
    canvas.drawRRect(
      gondolaRR,
      Paint()
        ..color = TTR.ink
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.32, h * 0.74, w * 0.36, h * 0.015),
      Paint()..color = TTR.brass,
    );

    // Lamp windows
    final winOutline = Paint()
      ..color = TTR.ink
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 4; i++) {
      final pos = Offset(w * (0.38 + i * 0.08), h * 0.79);
      canvas.drawCircle(pos, h * 0.025, Paint()..color = TTR.mustard);
      canvas.drawCircle(pos, h * 0.025, winOutline);
    }

    // Ropes
    final rope = Paint()
      ..color = TTR.ink
      ..strokeWidth = 0.6;
    for (final x in [0.36, 0.5, 0.64]) {
      canvas.drawLine(
        Offset(w * x, h * 0.62),
        Offset(w * x, h * 0.68),
        rope,
      );
    }

    // Propeller
    final propX = w * 0.94;
    final propY = h * 0.4;
    canvas.drawCircle(
      Offset(propX, propY),
      h * 0.07,
      Paint()
        ..color = engineOn ? TTR.brass : TTR.aged
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
    if (engineOn) {
      canvas.drawLine(
        Offset(propX - h * 0.07, propY),
        Offset(propX + h * 0.07, propY),
        Paint()
          ..color = TTR.brass
          ..strokeWidth = 1.2,
      );
    }
  }

  void _drawStar(
      Canvas canvas, Offset c, double r, Color fill, Color stroke) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final pt = Offset(c.dx + cos(a) * rr, c.dy + sin(a) * rr);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ZeppelinPainter old) =>
      old.engineOn != engineOn || old.throttle != throttle;
}

// ─── Biplane ────────────────────────────────────────────────────────────────

class _Biplane extends StatelessWidget {
  const _Biplane();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 40,
      child: CustomPaint(painter: _BiplanePainter()),
    );
  }
}

class _BiplanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final outline = Paint()
      ..color = TTR.ink
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Fuselage (TTR red)
    final fuselage = Path()
      ..moveTo(w * 0.95, h * 0.5)
      ..lineTo(w * 0.2, h * 0.4)
      ..lineTo(w * 0.0, h * 0.5)
      ..lineTo(w * 0.2, h * 0.6)
      ..close();
    canvas.drawPath(fuselage, Paint()..color = TTR.red);
    canvas.drawPath(fuselage, outline);

    // Upper wing
    final upperWing = Rect.fromLTWH(w * 0.3, h * 0.18, w * 0.45, h * 0.1);
    canvas.drawRect(upperWing, Paint()..color = TTR.wood);
    canvas.drawRect(upperWing, outline);
    // Lower wing
    final lowerWing = Rect.fromLTWH(w * 0.3, h * 0.62, w * 0.45, h * 0.1);
    canvas.drawRect(lowerWing, Paint()..color = TTR.wood);
    canvas.drawRect(lowerWing, outline);

    // Struts
    final strut = Paint()
      ..color = TTR.ink
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(w * 0.4, h * 0.28), Offset(w * 0.4, h * 0.62), strut);
    canvas.drawLine(
        Offset(w * 0.65, h * 0.28), Offset(w * 0.65, h * 0.62), strut);

    // Tail fin
    final tail = Path()
      ..moveTo(w * 0.15, h * 0.5)
      ..lineTo(w * 0.0, h * 0.2)
      ..lineTo(w * 0.18, h * 0.5)
      ..close();
    canvas.drawPath(tail, Paint()..color = TTR.wood);
    canvas.drawPath(tail, outline);

    // Propeller
    canvas.drawLine(
      Offset(w * 0.95, h * 0.3),
      Offset(w * 0.95, h * 0.7),
      Paint()
        ..color = TTR.ink
        ..strokeWidth = 1.5,
    );

    // Cockpit
    canvas.drawCircle(
      Offset(w * 0.6, h * 0.42),
      h * 0.08,
      Paint()..color = TTR.navy,
    );
    canvas.drawCircle(Offset(w * 0.6, h * 0.42), h * 0.08, outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Cloud ──────────────────────────────────────────────────────────────────

class _Cloud extends StatelessWidget {
  final double scale;
  final int seed;
  const _Cloud({required this.scale, this.seed = 0});
  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: 120,
        height: 52,
        child: CustomPaint(painter: _CloudPainter(seed: seed)),
      ),
    );
  }
}

class _CloudPainter extends CustomPainter {
  final int seed;
  _CloudPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rng = Random(seed);

    // Build a soft puffy silhouette as one continuous path along a flat
    // base with rounded bumps on top — no visible "stripe" artefact.
    final baseY = h * 0.78;
    // Bump centers (x fraction, top-y fraction, radius fraction of width)
    final bumps = <List<double>>[
      [0.12, 0.55, 0.10],
      [0.28, 0.32, 0.16],
      [0.48, 0.18, 0.20],
      [0.68, 0.30, 0.17],
      [0.86, 0.55, 0.11],
    ];
    // Add slight jitter so each cloud looks unique
    for (final b in bumps) {
      b[0] += (rng.nextDouble() - 0.5) * 0.02;
      b[1] += (rng.nextDouble() - 0.5) * 0.04;
      b[2] *= 0.92 + rng.nextDouble() * 0.16;
    }

    final path = Path();
    final leftX = bumps.first[0] * w;
    path.moveTo(leftX, baseY);
    // Left-side curl up to first bump
    path.quadraticBezierTo(leftX - 6, baseY - 6, leftX - 2, baseY - 14);

    for (var i = 0; i < bumps.length; i++) {
      final b = bumps[i];
      final cx = b[0] * w;
      final cy = b[1] * h;
      final r = b[2] * w;
      // Arc over each bump (top semicircle approximation via cubic)
      final startX = cx - r;
      final endX = cx + r;
      path.cubicTo(
        startX, cy - r * 0.1, // control 1: pull up on left
        cx - r * 0.6, cy - r, // control 2: top-left
        cx, cy - r,            // bump apex
      );
      path.cubicTo(
        cx + r * 0.6, cy - r,
        endX, cy - r * 0.1,
        endX, cy + r * 0.4,
      );
      // Dip between bumps
      if (i < bumps.length - 1) {
        final nb = bumps[i + 1];
        final ncx = nb[0] * w;
        final ncr = nb[2] * w;
        final dipMidX = (endX + (ncx - ncr)) / 2;
        final dipY = max(baseY - 8, max(cy + r * 0.4, nb[1] * h + ncr * 0.3));
        path.quadraticBezierTo(dipMidX, dipY, ncx - ncr, nb[1] * h + ncr * 0.4);
      }
    }
    // Right tail back down to base
    final rightX = bumps.last[0] * w;
    final lastR = bumps.last[2] * w;
    path.quadraticBezierTo(
      rightX + lastR + 4, baseY - 4,
      rightX + lastR - 2, baseY,
    );
    // Flat-ish underside
    path.lineTo(leftX, baseY);
    path.close();

    // Soft drop shadow underneath
    canvas.drawPath(
      path.shift(const Offset(2, 3)),
      Paint()
        ..color = TTR.ink.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Fill — subtle vertical gradient (cream top → warm beige bottom)
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [TTR.cream, TTR.parchment.withValues(alpha: 0.9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Inked outline — slightly varied weight for hand-drawn feel
    canvas.drawPath(
      path,
      Paint()
        ..color = TTR.inkLight.withValues(alpha: 0.75)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Inner highlight curve (catches the sunset light)
    final hi = Path();
    hi.moveTo(w * 0.22, h * 0.50);
    hi.quadraticBezierTo(w * 0.38, h * 0.28, w * 0.55, h * 0.28);
    canvas.drawPath(
      hi,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CloudPainter old) => old.seed != seed;
}

// ─── Vintage HUD (passport ticket) ──────────────────────────────────────────

class _Hud extends StatelessWidget {
  final double altitude, throttle, heading;
  final bool engineOn;
  final int planes;

  const _Hud({
    required this.altitude,
    required this.throttle,
    required this.heading,
    required this.engineOn,
    required this.planes,
  });

  @override
  Widget build(BuildContext context) {
    final altMeters = (altitude * 2400).round();
    final speed = (throttle * 120).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: TTR.cream,
        border: Border.all(color: TTR.ink, width: 2),
        boxShadow: [
          BoxShadow(
            color: TTR.ink.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: TTR.ink,
          fontFamily: 'Georgia',
          fontSize: 11,
          height: 1.6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: engineOn ? TTR.green : TTR.red,
                border: Border.all(color: TTR.ink, width: 1),
              ),
              child: Text(
                engineOn ? 'IN  FLIGHT' : 'GROUNDED',
                style: const TextStyle(
                  color: TTR.cream,
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ),
            const _HudRow(label: 'AIRSHIP', value: 'HMS-I'),
            _HudRow(label: 'ALTITUDE', value: '${_pad(altMeters, 4)} m'),
            _HudRow(label: 'SPEED', value: '${_pad(speed, 3)} km/h'),
            _HudRow(
                label: 'BEARING',
                value: '${(heading * 45).toStringAsFixed(0).padLeft(3)}°'),
            _HudRow(label: 'TRAFFIC', value: '$planes ✈'),
          ],
        ),
      ),
    );
  }

  String _pad(int n, int w) => n.toString().padLeft(w);
}

class _HudRow extends StatelessWidget {
  final String label, value;
  const _HudRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(
              color: TTR.inkLight,
              fontFamily: 'Georgia',
              fontSize: 10,
              fontStyle: FontStyle.italic,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: TTR.ink,
            fontFamily: 'Georgia',
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ─── Wooden control panel ───────────────────────────────────────────────────

class _ControlPanel extends StatelessWidget {
  final double altitude, throttle, heading;
  final bool engineOn;
  final ValueChanged<double> onAltitude, onThrottle, onHeading;
  final ValueChanged<bool> onEngine;

  const _ControlPanel({
    required this.altitude,
    required this.throttle,
    required this.heading,
    required this.engineOn,
    required this.onAltitude,
    required this.onThrottle,
    required this.onHeading,
    required this.onEngine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [TTR.woodLight, TTR.wood],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: TTR.ink, width: 3),
        boxShadow: [
          BoxShadow(
            color: TTR.ink.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [TTR.brassLight, TTR.brass],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(color: TTR.ink, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 14, color: TTR.ink),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'B R I D G E   C O N T R O L S',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: TTR.ink,
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.star, size: 14, color: TTR.ink),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      engineOn ? 'ENGINE  RUNNING' : 'ENGINE  IDLE',
                      style: TextStyle(
                        color: engineOn ? TTR.green : TTR.red,
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: engineOn,
                        onChanged: onEngine,
                        activeThumbColor: TTR.green,
                        activeTrackColor: TTR.parchment,
                        inactiveThumbColor: TTR.red,
                        inactiveTrackColor: TTR.parchment,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _BrassSlider(
            label: 'ALTITUDE',
            value: altitude,
            onChanged: onAltitude,
            accent: TTR.navy,
            valueLabel: '${(altitude * 2400).round()} m',
          ),
          _BrassSlider(
            label: 'THROTTLE',
            value: throttle,
            onChanged: engineOn ? onThrottle : null,
            accent: TTR.red,
            valueLabel: '${(throttle * 120).round()} km/h',
          ),
          _BrassSlider(
            label: 'BEARING',
            value: (heading + 1) / 2,
            onChanged: (v) => onHeading(v * 2 - 1),
            accent: TTR.green,
            valueLabel: '${(heading * 45).toStringAsFixed(0)}°',
          ),
        ],
      ),
    );
  }
}

class _BrassSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  final Color accent;
  final String valueLabel;

  const _BrassSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.accent,
    required this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 96,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [TTR.brassLight, TTR.brass],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(color: TTR.ink, width: 1),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: TTR.ink,
                fontFamily: 'Georgia',
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                activeTrackColor: accent,
                thumbColor: TTR.brassLight,
                inactiveTrackColor: TTR.parchment.withValues(alpha: 0.6),
                overlayColor: accent.withValues(alpha: 0.2),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 9,
                  disabledThumbRadius: 6,
                ),
              ),
              child: Slider(
                value: value.clamp(0.0, 1.0),
                onChanged: onChanged,
              ),
            ),
          ),
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: TTR.cream,
              border: Border.all(color: TTR.ink, width: 1),
            ),
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: TTR.ink,
                fontFamily: 'Georgia',
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
