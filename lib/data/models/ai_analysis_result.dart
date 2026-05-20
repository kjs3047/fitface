class AiAnalysisResult {
  const AiAnalysisResult({
    required this.score,
    required this.comment,
    this.bestSnapshotId,
    this.candidateScores = const {},
  });

  final int score;
  final String comment;
  final String? bestSnapshotId;
  final Map<String, int> candidateScores;

  AiAnalysisResult copyWith({
    int? score,
    String? comment,
    String? bestSnapshotId,
    Map<String, int>? candidateScores,
  }) {
    return AiAnalysisResult(
      score: score ?? this.score,
      comment: comment ?? this.comment,
      bestSnapshotId: bestSnapshotId ?? this.bestSnapshotId,
      candidateScores: candidateScores ?? this.candidateScores,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'comment': comment,
      'bestSnapshotId': bestSnapshotId,
      'candidateScores': candidateScores,
    };
  }

  factory AiAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawScores = json['candidateScores'] as Map<String, dynamic>?;
    return AiAnalysisResult(
      score: json['score'] as int,
      comment: json['comment'] as String,
      bestSnapshotId: json['bestSnapshotId'] as String?,
      candidateScores: rawScores == null
          ? const {}
          : rawScores.map(
              (key, value) => MapEntry(key, (value as num).round()),
            ),
    );
  }
}
