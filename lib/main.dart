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
  // Actual airship state (the slow, real-world values shown on instruments)
  double _altitude = 0.5;
  double _throttle = 0.4;
  double _heading = 0;
  // Commanded targets the bridge sliders set — the airship eases toward these
  double _altitudeTarget = 0.5;
  double _throttleTarget = 0.4;
  double _headingTarget = 0;
  bool _engineOn = true;

  // Per-tick easing factor — ~2 sec to converge ( (1-_smooth)^120 ≈ 0.03 )
  static const double _smooth = 0.03;

  // Crash state
  bool _crashed = false;
  final List<Debris> _debris = [];
  double _crashFlash = 0; // 1 → 0 fades after impact

  final List<Plane> _planes = [];
  final Random _rng = Random();
  Size _skySize = Size.zero;

  // Constants used both for rendering and collision math.
  static const double _zeppelinW = 180;
  static const double _zeppelinH = 100;
  static const double _planeW = 64;
  static const double _planeH = 40;

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

    // Start with an empty sky; planes drift in from the edges over time.
    _ticker.addListener(_tick);
  }

  // Physics constants for visual airspeed math.
  // The plane's true airspeed is ~150 km/h with a small spread, and the
  // visible drift across the sky is the *relative* speed against the zeppelin
  // (added when flying opposite, subtracted when flying alongside).
  static const double _zeppelinMaxKmh = 120;
  static const double _planeAirspeedKmh = 150;
  static const double _planeAirspeedSpread = 30; // ±15 km/h jitter
  // Tuned so 150 km/h ≈ middle of the previous drift rate (~0.0024 frac/tick).
  static const double _speedScale = 1.6e-5;

  // ─── Test hooks ──────────────────────────────────────────────────────────
  @visibleForTesting
  static const double smoothFactor = _smooth;
  @visibleForTesting
  static const double zeppelinMaxKmh = _zeppelinMaxKmh;
  @visibleForTesting
  static const double planeAirspeedKmh = _planeAirspeedKmh;
  @visibleForTesting
  static const double speedScale = _speedScale;
  @visibleForTesting
  static const double zeppelinW = _zeppelinW;
  @visibleForTesting
  static const double zeppelinH = _zeppelinH;
  @visibleForTesting
  static const double planeW = _planeW;
  @visibleForTesting
  static const double planeH = _planeH;

  @visibleForTesting
  double get throttle => _throttle;
  @visibleForTesting
  set throttle(double v) => setState(() => _throttle = v);
  @visibleForTesting
  double get throttleTarget => _throttleTarget;
  @visibleForTesting
  set throttleTarget(double v) => setState(() => _throttleTarget = v);
  @visibleForTesting
  double get altitude => _altitude;
  @visibleForTesting
  set altitude(double v) => setState(() => _altitude = v);
  @visibleForTesting
  double get altitudeTarget => _altitudeTarget;
  @visibleForTesting
  set altitudeTarget(double v) => setState(() => _altitudeTarget = v);
  @visibleForTesting
  double get heading => _heading;
  @visibleForTesting
  set heading(double v) => setState(() => _heading = v);
  @visibleForTesting
  double get headingTarget => _headingTarget;
  @visibleForTesting
  set headingTarget(double v) => setState(() => _headingTarget = v);
  @visibleForTesting
  bool get engineOn => _engineOn;
  @visibleForTesting
  set engineOn(bool v) => setState(() => _engineOn = v);
  @visibleForTesting
  bool get crashed => _crashed;
  @visibleForTesting
  double get crashFlash => _crashFlash;
  @visibleForTesting
  List<Plane> get planes => _planes;
  @visibleForTesting
  List<Debris> get debris => _debris;
  @visibleForTesting
  Size get skySize => _skySize;
  @visibleForTesting
  // ignore: avoid_setters_without_getters
  set skySize(Size s) => _skySize = s;

  @visibleForTesting
  void runTick() => _tick();
  @visibleForTesting
  void triggerCrash(Offset origin) => _triggerCrash(origin);
  @visibleForTesting
  void reset() => _reset();
  @visibleForTesting
  Plane spawnPlane({bool initial = false}) => _spawnPlane(initial: initial);
  @visibleForTesting
  Rect zeppelinRect() => _zeppelinRect();
  @visibleForTesting
  Rect planeRect(Plane p) => _planeRect(p);

  Plane _spawnPlane({bool initial = false}) {
    final goingRight = _rng.nextBool();
    return Plane(
      x: initial ? _rng.nextDouble() : (goingRight ? -0.20 : 1.20),
      y: 0.18 + _rng.nextDouble() * 0.50,
      // Each plane's true airspeed in km/h
      airspeedKmh: _planeAirspeedKmh +
          (_rng.nextDouble() - 0.5) * _planeAirspeedSpread,
      goingRight: goingRight,
      scale: 0.55 + _rng.nextDouble() * 0.25,
    );
  }

  Rect _zeppelinRect() {
    if (_skySize == Size.zero) return Rect.zero;
    final xPos =
        (0.5 + _heading * 0.25) * (_skySize.width - _zeppelinW);
    final yPos = (1 - _altitude) * (_skySize.height - 140);
    // Hit box smaller than the bounding box (focus on envelope + gondola)
    return Rect.fromLTWH(
      xPos + _zeppelinW * 0.05,
      yPos + _zeppelinH * 0.15,
      _zeppelinW * 0.85,
      _zeppelinH * 0.7,
    );
  }

  Rect _planeRect(Plane p) {
    final w = _planeW * p.scale;
    final h = _planeH * p.scale;
    return Rect.fromLTWH(p.x * _skySize.width, p.y * _skySize.height, w, h);
  }

  void _tick() {
    setState(() {
      if (!_crashed) {
        // Ease real-world values toward commanded targets
        _altitude += (_altitudeTarget - _altitude) * _smooth;
        _heading += (_headingTarget - _heading) * _smooth;
        final effectiveThrottle = _engineOn ? _throttleTarget : 0.0;
        _throttle += (effectiveThrottle - _throttle) * _smooth;

        // The zeppelin's current speed (smoothed via the hidden _throttle field
        // that progresses toward _throttleTarget). Used to compute the visible
        // relative motion of the surrounding aircraft.
        final zeppelinKmh = _throttle * _zeppelinMaxKmh;
        for (final p in _planes) {
          // Planes with the wind (same direction as zeppelin → "rightward"
          // convention): subtract the zeppelin speed — they appear slower.
          // Planes against the wind: add the zeppelin speed — they appear
          // to scream past.
          final relativeKmh = p.goingRight
              ? (p.airspeedKmh - zeppelinKmh)
              : (p.airspeedKmh + zeppelinKmh);
          final perTick = relativeKmh * _speedScale;
          p.x += p.goingRight ? perTick : -perTick;
        }
        _planes.removeWhere((p) => p.x < -0.2 || p.x > 1.2);
        if (_planes.length < 3 && _rng.nextDouble() < 0.015) {
          _planes.add(_spawnPlane());
        }

        // Collision check
        if (_skySize != Size.zero) {
          final zRect = _zeppelinRect();
          for (final p in _planes) {
            if (zRect.overlaps(_planeRect(p))) {
              _triggerCrash(zRect.center);
              break;
            }
          }
        }
      } else {
        // Debris physics
        for (final d in _debris) {
          d.vy += 0.45; // gravity
          d.x += d.vx;
          d.y += d.vy;
          d.rotation += d.spin;
          d.life -= 1;
        }
        _debris.removeWhere((d) =>
            d.y > _skySize.height + 60 || d.life <= 0);
        _crashFlash = (_crashFlash - 0.04).clamp(0.0, 1.0);
      }
    });
  }

  void _triggerCrash(Offset origin) {
    _crashed = true;
    _crashFlash = 1.0;
    _engineOn = false;
    _debris.clear();
    // Spawn debris pieces around impact point
    const kinds = DebrisKind.values;
    for (int i = 0; i < 18; i++) {
      final kind = kinds[i % kinds.length];
      final ang = _rng.nextDouble() * 2 * pi;
      final v = 3 + _rng.nextDouble() * 5;
      _debris.add(Debris(
        x: origin.dx + (_rng.nextDouble() - 0.5) * 40,
        y: origin.dy + (_rng.nextDouble() - 0.5) * 30,
        vx: cos(ang) * v,
        vy: sin(ang) * v - 4, // bias upward initially
        rotation: _rng.nextDouble() * 2 * pi,
        spin: (_rng.nextDouble() - 0.5) * 0.3,
        kind: kind,
        size: 8 + _rng.nextDouble() * 14,
        life: 180,
      ));
    }
  }

  void _reset() {
    setState(() {
      _crashed = false;
      _debris.clear();
      _crashFlash = 0;
      _engineOn = true;
      _altitude = 0.5;
      _throttle = 0.4;
      _heading = 0;
      _altitudeTarget = 0.5;
      _throttleTarget = 0.4;
      _headingTarget = 0;
      _planes.clear();
      // Reset to empty sky — planes will arrive again on their own.
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
                    clipBehavior: Clip.hardEdge,
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
                    child: LayoutBuilder(
                      builder: (context, sky) {
                        // Update collision-math size for the next tick
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final s = Size(sky.maxWidth, sky.maxHeight);
                          if (_skySize != s) _skySize = s;
                        });
                        return Stack(
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
                            ..._buildClouds(sky),
                            // Zeppelin sits behind the planes — aircraft
                            // are the foreground subject.
                            if (!_crashed)
                              AnimatedBuilder(
                                animation: _zeppelinBob,
                                builder: (context, child) {
                                  final bob =
                                      sin(_zeppelinBob.value * 2 * pi) * 8;
                                  final yPos = (1 - _altitude) *
                                          (sky.maxHeight - 140) +
                                      bob;
                                  final xPos = (0.5 + _heading * 0.25) *
                                      (sky.maxWidth - _zeppelinW);
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
                            ..._planes.map((p) => _buildPlane(p, sky)),
                            // Debris on top
                            if (_crashed)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: DebrisPainter(_debris),
                                  ),
                                ),
                              ),
                            // White impact flash
                            if (_crashFlash > 0)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    color: Colors.white.withValues(
                                      alpha: _crashFlash * 0.7,
                                    ),
                                  ),
                                ),
                              ),
                            const Positioned(
                              right: 14,
                              top: 14,
                              child: _CompassRose(),
                            ),
                            const Positioned(
                              left: 14,
                              top: 14,
                              child: _Logo(size: 64),
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
                                crashed: _crashed,
                              ),
                            ),
                            // Crash banner + reset
                            if (_crashed)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: sky.maxHeight * 0.38,
                                child: Center(child: _CrashBanner(onReset: _reset)),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                _ControlPanel(
                  altitude: _altitudeTarget,
                  throttle: _throttleTarget,
                  heading: _headingTarget,
                  engineOn: _engineOn,
                  onAltitude: (v) => setState(() => _altitudeTarget = v),
                  onThrottle: (v) => setState(() => _throttleTarget = v),
                  onHeading: (v) => setState(() => _headingTarget = v),
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

  Widget _buildPlane(Plane p, BoxConstraints c) {
    return Positioned(
      left: p.x * c.maxWidth,
      top: p.y * c.maxHeight,
      child: Transform.scale(
        scale: p.scale,
        child: Transform.flip(
          flipX: !p.goingRight,
          child: const _Aircraft(),
        ),
      ),
    );
  }
}

