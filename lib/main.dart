import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const ZeppelinApp());
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB8860B),
          brightness: Brightness.dark,
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
  // Zeppelin state
  double _altitude = 0.5; // 0 (ground) → 1 (max)
  double _throttle = 0.4; // 0 → 1
  double _heading = 0; // -1 (left) → 1 (right)
  bool _engineOn = true;

  // Airplane fleet
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

    // Seed initial planes
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
                  child: Stack(
                    children: [
                      // Sky gradient
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF1E3A5F),
                              Color(0xFF4A90B8),
                              Color(0xFFE8B87C),
                            ],
                            stops: [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                      // Clouds (parallax)
                      ..._buildClouds(constraints),
                      // Planes
                      ..._planes.map((p) => _buildPlane(p, constraints)),
                      // Zeppelin
                      AnimatedBuilder(
                        animation: _zeppelinBob,
                        builder: (context, child) {
                          final bob = sin(_zeppelinBob.value * 2 * pi) * 8;
                          final yPos = (1 - _altitude) *
                              (constraints.maxHeight - 120) +
                              bob;
                          final xPos = (0.5 + _heading * 0.25) *
                              (constraints.maxWidth - 160);
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
                      // HUD overlay
                      Positioned(
                        top: 12,
                        left: 12,
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
                // Control panel
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
    final cloudOffsets = [
      [0.1, 0.15, 1.0],
      [0.4, 0.25, 1.4],
      [0.75, 0.1, 0.9],
      [0.6, 0.4, 1.1],
      [0.15, 0.5, 1.2],
    ];
    return cloudOffsets.map((o) {
      return Positioned(
        left: o[0] * c.maxWidth,
        top: o[1] * c.maxHeight,
        child: Opacity(
          opacity: 0.6,
          child: _Cloud(scale: o[2]),
        ),
      );
    }).toList();
  }

  Widget _buildPlane(_Plane p, BoxConstraints c) {
    return Positioned(
      left: p.x * c.maxWidth,
      top: p.y * c.maxHeight,
      child: Transform.scale(
        scale: p.scale,
        child: Transform.flip(
          flipX: !p.goingRight,
          child: const _Airplane(),
        ),
      ),
    );
  }
}

class _Plane {
  double x;
  double y;
  double speed;
  bool goingRight;
  double scale;
  _Plane({
    required this.x,
    required this.y,
    required this.speed,
    required this.goingRight,
    required this.scale,
  });
}

// ─── Zeppelin ────────────────────────────────────────────────────────────────

class _ZeppelinWidget extends StatelessWidget {
  final bool engineOn;
  final double throttle;
  const _ZeppelinWidget({required this.engineOn, required this.throttle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 90,
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

    // Envelope (the big balloon)
    final envelopeRect = Rect.fromLTWH(w * 0.05, h * 0.15, w * 0.85, h * 0.5);
    final envelopePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFD9D2B6), Color(0xFF8C7E5A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(envelopeRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(envelopeRect, Radius.circular(h * 0.25)),
      envelopePaint,
    );

    // Stripe
    final stripe = Paint()..color = const Color(0xFFB8860B);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.05, h * 0.38, w * 0.85, h * 0.04),
      stripe,
    );

    // Tail fin
    final fin = Path()
      ..moveTo(w * 0.08, h * 0.4)
      ..lineTo(w * 0.0, h * 0.15)
      ..lineTo(w * 0.0, h * 0.7)
      ..close();
    canvas.drawPath(fin, Paint()..color = const Color(0xFF6B5D3A));

    // Gondola
    final gondolaRect = Rect.fromLTWH(w * 0.32, h * 0.68, w * 0.36, h * 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(gondolaRect, Radius.circular(h * 0.06)),
      Paint()..color = const Color(0xFF3A3A3A),
    );

    // Windows
    final winPaint = Paint()..color = const Color(0xFFFFE680);
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(w * (0.38 + i * 0.08), h * 0.77),
        h * 0.025,
        winPaint,
      );
    }

    // Propeller indicator (right side)
    final propX = w * 0.92;
    final propY = h * 0.4;
    final propPaint = Paint()
      ..color = engineOn ? Colors.white.withValues(alpha: 0.5) : Colors.grey
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(propX, propY), h * 0.08, propPaint);
  }

  @override
  bool shouldRepaint(covariant _ZeppelinPainter old) =>
      old.engineOn != engineOn || old.throttle != throttle;
}

