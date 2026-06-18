import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeppelin_app/main.dart';

import '../helpers/test_helpers.dart';

/// Task #12 — full-app boot smoke + golden image of the sky scene.
void main() {
  testWidgets('ZeppelinApp boots without exceptions', (tester) async {
    await tester.pumpWidget(const ZeppelinApp());
    await tester.pump();
    expect(find.byType(ZeppelinApp), findsOneWidget);
    expect(find.byType(ZeppelinControlPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sky scene renders at defaults — golden capture',
      (tester) async {
    // Match the iPhone 17 simulator viewport roughly so the golden is stable
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = await pumpZeppelinApp(tester);
    state.altitudeTarget = 0.5;
    state.throttleTarget = 0.0; // no planes will appear → stable image
    state.headingTarget = 0.0;
    await advance(tester, state, 3000);

    // Capture the page; update with --update-goldens to regenerate.
    await expectLater(
      find.byType(ZeppelinControlPage),
      matchesGoldenFile('goldens/sky_scene_defaults.png'),
    );
  }, skip: true);
  // ^ goldens skip by default — run `flutter test --update-goldens` once
  // on the dev machine to create the baseline, then remove `skip: true`.
}
