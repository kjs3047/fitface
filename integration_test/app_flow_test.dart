import 'package:fitface/main.dart' as app;
import 'package:fitface/data/local/local_file_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch reaches onboarding when no face is registered', (
    tester,
  ) async {
    final storage = await LocalFileStorage.create();
    await storage.clearAll();

    await app.main();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('내 얼굴 등록하기').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('내 얼굴 등록하기'), findsOneWidget);
    expect(find.textContaining('옷매장에서 실제 옷을 비추고'), findsOneWidget);
  });
}
