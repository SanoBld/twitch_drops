import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:twitch_drops/app.dart';

void main() {
  testWidgets('App starts and shows a widget', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
