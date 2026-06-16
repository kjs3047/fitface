import 'dart:async';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:fitface/app.dart';
import 'package:fitface/data/local/local_file_storage.dart';
import 'package:fitface/data/models/ai_analysis_result.dart';
import 'package:fitface/data/models/ai_settings.dart';
import 'package:fitface/data/models/image_feature_summary.dart';
import 'package:fitface/data/models/outfit_snapshot.dart';
import 'package:fitface/data/models/personal_color_result.dart';
import 'package:fitface/data/repositories/ai_settings_repository.dart';
import 'package:fitface/data/repositories/snapshot_repository.dart';
import 'package:fitface/data/repositories/user_profile_repository.dart';
import 'package:fitface/domain/services/ai_analysis_service.dart';
import 'package:fitface/domain/services/background_removal_service.dart';
import 'package:fitface/domain/services/face_image_quality_service.dart';
import 'package:fitface/domain/services/local_gemma_chat_service.dart';
import 'package:fitface/domain/services/open_ai_proxy_health_service.dart';
import 'package:fitface/presentation/screens/ai_chat/local_gemma_chat_screen.dart';
import 'package:fitface/presentation/screens/camera_match/camera_match_screen.dart';
import 'package:fitface/presentation/screens/compare/compare_screen.dart';
import 'package:fitface/presentation/screens/compare/snapshot_image_viewer_screen.dart';
import 'package:fitface/presentation/screens/face_register/face_capture_screen.dart';
import 'package:fitface/presentation/screens/face_register/face_preview_screen.dart';
import 'package:fitface/presentation/screens/face_register/face_register_screen.dart';
import 'package:fitface/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:fitface/presentation/screens/settings/settings_screen.dart';
import 'package:fitface/presentation/routes/app_routes.dart';
import 'package:fitface/presentation/routes/route_names.dart';
import 'package:fitface/presentation/widgets/ai_processing_status.dart';
import 'package:fitface/presentation/widgets/personal_color_result_card.dart';
import 'package:fitface/providers/repository_provider.dart';
import 'package:fitface/providers/service_provider.dart';
import 'package:fitface/providers/storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

