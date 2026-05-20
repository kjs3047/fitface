import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/local_file_storage.dart';

final localFileStorageProvider = Provider<LocalFileStorage>((ref) {
  throw UnimplementedError('LocalFileStorage must be provided at app startup.');
});
