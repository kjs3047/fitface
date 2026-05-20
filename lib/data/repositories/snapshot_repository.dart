import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/date_utils.dart';
import '../local/local_file_storage.dart';
import '../models/outfit_snapshot.dart';

class SnapshotRepository {
  SnapshotRepository(this._storage);

  final LocalFileStorage _storage;
  final _uuid = const Uuid();

  Future<List<OutfitSnapshot>> loadSnapshots() async {
    final json = await _storage.readJsonList(StorageKeys.snapshotsJson);
    return json
        .map((value) => OutfitSnapshot.fromJson(value as Map<String, dynamic>))
        .toList();
  }

  Future<OutfitSnapshot> createSnapshotFromBytes(Uint8List bytes) async {
    final now = DateTime.now();
    final path = await _storage.writeBytesToSubdir(
      StorageKeys.snapshotsDir,
      'snapshot_${FitFaceDateUtils.fileStamp(now)}.png',
      bytes,
    );
    return OutfitSnapshot(
      id: _uuid.v4(),
      imagePath: path,
      createdAt: now,
    );
  }

  Future<OutfitSnapshot> addSnapshot(OutfitSnapshot snapshot) async {
    final snapshots = await loadSnapshots();
    if (snapshots.length >= AppConstants.maxSnapshots) {
      throw const SnapshotLimitException();
    }
    snapshots.add(snapshot);
    await _saveSnapshots(snapshots);
    return snapshot;
  }

  Future<OutfitSnapshot> replaceSnapshot(
    int index,
    OutfitSnapshot snapshot,
  ) async {
    final snapshots = await loadSnapshots();
    if (index < 0 || index >= snapshots.length) {
      throw RangeError.index(index, snapshots, 'index');
    }
    final old = snapshots[index];
    snapshots[index] = snapshot;
    await _saveSnapshots(snapshots);
    await _storage.deleteFileSafely(old.imagePath);
    return snapshot;
  }

  Future<OutfitSnapshot> updateSnapshot(OutfitSnapshot snapshot) async {
    final snapshots = await loadSnapshots();
    final index = snapshots.indexWhere((item) => item.id == snapshot.id);
    if (index == -1) {
      throw StateError('후보를 찾을 수 없습니다.');
    }
    snapshots[index] = snapshot;
    await _saveSnapshots(snapshots);
    return snapshot;
  }

  Future<void> deleteSnapshot(String snapshotId) async {
    final snapshots = await loadSnapshots();
    final index = snapshots.indexWhere((item) => item.id == snapshotId);
    if (index == -1) {
      return;
    }
    final snapshot = snapshots.removeAt(index);
    await _saveSnapshots(snapshots);
    await _storage.deleteFileSafely(snapshot.imagePath);
  }

  Future<void> clearSnapshots({bool deleteImages = true}) async {
    final snapshots = await loadSnapshots();
    if (deleteImages) {
      for (final snapshot in snapshots) {
        await _storage.deleteFileSafely(snapshot.imagePath);
      }
    }
    await _storage.writeJsonList(StorageKeys.snapshotsJson, const []);
  }

  Future<void> _saveSnapshots(List<OutfitSnapshot> snapshots) async {
    await _storage.writeJsonList(
      StorageKeys.snapshotsJson,
      snapshots.map((snapshot) => snapshot.toJson()).toList(),
    );
  }
}
