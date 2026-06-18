import 'package:flutter_test/flutter_test.dart';
import 'package:zeppelin_app/main.dart';

import '../helpers/test_helpers.dart';

/// Task #6 — AABB collision detection between zeppelin and plane.
void main() {
  testWidgets('overlapping rects flip crashed=true on next tick',
      (tester) async {
    final state = await pumpZeppelinApp(tester);
    setSky(state);

    final zRect = state.zeppelinRect();
    // Position the plane right on top of the zeppelin centre.
    final cx = zRect.center.dx;
    final cy = zRect.center.dy;
    final px = cx / state.skySize.width;
    final py = cy / state.skySize.height;

    state.planes.add(Plane(
      x: px - 0.01,
      y: py - 0.01,
      airspeedKmh: 150,
      goingRight: true,
      scale: 1.0,
    ));

    expect(state.crashed, isFalse);
    state.runTick();
    expect(state.crashed, isTrue);
  });

  testWidgets('non-overlapping plane does NOT trigger crash', (tester) async {
    final state = await pumpZeppelinApp(tester);
    setSky(state);

    // Plane far above the zeppelin.
    state.planes.add(Plane(
      x: 0.05,
      y: 0.02,
      airspeedKmh: 150,
      goingRight: true,
      scale: 0.5,
    ));
    state.runTick();
    expect(state.crashed, isFalse);
  });
}
