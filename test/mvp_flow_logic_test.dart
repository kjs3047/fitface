import 'dart:io';
import 'dart:typed_data';

import 'package:fitface/core/utils/image_utils.dart';
import 'package:fitface/data/local/local_file_storage.dart';
import 'package:fitface/data/repositories/preset_repository.dart';
import 'package:fitface/data/repositories/snapshot_repository.dart';
import 'package:fitface/data/repositories/user_profile_repository.dart';
import 'package:fitface/domain/services/face_neck_cutout_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('MVP local flow covers crop, profile, snapshots, memo, and reset',
      () async {
    final tempRoot = await Directory.systemTemp.createTemp('fitface_mvp_flow_');
    addTearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    final storage = await LocalFileStorage.create(root: tempRoot);
    final profileRepository = UserProfileRepository(storage);
    final presetRepository = PresetRepository(storage);
    final snapshotRepository = SnapshotRepository(storage);

    final sourceImage = img.Image(width: 320, height: 420);
    img.fill(sourceImage, color: img.ColorRgb8(210, 180, 160));
    final sourcePath = await storage.writeBytesToSubdir(
      'profile',
      'source.jpg',
      Uint8List.fromList(img.encodeJpg(sourceImage)),
    );

    final croppedPath = await ImageUtils.cropFaceGuide(
      inputPath: sourcePath,
      storage: storage,
      zoom: 1.4,
      horizontal: 0.2,
      vertical: -0.2,
    );
    expect(await File(croppedPath).exists(), isTrue);

    final overlayPath = await FaceNeckCutoutService().removeBackground(
      croppedPath,
    );
    final profile = await profileRepository.saveFace(
      originalFaceImagePath: sourcePath,
      croppedFaceImagePath: croppedPath,
      overlayFaceImagePath: overlayPath,
    );
    await presetRepository.saveDefaultPreset();
    expect(profile.croppedFaceImagePath, croppedPath);
    expect(profile.overlayFaceImagePath, overlayPath);
    expect(overlayPath, endsWith('.png'));
    expect(await File(overlayPath).exists(), isTrue);
    expect((await presetRepository.loadPreset())?.opacity, 0.85);

    for (var i = 0; i < 3; i++) {
      final snapshot = await snapshotRepository.createSnapshotFromBytes(
        Uint8List.fromList([137, 80, 78, 71, i]),
      );
      await snapshotRepository.addSnapshot(snapshot);
    }
    expect((await snapshotRepository.loadSnapshots()).length, 3);

    final replacement = await snapshotRepository.createSnapshotFromBytes(
      Uint8List.fromList([137, 80, 78, 71, 9]),
    );
    await snapshotRepository.replaceSnapshot(0, replacement);
    var snapshots = await snapshotRepository.loadSnapshots();
    expect(snapshots.first.id, replacement.id);

    final memoSnapshot = snapshots.first.copyWith(memo: '밝은 재킷 후보');
    await snapshotRepository.updateSnapshot(memoSnapshot);
    snapshots = await snapshotRepository.loadSnapshots();
    expect(snapshots.first.memo, '밝은 재킷 후보');

    await snapshotRepository.deleteSnapshot(snapshots.first.id);
    expect((await snapshotRepository.loadSnapshots()).length, 2);

    await storage.clearAll();
    expect(await profileRepository.loadProfile(), isNull);
    expect(await snapshotRepository.loadSnapshots(), isEmpty);
  });
}
