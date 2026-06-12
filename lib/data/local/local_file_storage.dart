import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/storage_keys.dart';

class LocalFileStorage {
  LocalFileStorage._(this.rootDirectory);

  final Directory rootDirectory;

  Directory get metadataDirectory =>
      Directory(p.join(rootDirectory.path, StorageKeys.metadataDir));

  static Future<LocalFileStorage> create({Directory? root}) async {
    final documents = root ?? await getApplicationDocumentsDirectory();
    final storage =
        LocalFileStorage._(Directory(p.join(documents.path, 'fitface')));
    await storage.init();
    return storage;
  }

  Future<void> init() async {
    await rootDirectory.create(recursive: true);
    await metadataDirectory.create(recursive: true);
    await Directory(p.join(rootDirectory.path, StorageKeys.profileDir))
        .create(recursive: true);
    await Directory(p.join(rootDirectory.path, StorageKeys.snapshotsDir))
        .create(recursive: true);
  }

  File metadataFile(String fileName) {
    return File(p.join(metadataDirectory.path, fileName));
  }

  Future<Map<String, dynamic>?> readJsonMap(String fileName) async {
    final file = metadataFile(fileName);
    if (!await file.exists()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      // 쓰기 도중 크래시 등으로 손상된 파일은 없는 것으로 취급한다.
      return null;
    }
  }

  Future<List<dynamic>> readJsonList(String fileName) async {
    final file = metadataFile(fileName);
    if (!await file.exists()) {
      return const [];
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is List<dynamic> ? decoded : const [];
    } on FormatException {
      // 손상된 메타데이터는 빈 목록으로 폴백해 로드가 영구 실패하지 않게 한다.
      return const [];
    }
  }

  Future<void> writeJsonMap(String fileName, Map<String, dynamic> value) async {
    await _writeAtomically(fileName, jsonEncode(value));
  }

  Future<void> writeJsonList(String fileName, List<dynamic> value) async {
    await _writeAtomically(fileName, jsonEncode(value));
  }

  /// 임시 파일에 먼저 쓰고 flush한 뒤 원자적으로 rename한다. 쓰기 도중
  /// 크래시가 나도 기존 파일이 깨지지 않는다.
  Future<void> _writeAtomically(String fileName, String contents) async {
    await metadataDirectory.create(recursive: true);
    final target = metadataFile(fileName);
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(contents, flush: true);
    await temp.rename(target.path);
  }

  Future<void> deleteMetadata(String fileName) async {
    final file = metadataFile(fileName);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String> writeBytesToSubdir(
    String subdir,
    String fileName,
    Uint8List bytes,
  ) async {
    final directory = Directory(p.join(rootDirectory.path, subdir));
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String> copyFileToSubdir(
    String sourcePath,
    String subdir,
    String fileName,
  ) async {
    final directory = Directory(p.join(rootDirectory.path, subdir));
    await directory.create(recursive: true);
    final copied =
        await File(sourcePath).copy(p.join(directory.path, fileName));
    return copied.path;
  }

  Future<void> deleteFileSafely(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      return;
    }
    final file = File(filePath);
    final root = rootDirectory.absolute.path;
    final target = file.absolute.path;
    if (!target.startsWith(root) || !await file.exists()) {
      return;
    }
    await file.delete();
  }

  Future<void> clearAll() async {
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
    await init();
  }
}
