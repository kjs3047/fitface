import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/local/local_file_storage.dart';
import 'providers/storage_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await LocalFileStorage.create();

  runApp(
    ProviderScope(
      overrides: [
        localFileStorageProvider.overrideWithValue(storage),
      ],
      child: const FitFaceApp(),
    ),
  );
}
