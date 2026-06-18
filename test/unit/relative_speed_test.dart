import 'package:flutter_test/flutter_test.dart';
import 'package:zeppelin_app/main.dart';

import '../helpers/test_helpers.dart';

/// Task #4 — relative-speed physics.
/// Plane drift across the sky = airspeed ± zeppelinSpeed depending on
/// matching/opposing directions.
void main() {
  testWidgets('right-going plane drift = (150 - zeppelinKmh) × speedScale',
      (tester) async {
    final state = await pumpZeppelinApp(tester);
    // Force-settle throttle at 0 without waiting for smoothing
    state.throttle = 0.0;
    state.throttleTarget = 0.0;

    final p = Plane(
      x: 0.0, y: 0.3, airspeedKmh: 150, goingRight: true, scale: 1.0,
    );
    state.planes.add(p);
    final x0 = p.x;
    state.runTick();
    final dx0 = p.x - x0;
    // 150 km/h × 1.6e-5 = 0.0024 per tick
    expect(dx0, closeTo(150 * 1.6e-5, 1e-7));

    // Now set throttle directly to 1.0 (zeppelin 120 km/h)
    state.throttle = 1.0;
    state.throttleTarget = 1.0;
    state.planes.clear();
    final p2 = Plane(
      x: 0.0, y: 0.3, airspeedKmh: 150, goingRight: true, scale: 1.0,
    );
    state.planes.add(p2);
    final y0 = p2.x;
    state.runTick();
    final dx1 = p2.x - y0;
    // After one tick the smoothed throttle eased slightly from 1.0; the
    // tick uses the NEW smoothed value: 1.0 + (1.0 - 1.0) * 0.03 = 1.0.
    // So zeppelinKmh = 120, drift = (150 - 120) × 1.6e-5 = 4.8e-4.
    expect(dx1, closeTo((150 - 120) * 1.6e-5, 1e-7));
    expect(dx1, lessThan(dx0));
  });

  testWidgets('left-going plane drift = -(150 + zeppelinKmh) × speedScale',
      (tester) async {
    final state = await pumpZeppelinApp(tester);
    state.throttle = 1.0;
    state.throttleTarget = 1.0;

    final p = Plane(
      x: 1.0, y: 0.3, airspeedKmh: 150, goingRight: false, scale: 1.0,
    );
    state.planes.add(p);
    final x0 = p.x;
    state.runTick();
    final dx = p.x - x0;
    expect(dx, closeTo(-(150 + 120) * 1.6e-5, 1e-7));
  });
}
