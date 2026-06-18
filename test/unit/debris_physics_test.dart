import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

/// Task #8 — debris physics: gravity (vy increases), rotation, removal.
void main() {
  testWidgets('vy grows each tick under gravity (0.45)', (tester) async {
    final state = await pumpZeppelinApp(tester);
    setSky(state);
    state.triggerCrash(const Offset(200, 300));
    final piece = state.debris.first;
    final vyBefore = piece.vy;
    state.runTick();
    expect(piece.vy, closeTo(vyBefore + 0.45, 1e-9));
  });

  testWidgets('rotation accumulates by spin each tick', (tester) async {
    final state = await pumpZeppelinApp(tester);
    setSky(state);
    state.triggerCrash(const Offset(200, 300));
    final piece = state.debris.first;
    final rotBefore = piece.rotation;
    final spin = piece.spin;
    state.runTick();
    expect(piece.rotation, closeTo(rotBefore + spin, 1e-9));
  });

  testWidgets('debris falls off-screen and is removed', (tester) async {
    final state = await pumpZeppelinApp(tester);
    setSky(state, w: 400, h: 600);
    state.triggerCrash(const Offset(200, 300));
    // Push all debris below the screen → state.skySize.height + 60 = 660
    for (final d in state.debris) {
      d.y = 800.0;
    }
    state.runTick();
    expect(state.debris, isEmpty);
  });

  testWidgets('debris is removed when life hits 0', (tester) async {
    final state = await pumpZeppelinApp(tester);
    setSky(state);
    state.triggerCrash(const Offset(200, 300));
    for (final d in state.debris) {
      d.life = 1;
      d.y = 100.0; // keep on-screen so off-screen rule doesn't dominate
    }
    state.runTick();
    expect(state.debris, isEmpty);
  });
}
