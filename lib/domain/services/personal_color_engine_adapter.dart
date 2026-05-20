import '../../data/models/image_feature_summary.dart';
import '../../data/models/personal_color_result.dart';

class PersonalColorAnalysisRequest {
  const PersonalColorAnalysisRequest({
    required this.faceImagePath,
    required this.prompt,
    required this.includeImage,
    this.features,
  });

  final String faceImagePath;
  final String prompt;
  final bool includeImage;
  final ImageFeatureSummary? features;
}

abstract class PersonalColorEngineAdapter {
  String get engineName;

  Future<PersonalColorResult> analyze(PersonalColorAnalysisRequest request);
}
