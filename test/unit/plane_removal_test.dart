import 'package:flutter_test/flutter_test.dart';
import 'package:zeppelin_app/main.dart';

import '../helpers/test_helpers.dart';

/// Task #5 — planes are removed when off-screen (x < -0.2 or x > 1.2).
void main() {
  testWidgets('right-going plane is removed once x > 1.2', (tester) async {
    final state = await pumpZeppelinApp(tester);
    state.planes.add(Plane(
      x: 1.25,
      y: 0.3,
      airspeedKmh: 150,
      goingRight: true,
      scale: 1.0,
    ));
    state.runTick();
    expect(state.planes, isEmpty);
  });

  testWidgets('left-going plane is removed once x < -0.2', (tester) async {
    final state = await pumpZeppelinApp(tester);
    state.planes.add(Plane(
      x: -0.25,
      y: 0.3,
      airspeedKmh: 150,
      goingRight: false,
      scale: 1.0,
    ));
    state.runTick();
    expect(state.planes, isEmpty);
  });

  testWidgets('plane inside the visible band is NOT removed', (tester) async {
    final state = await pumpZeppelinApp(tester);
    state.planes.add(Plane(
      x: 0.5,
      y: 0.3,
      airspeedKmh: 150,
      goingRight: true,
      scale: 1.0,
    ));
    state.runTick();
    expect(state.planes.length, 1);
  });
}
