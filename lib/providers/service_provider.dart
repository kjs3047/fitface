import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/ai_analysis_service.dart';
import '../domain/services/background_removal_service.dart';
import '../domain/services/face_neck_cutout_service.dart';
import '../domain/services/mock_ai_analysis_service.dart';
import '../domain/services/mock_personal_color_service.dart';
import '../domain/services/personal_color_service.dart';

final backgroundRemovalServiceProvider =
    Provider<BackgroundRemovalService>((ref) {
  return FaceNeckCutoutService();
});

final aiAnalysisServiceProvider = Provider<AiAnalysisService>((ref) {
  return MockAiAnalysisService();
});

final personalColorServiceProvider = Provider<PersonalColorService>((ref) {
  return MockPersonalColorService();
});
