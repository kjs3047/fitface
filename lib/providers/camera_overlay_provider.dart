import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../data/models/overlay_preset.dart';
import '../data/repositories/preset_repository.dart';
import 'repository_provider.dart';

final cameraOverlayProvider =
    StateNotifierProvider<CameraOverlayNotifier, CameraOverlayState>((ref) {
  return CameraOverlayNotifier(ref.watch(presetRepositoryProvider));
});

class CameraOverlayState {
  const CameraOverlayState({
    required this.position,
    required this.scale,
    required this.opacity,
  });

  factory CameraOverlayState.defaults() {
    return const CameraOverlayState(
      position: Offset.zero,
      scale: AppConstants.defaultOverlayScale,
      opacity: AppConstants.defaultOverlayOpacity,
    );
  }

  final Offset position;
  final double scale;
  final double opacity;

  CameraOverlayState copyWith({
    Offset? position,
    double? scale,
    double? opacity,
  }) {
    return CameraOverlayState(
      position: position ?? this.position,
      scale: scale ?? this.scale,
      opacity: opacity ?? this.opacity,
    );
  }
}

class CameraOverlayNotifier extends StateNotifier<CameraOverlayState> {
  CameraOverlayNotifier(this._repository)
      : super(CameraOverlayState.defaults()) {
    loadPreset();
  }

  final PresetRepository _repository;

  /// 제스처/슬라이더는 초당 수십 번 상태를 바꾸므로 매번 디스크에 쓰지 않고
  /// 마지막 변경만 묶어서 저장한다.
  static const _saveDebounce = Duration(milliseconds: 600);
  Timer? _saveTimer;

  Future<void> loadPreset() async {
    final preset = await _repository.loadPreset();
    if (preset == null) {
      return;
    }
    state = CameraOverlayState(
      position: Offset(preset.positionX, preset.positionY),
      scale: preset.scale
          .clamp(
            AppConstants.minOverlayScale,
            AppConstants.maxOverlayScale,
          )
          .toDouble(),
      opacity: preset.opacity
          .clamp(
            AppConstants.minOverlayOpacity,
            AppConstants.maxOverlayOpacity,
          )
          .toDouble(),
    );
  }

  Future<void> savePreset() async {
    await _repository.savePreset(
      OverlayPreset(
        id: 'default',
        positionX: state.position.dx,
        positionY: state.position.dy,
        scale: state.scale,
        opacity: state.opacity,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, () {
      // 본문이 mounted 여부와 무관하게 실행될 수 있으므로 결과는 무시한다.
      savePreset();
    });
  }

  void moveBy(Offset delta) {
    state = state.copyWith(position: state.position + delta);
    _scheduleSave();
  }

  void setTransform({
    required Offset position,
    required double scale,
  }) {
    state = state.copyWith(
      position: position,
      scale: scale
          .clamp(
            AppConstants.minOverlayScale,
            AppConstants.maxOverlayScale,
          )
          .toDouble(),
    );
    _scheduleSave();
  }

  void setOpacity(double opacity) {
    state = state.copyWith(
      opacity: opacity
          .clamp(
            AppConstants.minOverlayOpacity,
            AppConstants.maxOverlayOpacity,
          )
          .toDouble(),
    );
    _scheduleSave();
  }

  Future<void> reset() async {
    _saveTimer?.cancel();
    state = CameraOverlayState.defaults();
    await _repository.saveDefaultPreset();
  }

  @override
  void dispose() {
    // 이 Provider는 앱 생애 동안 유지되어 디바운스 타이머가 거의 항상 먼저
    // 발사되므로, dispose에서는 보류 중인 저장 타이머만 취소한다.
    // (dispose 후 비동기 write를 시작하면 저장소 정리와 충돌할 수 있다.)
    _saveTimer?.cancel();
    _saveTimer = null;
    super.dispose();
  }
}
