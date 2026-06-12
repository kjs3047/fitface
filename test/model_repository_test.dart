import 'dart:io';
import 'dart:typed_data';

import 'package:fitface/core/constants/storage_keys.dart';
import 'package:fitface/core/errors/app_exception.dart';
import 'package:fitface/data/local/local_file_storage.dart';
import 'package:fitface/data/models/ai_settings.dart';
import 'package:fitface/data/models/ai_analysis_result.dart';
import 'package:fitface/data/repositories/ai_settings_repository.dart';
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
      candidateComments: {
        'candidate_1': '가장 안정적인 후보입니다.',
      },
      tags: ['쿨톤추천', '밝은색감'],
      strengths: ['얼굴 주변 밝기가 안정적입니다.'],
      concerns: ['매장 조명에 따라 달라질 수 있습니다.'],
      suggestions: ['소프트 블루 계열을 우선 보세요.'],
      confidence: 0.82,
      engine: 'localGemma',
      analysisMode: 'imageAndFeatures',
      comment: '후보별 점수 테스트',
    );

    final decoded = AiAnalysisResult.fromJson(result.toJson());

    expect(decoded.score, 91);
    expect(decoded.bestSnapshotId, 'candidate_1');
    expect(decoded.candidateScores['candidate_0'], 78);
    expect(decoded.candidateScores['candidate_1'], 91);
    expect(decoded.candidateScores['candidate_2'], 72);
    expect(decoded.candidateComments['candidate_1'], '가장 안정적인 후보입니다.');
    expect(decoded.tags, contains('쿨톤추천'));
    expect(decoded.strengths, isNotEmpty);
    expect(decoded.concerns, isNotEmpty);
    expect(decoded.suggestions, isNotEmpty);
    expect(decoded.confidence, 0.82);
    expect(decoded.engine, 'localGemma');
    expect(decoded.analysisMode, 'imageAndFeatures');
  });

  test('AiSettingsRepository persists engine and proxy settings', () async {
    final repository = AiSettingsRepository(storage);

    final saved = await repository.saveSettings(
      AiSettings.defaults().copyWith(
        mode: AiEngineMode.openAi,
        allowCloudAnalysis: true,
        openAiProxyUrl: 'https://example.com',
      ),
    );

    final loaded = await repository.loadSettings();
    expect(saved.mode, AiEngineMode.openAi);
    expect(loaded.mode, AiEngineMode.openAi);
    expect(loaded.allowCloudAnalysis, isTrue);
    expect(loaded.openAiProxyUrl, 'https://example.com');

    await repository.clearSettings();
    expect((await repository.loadSettings()).mode, AiEngineMode.mock);
  });

  test('LocalFileStorage falls back when metadata is corrupted', () async {
    // 쓰기 도중 크래시로 손상된 JSON을 흉내 낸다.
    await storage.metadataFile(StorageKeys.snapshotsJson).writeAsString(
          '{ this is not valid json',
        );
    await storage
        .metadataFile(StorageKeys.profileJson)
        .writeAsString('broken');

    expect(await storage.readJsonList(StorageKeys.snapshotsJson), isEmpty);
    expect(await storage.readJsonMap(StorageKeys.profileJson), isNull);

    // 폴백 후에도 정상 쓰기/읽기가 이어진다.
    await storage.writeJsonList(StorageKeys.snapshotsJson, [
      {'id': 'a'},
    ]);
    final reloaded = await storage.readJsonList(StorageKeys.snapshotsJson);
    expect(reloaded, hasLength(1));
    expect((reloaded.first as Map)['id'], 'a');
  });

  test('LocalFileStorage write leaves no leftover temp file', () async {
    await storage.writeJsonMap(StorageKeys.profileJson, {'id': 'x'});
    final tempFile = File(
      '${storage.metadataFile(StorageKeys.profileJson).path}.tmp',
    );
    expect(await tempFile.exists(), isFalse);
    expect(
      (await storage.readJsonMap(StorageKeys.profileJson))?['id'],
      'x',
    );
  });
}
