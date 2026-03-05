import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:remembite/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Smoke tests', () {
    // NOTE: This test requires a real device or emulator with google-services.json
    // (or GoogleService-Info.plist on iOS). Firebase.initializeApp() inside app.main()
    // will throw in environments without Firebase test configuration.
    // Run with: flutter test integration_test/app_test.dart -d <device-id>
    testWidgets('App launches and shows sign-in screen when not authenticated',
        (tester) async {
      // Use runAsync to properly await app.main(), which contains async
      // Firebase.initializeApp() and other async setup.
      await tester.runAsync(() async => app.main());
      await tester.pump(const Duration(seconds: 5));

      // The app should render a ProviderScope (root widget wrapping MaterialApp.router)
      expect(find.byType(ProviderScope), findsOneWidget);

      // Unauthenticated cold start should show the sign-in screen
      expect(find.textContaining('Continue with Google'), findsAtLeast(1));
    });
  });
}
