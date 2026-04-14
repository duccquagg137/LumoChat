import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumochat/main.dart';

void main() {
  testWidgets('LumoChat app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LumoChatApp(isFirebaseInitialized: false),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    final openAppFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data == 'Open App' || widget.data == 'Mở ứng dụng'),
      description: 'Open App CTA in vi/en',
    );
    expect(openAppFinder, findsOneWidget);
  });
}
