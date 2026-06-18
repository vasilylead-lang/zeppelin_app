import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

/// Task #2 — throttle smoothing.
/// The slider edits a hidden target; the actual throttle eases toward it.
void main() {
  testWidgets('throttle target jumps; smoothed throttle eases over time',
      (tester) async {
    final state = await pumpZeppelinApp(tester);
    expect(state.throttle, closeTo(0.4, 1e-9));
    expect(state.throttleTarget, closeTo(0.4, 1e-9));

    state.throttleTarget = 1.0;
    await tester.pump();
    expect(state.throttleTarget, 1.0);
    // Smoothed value hasn't caught up after one frame.
    expect(state.throttle, lessThan(0.5));

    await advance(tester, state, 250);
    expect(state.throttle, greaterThan(0.45));
    expect(state.throttle, lessThan(0.95));

    await advance(tester, state, 3000);
    expect(state.throttle, closeTo(1.0, 0.02));
  });

  testWidgets('throttle smoothing runs downward too', (tester) async {
    final state = await pumpZeppelinApp(tester);
    state.throttleTarget = 0.0;
    await advance(tester, state, 3000);
    expect(state.throttle, closeTo(0.0, 0.02));
  });
}
