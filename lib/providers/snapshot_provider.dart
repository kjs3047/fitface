import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/outfit_snapshot.dart';
import '../data/repositories/snapshot_repository.dart';
import 'repository_provider.dart';

final snapshotProvider =
    StateNotifierProvider<SnapshotNotifier, AsyncValue<List<OutfitSnapshot>>>(
  (ref) {
    return SnapshotNotifier(ref.watch(snapshotRepositoryProvider));
  },
);

class SnapshotNotifier extends StateNotifier<AsyncValue<List<OutfitSnapshot>>> {
  SnapshotNotifier(this._repository) : super(const AsyncValue.loading()) {
    load();
  }

  final SnapshotRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.loadSnapshots);
  }

  Future<OutfitSnapshot> createSnapshotFromBytes(
    Uint8List bytes, {
    Uint8List? rawBytes,
  }) {
    return _repository.createSnapshotFromBytes(bytes, rawBytes: rawBytes);
  }

  Future<OutfitSnapshot> saveTryOnResult({
    required String snapshotId,
    required Uint8List imageBytes,
    required String bodyType,
  }) async {
    final updated = await _repository.saveTryOnResult(
      snapshotId: snapshotId,
      imageBytes: imageBytes,
      bodyType: bodyType,
    );
    await load();
    return updated;
  }

  Future<OutfitSnapshot> add(OutfitSnapshot snapshot) async {
    final saved = await _repository.addSnapshot(snapshot);
    await load();
    return saved;
  }

  Future<OutfitSnapshot> replace(int index, OutfitSnapshot snapshot) async {
    final saved = await _repository.replaceSnapshot(index, snapshot);
    await load();
    return saved;
  }

  Future<void> updateMemo(String snapshotId, String? memo) async {
    final snapshots = state.value ?? await _repository.loadSnapshots();
    final snapshot = snapshots.firstWhere((item) => item.id == snapshotId);
    final normalized = memo == null || memo.trim().isEmpty ? null : memo.trim();
    await _repository.updateSnapshot(
      snapshot.copyWith(memo: normalized, clearMemo: normalized == null),
    );
    await load();
  }

  Future<void> updateAiResult({
    required String snapshotId,
    required int score,
    required String comment,
    required List<String> tags,
  }) async {
    await _repository.updateAiResult(
      snapshotId: snapshotId,
      score: score,
      comment: comment,
      tags: tags,
    );
    await load();
  }

  Future<void> clearAiResults() async {
    await _repository.clearAiResults();
    await load();
  }

  Future<void> delete(String snapshotId) async {
    await _repository.deleteSnapshot(snapshotId);
    await load();
  }

  Future<void> clear() async {
    await _repository.clearSnapshots();
    state = const AsyncValue.data([]);
  }
}
