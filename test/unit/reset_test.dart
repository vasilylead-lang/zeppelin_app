import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

/// Task #9 — COMMISSION NEW AIRSHIP resets the world.
void main() {
  testWidgets('reset clears crash state and restores defaults',
      (tester) async {
    final state = await pumpZeppelinApp(tester);
    setSky(state);

    // Make the world dirty.
    state.altitudeTarget = 0.9;
    state.headingTarget = 0.7;
    state.throttleTarget = 0.8;
    state.triggerCrash(const Offset(200, 300));
    expect(state.crashed, isTrue);
    expect(state.debris, isNotEmpty);
    expect(state.engineOn, isFalse);

    // Reset
    state.reset();
    expect(state.crashed, isFalse);
    expect(state.debris, isEmpty);
    expect(state.engineOn, isTrue);
    expect(state.altitudeTarget, closeTo(0.5, 1e-9));
    expect(state.headingTarget, closeTo(0.0, 1e-9));
    expect(state.throttleTarget, closeTo(0.4, 1e-9));
    expect(state.planes, isEmpty);
    expect(state.crashFlash, 0);
  });
}
