class CompareSession {
  const CompareSession({
    required this.id,
    required this.snapshotIds,
    this.aiBestSnapshotId,
    required this.createdAt,
  });

  final String id;
  final List<String> snapshotIds;
  final String? aiBestSnapshotId;
  final DateTime createdAt;

  CompareSession copyWith({
    String? id,
    List<String>? snapshotIds,
    String? aiBestSnapshotId,
    DateTime? createdAt,
    bool clearAiBestSnapshotId = false,
  }) {
    return CompareSession(
      id: id ?? this.id,
      snapshotIds: snapshotIds ?? this.snapshotIds,
      aiBestSnapshotId: clearAiBestSnapshotId
          ? null
          : aiBestSnapshotId ?? this.aiBestSnapshotId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'snapshotIds': snapshotIds,
      'aiBestSnapshotId': aiBestSnapshotId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CompareSession.fromJson(Map<String, dynamic> json) {
    return CompareSession(
      id: json['id'] as String,
      snapshotIds: ((json['snapshotIds'] as List<dynamic>?) ?? const [])
          .map((value) => value as String)
          .toList(),
      aiBestSnapshotId: json['aiBestSnapshotId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
