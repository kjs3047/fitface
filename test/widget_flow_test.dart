import 'dart:io';

import 'package:fitface/app.dart';
import 'package:fitface/data/local/local_file_storage.dart';
import 'package:fitface/data/models/ai_analysis_result.dart';
import 'package:fitface/data/models/image_feature_summary.dart';
import 'package:fitface/data/models/outfit_snapshot.dart';
import 'package:fitface/data/models/personal_color_result.dart';
import 'package:fitface/data/repositories/snapshot_repository.dart';
import 'package:fitface/data/repositories/user_profile_repository.dart';
import 'package:fitface/domain/services/ai_analysis_service.dart';
import 'package:fitface/domain/services/background_removal_service.dart';
import 'package:fitface/domain/services/face_image_quality_service.dart';
import 'package:fitface/presentation/screens/compare/compare_screen.dart';
import 'package:fitface/presentation/screens/compare/snapshot_image_viewer_screen.dart';
import 'package:fitface/presentation/screens/face_register/face_capture_screen.dart';
import 'package:fitface/presentation/screens/face_register/face_preview_screen.dart';
import 'package:fitface/presentation/screens/face_register/face_register_screen.dart';
import 'package:fitface/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:fitface/presentation/screens/settings/settings_screen.dart';
import 'package:fitface/presentation/routes/app_routes.dart';
import 'package:fitface/presentation/widgets/personal_color_result_card.dart';
import 'package:fitface/providers/repository_provider.dart';
import 'package:fitface/providers/service_provider.dart';
import 'package:fitface/providers/storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory tempRoot;
  late LocalFileStorage storage;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('fitface_widget_');
    storage = await LocalFileStorage.create(root: tempRoot);
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [localFileStorageProvider.overrideWithValue(storage)],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('Onboarding shows required copy and register button',
      (tester) async {
    await tester.pumpWidget(wrap(const OnboardingScreen()));

    expect(find.text('FitFace'), findsOneWidget);
    expect(find.text('내 얼굴 등록하기'), findsOneWidget);
    expect(find.textContaining('옷매장에서 실제 옷을 비추고'), findsOneWidget);
  });

  testWidgets('FaceRegister shows gallery, camera, and guide copy',
      (tester) async {
    await tester.pumpWidget(wrap(const FaceRegisterScreen()));

    expect(find.text('갤러리에서 선택'), findsOneWidget);
    expect(find.text('카메라로 촬영'), findsOneWidget);
    expect(find.textContaining('정면을 바라본 사진'), findsOneWidget);
    expect(find.textContaining('실루엣 선'), findsOneWidget);
  });

  testWidgets('FaceRegister shows current registered face image', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await UserProfileRepository(storage).saveFace(
        originalFaceImagePath: 'missing_current_face.jpg',
        croppedFaceImagePath: 'missing_current_face.jpg',
        overlayFaceImagePath: 'missing_current_face.jpg',
      );
    });

    await tester.pumpWidget(wrap(const FaceRegisterScreen()));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('현재 등록된 얼굴').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('현재 등록된 얼굴'), findsOneWidget);
    expect(
      find.byKey(const Key('face-register-current-face-image')),
      findsOneWidget,
    );
    final currentImage = tester.widget<Image>(
      find.byKey(const Key('face-register-current-face-image')),
    );
    expect(currentImage.fit, BoxFit.contain);
  });

  testWidgets('FaceCapture shows the same silhouette guide', (tester) async {
    await tester.pumpWidget(wrap(const FaceCaptureScreen()));

    expect(find.text('얼굴 촬영'), findsOneWidget);
    expect(find.byKey(const Key('face-capture-cutout-guide')), findsOneWidget);
    expect(find.textContaining('실루엣 선'), findsOneWidget);
  });

  testWidgets('FacePreview shows face image quality guidance', (tester) async {
    final sourceFile = File('${tempRoot.path}/face.png');
    await tester.runAsync(() async {
      final source = img.Image(width: 80, height: 112);
      img.fill(source, color: img.ColorRgb8(34, 34, 38));
      await sourceFile.writeAsBytes(img.encodePng(source), flush: true);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localFileStorageProvider.overrideWithValue(storage),
          backgroundRemovalServiceProvider.overrideWithValue(
            const _ImmediateBackgroundRemovalService(),
          ),
          faceImageQualityServiceProvider.overrideWithValue(
            const _WarningFaceImageQualityService(),
          ),
        ],
        child: MaterialApp(
          home: FacePreviewScreen(
            args: FacePreviewArgs(
              originalImagePath: sourceFile.path,
              croppedImagePath: sourceFile.path,
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.text('사진 품질 참고'), findsOneWidget);
    expect(find.textContaining('어두'), findsWidgets);
  });

  testWidgets('Compare screen shows three empty slots', (tester) async {
    await tester.pumpWidget(wrap(const CompareScreen()));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('비어 있음').evaluate().length == 3) {
        break;
      }
    }

    expect(find.text('비어 있음'), findsNWidgets(3));
    expect(find.text('AI에게 3개 비교 요청'), findsOneWidget);
  });

  testWidgets('Compare screen marks AI best candidate and scores every option',
      (
    tester,
  ) async {
    final snapshots = [
      for (var index = 0; index < 3; index++)
        OutfitSnapshot(
          id: 'candidate_$index',
          imagePath: 'missing_candidate_$index.png',
          createdAt: DateTime(2026, 5, 19, 12, index),
          memo: '후보 ${index + 1} 메모',
        ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localFileStorageProvider.overrideWithValue(storage),
          snapshotRepositoryProvider.overrideWithValue(
            _MemorySnapshotRepository(storage, snapshots),
          ),
          aiAnalysisServiceProvider.overrideWithValue(
            _BestSecondCandidateAiService(bestSnapshotId: snapshots[1].id),
          ),
        ],
        child: const MaterialApp(home: CompareScreen()),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('AI에게 3개 비교 요청').evaluate().isNotEmpty) {
        break;
      }
    }

    await tester.tap(find.text('AI에게 3개 비교 요청'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const Key('compare-best-thumbnail-border')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('compare-best-badge')), findsOneWidget);
    expect(find.text('★ BEST'), findsOneWidget);
    expect(find.byKey(const Key('compare-best-score')), findsOneWidget);
    expect(find.text('87/100'), findsOneWidget);
    expect(
      find.byKey(const Key('compare-candidate-score-candidate_0')),
      findsOneWidget,
    );
    expect(find.text('74/100'), findsOneWidget);
    expect(find.textContaining('색 조화'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pump();

    expect(
      find.byKey(const Key('compare-candidate-score-candidate_2')),
      findsOneWidget,
    );
    expect(find.text('69/100'), findsOneWidget);
  });

  testWidgets('SnapshotImageViewer supports pinch zoom', (tester) async {
    await tester.pumpWidget(
      wrap(const SnapshotImageViewerScreen(imagePath: 'missing.png')),
    );

    final viewer = tester.widget<InteractiveViewer>(
      find.byKey(const Key('snapshot-image-viewer')),
    );

    expect(find.text('이미지 보기'), findsOneWidget);
    expect(viewer.minScale, 1);
    expect(viewer.maxScale, 5);
  });

  testWidgets('PersonalColorResultCard shows treemap and palette hex codes', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const PersonalColorResultCard(
          result: PersonalColorResult(
            type: '여름 쿨',
            recommendedColors: ['라벤더', '소프트 블루', '로즈 핑크', '민트', '화이트'],
            avoidColors: ['오렌지', '브라운', '옐로', '레드', '블랙'],
            comment: '테스트 결과',
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('personal-color-signature-tile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('personal-color-treemap-tile-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('personal-color-treemap-tile-3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('personal-color-palette-recommended')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('personal-color-palette-avoid')),
      findsOneWidget,
    );
    expect(find.text('시그니처'), findsOneWidget);
    expect(find.text('추천 컬러'), findsOneWidget);
    expect(find.text('주의 색상'), findsOneWidget);
    expect(find.text('라벤더'), findsWidgets);
    expect(find.text('#B8A9E6'), findsWidgets);
    expect(find.text('소프트 블루'), findsWidgets);
    expect(find.text('#9DB7D5'), findsWidgets);
    expect(find.text('오렌지'), findsOneWidget);
    expect(find.text('#F26A21'), findsOneWidget);
    expect(
      find.byKey(
        const Key('personal-color-palette-code-recommended-화이트'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('personal-color-palette-code-avoid-블랙')),
      findsOneWidget,
    );
  });

  testWidgets('PersonalColorResultCard handles large text without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(1.45),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: PersonalColorResultCard(
                  result: PersonalColorResult(
                    type: '뉴트럴-딥(소프트)',
                    recommendedColors: [
                      '네이비',
                      '차콜 그레이',
                      '딥 틸',
                      '웜 그레이시 베이지',
                      '버건디',
                    ],
                    avoidColors: [
                      '형광 노랑',
                      '선명한 오렌지',
                      '과한 베이지',
                      '탁한 갈색',
                      '연한 파스텔 핑크',
                    ],
                    comment: '테스트 결과',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('personal-color-treemap-tile-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('personal-color-treemap-tile-3')),
      findsOneWidget,
    );
  });

  testWidgets('Settings screen exposes privacy and reset actions',
      (tester) async {
    await tester.pumpWidget(wrap(const SettingsScreen()));

    expect(find.text('얼굴 사진 변경'), findsOneWidget);
    expect(find.text('저장된 후보 전체 삭제'), findsOneWidget);
    expect(find.text('앱 데이터 초기화'), findsOneWidget);
    expect(find.text('연결 테스트'), findsOneWidget);
    expect(find.text('모델 파일 가져오기'), findsOneWidget);
    expect(find.textContaining('기기 내부에만 저장'), findsOneWidget);
  });

  testWidgets('FitFaceApp starts at splash', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localFileStorageProvider.overrideWithValue(storage)],
        child: const FitFaceApp(),
      ),
    );

    expect(find.text('FitFace'), findsOneWidget);
  });
}

