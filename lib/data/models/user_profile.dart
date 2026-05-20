class UserProfile {
  const UserProfile({
    required this.id,
    this.originalFaceImagePath,
    this.croppedFaceImagePath,
    this.overlayFaceImagePath,
    this.personalColorType,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? originalFaceImagePath;
  final String? croppedFaceImagePath;
  final String? overlayFaceImagePath;
  final String? personalColorType;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile copyWith({
    String? id,
    String? originalFaceImagePath,
    String? croppedFaceImagePath,
    String? overlayFaceImagePath,
    String? personalColorType,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearOriginalFaceImagePath = false,
    bool clearCroppedFaceImagePath = false,
    bool clearOverlayFaceImagePath = false,
    bool clearPersonalColorType = false,
  }) {
    return UserProfile(
      id: id ?? this.id,
      originalFaceImagePath: clearOriginalFaceImagePath
          ? null
          : originalFaceImagePath ?? this.originalFaceImagePath,
      croppedFaceImagePath: clearCroppedFaceImagePath
          ? null
          : croppedFaceImagePath ?? this.croppedFaceImagePath,
      overlayFaceImagePath: clearOverlayFaceImagePath
          ? null
          : overlayFaceImagePath ?? this.overlayFaceImagePath,
      personalColorType: clearPersonalColorType
          ? null
          : personalColorType ?? this.personalColorType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalFaceImagePath': originalFaceImagePath,
      'croppedFaceImagePath': croppedFaceImagePath,
      'overlayFaceImagePath': overlayFaceImagePath,
      'personalColorType': personalColorType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      originalFaceImagePath: json['originalFaceImagePath'] as String?,
      croppedFaceImagePath: json['croppedFaceImagePath'] as String?,
      overlayFaceImagePath: json['overlayFaceImagePath'] as String?,
      personalColorType: json['personalColorType'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
