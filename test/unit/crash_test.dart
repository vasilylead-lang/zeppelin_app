import 'package:flutter_test/flutter_test.dart';
import 'package:zeppelin_app/main.dart';

import '../helpers/test_helpers.dart';

/// Task #7 — crash sequence: flash, 18 debris pieces, engine cut.
void main() {
  testWidgets('triggerCrash sets all expected state', (tester) async {
    final state = await pumpZeppelinApp(tester);
    setSky(state);
    state.triggerCrash(const Offset(200, 300));

    expect(state.crashed, isTrue);
    expect(state.engineOn, isFalse);
    expect(state.crashFlash, closeTo(1.0, 1e-9));
    expect(state.debris.length, 18);

    // All six kinds should be represented (round-robin generation).
    final kinds = state.debris.map((Debris d) => d.kind).toSet();
    expect(kinds, equals(DebrisKind.values.toSet()));
  });

  testWidgets('crashFlash fades to zero over time', (tester) async {
    final state = await pumpZeppelinApp(tester);
    setSky(state);
    state.triggerCrash(const Offset(200, 300));
    final initialFlash = state.crashFlash;
    await advance(tester, state, 1000);
    expect(state.crashFlash, lessThan(initialFlash));
    await advance(tester, state, 2000);
    expect(state.crashFlash, closeTo(0.0, 1e-9));
  });
}
