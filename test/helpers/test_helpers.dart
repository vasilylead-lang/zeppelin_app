import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeppelin_app/main.dart';

/// Pumps the full app and returns the State of the control page.
///
/// Use the returned dynamic state to read the `@visibleForTesting` getters
/// declared on `_ZeppelinControlPageState` (throttle, planes, debris, …).
/// We use `dynamic` because the state class itself is private — but its
/// public test hooks dispatch fine through dynamic.
Future<dynamic> pumpZeppelinApp(WidgetTester tester) async {
  await tester.pumpWidget(const ZeppelinApp());
  // First frame schedules the post-frame skySize capture; advance one tick.
  await tester.pump();
  return tester.state(find.byType(ZeppelinControlPage));
}

/// Advance the simulation by N ticks (≈ 60 fps).
///
/// This calls `runTick()` directly rather than relying on the real
/// AnimationController so tests are deterministic regardless of the test
/// framework's pump cadence. The trailing `pump()` lets any widget rebuilds
/// from setState propagate so finders see fresh widgets.
Future<void> tickN(WidgetTester tester, dynamic state, int n) async {
  for (int i = 0; i < n; i++) {
    state.runTick();
  }
  await tester.pump();
}

/// Convenience: simulate `millis` of wall-clock time worth of physics ticks.
/// (No actual time passes — purely deterministic frame counting.)
Future<void> advance(WidgetTester tester, dynamic state, int millis) async {
  await tickN(tester, state, (millis / 16).ceil());
}

/// Force a known sky size on the state so collision math is deterministic.
void setSky(dynamic state, {double w = 400, double h = 600}) {
  state.skySize = Size(w, h);
}
