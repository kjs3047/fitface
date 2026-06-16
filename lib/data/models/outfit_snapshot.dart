class OutfitSnapshot {
  const OutfitSnapshot({
    required this.id,
    required this.imagePath,
    this.rawImagePath,
    this.memo,
    this.tags = const [],
    this.aiScore,
    this.aiComment,
    this.tryOnImagePath,
    this.tryOnBodyType,
    this.tryOnRegenCount = 0,
    required this.createdAt,
  });

  final String id;

  /// 얼굴 오버레이가 합성된 캡처본(기존 표시용).
  final String imagePath;

  /// 오버레이 없는 카메라 원본 프레임. 가상착장 생성 입력에 쓴다.
  /// 기존 스냅샷은 null(다시 촬영해야 가상착장 가능).
  final String? rawImagePath;

  final String? memo;
  final List<String> tags;
  final int? aiScore;
  final String? aiComment;

  /// 가상착장 생성 결과 이미지 경로(로컬 저장).
  final String? tryOnImagePath;

  /// 그 결과를 만든 체형(BodyType.name). 캐시 키 + 체형 바뀌면 재생성 판단에 쓴다.
  final String? tryOnBodyType;

  /// 가상착장 재생성 누적 횟수(비용 방어 — 스냅샷당 상한 제한).
  final int tryOnRegenCount;

  final DateTime createdAt;

  bool get hasRawImage => rawImagePath != null && rawImagePath!.isNotEmpty;
  bool get hasTryOnImage =>
      tryOnImagePath != null && tryOnImagePath!.isNotEmpty;

  OutfitSnapshot copyWith({
    String? id,
    String? imagePath,
    String? rawImagePath,
    String? memo,
    List<String>? tags,
    int? aiScore,
    String? aiComment,
    String? tryOnImagePath,
    String? tryOnBodyType,
    int? tryOnRegenCount,
    DateTime? createdAt,
    bool clearMemo = false,
    bool clearAi = false,
    bool clearRawImage = false,
    bool clearTryOn = false,
  }) {
    return OutfitSnapshot(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      rawImagePath: clearRawImage ? null : rawImagePath ?? this.rawImagePath,
      memo: clearMemo ? null : memo ?? this.memo,
      tags: tags ?? this.tags,
      aiScore: clearAi ? null : aiScore ?? this.aiScore,
      aiComment: clearAi ? null : aiComment ?? this.aiComment,
      tryOnImagePath:
          clearTryOn ? null : tryOnImagePath ?? this.tryOnImagePath,
      tryOnBodyType: clearTryOn ? null : tryOnBodyType ?? this.tryOnBodyType,
      tryOnRegenCount: tryOnRegenCount ?? this.tryOnRegenCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'rawImagePath': rawImagePath,
      'memo': memo,
      'tags': tags,
      'aiScore': aiScore,
      'aiComment': aiComment,
      'tryOnImagePath': tryOnImagePath,
      'tryOnBodyType': tryOnBodyType,
      'tryOnRegenCount': tryOnRegenCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory OutfitSnapshot.fromJson(Map<String, dynamic> json) {
    return OutfitSnapshot(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      rawImagePath: json['rawImagePath'] as String?,
      memo: json['memo'] as String?,
      tags: ((json['tags'] as List<dynamic>?) ?? const [])
          .map((value) => value as String)
          .toList(),
      aiScore: json['aiScore'] as int?,
      aiComment: json['aiComment'] as String?,
      tryOnImagePath: json['tryOnImagePath'] as String?,
      tryOnBodyType: json['tryOnBodyType'] as String?,
      tryOnRegenCount: (json['tryOnRegenCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
