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
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  Future<List<dynamic>> readJsonList(String fileName) async {
    final file = metadataFile(fileName);
    if (!await file.exists()) {
      return const [];
    }
    return jsonDecode(await file.readAsString()) as List<dynamic>;
  }

  Future<void> writeJsonMap(String fileName, Map<String, dynamic> value) async {
    await metadataDirectory.create(recursive: true);
    await metadataFile(fileName).writeAsString(jsonEncode(value));
  }

  Future<void> writeJsonList(String fileName, List<dynamic> value) async {
    await metadataDirectory.create(recursive: true);
    await metadataFile(fileName).writeAsString(jsonEncode(value));
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
