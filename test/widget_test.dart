import 'package:flutter_test/flutter_test.dart';
import 'package:lumochat/main.dart';

void main() {
  testWidgets('LumoChat app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LumoChatApp(isFirebaseInitialized: false));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Open App'), findsOneWidget);
  });
}
