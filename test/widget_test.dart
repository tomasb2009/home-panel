import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:home_panel/main.dart';

void main() {
  testWidgets('App shell renders home dashboard', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HomePanelApp());
    await tester.pumpAndSettle();

    expect(find.text('20:45'), findsOneWidget);
    expect(find.text('Parcialmente nublado'), findsOneWidget);
    expect(find.text('Buenas noches, Familia'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Luces'), findsOneWidget);
  });
}
