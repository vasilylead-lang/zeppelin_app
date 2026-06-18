import 'package:flutter_test/flutter_test.dart';
import 'package:zeppelin_app/main.dart';

import '../helpers/test_helpers.dart';

/// Task #3 — plane spawn cadence and cap.
void main() {
  testWidgets('starts with empty sky', (tester) async {
    final state = await pumpZeppelinApp(tester);
    expect(state.planes, isEmpty);
  });

  testWidgets('newly-spawned planes appear at the edges', (tester) async {
    final state = await pumpZeppelinApp(tester);
    // Force a spawn via the public test hook
    final Plane p = state.spawnPlane();
    // Going right → starts at x ≈ -0.20; going left → starts at x ≈ 1.20
    expect(
      (p.goingRight && p.x == -0.20) || (!p.goingRight && p.x == 1.20),
      isTrue,
      reason: 'plane at x=${p.x} goingRight=${p.goingRight}',
    );
    expect(p.y, greaterThanOrEqualTo(0.18));
    expect(p.y, lessThanOrEqualTo(0.18 + 0.50));
    expect(p.scale, greaterThanOrEqualTo(0.55));
    expect(p.scale, lessThanOrEqualTo(0.55 + 0.25));
  });

  testWidgets('plane count never exceeds the cap of 3', (tester) async {
    final state = await pumpZeppelinApp(tester);
    // Run for a generous 30 simulated seconds — the spawn gate is 1.5%/tick,
    // so plenty of opportunities to overshoot the cap.
    setSky(state);
    await advance(tester, state, 30000);
    expect(state.planes.length, lessThanOrEqualTo(3));
  });
}