class Plane {
  double x, y, airspeedKmh, scale;
  bool goingRight;
  Plane({
    required this.x,
    required this.y,
    required this.airspeedKmh,
    required this.goingRight,
    required this.scale,
  });
}

// ─── Debris ─────────────────────────────────────────────────────────────────

enum DebrisKind { envelope, gondola, propeller, fin, window, plank }

class Debris {
  double x, y, vx, vy, rotation, spin, size;
  int life;
  DebrisKind kind;
  Debris({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.spin,
    required this.kind,
    required this.size,
    required this.life,
  });
}

class DebrisPainter extends CustomPainter {
  final List<Debris> debris;
  DebrisPainter(this.debris);

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = TTR.ink
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final d in debris) {
      canvas.save();
      canvas.translate(d.x, d.y);
      canvas.rotate(d.rotation);
      final fade = (d.life / 180).clamp(0.0, 1.0);
      switch (d.kind) {
        case DebrisKind.envelope:
          // Cream chunk
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: d.size * 1.6,
            height: d.size * 0.9,
          );
          canvas.drawOval(
            rect,
            Paint()..color = TTR.cream.withValues(alpha: fade),
          );
          canvas.drawOval(rect, outline);
          break;
        case DebrisKind.gondola:
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: d.size * 1.4,
            height: d.size * 0.7,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(3)),
            Paint()..color = TTR.wood.withValues(alpha: fade),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(3)),
            outline,
          );
          break;
        case DebrisKind.propeller:
          final p = Paint()
            ..color = TTR.brass.withValues(alpha: fade)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(
            Offset(-d.size, 0),
            Offset(d.size, 0),
            p,
          );
          canvas.drawCircle(
            Offset.zero,
            3,
            Paint()..color = TTR.ink.withValues(alpha: fade),
          );
          break;
        case DebrisKind.fin:
          final path = Path()
            ..moveTo(-d.size * 0.6, d.size * 0.5)
            ..lineTo(d.size * 0.6, 0)
            ..lineTo(-d.size * 0.6, -d.size * 0.5)
            ..close();
          canvas.drawPath(
            path,
            Paint()..color = TTR.red.withValues(alpha: fade),
          );
          canvas.drawPath(path, outline);
          break;
        case DebrisKind.window:
          canvas.drawCircle(
            Offset.zero,
            d.size * 0.4,
            Paint()..color = TTR.mustard.withValues(alpha: fade),
          );
          canvas.drawCircle(Offset.zero, d.size * 0.4, outline);
          break;
        case DebrisKind.plank:
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: d.size * 1.8,
            height: d.size * 0.3,
          );
          canvas.drawRect(
            rect,
            Paint()..color = TTR.woodLight.withValues(alpha: fade),
          );
          canvas.drawRect(rect, outline);
          break;
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant DebrisPainter old) => true;
}

