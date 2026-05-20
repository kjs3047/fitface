import 'dart:typed_data';

import 'package:fitface/data/local/local_file_storage.dart';
import 'package:fitface/data/models/personal_color_result.dart';
import 'package:fitface/data/repositories/user_profile_repository.dart';
import 'package:fitface/domain/services/personal_color_service.dart';
import 'package:fitface/presentation/screens/personal_color/personal_color_screen.dart';
import 'package:fitface/providers/service_provider.dart';
import 'package:fitface/providers/storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('personal color uses the registered face image on device', (
    tester,
  ) async {
    final storage = await LocalFileStorage.create();
    await storage.clearAll();

    final faceImage = img.Image(width: 120, height: 180);
    img.fill(faceImage, color: img.ColorRgb8(210, 172, 145));
    final croppedPath = await storage.writeBytesToSubdir(
      'profile',
      'personal_color_face.jpg',
      Uint8List.fromList(img.encodeJpg(faceImage, quality: 95)),
    );
    final overlayPath = await storage.writeBytesToSubdir(
      'profile',
      'personal_color_overlay.png',
      Uint8List.fromList(img.encodePng(faceImage)),
    );

    await UserProfileRepository(storage).saveFace(
      originalFaceImagePath: croppedPath,
      croppedFaceImagePath: croppedPath,
      overlayFaceImagePath: overlayPath,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localFileStorageProvider.overrideWithValue(storage),
          personalColorServiceProvider.overrideWithValue(
            const _ImmediatePersonalColorService(),
          ),
        ],
        child: const MaterialApp(home: PersonalColorScreen()),
      ),
    );

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('여름 쿨').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(
      find.byKey(const Key('personal-color-face-thumbnail')),
      findsOneWidget,
    );
    expect(find.text('현재 얼굴 이미지'), findsOneWidget);
    expect(find.text('이 얼굴에 대한 퍼스널 컬러 결과입니다.'), findsOneWidget);
    expect(find.text('여름 쿨'), findsOneWidget);
  });
}

class _ImmediatePersonalColorService implements PersonalColorService {
  const _ImmediatePersonalColorService();

  @override
  Future<PersonalColorResult> analyze({String? faceImagePath}) async {
    return const PersonalColorResult(
      type: '여름 쿨',
      recommendedColors: ['라벤더'],
      avoidColors: ['오렌지'],
      comment: '테스트 결과',
    );
  }
}