void main() {
  late Directory tempRoot;
  late LocalFileStorage storage;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('fitface_widget_');
    storage = await LocalFileStorage.create(root: tempRoot);
  });

  tearDown(() async {
    imageCache.clear();
    imageCache.clearLiveImages();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Widget wrap(
    Widget child, {
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        localFileStorageProvider.overrideWithValue(storage),
        ...overrides,
      ],
      child: MaterialApp(home: child),
    );
  }

  void useTallTestView(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  AiSettings readyLocalGemmaSettings() {
    return AiSettings.defaults().copyWith(
      mode: AiEngineMode.localGemma,
      localModelPath: '/models/gemma-4-E4B-it.litertlm',
      localModelName: 'gemma-4-E4B-it.litertlm',
    );
  }

  AiSettings localGemmaModeSettings() {
    return AiSettings.defaults().copyWith(mode: AiEngineMode.localGemma);
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

  testWidgets(
    'FaceCapture requests permission before opening the first camera',
    (tester) async {
      final originalCamera = CameraPlatform.instance;
      final originalPermission = PermissionHandlerPlatform.instance;
      final permission = _GrantingPermissionHandler();
      final camera = _FaceCaptureCameraPlatform(
        canUseCamera: () => permission.requestedPermissions.isNotEmpty,
      );
      CameraPlatform.instance = camera;
      PermissionHandlerPlatform.instance = permission;

      try {
        await tester.pumpWidget(wrap(const FaceCaptureScreen()));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (find.text('촬영하기').evaluate().isNotEmpty &&
              find.widgetWithText(FilledButton, '촬영하기').evaluate().isNotEmpty) {
            final button = tester.widget<FilledButton>(
              find.widgetWithText(FilledButton, '촬영하기'),
            );
            if (button.onPressed != null) {
              break;
            }
          }
        }

        expect(permission.requestedPermissions, contains(Permission.camera));
        expect(camera.availableCameraCalls, 1);
        expect(camera.createdCameraCount, 1);
        expect(find.textContaining('카메라를 사용할 수 없습니다'), findsNothing);
        final captureButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, '촬영하기'),
        );
        expect(captureButton.onPressed, isNotNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        CameraPlatform.instance = originalCamera;
        PermissionHandlerPlatform.instance = originalPermission;
      }
    },
  );

  testWidgets('FaceCapture releases its camera before opening crop', (
    tester,
  ) async {
    useTallTestView(tester);
    final originalCamera = CameraPlatform.instance;
    final originalPermission = PermissionHandlerPlatform.instance;
    final permission = _GrantingPermissionHandler();
    final camera = _FaceCaptureCameraPlatform(
      canUseCamera: () => permission.requestedPermissions.isNotEmpty,
    );
    CameraPlatform.instance = camera;
    PermissionHandlerPlatform.instance = permission;

    final rawCapture = File('${tempRoot.path}/raw_capture.jpg');
    await tester.runAsync(() async {
      final image = img.Image(width: 24, height: 24);
      img.fill(image, color: img.ColorRgb8(96, 96, 96));
      await rawCapture.writeAsBytes(img.encodeJpg(image), flush: true);
    });
    camera.nextPicturePath = rawCapture.path;

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [localFileStorageProvider.overrideWithValue(storage)],
          child: MaterialApp(
            onGenerateRoute: (settings) {
              if (settings.name == RouteNames.faceCrop) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const Scaffold(body: Text('crop stub')),
                );
              }
              return AppRoutes.onGenerateRoute(settings);
            },
            home: const FaceCaptureScreen(),
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.widgetWithText(FilledButton, '촬영하기').evaluate().isEmpty) {
          continue;
        }
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, '촬영하기'),
        );
        if (button.onPressed != null) {
          break;
        }
      }

      final captureButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '촬영하기'),
      );
      expect(captureButton.onPressed, isNotNull);

      await tester.ensureVisible(find.widgetWithText(FilledButton, '촬영하기'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '촬영하기'));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump(const Duration(milliseconds: 100));
        if (camera.disposedCameraIds.contains(1)) {
          break;
        }
      }

      expect(camera.disposedCameraIds, contains(1));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      imageCache.clear();
      imageCache.clearLiveImages();
      CameraPlatform.instance = originalCamera;
      PermissionHandlerPlatform.instance = originalPermission;
    }
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

  testWidgets('Compare screen blocks candidate actions while AI is comparing', (
    tester,
  ) async {
    final snapshots = [
      for (var index = 0; index < 3; index++)
        OutfitSnapshot(
          id: 'locked_candidate_$index',
          imagePath: 'missing_locked_candidate_$index.png',
          createdAt: DateTime(2026, 5, 19, 13, index),
          memo: '비교 중 후보 ${index + 1}',
        ),
    ];
    final aiService = _PendingCompareAiService();
    addTearDown(aiService.complete);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localFileStorageProvider.overrideWithValue(storage),
          snapshotRepositoryProvider.overrideWithValue(
            _MemorySnapshotRepository(storage, snapshots),
          ),
          aiAnalysisServiceProvider.overrideWithValue(aiService),
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

    expect(find.text('비교 중...'), findsOneWidget);

    await tester.tap(find.text('비교 중 후보 1'));
    await tester.pump();

    expect(find.text('AI 비교가 끝난 뒤 후보를 열 수 있습니다.'), findsOneWidget);
    expect(find.text('후보 상세'), findsNothing);

    await tester.tap(find.byTooltip('후보 삭제').first);
    await tester.pump();

    expect(find.text('후보 삭제'), findsNothing);
    expect(find.text('AI 비교가 끝난 뒤 후보를 열 수 있습니다.'), findsOneWidget);

    await tester.tap(find.byTooltip('카메라'));
    await tester.pump();

    expect(find.text('비교 중 이동'), findsOneWidget);
    expect(find.textContaining('진행 중인 결과를 받을 수 없습니다'), findsOneWidget);

    await tester.tap(find.text('계속 기다리기'));
    await tester.pump();

    expect(find.text('비교 중...'), findsOneWidget);
  });

  testWidgets('CameraMatch releases its camera when settings opens', (
    tester,
  ) async {
    final originalCamera = CameraPlatform.instance;
    final originalPermission = PermissionHandlerPlatform.instance;
    final permission = _GrantingPermissionHandler();
    final camera = _FaceCaptureCameraPlatform(
      canUseCamera: () => permission.requestedPermissions.isNotEmpty,
    );
    CameraPlatform.instance = camera;
    PermissionHandlerPlatform.instance = permission;

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [localFileStorageProvider.overrideWithValue(storage)],
          child: MaterialApp(
            navigatorObservers: [AppRoutes.routeObserver],
            onGenerateRoute: AppRoutes.onGenerateRoute,
            home: const CameraMatchScreen(),
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byTooltip('설정').evaluate().isNotEmpty &&
            camera.createdCameraCount > 0) {
          break;
        }
      }

      expect(camera.createdCameraCount, 1);

      final cameraMatchContext = tester.element(find.byType(CameraMatchScreen));
      Navigator.of(cameraMatchContext).pushNamed(RouteNames.settings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(camera.disposedCameraIds, contains(1));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      imageCache.clear();
      imageCache.clearLiveImages();
      CameraPlatform.instance = originalCamera;
      PermissionHandlerPlatform.instance = originalPermission;
    }
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
            recommendedColors: [
              PersonalColorSwatch(name: '라벤더'),
              PersonalColorSwatch(name: '소프트 블루'),
              PersonalColorSwatch(name: '로즈 핑크'),
              PersonalColorSwatch(name: '민트'),
              PersonalColorSwatch(name: '화이트'),
            ],
            avoidColors: [
              PersonalColorSwatch(name: '오렌지'),
              PersonalColorSwatch(name: '브라운'),
              PersonalColorSwatch(name: '옐로'),
              PersonalColorSwatch(name: '레드'),
              PersonalColorSwatch(name: '블랙'),
            ],
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
                      PersonalColorSwatch(name: '네이비'),
                      PersonalColorSwatch(name: '차콜 그레이'),
                      PersonalColorSwatch(name: '딥 틸'),
                      PersonalColorSwatch(name: '웜 그레이시 베이지'),
                      PersonalColorSwatch(name: '버건디'),
                    ],
                    avoidColors: [
                      PersonalColorSwatch(name: '형광 노랑'),
                      PersonalColorSwatch(name: '선명한 오렌지'),
                      PersonalColorSwatch(name: '과한 베이지'),
                      PersonalColorSwatch(name: '탁한 갈색'),
                      PersonalColorSwatch(name: '연한 파스텔 핑크'),
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

  testWidgets('Settings shows Local Gemma chatbot only in Local Gemma mode',
      (tester) async {
    useTallTestView(tester);
    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('AI 챗봇'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      wrap(
        const SettingsScreen(),
        overrides: [
          aiSettingsRepositoryProvider.overrideWithValue(
            _StaticAiSettingsRepository(
              storage,
              localGemmaModeSettings(),
            ),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('AI 챗봇'), findsOneWidget);
    expect(find.text('모델 파일 가져오기 후 사용 가능'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      wrap(
        const SettingsScreen(),
        overrides: [
          aiSettingsRepositoryProvider.overrideWithValue(
            _StaticAiSettingsRepository(
              storage,
              readyLocalGemmaSettings(),
            ),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('AI 챗봇'), findsOneWidget);
    expect(find.text('Local Gemma로 기기 안에서 대화'), findsOneWidget);
  });

  testWidgets('Local Gemma chat sends text and renders response',
      (tester) async {
    final chatService = _FakeLocalGemmaChatService(
      responseText: '차분한 딥 그린이나 차콜 재킷이 안정적으로 어울립니다.',
    );

    await tester.pumpWidget(
      wrap(
        const LocalGemmaChatScreen(),
        overrides: [
          aiSettingsRepositoryProvider.overrideWithValue(
            _StaticAiSettingsRepository(
              storage,
              readyLocalGemmaSettings(),
            ),
          ),
          localGemmaChatServiceProvider.overrideWithValue(chatService),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const Key('local-gemma-chat-input')),
      '가을 재킷 색상 추천해줘',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('local-gemma-chat-send-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('가을 재킷 색상 추천해줘'), findsOneWidget);
    expect(
      find.text('차분한 딥 그린이나 차콜 재킷이 안정적으로 어울립니다.'),
      findsOneWidget,
    );
    expect(chatService.lastRequest?.message, '가을 재킷 색상 추천해줘');
    expect(chatService.lastRequest?.imagePath, isNull);
  });

  testWidgets('OpenAI proxy dialog includes connection test action',
      (tester) async {
    final healthService = _SuccessOpenAiProxyHealthService();

    useTallTestView(tester);
    await tester.pumpWidget(
      wrap(
        const SettingsScreen(),
        overrides: [
          openAiProxyHealthServiceProvider.overrideWithValue(healthService),
        ],
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('OpenAI 프록시 주소'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('OpenAI 프록시 주소'), findsWidgets);
    expect(
      find.byKey(const Key('ai-settings-openai-proxy-url-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('ai-settings-openai-proxy-test-button')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('ai-settings-openai-proxy-url-field')),
      'http://127.0.0.1:8787',
    );
    await tester
        .tap(find.byKey(const Key('ai-settings-openai-proxy-test-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('OpenAI 프록시 연결이 확인되었습니다.'), findsOneWidget);
    expect(healthService.checkedUrl, 'http://127.0.0.1:8787');
  });

  testWidgets('Local Gemma status guides import instead of manual path input',
      (tester) async {
    useTallTestView(tester);
    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Local Gemma 상태'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Local Gemma 모델'), findsOneWidget);
    expect(find.text('권장 모델 파일'), findsOneWidget);
    expect(find.text('gemma-4-E4B-it.litertlm'), findsOneWidget);
    expect(
      find.textContaining('huggingface.co/litert-community'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, '모델 파일 가져오기'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('AI processing status explains slow Local Gemma work',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiProcessingStatus(
            keyPrefix: 'test-ai',
            mode: AiEngineMode.localGemma,
            label: '후보 비교 중',
            localMessage: 'Local Gemma가 후보 3개의 이미지와 색상 정보를 비교하고 있습니다.',
            cloudMessage: 'OpenAI 프록시 서버로 후보 비교 요청을 보내고 있습니다.',
          ),
        ),
      ),
    );

    expect(find.textContaining('후보 비교 중'), findsOneWidget);
    expect(find.textContaining('Local Gemma가 후보 3개'), findsOneWidget);

    await tester.pump(const Duration(seconds: 11));

    expect(find.textContaining('기기에서 직접 분석 중'), findsOneWidget);
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

class _PendingCompareAiService implements AiAnalysisService {
  final Completer<AiAnalysisResult> _compareCompleter =
      Completer<AiAnalysisResult>();

  void complete() {
    if (!_compareCompleter.isCompleted) {
      _compareCompleter.complete(
        const AiAnalysisResult(
          score: 80,
          comment: '비교 완료',
        ),
      );
    }
  }

  @override
  Future<AiAnalysisResult> analyzeSnapshot(OutfitSnapshot snapshot) async {
    return const AiAnalysisResult(score: 70, comment: '후보 분석');
  }

  @override
  Future<AiAnalysisResult> compareSnapshots(
    List<OutfitSnapshot> snapshots,
  ) {
    return _compareCompleter.future;
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

class _GrantingPermissionHandler extends PermissionHandlerPlatform {
  final requestedPermissions = <Permission>[];

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async {
    return PermissionStatus.granted;
  }

  @override
  Future<ServiceStatus> checkServiceStatus(Permission permission) async {
    return ServiceStatus.enabled;
  }

  @override
  Future<bool> openAppSettings() async {
    return true;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    requestedPermissions.addAll(permissions);
    return {
      for (final permission in permissions)
        permission: PermissionStatus.granted,
    };
  }

  @override
  Future<bool> shouldShowRequestPermissionRationale(
    Permission permission,
  ) async {
    return false;
  }
}

class _FaceCaptureCameraPlatform extends CameraPlatform {
  _FaceCaptureCameraPlatform({required this.canUseCamera});

  final bool Function() canUseCamera;
  final _initializedControllers =
      <int, StreamController<CameraInitializedEvent>>{};
  final _errorControllers = <int, StreamController<CameraErrorEvent>>{};
  final disposedCameraIds = <int>[];
  String? nextPicturePath;
  int availableCameraCalls = 0;
  int createdCameraCount = 0;

  @override
  Future<List<CameraDescription>> availableCameras() async {
    availableCameraCalls++;
    if (!canUseCamera()) {
      throw StateError('camera permission was not requested first');
    }
    return const [
      CameraDescription(
        name: 'front',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 90,
      ),
    ];
  }

  @override
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) async {
    createdCameraCount++;
    final cameraId = createdCameraCount;
    _initializedControllers[cameraId] =
        StreamController<CameraInitializedEvent>.broadcast();
    _errorControllers[cameraId] =
        StreamController<CameraErrorEvent>.broadcast();
    return cameraId;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    await Future<void>.delayed(Duration.zero);
    _initializedControllers[cameraId]?.add(
      const CameraInitializedEvent(
        1,
        720,
        1280,
        ExposureMode.auto,
        true,
        FocusMode.auto,
        true,
      ),
    );
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) {
    return _initializedControllers[cameraId]!.stream;
  }

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) {
    return _errorControllers[cameraId]!.stream;
  }

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() {
    return const Stream<DeviceOrientationChangedEvent>.empty();
  }

  @override
  Widget buildPreview(int cameraId) {
    return const ColoredBox(color: Colors.black);
  }

  @override
  Future<XFile> takePicture(int cameraId) async {
    final path = nextPicturePath;
    if (path == null) {
      throw StateError('nextPicturePath was not configured');
    }
    return XFile(path);
  }

  @override
  Future<void> dispose(int cameraId) async {
    disposedCameraIds.add(cameraId);
    await _initializedControllers.remove(cameraId)?.close();
    _errorControllers.remove(cameraId);
  }
}

class _StaticAiSettingsRepository extends AiSettingsRepository {
  _StaticAiSettingsRepository(super.storage, this.settings);

  final AiSettings settings;

  @override
  Future<AiSettings> loadSettings() async {
    return settings;
  }

  @override
  Future<AiSettings> saveSettings(AiSettings settings) async {
    return settings;
  }
}

class _FakeLocalGemmaChatService extends LocalGemmaChatService {
  _FakeLocalGemmaChatService({required this.responseText})
      : super(
          settings: AiSettings.defaults().copyWith(
            mode: AiEngineMode.localGemma,
            localModelPath: '/models/gemma-4-E4B-it.litertlm',
          ),
        );

  final String responseText;
  LocalGemmaChatRequest? lastRequest;
  bool closed = false;

  @override
  Future<LocalGemmaChatResponse> send(LocalGemmaChatRequest request) async {
    lastRequest = request;
    return LocalGemmaChatResponse(
      text: responseText,
      usedImage: request.imagePath != null,
      createdAt: DateTime(2026),
    );
  }

  @override
  Future<void> closeSession() async {
    closed = true;
  }
}

class _SuccessOpenAiProxyHealthService extends OpenAiProxyHealthService {
  String? checkedUrl;

  @override
  Future<OpenAiProxyHealthCheck> check(String proxyUrl) async {
    checkedUrl = proxyUrl;
    return OpenAiProxyHealthCheck(
      proxyUrl: proxyUrl,
      message: 'OpenAI 프록시 연결이 확인되었습니다.',
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
