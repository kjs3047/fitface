import 'dart:typed_data';

import 'package:fitface/data/local/local_file_storage.dart';
import 'package:fitface/data/repositories/snapshot_repository.dart';
import 'package:fitface/presentation/screens/compare/snapshot_detail_screen.dart';
import 'package:fitface/providers/storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('snapshot detail swipes and opens zoomable image on device', (
    tester,
  ) async {
    final storage = await LocalFileStorage.create();
    await storage.clearAll();
    final repository = SnapshotRepository(storage);

    for (var i = 0; i < 3; i++) {
      final image = img.Image(width: 120, height: 180);
      img.fill(image, color: img.ColorRgb8(130 + i * 25, 120, 180));
      final snapshot = await repository.createSnapshotFromBytes(
        Uint8List.fromList(img.encodePng(image)),
      );
      await repository.addSnapshot(snapshot.copyWith(memo: '후보 ${i + 1}'));
    }
    final snapshots = await repository.loadSnapshots();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localFileStorageProvider.overrideWithValue(storage)],
        child: MaterialApp(
          home: SnapshotDetailScreen(snapshotId: snapshots.first.id),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('1 / 3').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('1 / 3'), findsOneWidget);
    final memoField = tester.widget<TextField>(find.byType(TextField));
    expect(memoField.maxLines, 3);

    await tester.tap(
      find.byKey(const Key('snapshot-detail-image-open-button')).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('이미지 보기'), findsOneWidget);
    expect(find.byKey(const Key('snapshot-image-viewer')), findsOneWidget);

    Navigator.of(tester.element(find.text('이미지 보기'))).pop();
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('snapshot-detail-page-view')),
      const Offset(-500, 0),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('2 / 3').evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.text('2 / 3'), findsOneWidget);

    expect(find.text('AI 퍼스널 컬러 진단'), findsNothing);
  });
}
