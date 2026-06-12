class AiAnalysisResult {
  const AiAnalysisResult({
    required this.score,
    required this.comment,
    this.bestSnapshotId,
    this.candidateScores = const {},
    this.candidateComments = const {},
    this.tags = const [],
    this.strengths = const [],
    this.concerns = const [],
    this.suggestions = const [],
    this.confidence,
    this.engine = 'mock',
    this.analysisMode = 'imageAndFeatures',
    this.createdAt,
    this.rawFeatureSummary,
    this.usedPersonalColor = false,
  });

  final int score;
  final String comment;
  final String? bestSnapshotId;
  final Map<String, int> candidateScores;
  final Map<String, String> candidateComments;
  final List<String> tags;
  final List<String> strengths;
  final List<String> concerns;
  final List<String> suggestions;
  final double? confidence;
  final String engine;
  final String analysisMode;
  final DateTime? createdAt;
  final Map<String, dynamic>? rawFeatureSummary;

  /// 저장된 퍼스널 컬러 결과가 분석 프롬프트에 반영됐는지 여부.
  /// false면 UI에서 "퍼스널 컬러를 설정하면 더 정확해집니다" 안내를 띄운다.
  final bool usedPersonalColor;

  AiAnalysisResult copyWith({
    int? score,
    String? comment,
    String? bestSnapshotId,
    Map<String, int>? candidateScores,
    Map<String, String>? candidateComments,
    List<String>? tags,
    List<String>? strengths,
    List<String>? concerns,
    List<String>? suggestions,
    double? confidence,
    String? engine,
    String? analysisMode,
    DateTime? createdAt,
    Map<String, dynamic>? rawFeatureSummary,
    bool? usedPersonalColor,
  }) {
    return AiAnalysisResult(
      score: score ?? this.score,
      comment: comment ?? this.comment,
      bestSnapshotId: bestSnapshotId ?? this.bestSnapshotId,
      candidateScores: candidateScores ?? this.candidateScores,
      candidateComments: candidateComments ?? this.candidateComments,
      tags: tags ?? this.tags,
      strengths: strengths ?? this.strengths,
      concerns: concerns ?? this.concerns,
      suggestions: suggestions ?? this.suggestions,
      confidence: confidence ?? this.confidence,
      engine: engine ?? this.engine,
      analysisMode: analysisMode ?? this.analysisMode,
      createdAt: createdAt ?? this.createdAt,
      rawFeatureSummary: rawFeatureSummary ?? this.rawFeatureSummary,
      usedPersonalColor: usedPersonalColor ?? this.usedPersonalColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'comment': comment,
      'bestSnapshotId': bestSnapshotId,
      'candidateScores': candidateScores,
      'candidateComments': candidateComments,
      'tags': tags,
      'strengths': strengths,
      'concerns': concerns,
      'suggestions': suggestions,
      'confidence': confidence,
      'engine': engine,
      'analysisMode': analysisMode,
      'createdAt': createdAt?.toIso8601String(),
      'rawFeatureSummary': rawFeatureSummary,
      'usedPersonalColor': usedPersonalColor,
    };
  }

  factory AiAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawScores = json['candidateScores'] as Map<String, dynamic>?;
    final rawComments = json['candidateComments'] as Map<String, dynamic>?;
    return AiAnalysisResult(
      score: (json['score'] as num).round(),
      comment: json['comment'] as String,
      bestSnapshotId: json['bestSnapshotId'] as String?,
      candidateScores: rawScores == null
          ? const {}
          : rawScores.map(
              (key, value) => MapEntry(key, (value as num).round()),
            ),
      candidateComments: rawComments == null
          ? const {}
          : rawComments.map((key, value) => MapEntry(key, value as String)),
      tags: _stringList(json['tags']),
      strengths: _stringList(json['strengths']),
      concerns: _stringList(json['concerns']),
      suggestions: _stringList(json['suggestions']),
      confidence: (json['confidence'] as num?)?.toDouble(),
      engine: json['engine'] as String? ?? 'mock',
      analysisMode: json['analysisMode'] as String? ?? 'imageAndFeatures',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      rawFeatureSummary: json['rawFeatureSummary'] as Map<String, dynamic>?,
      usedPersonalColor: json['usedPersonalColor'] as bool? ?? false,
    );
  }

  static List<String> _stringList(Object? value) {
    return ((value as List<dynamic>?) ?? const [])
        .map((item) => item as String)
        .toList();
  }
}
