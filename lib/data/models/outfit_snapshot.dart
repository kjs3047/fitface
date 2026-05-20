class OutfitSnapshot {
  const OutfitSnapshot({
    required this.id,
    required this.imagePath,
    this.memo,
    this.tags = const [],
    this.aiScore,
    this.aiComment,
    required this.createdAt,
  });

  final String id;
  final String imagePath;
  final String? memo;
  final List<String> tags;
  final int? aiScore;
  final String? aiComment;
  final DateTime createdAt;

  OutfitSnapshot copyWith({
    String? id,
    String? imagePath,
    String? memo,
    List<String>? tags,
    int? aiScore,
    String? aiComment,
    DateTime? createdAt,
    bool clearMemo = false,
    bool clearAi = false,
  }) {
    return OutfitSnapshot(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      memo: clearMemo ? null : memo ?? this.memo,
      tags: tags ?? this.tags,
      aiScore: clearAi ? null : aiScore ?? this.aiScore,
      aiComment: clearAi ? null : aiComment ?? this.aiComment,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'memo': memo,
      'tags': tags,
      'aiScore': aiScore,
      'aiComment': aiComment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory OutfitSnapshot.fromJson(Map<String, dynamic> json) {
    return OutfitSnapshot(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      memo: json['memo'] as String?,
      tags: ((json['tags'] as List<dynamic>?) ?? const [])
          .map((value) => value as String)
          .toList(),
      aiScore: json['aiScore'] as int?,
      aiComment: json['aiComment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
