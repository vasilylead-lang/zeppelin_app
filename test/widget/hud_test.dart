import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

/// Task #11 — HUD displays the right values.
void main() {
  testWidgets('HUD shows IN FLIGHT, ALT, SPD, BEARING, TRAFFIC', (tester) async {
    final state = await pumpZeppelinApp(tester);
    setSky(state);

    // Settle the smoothed values
    state.altitudeTarget = 0.5;
    state.throttleTarget = 0.4;
    state.headingTarget = -0.2;
    await advance(tester, state, 3000);

    // ALTITUDE: 0.5 * 2400 = 1200 → "1200 m"
    expect(find.textContaining('1200'), findsWidgets);
    // SPEED: 0.4 * 120 = 48 → " 48 km/h"
    expect(find.textContaining('48'), findsWidgets);
    // BEARING: -0.2 * 45 ≈ -9°
    expect(find.textContaining('-9'), findsWidgets);
    expect(find.text('IN  FLIGHT'), findsOneWidget);
  });

  testWidgets('HUD flips to GROUNDED when engine is off', (tester) async {
    final state = await pumpZeppelinApp(tester);
    setSky(state);
    state.engineOn = false;
    await tester.pump();
    expect(find.text('GROUNDED'), findsOneWidget);
  });

  testWidgets('HUD flips to WRECKED after a crash', (tester) async {
    final state = await pumpZeppelinApp(tester);
    setSky(state);
    state.triggerCrash(const Offset(200, 300));
    await tester.pump();
    expect(find.text('WRECKED'), findsOneWidget);
  });
}
