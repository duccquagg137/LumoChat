import 'package:flutter_test/flutter_test.dart';
import 'package:lumochat/main.dart';

void main() {
  testWidgets('LumoChat app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LumoChatApp(isFirebaseInitialized: false));
    expect(find.text('LumoChat'), findsOneWidget);
  });
}