// ─── Crash banner ───────────────────────────────────────────────────────────

class _CrashBanner extends StatelessWidget {
  final VoidCallback onReset;
  const _CrashBanner({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
      decoration: BoxDecoration(
        color: TTR.cream,
        border: Border.all(color: TTR.ink, width: 3),
        boxShadow: [
          BoxShadow(
            color: TTR.ink.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(3, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '✦  EXPEDITION  LOST  ✦',
            style: TextStyle(
              color: TTR.red,
              fontFamily: 'Georgia',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'The airship has collided with an aircraft.',
            style: TextStyle(
              color: TTR.ink,
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onReset,
            style: ElevatedButton.styleFrom(
              backgroundColor: TTR.green,
              foregroundColor: TTR.cream,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: const BorderSide(color: TTR.ink, width: 2),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            ),
            child: const Text(
              'COMMISSION  NEW  AIRSHIP',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
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

// ─── Logo medallion ─────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  final double size;
  const _Logo({this.size = 80});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1;

    // ── Outer red ring with thick ink border ──
    canvas.drawCircle(c, r, Paint()..color = TTR.red);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = TTR.ink
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // ── Cream inner disc with ink hairline + brass accent ──
    final innerR = r - size.width * 0.10;
    canvas.drawCircle(c, innerR, Paint()..color = TTR.cream);
    canvas.drawCircle(
      c,
      innerR,
      Paint()
        ..color = TTR.ink
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      c,
      innerR - 2.5,
      Paint()
        ..color = TTR.brass
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );

    // ── Paper grain inside ──
    final rng = Random(7);
    for (int i = 0; i < 22; i++) {
      final ang = rng.nextDouble() * 2 * pi;
      final rad = rng.nextDouble() * (innerR - 4);
      canvas.drawCircle(
        Offset(c.dx + cos(ang) * rad, c.dy + sin(ang) * rad),
        rng.nextDouble() * 0.7,
        Paint()..color = TTR.inkLight.withValues(alpha: 0.10),
      );
    }

    // ── Stars on the red ring (decorative) ──
    for (int i = 0; i < 6; i++) {
      final a = -pi / 2 + i * pi / 3;
      final pos = Offset(
        c.dx + cos(a) * (r - size.width * 0.05),
        c.dy + sin(a) * (r - size.width * 0.05),
      );
      _drawStar(canvas, pos, size.width * 0.035, TTR.cream);
    }

    // ── Zeppelin silhouette (right-facing, dominates center) ──
    final zCenter = Offset(c.dx + 1, c.dy + size.height * 0.05);
    final zW = size.width * 0.50;
    final zH = size.height * 0.20;

    // Tail fin (drawn first, behind envelope)
    final finBaseX = zCenter.dx - zW / 2 + 2;
    final fin = Path()
      ..moveTo(finBaseX, zCenter.dy - zH * 0.15)
      ..lineTo(finBaseX - size.width * 0.06, zCenter.dy - zH * 0.65)
      ..lineTo(finBaseX - size.width * 0.06, zCenter.dy + zH * 0.65)
      ..close();
    canvas.drawPath(fin, Paint()..color = TTR.wood);
    canvas.drawPath(
      fin,
      Paint()
        ..color = TTR.ink
        ..strokeWidth = 0.7
        ..style = PaintingStyle.stroke,
    );

    // Envelope (cream → tan gradient)
    final envelopeRect =
        Rect.fromCenter(center: zCenter, width: zW, height: zH);
    final envelope =
        RRect.fromRectAndRadius(envelopeRect, Radius.circular(zH / 2));
    canvas.drawRRect(
      envelope,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF4E8C9), Color(0xFFB89968)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(envelopeRect),
    );
    canvas.drawRRect(
      envelope,
      Paint()
        ..color = TTR.ink
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke,
    );

    // Red stripe with brass under-stripe
    canvas.drawRect(
      Rect.fromCenter(
        center: zCenter,
        width: zW - 6,
        height: zH * 0.18,
      ),
      Paint()..color = TTR.red,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(zCenter.dx, zCenter.dy + zH * 0.20),
        width: zW - 6,
        height: zH * 0.06,
      ),
      Paint()..color = TTR.brass,
    );

    // Gondola
    final gondolaRect = Rect.fromCenter(
      center: Offset(zCenter.dx, zCenter.dy + zH * 0.65),
      width: zW * 0.42,
      height: zH * 0.36,
    );
    final gondola =
        RRect.fromRectAndRadius(gondolaRect, const Radius.circular(2));
    canvas.drawRRect(gondola, Paint()..color = TTR.wood);
    canvas.drawRRect(
      gondola,
      Paint()
        ..color = TTR.ink
        ..strokeWidth = 0.7
        ..style = PaintingStyle.stroke,
    );

    // ── Tiny aircraft (much smaller, above-right of the zeppelin) ──
    final pC = Offset(
      c.dx + size.width * 0.22,
      c.dy - size.height * 0.22,
    );
    final pW = size.width * 0.16;

    final planeInk = Paint()
      ..color = TTR.ink
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    // Fuselage (horizontal cigar, simplified)
    canvas.drawLine(
      Offset(pC.dx - pW * 0.45, pC.dy),
      Offset(pC.dx + pW * 0.5, pC.dy),
      planeInk,
    );
    // Wing (perpendicular)
    canvas.drawLine(
      Offset(pC.dx - pW * 0.1, pC.dy - pW * 0.28),
      Offset(pC.dx - pW * 0.1, pC.dy + pW * 0.28),
      planeInk,
    );
    // Tail (small vertical at rear)
    canvas.drawLine(
      Offset(pC.dx - pW * 0.4, pC.dy - pW * 0.18),
      Offset(pC.dx - pW * 0.4, pC.dy + pW * 0.05),
      Paint()
        ..color = TTR.ink
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
    // Propeller hub dot
    canvas.drawCircle(
      Offset(pC.dx + pW * 0.5, pC.dy),
      1.2,
      Paint()..color = TTR.brass,
    );
  }

  void _drawStar(Canvas canvas, Offset c, double r, Color fill) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? r : r * 0.42;
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
        ..color = TTR.ink
        ..strokeWidth = 0.4
        ..style = PaintingStyle.stroke,
    );
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

class _Aircraft extends StatelessWidget {
  const _Aircraft();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 40,
      child: CustomPaint(painter: _AircraftPainter()),
    );
  }
}

class _AircraftPainter extends CustomPainter {
  // Right-facing 1941 Stinson Vultee L-1E Vigilant —
  // side view, foreground subject.
  static const olive = Color(0xFF5B6B3F);
  static const oliveLight = Color(0xFF7A8B5C);
  static const oliveDark = Color(0xFF3F4A2A);
  static const canopyGlass = Color(0xFF5A7891);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final outline = Paint()
      ..color = TTR.ink
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    final strut = Paint()
      ..color = TTR.ink
      ..strokeWidth = 0.9;

    // ── Vertical tail fin ──
    final tailFin = Path()
      ..moveTo(w * 0.05, h * 0.42)
      ..quadraticBezierTo(w * 0.05, h * 0.10, w * 0.13, h * 0.08)
      ..quadraticBezierTo(w * 0.20, h * 0.18, w * 0.20, h * 0.42)
      ..close();
    canvas.drawPath(tailFin, Paint()..color = olive);
    canvas.drawPath(tailFin, outline);

    // ── Horizontal stabilizer ──
    final hStab = Path()
      ..moveTo(w * 0.02, h * 0.50)
      ..lineTo(w * 0.22, h * 0.46)
      ..lineTo(w * 0.22, h * 0.54)
      ..lineTo(w * 0.02, h * 0.52)
      ..close();
    canvas.drawPath(hStab, Paint()..color = oliveLight);
    canvas.drawPath(hStab, outline);

    // ── Tailwheel ──
    canvas.drawLine(Offset(w * 0.10, h * 0.60),
        Offset(w * 0.10, h * 0.68), strut);
    canvas.drawCircle(Offset(w * 0.10, h * 0.70), h * 0.025,
        Paint()..color = TTR.ink);

    // ── Main gear V-strut + teardrop spat (forward, under the cowl) ──
    canvas.drawLine(Offset(w * 0.62, h * 0.60),
        Offset(w * 0.64, h * 0.78),
        Paint()..color = TTR.ink..strokeWidth = 1.2);
    canvas.drawLine(Offset(w * 0.72, h * 0.60),
        Offset(w * 0.66, h * 0.78),
        Paint()..color = TTR.ink..strokeWidth = 1.2);
    final spat = Path()
      ..moveTo(w * 0.58, h * 0.78)
      ..quadraticBezierTo(w * 0.56, h * 0.92, w * 0.65, h * 0.94)
      ..quadraticBezierTo(w * 0.74, h * 0.92, w * 0.74, h * 0.80)
      ..quadraticBezierTo(w * 0.70, h * 0.74, w * 0.62, h * 0.76)
      ..quadraticBezierTo(w * 0.59, h * 0.77, w * 0.58, h * 0.78)
      ..close();
    canvas.drawPath(spat, Paint()..color = olive);
    canvas.drawPath(spat, outline);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.65, h * 0.92),
        width: w * 0.14,
        height: h * 0.08,
      ),
      0, pi, false,
      Paint()
        ..color = TTR.ink
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    // ── Fuselage (horizontal cigar, right-facing nose) ──
    final fuselage = Path()
      ..moveTo(w * 0.04, h * 0.50)
      ..quadraticBezierTo(w * 0.04, h * 0.42, w * 0.18, h * 0.42)
      ..lineTo(w * 0.74, h * 0.40)
      ..quadraticBezierTo(w * 0.84, h * 0.42, w * 0.88, h * 0.46)
      ..quadraticBezierTo(w * 0.91, h * 0.50, w * 0.88, h * 0.54)
      ..quadraticBezierTo(w * 0.84, h * 0.58, w * 0.74, h * 0.60)
      ..lineTo(w * 0.18, h * 0.60)
      ..quadraticBezierTo(w * 0.04, h * 0.58, w * 0.04, h * 0.50)
      ..close();
    canvas.drawPath(fuselage, Paint()..color = olive);
    canvas.drawPath(fuselage, outline);
    canvas.drawLine(
      Offset(w * 0.18, h * 0.58),
      Offset(w * 0.74, h * 0.58),
      Paint()..color = oliveLight..strokeWidth = 0.6,
    );

    // ── Greenhouse canopy (multi-pane on top) ──
    final canopy = Path()
      ..moveTo(w * 0.30, h * 0.42)
      ..quadraticBezierTo(w * 0.30, h * 0.30, w * 0.40, h * 0.28)
      ..lineTo(w * 0.66, h * 0.28)
      ..quadraticBezierTo(w * 0.74, h * 0.30, w * 0.74, h * 0.42)
      ..close();
    canvas.drawPath(canopy, Paint()..color = canopyGlass);
    canvas.drawPath(canopy, outline);
    final frame = Paint()..color = TTR.ink..strokeWidth = 0.7;
    for (final f in [0.36, 0.44, 0.52, 0.60, 0.68]) {
      final upperY = (f < 0.40)
          ? h * (0.42 - (f - 0.30) / 0.10 * 0.12)
          : (f > 0.66)
              ? h * (0.28 + (f - 0.66) / 0.08 * 0.14)
              : h * 0.28;
      canvas.drawLine(
          Offset(w * f, h * 0.42), Offset(w * f, upperY), frame);
    }

    // ── High wing (above fuselage) ──
    final wingRect =
        Rect.fromLTWH(w * 0.16, h * 0.20, w * 0.62, h * 0.08);
    canvas.drawRect(wingRect, Paint()..color = oliveLight);
    canvas.drawRect(wingRect, outline);
    canvas.drawLine(
      Offset(w * 0.16, h * 0.22),
      Offset(w * 0.78, h * 0.22),
      Paint()..color = oliveDark..strokeWidth = 0.8,
    );

    // ── Wing struts (V from wing to fuselage) ──
    canvas.drawLine(
        Offset(w * 0.30, h * 0.28), Offset(w * 0.24, h * 0.42), strut);
    canvas.drawLine(
        Offset(w * 0.30, h * 0.28), Offset(w * 0.34, h * 0.42), strut);
    canvas.drawLine(
        Offset(w * 0.64, h * 0.28), Offset(w * 0.58, h * 0.42), strut);
    canvas.drawLine(
        Offset(w * 0.64, h * 0.28), Offset(w * 0.68, h * 0.42), strut);

    // ── US star insignia on fuselage side ──
    final fuseStar = Offset(w * 0.24, h * 0.51);
    canvas.drawCircle(fuseStar, h * 0.06, Paint()..color = TTR.navy);
    canvas.drawCircle(fuseStar, h * 0.06, outline);
    _drawWhiteStar(canvas, fuseStar, h * 0.038);
    // ── Star on top of wing ──
    final wingStar = Offset(w * 0.36, h * 0.24);
    canvas.drawCircle(wingStar, h * 0.028, Paint()..color = TTR.navy);
    _drawWhiteStar(canvas, wingStar, h * 0.018);

    // ── Engine cowl ──
    final cowlRect = Rect.fromCenter(
      center: Offset(w * 0.91, h * 0.50),
      width: w * 0.10,
      height: h * 0.22,
    );
    canvas.drawOval(cowlRect, Paint()..color = oliveDark);
    canvas.drawOval(cowlRect, outline);
    final cyl = Paint()..color = TTR.ink..strokeWidth = 0.7;
    canvas.drawLine(
        Offset(w * 0.90, h * 0.42), Offset(w * 0.93, h * 0.42), cyl);
    canvas.drawLine(
        Offset(w * 0.90, h * 0.58), Offset(w * 0.93, h * 0.58), cyl);

    // ── Propeller blade + hub ──
    canvas.drawLine(
      Offset(w * 0.97, h * 0.18),
      Offset(w * 0.97, h * 0.82),
      Paint()
        ..color = TTR.ink
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(w * 0.97, h * 0.50), 2,
        Paint()..color = TTR.brass);
    canvas.drawCircle(
      Offset(w * 0.97, h * 0.50), 2,
      Paint()
        ..color = TTR.ink
        ..strokeWidth = 0.6
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawWhiteStar(Canvas canvas, Offset c, double r) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? r : r * 0.42;
      final pt = Offset(c.dx + cos(a) * rr, c.dy + sin(a) * rr);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = TTR.cream);
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
  final bool crashed;

  const _Hud({
    required this.altitude,
    required this.throttle,
    required this.heading,
    required this.engineOn,
    required this.planes,
    this.crashed = false,
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
                crashed
                    ? 'WRECKED'
                    : (engineOn ? 'IN  FLIGHT' : 'GROUNDED'),
                style: const TextStyle(
                  color: TTR.cream,
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ),
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
