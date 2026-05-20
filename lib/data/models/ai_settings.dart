enum AiEngineMode {
  off('off'),
  mock('mock'),
  localGemma('localGemma'),
  openAi('openAi');

  const AiEngineMode(this.value);

  final String value;

  static AiEngineMode fromValue(String? value) {
    return AiEngineMode.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => AiEngineMode.mock,
    );
  }
}

class AiSettings {
  const AiSettings({
    required this.mode,
    required this.allowCloudAnalysis,
    this.openAiProxyUrl,
    this.localModelPath,
    this.localModelName,
    required this.updatedAt,
  });

  factory AiSettings.defaults() {
    return AiSettings(
      mode: AiEngineMode.mock,
      allowCloudAnalysis: false,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final AiEngineMode mode;
  final bool allowCloudAnalysis;
  final String? openAiProxyUrl;
  final String? localModelPath;
  final String? localModelName;
  final DateTime updatedAt;

  AiSettings copyWith({
    AiEngineMode? mode,
    bool? allowCloudAnalysis,
    String? openAiProxyUrl,
    String? localModelPath,
    String? localModelName,
    DateTime? updatedAt,
    bool clearOpenAiProxyUrl = false,
    bool clearLocalModelPath = false,
    bool clearLocalModelName = false,
  }) {
    return AiSettings(
      mode: mode ?? this.mode,
      allowCloudAnalysis: allowCloudAnalysis ?? this.allowCloudAnalysis,
      openAiProxyUrl:
          clearOpenAiProxyUrl ? null : openAiProxyUrl ?? this.openAiProxyUrl,
      localModelPath:
          clearLocalModelPath ? null : localModelPath ?? this.localModelPath,
      localModelName:
          clearLocalModelName ? null : localModelName ?? this.localModelName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.value,
      'allowCloudAnalysis': allowCloudAnalysis,
      'openAiProxyUrl': openAiProxyUrl,
      'localModelPath': localModelPath,
      'localModelName': localModelName,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    return AiSettings(
      mode: AiEngineMode.fromValue(json['mode'] as String?),
      allowCloudAnalysis: json['allowCloudAnalysis'] as bool? ?? false,
      openAiProxyUrl: json['openAiProxyUrl'] as String?,
      localModelPath: json['localModelPath'] as String?,
      localModelName: json['localModelName'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
