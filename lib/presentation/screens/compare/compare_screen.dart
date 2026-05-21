import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/ai_analysis_result.dart';
import '../../../data/models/ai_settings.dart';
import '../../../data/models/outfit_snapshot.dart';
import '../../../providers/ai_settings_provider.dart';
import '../../../providers/service_provider.dart';
import '../../../providers/snapshot_provider.dart';
import '../../widgets/ai_processing_status.dart';
import '../../routes/route_names.dart';
import '../../widgets/app_top_bar.dart';

class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  AiAnalysisResult? _compareResult;
  bool _isComparing = false;

  void _showComparingBlockedMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('AI 비교가 끝난 뒤 후보를 열 수 있습니다.')),
      );
  }

  Future<bool> _confirmLeaveDuringComparison() async {
    if (!_isComparing) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('비교 중 이동'),
        content: const Text(
          'Local Gemma 비교가 진행 중입니다. 지금 이동하면 진행 중인 결과를 받을 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 기다리기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('이동하기'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _openCamera() async {
    if (_isComparing) {
      final confirmed = await _confirmLeaveDuringComparison();
      if (!confirmed || !mounted) {
        return;
      }
      setState(() => _isComparing = false);
    }
    if (!mounted) {
      return;
    }
    Navigator.pushReplacementNamed(context, RouteNames.cameraMatch);
  }

  void _openSnapshotDetail(String snapshotId) {
    if (_isComparing) {
      _showComparingBlockedMessage();
      return;
    }
    Navigator.pushNamed(
      context,
      RouteNames.snapshotDetail,
      arguments: snapshotId,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String snapshotId,
  ) async {
    if (_isComparing) {
      _showComparingBlockedMessage();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('후보 삭제'),
        content: const Text('이 후보를 삭제할까요?'),
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
    if (confirmed == true) {
      await ref.read(snapshotProvider.notifier).delete(snapshotId);
      if (mounted) {
        setState(() => _compareResult = null);
      }
    }
  }

  Future<void> _compareAi(List<OutfitSnapshot> snapshots) async {
    if (_isComparing || snapshots.isEmpty) {
      return;
    }
    setState(() => _isComparing = true);
    try {
      final result =
          await ref.read(aiAnalysisServiceProvider).compareSnapshots(snapshots);
      if (!mounted) {
        return;
      }
      setState(() => _compareResult = result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 비교 결과를 가져오지 못했습니다: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isComparing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshotsAsync = ref.watch(snapshotProvider);
    final aiSettings =
        ref.watch(aiSettingsProvider).valueOrNull ?? AiSettings.defaults();

    return PopScope(
      canPop: !_isComparing,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !_isComparing) {
          return;
        }
        final confirmed = await _confirmLeaveDuringComparison();
        if (!confirmed || !context.mounted) {
          return;
        }
        setState(() => _isComparing = false);
        Navigator.pop(context, result);
      },
      child: Scaffold(
        appBar: AppTopBar(
          title: '후보 비교',
          actions: [
            IconButton(
              tooltip: '카메라',
              onPressed: _openCamera,
              icon: const Icon(Icons.photo_camera_outlined),
            ),
          ],
        ),
        body: snapshotsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text('후보를 불러오지 못했습니다: $error')),
          data: (snapshots) {
            final compareResult = _visibleCompareResult(snapshots);
            return SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      children: [
                        const _CompareHeader(),
                        if (compareResult != null) ...[
                          const SizedBox(height: 10),
                          _AiCompareSummary(result: compareResult),
                        ],
                        const SizedBox(height: 12),
                        for (var index = 0; index < 3; index++) ...[
                          if (index >= snapshots.length)
                            _EmptySlot(index: index)
                          else
                            _SnapshotSlot(
                              index: index,
                              snapshot: snapshots[index],
                              isBest: compareResult?.bestSnapshotId ==
                                  snapshots[index].id,
                              score: compareResult == null
                                  ? null
                                  : _scoreForSnapshot(
                                      compareResult,
                                      snapshots[index].id,
                                    ),
                              isLocked: _isComparing,
                              onBlockedTap: _showComparingBlockedMessage,
                              onTap: () =>
                                  _openSnapshotDetail(snapshots[index].id),
                              onDelete: () =>
                                  _confirmDelete(context, snapshots[index].id),
                            ),
                          if (index != 2) const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppTheme.surface,
                      border: Border(top: BorderSide(color: AppTheme.line)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: snapshots.isEmpty || _isComparing
                                ? null
                                : () => _compareAi(snapshots),
                            icon: _isComparing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_outlined),
                            label: Text(
                              _isComparing ? '비교 중...' : 'AI에게 3개 비교 요청',
                            ),
                          ),
                          if (_isComparing) ...[
                            const SizedBox(height: 10),
                            AiProcessingStatus(
                              keyPrefix: 'compare',
                              mode: aiSettings.mode,
                              label: '후보 비교 중',
                              localMessage:
                                  'Local Gemma가 후보 ${snapshots.length}개의 이미지와 색상 정보를 비교하고 있습니다.',
                              cloudMessage:
                                  'OpenAI 프록시 서버로 후보 비교 요청을 보내고 있습니다.',
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
      ),
    );
  }

  AiAnalysisResult? _visibleCompareResult(List<OutfitSnapshot> snapshots) {
    final result = _compareResult;
    if (result == null || snapshots.isEmpty) {
      return null;
    }
    final visibleScores = <String, int>{};
    for (final snapshot in snapshots) {
      final score = result.candidateScores[snapshot.id];
      if (score != null) {
        visibleScores[snapshot.id] = score.clamp(0, 100).toInt();
      }
    }
    var bestSnapshotId = result.bestSnapshotId;
    if (bestSnapshotId == null && visibleScores.isNotEmpty) {
      bestSnapshotId = visibleScores.entries
          .reduce(
            (current, next) => current.value >= next.value ? current : next,
          )
          .key;
    }
    bestSnapshotId ??= snapshots.first.id;
    final hasBest = snapshots.any((snapshot) => snapshot.id == bestSnapshotId);
    if (!hasBest) {
      return null;
    }
    if (visibleScores.isEmpty) {
      visibleScores[bestSnapshotId] = result.score.clamp(0, 100).toInt();
    }
    return result.copyWith(
      bestSnapshotId: bestSnapshotId,
      score:
          (visibleScores[bestSnapshotId] ?? result.score).clamp(0, 100).toInt(),
      candidateScores: visibleScores,
    );
  }

  int? _scoreForSnapshot(AiAnalysisResult result, String snapshotId) {
    return result.candidateScores[snapshotId]?.clamp(0, 100).toInt();
  }
}

class _CompareHeader extends StatelessWidget {
  const _CompareHeader();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.compare_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '후보 3개를 한눈에 비교',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '매장에서 저장한 착장 화면을 리스트로 확인하고 자세한 메모를 남길 수 있습니다.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiCompareSummary extends StatelessWidget {
  const _AiCompareSummary({required this.result});

  final AiAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.bronzeSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.auto_awesome,
                  color: AppTheme.bronze,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI 비교 결과',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _engineLabel(result),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.comment,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _engineLabel(AiAnalysisResult result) {
    switch (result.engine) {
      case 'openAi':
        return result.analysisMode == 'featuresOnly'
            ? 'OpenAI API · 색상정보 분석'
            : 'OpenAI API · 이미지+색상정보 분석';
      case 'localGemma':
        return result.analysisMode == 'featuresOnly'
            ? 'Local Gemma · 색상정보 분석'
            : 'Local Gemma · 이미지+색상정보 분석';
      case 'ruleBased':
        return '색상정보 fallback';
      default:
        return result.engine;
    }
  }
}

class _SnapshotSlot extends StatelessWidget {
  const _SnapshotSlot({
    required this.index,
    required this.snapshot,
    required this.isBest,
    required this.score,
    required this.isLocked,
    required this.onBlockedTap,
    required this.onTap,
    required this.onDelete,
  });

  final int index;
  final OutfitSnapshot snapshot;
  final bool isBest;
  final int? score;
  final bool isLocked;
  final VoidCallback onBlockedTap;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final memo = snapshot.memo?.trim();
    return Opacity(
      opacity: isLocked ? 0.68 : 1,
      child: Card(
        child: InkWell(
          onTap: isLocked ? onBlockedTap : onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _SnapshotThumbnail(
                  imagePath: snapshot.imagePath,
                  isBest: isBest,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '후보 ${index + 1}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        memo == null || memo.isEmpty ? '메모 없음' : memo,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDate(snapshot.createdAt),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    if (score != null) ...[
                      _CandidateScoreBadge(
                        snapshotId: snapshot.id,
                        score: score!,
                        isBest: isBest,
                      ),
                      const SizedBox(height: 8),
                    ],
                    IconButton(
                      tooltip: '후보 삭제',
                      onPressed: isLocked ? onBlockedTap : onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                    IconButton(
                      tooltip: '상세 보기',
                      onPressed: isLocked ? onBlockedTap : onTap,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month.$day $hour:$minute';
  }
}

class _SnapshotThumbnail extends StatelessWidget {
  const _SnapshotThumbnail({
    required this.imagePath,
    required this.isBest,
  });

  final String imagePath;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: isBest ? const Key('compare-best-thumbnail-border') : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBest ? AppTheme.bronze : Colors.transparent,
          width: 3,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.file(
            File(imagePath),
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
    );
  }
}

class _CandidateScoreBadge extends StatelessWidget {
  const _CandidateScoreBadge({
    required this.snapshotId,
    required this.score,
    required this.isBest,
  });

  final String snapshotId;
  final int score;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final safeScore = score.clamp(0, 100).toInt();
    final foreground = isBest ? Colors.white : AppTheme.ink;
    return DecoratedBox(
      key: isBest
          ? const Key('compare-best-badge')
          : Key('compare-candidate-score-badge-$snapshotId'),
      decoration: BoxDecoration(
        color: isBest ? AppTheme.bronze : AppTheme.accentSoft,
        borderRadius: BorderRadius.circular(8),
        border: isBest ? null : Border.all(color: AppTheme.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Column(
          children: [
            Text(
              isBest ? '★ BEST' : 'AI 점수',
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$safeScore/100',
              key: isBest
                  ? const Key('compare-best-score')
                  : Key('compare-candidate-score-$snapshotId'),
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SizedBox(
                width: 54,
                height: 54,
                child: Icon(Icons.add_photo_alternate_outlined),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '후보 ${index + 1}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '비어 있음',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '카메라 화면에서 스냅을 저장하면 여기에 추가됩니다.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
