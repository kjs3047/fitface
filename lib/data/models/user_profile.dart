import '../../domain/profile/body_type.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    this.originalFaceImagePath,
    this.croppedFaceImagePath,
    this.overlayFaceImagePath,
    this.personalColorType,
    this.gender,
    this.bodyType,
    this.heightCm,
    this.weightKg,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? originalFaceImagePath;
  final String? croppedFaceImagePath;
  final String? overlayFaceImagePath;
  final String? personalColorType;

  /// 가상착장용 신체 정보 (전부 nullable, 미등록 허용).
  final Gender? gender;
  final BodyType? bodyType;
  final int? heightCm;
  final int? weightKg;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// 가상착장에 필요한 최소 신체 정보(체형)가 등록돼 있는가.
  bool get hasBodyInfo => bodyType != null;

  UserProfile copyWith({
    String? id,
    String? originalFaceImagePath,
    String? croppedFaceImagePath,
    String? overlayFaceImagePath,
    String? personalColorType,
    Gender? gender,
    BodyType? bodyType,
    int? heightCm,
    int? weightKg,
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
      gender: gender ?? this.gender,
      bodyType: bodyType ?? this.bodyType,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
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
      'gender': gender?.name,
      'bodyType': bodyType?.name,
      'heightCm': heightCm,
      'weightKg': weightKg,
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
      gender: Gender.fromName(json['gender'] as String?),
      bodyType: BodyType.fromName(json['bodyType'] as String?),
      heightCm: (json['heightCm'] as num?)?.toInt(),
      weightKg: (json['weightKg'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
