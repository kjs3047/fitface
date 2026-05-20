import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/ai_analysis_result.dart';
import '../../../data/models/outfit_snapshot.dart';
import '../../../providers/service_provider.dart';
import '../../../providers/snapshot_provider.dart';
import '../../widgets/app_top_bar.dart';
import 'snapshot_image_viewer_screen.dart';

class SnapshotDetailScreen extends ConsumerStatefulWidget {
  const SnapshotDetailScreen({
    required this.snapshotId,
    super.key,
  });

  final String snapshotId;

  @override
  ConsumerState<SnapshotDetailScreen> createState() =>
      _SnapshotDetailScreenState();
}

class _SnapshotDetailScreenState extends ConsumerState<SnapshotDetailScreen> {
  final _memoController = TextEditingController();
  PageController? _pageController;
  String? _currentSnapshotId;
  String? _analyzingSnapshotId;
  int _currentIndex = 0;
  final _sessionAiResults = <String, AiAnalysisResult>{};

  @override
  void dispose() {
    _memoController.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  void _syncCurrentSnapshot(OutfitSnapshot snapshot, int index) {
    if (_currentSnapshotId == snapshot.id && _currentIndex == index) {
      return;
    }
    _currentSnapshotId = snapshot.id;
    _currentIndex = index;
    _memoController.text = snapshot.memo ?? '';
  }

  OutfitSnapshot? _currentSnapshot(List<OutfitSnapshot> snapshots) {
    final currentId = _currentSnapshotId;
    if (currentId == null) {
      return null;
    }
    for (final snapshot in snapshots) {
      if (snapshot.id == currentId) {
        return snapshot;
      }
    }
    return null;
  }

  Future<void> _saveMemo(List<OutfitSnapshot> snapshots) async {
    final snapshot = _currentSnapshot(snapshots);
    if (snapshot == null) {
      return;
    }
    await ref
        .read(snapshotProvider.notifier)
        .updateMemo(snapshot.id, _memoController.text);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('메모를 저장했습니다.')),
    );
  }

  Future<void> _delete(List<OutfitSnapshot> snapshots) async {
    final snapshot = _currentSnapshot(snapshots);
    if (snapshot == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('후보 삭제'),
        content: const Text('이미지와 메모가 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(snapshotProvider.notifier).delete(snapshot.id);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _runAi(List<OutfitSnapshot> snapshots) async {
    final snapshot = _currentSnapshot(snapshots);
    if (snapshot == null) {
      return;
    }
    if (_analyzingSnapshotId != null) {
      return;
    }
    setState(() => _analyzingSnapshotId = snapshot.id);
    try {
      final result = await ref.read(aiAnalysisServiceProvider).analyzeSnapshot(
            snapshot,
          );
      await ref.read(snapshotProvider.notifier).updateAiResult(
            snapshotId: snapshot.id,
            score: result.score,
            comment: result.comment,
            tags: result.tags,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _sessionAiResults[snapshot.id] = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 판단을 완료하지 못했습니다: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _analyzingSnapshotId = null);
      }
    }
  }

  AiAnalysisResult? _visibleAiResult(OutfitSnapshot snapshot) {
    final sessionResult = _sessionAiResults[snapshot.id];
    if (sessionResult != null) {
      return sessionResult;
    }
    final score = snapshot.aiScore;
    final comment = snapshot.aiComment;
    if (score == null || comment == null) {
      return null;
    }
    return AiAnalysisResult(
      score: score,
      comment: comment,
      tags: snapshot.tags,
      engine: 'cached',
      analysisMode: 'cached',
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshotsAsync = ref.watch(snapshotProvider);

    return Scaffold(
      appBar: const AppTopBar(title: '후보 상세'),
      body: snapshotsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('후보를 불러오지 못했습니다: $error'),
        ),
        data: (snapshots) {
          if (snapshots.isEmpty) {
            return const Center(child: Text('저장된 후보가 없습니다.'));
          }

          final requestedIndex = snapshots.indexWhere(
            (item) => item.id == widget.snapshotId,
          );
          final initialIndex = requestedIndex == -1 ? 0 : requestedIndex;
          _pageController ??= PageController(initialPage: initialIndex);

          if (_currentSnapshotId == null) {
            _syncCurrentSnapshot(snapshots[initialIndex], initialIndex);
          } else if (_currentIndex >= snapshots.length) {
            final nextIndex = snapshots.length - 1;
            _syncCurrentSnapshot(snapshots[nextIndex], nextIndex);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _pageController?.jumpToPage(nextIndex);
            });
          }

          final snapshot =
              _currentSnapshot(snapshots) ?? snapshots[initialIndex];
          final aiResult = _visibleAiResult(snapshot);
          final isAnalyzing = _analyzingSnapshotId == snapshot.id;
          final visibleIndex =
              snapshots.indexWhere((item) => item.id == snapshot.id);
          final safeIndex = visibleIndex == -1 ? initialIndex : visibleIndex;

          return SafeArea(
            child: ListView(
              key: const Key('snapshot-detail-scroll-view'),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.46,
                      child: PageView.builder(
                        key: const Key('snapshot-detail-page-view'),
                        controller: _pageController,
                        itemCount: snapshots.length,
                        onPageChanged: (index) {
                          setState(() {
                            _syncCurrentSnapshot(snapshots[index], index);
                          });
                        },
                        itemBuilder: (context, index) {
                          return _SnapshotImage(snapshot: snapshots[index]);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.line),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        '${safeIndex + 1} / ${snapshots.length}',
                        key: const Key('snapshot-detail-page-indicator'),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '후보 메모',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _memoController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: '선택 메모',
                            hintText: '색감, 핏, 매장명 등을 적어두세요.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _saveMemo(snapshots),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('저장'),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isAnalyzing
                                    ? null
                                    : () => _runAi(snapshots),
                                icon: const Icon(Icons.auto_awesome_outlined),
                                label: Text(isAnalyzing ? '분석 중' : 'AI 판단'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _delete(snapshots),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('삭제'),
                              ),
                            ),
                          ],
                        ),
                        if (isAnalyzing || aiResult != null) ...[
                          const SizedBox(height: 12),
                          _SnapshotAiResultCard(
                            result: aiResult,
                            isLoading: isAnalyzing,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SnapshotAiResultCard extends StatelessWidget {
  const _SnapshotAiResultCard({
    required this.result,
    required this.isLoading,
  });

  final AiAnalysisResult? result;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final currentResult = result;
    if (isLoading && currentResult == null) {
      return DecoratedBox(
        key: const Key('snapshot-detail-ai-loading-card'),
        decoration: BoxDecoration(
          color: AppTheme.accentSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.line),
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Expanded(child: Text('AI가 후보를 분석하는 중입니다.')),
            ],
          ),
        ),
      );
    }
    final visibleResult = currentResult;
    if (visibleResult == null) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      key: const Key('snapshot-detail-ai-result-card'),
      decoration: BoxDecoration(
        color: AppTheme.accentSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18),
                const SizedBox(width: 8),
                Text(
                  'AI 분석 결과',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${visibleResult.score.clamp(0, 100)}/100',
                  key: const Key('snapshot-detail-ai-score'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(visibleResult.comment),
            if (visibleResult.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in visibleResult.tags)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.line),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        child: Text(tag),
                      ),
                    ),
                ],
              ),
            ],
            if (visibleResult.suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                visibleResult.suggestions.first,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SnapshotImage extends StatelessWidget {
  const _SnapshotImage({
    required this.snapshot,
  });

  final OutfitSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: AppTheme.cameraBlack,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: const Key('snapshot-detail-image-open-button'),
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (context) => SnapshotImageViewerScreen(
                  imagePath: snapshot.imagePath,
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(snapshot.imagePath),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(
                  color: AppTheme.imagePlaceholder,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