class _BestSecondCandidateAiService implements AiAnalysisService {
  const _BestSecondCandidateAiService({required this.bestSnapshotId});

  final String bestSnapshotId;

  @override
  Future<AiAnalysisResult> analyzeSnapshot(OutfitSnapshot snapshot) async {
    return const AiAnalysisResult(
      score: 77,
      comment: '단일 후보 판단 결과입니다.',
    );
  }

  @override
  Future<AiAnalysisResult> compareSnapshots(
    List<OutfitSnapshot> snapshots,
  ) async {
    return AiAnalysisResult(
      score: 87,
      bestSnapshotId: bestSnapshotId,
      candidateScores: const {
        'candidate_0': 74,
        'candidate_1': 87,
        'candidate_2': 69,
      },
      comment: '두 번째 후보가 가장 안정적으로 어울리고 색 조화 기준에서도 우세합니다.',
    );
  }
}

class _ImmediateBackgroundRemovalService implements BackgroundRemovalService {
  const _ImmediateBackgroundRemovalService();

  @override
  Future<String> removeBackground(String inputImagePath) async {
    return inputImagePath;
  }
}

class _WarningFaceImageQualityService extends FaceImageQualityService {
  const _WarningFaceImageQualityService();

  @override
  Future<FaceImageQualityResult> evaluate(String imagePath) async {
    return const FaceImageQualityResult(
      status: FaceImageQualityStatus.warning,
      summary: '사진은 사용할 수 있습니다.',
      hints: ['얼굴 이미지가 어두워 AI 분석 신뢰도가 낮아질 수 있습니다.'],
      features: ImageFeatureSummary(
        averageHex: '#222226',
        dominantColors: [ColorSwatchSummary(hex: '#303030', ratio: 1)],
        brightness: 0.12,
        contrast: 0.02,
        saturation: 0.04,
        warmCoolBias: -0.02,
      ),
    );
  }
}

class _MemorySnapshotRepository extends SnapshotRepository {
  _MemorySnapshotRepository(super.storage, this._snapshots);

  final List<OutfitSnapshot> _snapshots;

  @override
  Future<List<OutfitSnapshot>> loadSnapshots() async {
    return _snapshots;
  }

  @override
  Future<void> deleteSnapshot(String snapshotId) async {
    _snapshots.removeWhere((snapshot) => snapshot.id == snapshotId);
  }
}
