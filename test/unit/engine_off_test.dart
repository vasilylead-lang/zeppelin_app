import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

/// Task #10 — engine-off forces effective throttle to 0; engine-on restores
/// progression toward _throttleTarget.
void main() {
  testWidgets('engine off drives throttle toward 0', (tester) async {
    final state = await pumpZeppelinApp(tester);
    state.throttle = 1.0;
    state.throttleTarget = 1.0;
    state.engineOn = false;

    // One tick with engine off: effective=0, throttle eases down by 3%.
    state.runTick();
    expect(state.throttle, closeTo(1.0 * (1 - 0.03), 1e-9));
    expect(state.throttleTarget, 1.0, reason: 'target is preserved');

    // Many ticks → close to 0.
    await tickN(tester, state, 300);
    expect(state.throttle, closeTo(0.0, 0.02));
  });

  testWidgets('engine back on resumes progression toward target',
      (tester) async {
    final state = await pumpZeppelinApp(tester);
    state.throttle = 0.0;
    state.throttleTarget = 0.8;
    state.engineOn = false;
    // Even with target=0.8 and engine off, throttle stays at 0.
    state.runTick();
    expect(state.throttle, closeTo(0.0, 1e-9));

    // Restore engine — throttle now climbs toward 0.8.
    state.engineOn = true;
    state.runTick();
    expect(state.throttle, closeTo(0.8 * 0.03, 1e-9));

    await tickN(tester, state, 300);
    expect(state.throttle, closeTo(0.8, 0.02));
  });
}
