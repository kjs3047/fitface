import 'dart:io';

import 'package:fitface/data/local/local_file_storage.dart';
import 'package:fitface/data/models/ai_analysis_result.dart';
import 'package:fitface/data/models/outfit_snapshot.dart';
import 'package:fitface/data/models/personal_color_result.dart';
import 'package:fitface/data/repositories/snapshot_repository.dart';
import 'package:fitface/domain/services/ai_analysis_service.dart';
import 'package:fitface/presentation/screens/compare/compare_screen.dart';
import 'package:fitface/providers/repository_provider.dart';
import 'package:fitface/providers/service_provider.dart';
import 'package:fitface/providers/storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempRoot;
  late LocalFileStorage storage;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('fitface_compare_');
    storage = await LocalFileStorage.create(root: tempRoot);
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Widget wrapCompareScreen(
    List<OutfitSnapshot> snapshots, {
    AiAnalysisService? aiService,
    bool overrideSavedPersonalColor = false,
    PersonalColorResult? savedPersonalColor,
  }) {
    return ProviderScope(
      overrides: [
        localFileStorageProvider.overrideWithValue(storage),
        snapshotRepositoryProvider.overrideWithValue(
          _MemorySnapshotRepository(storage, snapshots),
        ),
        if (overrideSavedPersonalColor)
          savedPersonalColorProvider.overrideWith(
            (ref) => savedPersonalColor,
          ),
        if (aiService != null)
          aiAnalysisServiceProvider.overrideWithValue(aiService),
      ],
      child: const MaterialApp(home: CompareScreen()),
    );
  }

  Future<void> pumpUntilReady(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    int maxPumps = 20,
  }) async {
    for (var index = 0; index < maxPumps; index++) {
      if (finder.evaluate().isNotEmpty) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finder, findsWidgets);
  }

  Future<void> dragUntilFound(
    WidgetTester tester,
    Finder target, {
    required Finder scrollable,
    int maxDrags = 10,
  }) async {
    for (var index = 0; index < maxDrags; index++) {
      if (target.evaluate().isNotEmpty) {
        return;
      }
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pump();
    }
    expect(target, findsWidgets);
  }

  void useTallTestView(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'Compare screen shows personal color hint before comparison when snapshots exist',
    (tester) async {
      useTallTestView(tester);
      final snapshots = [
        OutfitSnapshot(
          id: 'hint_candidate_0',
          imagePath: 'missing_hint_candidate_0.png',
          createdAt: DateTime(2026, 6, 15, 10),
          memo: '비교 전 후보',
        ),
      ];

      await tester.pumpWidget(
        wrapCompareScreen(
          snapshots,
          overrideSavedPersonalColor: true,
        ),
      );
      await pumpUntilReady(tester);
      await pumpUntilFound(tester, find.byType(Scrollable));

      await dragUntilFound(
        tester,
        find.byKey(const Key('personal-color-hint-banner')),
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.byKey(const Key('personal-color-hint-banner')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Compare screen hides personal color hint on an empty snapshot list',
    (tester) async {
      await tester.pumpWidget(wrapCompareScreen(const []));
      await pumpUntilReady(tester);

      expect(
        find.byKey(const Key('personal-color-hint-banner')),
        findsNothing,
      );
      expect(find.text('비어 있음'), findsNWidgets(3));
    },
  );

  testWidgets(
    'Compare screen hides personal color hint when personal color exists',
    (tester) async {
      useTallTestView(tester);
      final snapshots = [
        OutfitSnapshot(
          id: 'saved_color_candidate_0',
          imagePath: 'missing_saved_color_candidate_0.png',
          createdAt: DateTime(2026, 6, 15, 10),
        ),
      ];

      await tester.pumpWidget(
        wrapCompareScreen(
          snapshots,
          overrideSavedPersonalColor: true,
          savedPersonalColor: const PersonalColorResult(
            type: '여름 쿨',
            recommendedColors: [PersonalColorSwatch(name: '소프트 블루')],
            avoidColors: [PersonalColorSwatch(name: '강한 오렌지')],
            comment: '저장된 퍼스널 컬러 결과입니다.',
          ),
        ),
      );
      await pumpUntilReady(tester);

      expect(
        find.byKey(const Key('personal-color-hint-banner')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Compare screen renders per-candidate AI comments',
    (tester) async {
      final snapshots = [
        for (var index = 0; index < 3; index++)
          OutfitSnapshot(
            id: 'comment_candidate_$index',
            imagePath: 'missing_comment_candidate_$index.png',
            createdAt: DateTime(2026, 6, 15, 11, index),
            memo: '후보 ${index + 1}',
          ),
      ];

      await tester.pumpWidget(
        wrapCompareScreen(
          snapshots,
          aiService: const _CommentedCompareAiService(),
        ),
      );
      await pumpUntilReady(tester);

      await tester.tap(find.text('AI에게 3개 비교 요청'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const Key('compare-candidate-comment-comment_candidate_0')),
        findsOneWidget,
      );
      expect(find.text('밝기 균형은 좋지만 대비가 조금 약합니다.'), findsOneWidget);
      expect(
        find.byKey(const Key('compare-candidate-comment-comment_candidate_1')),
        findsOneWidget,
      );
      expect(find.text('퍼스널 컬러와 색감 대비가 가장 안정적입니다.'), findsOneWidget);
      expect(find.text('comment_candidate_1'), findsNothing);
    },
  );
}

class _MemorySnapshotRepository extends SnapshotRepository {
  _MemorySnapshotRepository(super.storage, this._snapshots);

  final List<OutfitSnapshot> _snapshots;

  @override
  Future<List<OutfitSnapshot>> loadSnapshots() async {
    return _snapshots;
  }
}

class _CommentedCompareAiService implements AiAnalysisService {
  const _CommentedCompareAiService();

  @override
  Future<AiAnalysisResult> analyzeSnapshot(OutfitSnapshot snapshot) async {
    return const AiAnalysisResult(score: 70, comment: '단일 후보 분석');
  }

  @override
  Future<AiAnalysisResult> compareSnapshots(
    List<OutfitSnapshot> snapshots,
  ) async {
    return const AiAnalysisResult(
      score: 88,
      bestSnapshotId: 'comment_candidate_1',
      candidateScores: {
        'comment_candidate_0': 74,
        'comment_candidate_1': 88,
        'comment_candidate_2': 69,
      },
      candidateComments: {
        'comment_candidate_0': '밝기 균형은 좋지만 대비가 조금 약합니다.',
        'comment_candidate_1': '퍼스널 컬러와 색감 대비가 가장 안정적입니다.',
        'comment_candidate_2': '전체 채도가 낮아 BEST 후보보다 덜 선명합니다.',
      },
      comment: '두 번째 후보가 가장 안정적입니다.',
    );
  }
}
