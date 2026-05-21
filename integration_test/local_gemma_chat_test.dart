import 'dart:convert';
import 'dart:io';

import 'package:fitface/data/local/local_file_storage.dart';
import 'package:fitface/data/models/ai_settings.dart';
import 'package:fitface/domain/services/local_gemma_chat_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'local Gemma chat can answer text and optional image prompts',
    (tester) async {
      const modelPath = String.fromEnvironment('LOCAL_GEMMA_MODEL_PATH');
      const modelName = String.fromEnvironment(
        'LOCAL_GEMMA_MODEL_NAME',
        defaultValue: 'gemma-4-E4B-it.litertlm',
      );
      const expectedModelBytes = int.fromEnvironment(
        'LOCAL_GEMMA_MODEL_BYTES',
      );
      const runImageDiagnostic = bool.fromEnvironment(
        'LOCAL_GEMMA_RUN_IMAGE_CHAT_DIAGNOSTIC',
      );

      if (modelPath.isEmpty) {
        return;
      }

      await _logModelPathVisibility(
        modelPath,
        expectedBytes: expectedModelBytes > 0 ? expectedModelBytes : null,
      );

      final settings = AiSettings.defaults().copyWith(
        mode: AiEngineMode.localGemma,
        localModelPath: modelPath,
        localModelName: modelName,
      );
      final service = LocalGemmaChatService(settings: settings);

      final textResponse = await service.send(
        const LocalGemmaChatRequest(
          message: '네이비 재킷에 어울리는 색을 한 문장으로 추천해줘.',
        ),
      );
      expect(textResponse.text, isNotEmpty);
      expect(textResponse.usedImage, isFalse);
      debugPrint(
        'LOCAL_GEMMA_CHAT_TEXT_RESULT=${jsonEncode({
              'text': textResponse.text,
              'usedImage': textResponse.usedImage,
            })}',
      );

      if (!runImageDiagnostic) {
        return;
      }

      final storage = await LocalFileStorage.create();
      final imagePath = await storage.writeBytesToSubdir(
        'diagnostic',
        'local_gemma_chat_image.jpg',
        Uint8List.fromList(img.encodeJpg(_chatDiagnosticImage(), quality: 92)),
      );

      final imageResponse = await service.send(
        LocalGemmaChatRequest(
          message: '첨부 이미지의 색상과 스타일 경향을 한 문장으로 말해줘.',
          imagePath: imagePath,
        ),
      );
      expect(imageResponse.text, isNotEmpty);
      expect(imageResponse.usedImage, isTrue);
      debugPrint(
        'LOCAL_GEMMA_CHAT_IMAGE_RESULT=${jsonEncode({
              'text': imageResponse.text,
              'usedImage': imageResponse.usedImage,
            })}',
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

img.Image _chatDiagnosticImage() {
  final image = img.Image(width: 180, height: 240);
  img.fill(image, color: img.ColorRgb8(232, 224, 211));
  img.fillRect(
    image,
    x1: 22,
    y1: 34,
    x2: 158,
    y2: 212,
    color: img.ColorRgb8(36, 52, 84),
  );
  img.fillRect(
    image,
    x1: 50,
    y1: 76,
    x2: 130,
    y2: 160,
    color: img.ColorRgb8(82, 132, 116),
  );
  img.fillCircle(
    image,
    x: 128,
    y: 54,
    radius: 14,
    color: img.ColorRgb8(184, 122, 75),
  );
  return image;
}

Future<void> _logModelPathVisibility(
  String modelPath, {
  required int? expectedBytes,
}) async {
  final modelFile = File(modelPath);
  final exists = await modelFile.exists();
  final length = exists ? await modelFile.length() : 0;
  debugPrint(
    'LOCAL_GEMMA_CHAT_MODEL=$modelPath exists=$exists bytes=$length expected=$expectedBytes',
  );
  if (exists && expectedBytes != null && length != expectedBytes) {
    throw StateError(
      'Local Gemma model size mismatch: $modelPath bytes=$length expected=$expectedBytes',
    );
  }
}
