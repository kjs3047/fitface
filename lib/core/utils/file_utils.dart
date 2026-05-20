import 'dart:io';

class FileUtils {
  static Future<bool> exists(String? path) async {
    if (path == null || path.isEmpty) {
      return false;
    }
    return File(path).exists();
  }
}
