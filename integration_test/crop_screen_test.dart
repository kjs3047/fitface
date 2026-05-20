import 'dart:io';
import 'dart:typed_data';

import 'package:fitface/data/local/local_file_storage.dart';
import 'package:fitface/presentation/routes/app_routes.dart';
import 'package:fitface/presentation/routes/route_names.dart';
import 'package:fitface/presentation/screens/face_register/face_crop_screen.dart';
import 'package:fitface/presentation/screens/face_register/face_preview_screen.dart';
import 'package:fitface/providers/storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('crop screen drag and controls create a guide-shaped crop', (
    tester,
  ) async {
    final storage = await LocalFileStorage.create();
    await storage.clearAll();

    final sourceImage = img.Image(width: 420, height: 720);
    for (var y = 0; y < sourceImage.height; y++) {
      for (var x = 0; x < sourceImage.width; x++) {
        sourceImage.setPixelRgb(
          x,
          y,
          (x / sourceImage.width * 255).round(),
          (y / sourceImage.height * 255).round(),
          160,
        );
      }
    }
    final sourcePath = await storage.writeBytesToSubdir(
      'profile',
      'integration_crop_source.jpg',
      Uint8List.fromList(img.encodeJpg(sourceImage, quality: 95)),
    );

    FacePreviewArgs? previewArgs;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localFileStorageProvider.overrideWithValue(storage)],
        child: MaterialApp(
          home: FaceCropScreen(imagePath: sourcePath),
          onGenerateRoute: (settings) {
            if (settings.name == RouteNames.facePreview) {
              previewArgs = settings.arguments! as FacePreviewArgs;
              return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('preview reached')),
              );
            }
            return null;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('얼굴~목 맞추기'), findsOneWidget);
    expect(find.byKey(const Key('face-crop-cutout-guide')), findsOneWidget);
    expect(find.textContaining('실루엣 선'), findsOneWidget);

    await tester.drag(find.byType(Slider).at(0), const Offset(160, 0));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('face-crop-viewport')),
      const Offset(-50, 35),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('preview reached'), findsOneWidget);
    final args = previewArgs;
    expect(args, isNotNull);
    final cropFile = File(args!.croppedImagePath);
    expect(await cropFile.exists(), isTrue);

    final cropped = img.decodeImage(await cropFile.readAsBytes());
    expect(cropped, isNotNull);
    expect(cropped!.width / cropped.height, closeTo(0.72, 0.04));
    expect(cropped.width, lessThan(sourceImage.width));
    expect(cropped.height, lessThan(sourceImage.height));
  });

  testWidgets('face preview creates transparent face-neck cutout', (
    tester,
  ) async {
    final storage = await LocalFileStorage.create();
    await storage.clearAll();

    final sourceImage = img.Image(width: 240, height: 340);
    img.fill(sourceImage, color: img.ColorRgb8(180, 140, 120));
    final sourcePath = await storage.writeBytesToSubdir(
      'profile',
      'preview_source.jpg',
      Uint8List.fromList(img.encodeJpg(sourceImage, quality: 95)),
    );
    final croppedPath = await storage.writeBytesToSubdir(
      'profile',
      'preview_crop.jpg',
      Uint8List.fromList(img.encodeJpg(sourceImage, quality: 95)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localFileStorageProvider.overrideWithValue(storage)],
        child: MaterialApp(
          home: FacePreviewScreen(
            args: FacePreviewArgs(
              originalImagePath: sourcePath,
              croppedImagePath: croppedPath,
            ),
          ),
        ),
      ),
    );

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final cutouts = storage.rootDirectory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.contains('face_neck_cutout_'))
          .toList();
      if (cutouts.isNotEmpty) {
        final cutout = img.decodeImage(await cutouts.first.readAsBytes());
        expect(cutout, isNotNull);
        expect(cutout!.getPixel(0, 0).a, 0);
        expect(cutout.getPixel(cutout.width ~/ 2, cutout.height ~/ 3).a, 255);
        expect(
          cutout.getPixel(cutout.width ~/ 2, (cutout.height * 0.78).round()).a,
          0,
        );
        expect(find.text('이 사진 사용하기'), findsOneWidget);
        return;
      }
    }

    fail('누끼 PNG 파일이 생성되지 않았습니다.');
  });
}
