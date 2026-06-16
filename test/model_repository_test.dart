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
import 'package:fitface/domain/profile/body_type.dart';
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

  test('saveBasicInfo creates a profile even without a registered face',
      () async {
    final repository = UserProfileRepository(storage);

    // 얼굴 등록 전(프로필 없음)에도 기본정보 저장 가능해야 한다.
    final saved = await repository.saveBasicInfo(
      gender: Gender.male,
      bodyType: BodyType.muscular,
      heightCm: 178,
      weightKg: 74,
    );
    expect(saved.gender, Gender.male);
    expect(saved.bodyType, BodyType.muscular);
    expect(saved.heightCm, 178);
    expect(saved.weightKg, 74);
    expect(saved.croppedFaceImagePath, isNull);

    final loaded = await repository.loadProfile();
    expect(loaded?.bodyType, BodyType.muscular);
    expect(loaded?.hasBodyInfo, isTrue);
  });

  test('saveBasicInfo preserves existing face/personal-color fields',
      () async {
    final repository = UserProfileRepository(storage);
    await repository.saveFace(
      originalFaceImagePath: 'o.jpg',
      croppedFaceImagePath: 'c.jpg',
      overlayFaceImagePath: 'v.png',
    );
    await repository.savePersonalColorType('가을 웜 뮤트');

    final updated = await repository.saveBasicInfo(
      gender: Gender.female,
      bodyType: BodyType.bottomHeavy,
    );
    expect(updated.croppedFaceImagePath, 'c.jpg');
    expect(updated.personalColorType, '가을 웜 뮤트');
    expect(updated.bodyType, BodyType.bottomHeavy);
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

  test('createSnapshotFromBytes stores a separate raw image when given',
      () async {
    final repository = SnapshotRepository(storage);
    final snapshot = await repository.createSnapshotFromBytes(
      Uint8List.fromList([1, 2, 3]),
      rawBytes: Uint8List.fromList([4, 5, 6]),
    );
    expect(snapshot.hasRawImage, isTrue);
    expect(snapshot.rawImagePath, isNot(snapshot.imagePath));
    // raw 없이 만들면 null.
    final noRaw =
        await repository.createSnapshotFromBytes(Uint8List.fromList([7]));
    expect(noRaw.hasRawImage, isFalse);
  });

  test('saveTryOnResult links image, body type, and bumps regen count',
      () async {
    final repository = SnapshotRepository(storage);
    final snapshot = await repository.createSnapshotFromBytes(
      Uint8List.fromList([1, 2, 3]),
      rawBytes: Uint8List.fromList([4, 5, 6]),
    );
    await repository.addSnapshot(snapshot);

    final first = await repository.saveTryOnResult(
      snapshotId: snapshot.id,
      imageBytes: Uint8List.fromList([10, 11, 12]),
      bodyType: 'normal',
    );
    expect(first.hasTryOnImage, isTrue);
    expect(first.tryOnBodyType, 'normal');
    expect(first.tryOnRegenCount, 1);

    final second = await repository.saveTryOnResult(
      snapshotId: snapshot.id,
      imageBytes: Uint8List.fromList([13, 14, 15]),
      bodyType: 'plus',
    );
    expect(second.tryOnRegenCount, 2);
    expect(second.tryOnBodyType, 'plus');
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

  test('AiAnalysisResult parses candidate result comments', () {
    final decoded = AiAnalysisResult.fromJson({
      'score': 88,
      'comment': '두 번째 후보가 가장 안정적입니다.',
      'bestSnapshotId': 'candidate_1',
      'candidateResults': [
        {
          'snapshotId': 'candidate_0',
          'score': 74,
          'comment': '밝기 균형은 좋지만 대비가 조금 약합니다.',
        },
        {
          'snapshotId': 'candidate_1',
          'score': 88,
          'comment': '퍼스널 컬러와 색감 대비가 가장 안정적입니다.',
        },
      ],
      'tags': <String>[],
      'strengths': <String>[],
      'concerns': <String>[],
      'suggestions': <String>[],
      'confidence': 0.81,
    });

    expect(decoded.candidateScores['candidate_0'], 74);
    expect(decoded.candidateScores['candidate_1'], 88);
    expect(
      decoded.candidateComments['candidate_0'],
      '밝기 균형은 좋지만 대비가 조금 약합니다.',
    );
    expect(
      decoded.candidateComments['candidate_1'],
      '퍼스널 컬러와 색감 대비가 가장 안정적입니다.',
    );
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
    await storage.metadataFile(StorageKeys.profileJson).writeAsString('broken');

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
