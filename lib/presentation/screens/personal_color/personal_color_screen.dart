import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/ai_settings.dart';
import '../../../data/models/personal_color_result.dart';
import '../../../data/models/user_profile.dart';
import '../../../providers/ai_settings_provider.dart';
import '../../../providers/repository_provider.dart';
import '../../../providers/service_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/ai_processing_status.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/personal_color_result_card.dart';

class PersonalColorScreen extends ConsumerStatefulWidget {
  const PersonalColorScreen({super.key});

  @override
  ConsumerState<PersonalColorScreen> createState() =>
      _PersonalColorScreenState();
}

class _PersonalColorScreenState extends ConsumerState<PersonalColorScreen> {
  PersonalColorResult? _result;
  String? _resultImagePath;
  bool _isLoadingCached = false;
  bool _isAnalyzing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final aiSettings =
        ref.watch(aiSettingsProvider).valueOrNull ?? AiSettings.defaults();
    return Scaffold(
      appBar: const AppTopBar(title: '퍼스널 컬러'),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('얼굴 정보를 불러오지 못했습니다: $error'),
        ),
        data: (profile) {
          final faceImagePath = _personalColorFacePath(profile);
          if (profile == null || faceImagePath == null) {
            return EmptyState(
              icon: Icons.face_retouching_natural_outlined,
              title: '등록된 얼굴 이미지가 없습니다.',
              message: '퍼스널 컬러는 현재 등록된 얼굴 이미지를 기준으로 확인합니다.',
              action: FilledButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  RouteNames.faceRegister,
                ),
                child: const Text('얼굴 등록하기'),
              ),
            );
          }

          _ensureCachedResultLoaded(faceImagePath);

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _RegisteredFaceCard(
                  imagePath: faceImagePath,
                  personalColorType: profile.personalColorType,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.light_mode_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '퍼스널 컬러 진단은 아래 얼굴 이미지를 기준으로 제공됩니다. '
                            '분석 시작을 누르면 선택한 AI 엔진으로 추천 팔레트를 확인합니다.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildAnalysisSection(faceImagePath, aiSettings.mode),
              ],
            ),
          );
        },
      ),
    );
  }

  void _ensureCachedResultLoaded(String faceImagePath) {
    if (_resultImagePath == faceImagePath || _isLoadingCached) {
      return;
    }
    _resultImagePath = faceImagePath;
    _result = null;
    _error = null;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingCached = true);
      try {
        final cached =
            await ref.read(personalColorRepositoryProvider).loadResult();
        if (!mounted || _resultImagePath != faceImagePath) {
          return;
        }
        setState(() => _result = cached);
      } catch (error) {
        if (mounted && _resultImagePath == faceImagePath) {
          setState(() => _error = error.toString());
        }
      } finally {
        if (mounted && _resultImagePath == faceImagePath) {
          setState(() => _isLoadingCached = false);
        }
      }
    });
  }

  Widget _buildAnalysisSection(String faceImagePath, AiEngineMode aiMode) {
    if (_isLoadingCached) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('퍼스널 컬러를 확인하는 중입니다.')),
            ],
          ),
        ),
      );
    }
    if (_isAnalyzing) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AiProcessingStatus(
            keyPrefix: 'personal-color',
            mode: aiMode,
            label: '퍼스널 컬러 분석 중',
            localMessage: 'Local Gemma가 얼굴 이미지와 추출 색상 정보를 함께 분석하고 있습니다.',
            cloudMessage: 'OpenAI 프록시 서버로 퍼스널 컬러 분석 요청을 보내고 있습니다.',
          ),
        ),
      );
    }
    final error = _error;
    if (error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('퍼스널 컬러를 확인하지 못했습니다: $error'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _analyze(faceImagePath),
                icon: const Icon(Icons.refresh),
                label: const Text('다시 분석'),
              ),
            ],
          ),
        ),
      );
    }
    final result = _result;
    if (result != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PersonalColorResultCard(result: result),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('personal-color-reanalyze-button'),
            onPressed: () => _analyze(faceImagePath),
            icon: const Icon(Icons.refresh),
            label: const Text('다시 분석'),
          ),
        ],
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '퍼스널 컬러 분석',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '밝은 자연광의 정면 사진일수록 결과를 참고하기 좋습니다. 결과는 스타일링 보조용입니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('personal-color-start-analysis-button'),
              onPressed: () => _analyze(faceImagePath),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('분석 시작'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyze(String faceImagePath) async {
    if (_isAnalyzing) {
      return;
    }
    setState(() {
      _isAnalyzing = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(personalColorServiceProvider)
          .analyze(faceImagePath: faceImagePath);
      await ref.read(personalColorRepositoryProvider).saveResult(result);
      await ref
          .read(userProfileProvider.notifier)
          .savePersonalColorType(result.type);
      if (!mounted) {
        return;
      }
      setState(() => _result = result);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  String? _personalColorFacePath(UserProfile? profile) {
    return profile?.croppedFaceImagePath ??
        profile?.originalFaceImagePath ??
        profile?.overlayFaceImagePath;
  }
}

class _RegisteredFaceCard extends StatelessWidget {
  const _RegisteredFaceCard({
    required this.imagePath,
    required this.personalColorType,
  });

  final String imagePath;
  final String? personalColorType;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration: const BoxDecoration(color: AppTheme.accentSoft),
                child: Image.file(
                  File(imagePath),
                  key: const Key('personal-color-face-thumbnail'),
                  width: 92,
                  height: 124,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const ColoredBox(
                      color: AppTheme.imagePlaceholder,
                      child: SizedBox(
                        width: 92,
                        height: 124,
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '현재 얼굴 이미지',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '이 얼굴에 대한 퍼스널 컬러 결과입니다.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (personalColorType != null) ...[
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.accentSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          '저장된 결과: $personalColorType',
                          key: const Key('personal-color-saved-type'),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
