import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
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
  int _currentIndex = 0;

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
    final result = await ref.read(aiAnalysisServiceProvider).analyzeSnapshot(
          snapshot,
        );
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI 판단'),
        content: Text(result.comment),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
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
                                onPressed: () => _runAi(snapshots),
                                icon: const Icon(Icons.auto_awesome_outlined),
                                label: const Text('AI 판단'),
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
