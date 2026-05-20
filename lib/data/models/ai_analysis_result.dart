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
    );
  }

  static List<String> _stringList(Object? value) {
    return ((value as List<dynamic>?) ?? const [])
        .map((item) => item as String)
        .toList();
  }
}
