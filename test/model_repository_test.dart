import 'dart:io';
import 'dart:typed_data';

import 'package:fitface/core/errors/app_exception.dart';
import 'package:fitface/data/local/local_file_storage.dart';
import 'package:fitface/data/models/ai_analysis_result.dart';
import 'package:fitface/data/repositories/snapshot_repository.dart';
import 'package:fitface/data/repositories/user_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempRoot;
  late LocalFileStorage storage;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('fitface_test_');
    storage = await LocalFileStorage.create(root: tempRoot);
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('UserProfileRepository saves, loads, and clears profile', () async {
    final repository = UserProfileRepository(storage);

    final saved = await repository.saveFace(
      originalFaceImagePath: 'original.jpg',
      croppedFaceImagePath: 'cropped.jpg',
      overlayFaceImagePath: 'overlay.png',
    );

    final loaded = await repository.loadProfile();
    expect(loaded?.id, saved.id);
    expect(loaded?.croppedFaceImagePath, 'cropped.jpg');
    expect(loaded?.overlayFaceImagePath, 'overlay.png');

    final updated = await repository.savePersonalColorType('여름 쿨');
    expect(updated.personalColorType, '여름 쿨');
    expect((await repository.loadProfile())?.personalColorType, '여름 쿨');

    await repository.clearProfile(deleteImages: false);
    expect(await repository.loadProfile(), isNull);
  });

  test('SnapshotRepository keeps max 3 and supports replacement', () async {
    final repository = SnapshotRepository(storage);

    for (var i = 0; i < 3; i++) {
      final snapshot = await repository.createSnapshotFromBytes(
        Uint8List.fromList([i, i + 1, i + 2]),
      );
      await repository.addSnapshot(snapshot);
    }

    expect((await repository.loadSnapshots()).length, 3);

    final fourth = await repository.createSnapshotFromBytes(
      Uint8List.fromList([9, 9, 9]),
    );
    expect(
      () => repository.addSnapshot(fourth),
      throwsA(isA<SnapshotLimitException>()),
    );

    await repository.replaceSnapshot(1, fourth);
    final snapshots = await repository.loadSnapshots();
    expect(snapshots.length, 3);
    expect(snapshots[1].id, fourth.id);
  });

  test('AiAnalysisResult keeps candidate scores in json', () {
    const result = AiAnalysisResult(
      score: 91,
      bestSnapshotId: 'candidate_1',
      candidateScores: {
        'candidate_0': 78,
        'candidate_1': 91,
        'candidate_2': 72,
      },
      comment: '후보별 점수 테스트',
    );

    final decoded = AiAnalysisResult.fromJson(result.toJson());

    expect(decoded.score, 91);
    expect(decoded.bestSnapshotId, 'candidate_1');
    expect(decoded.candidateScores['candidate_0'], 78);
    expect(decoded.candidateScores['candidate_1'], 91);
    expect(decoded.candidateScores['candidate_2'], 72);
  });
}