// ─── Airplane ────────────────────────────────────────────────────────────────

class _Airplane extends StatelessWidget {
  const _Airplane();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 30,
      child: CustomPaint(painter: _AirplanePainter()),
    );
  }
}

class _AirplanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Paint()..color = const Color(0xFFE6E6E6);
    final shadow = Paint()..color = const Color(0xFF9AA0A6);

    // Fuselage
    final fuselage = Path()
      ..moveTo(w * 0.95, h * 0.5)
      ..lineTo(w * 0.15, h * 0.35)
      ..lineTo(w * 0.0, h * 0.45)
      ..lineTo(w * 0.0, h * 0.55)
      ..lineTo(w * 0.15, h * 0.65)
      ..close();
    canvas.drawPath(fuselage, body);

    // Wings
    final wings = Path()
      ..moveTo(w * 0.55, h * 0.5)
      ..lineTo(w * 0.35, h * 0.05)
      ..lineTo(w * 0.5, h * 0.5)
      ..lineTo(w * 0.35, h * 0.95)
      ..close();
    canvas.drawPath(wings, shadow);

    // Tail fin
    final tail = Path()
      ..moveTo(w * 0.1, h * 0.5)
      ..lineTo(w * 0.0, h * 0.15)
      ..lineTo(w * 0.12, h * 0.5)
      ..close();
    canvas.drawPath(tail, shadow);

    // Cockpit window
    canvas.drawCircle(
      Offset(w * 0.82, h * 0.45),
      h * 0.1,
      Paint()..color = const Color(0xFF4FC3F7),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Cloud ───────────────────────────────────────────────────────────────────

class _Cloud extends StatelessWidget {
  final double scale;
  const _Cloud({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: 80,
        height: 36,
        child: CustomPaint(painter: _CloudPainter()),
      ),
    );
  }
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.6), 14, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.45), 18, paint);
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.6), 14, paint);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.25, size.height * 0.6, size.width * 0.5, 8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── HUD ─────────────────────────────────────────────────────────────────────

class _Hud extends StatelessWidget {
  final double altitude;
  final double throttle;
  final double heading;
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB8860B), width: 1),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFFFFE680),
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('◈ ZEPPELIN HMS-1 ◈',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: engineOn
                      ? const Color(0xFFFFE680)
                      : Colors.redAccent,
                )),
            Text('ALT: ${altMeters.toString().padLeft(4)} m'),
            Text('SPD: ${speed.toString().padLeft(3)} km/h'),
            Text('HDG: ${(heading * 45).toStringAsFixed(0).padLeft(3)}°'),
            Text('TRAFFIC: $planes ✈'),
            Text('ENG: ${engineOn ? "ON " : "OFF"}'),
          ],
        ),
      ),
    );
  }
}

// ─── Control panel ───────────────────────────────────────────────────────────

class _ControlPanel extends StatelessWidget {
  final double altitude;
  final double throttle;
  final double heading;
  final bool engineOn;
  final ValueChanged<double> onAltitude;
  final ValueChanged<double> onThrottle;
  final ValueChanged<double> onHeading;
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A2418), Color(0xFF1A1610)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(top: BorderSide(color: Color(0xFFB8860B), width: 2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CONTROL PANEL',
                style: TextStyle(
                  color: Color(0xFFFFE680),
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Text(
                    engineOn ? 'ENGINE ON' : 'ENGINE OFF',
                    style: TextStyle(
                      color: engineOn
                          ? const Color(0xFF7CFFA0)
                          : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: engineOn,
                    onChanged: onEngine,
                    activeThumbColor: const Color(0xFFB8860B),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Slider(
            label: 'ALTITUDE',
            value: altitude,
            onChanged: onAltitude,
            color: const Color(0xFF7CC4FF),
          ),
          _Slider(
            label: 'THROTTLE',
            value: throttle,
            onChanged: engineOn ? onThrottle : null,
            color: const Color(0xFFFFB347),
          ),
          _Slider(
            label: 'HEADING ',
            value: (heading + 1) / 2,
            onChanged: (v) => onHeading(v * 2 - 1),
            color: const Color(0xFFC589E8),
          ),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  final Color color;

  const _Slider({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD9D2B6),
              fontFamily: 'monospace',
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              overlayColor: color.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFFD9D2B6),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
