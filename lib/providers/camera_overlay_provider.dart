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

  void moveBy(Offset delta) {
    state = state.copyWith(position: state.position + delta);
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
  }

  Future<void> reset() async {
    state = CameraOverlayState.defaults();
    await _repository.saveDefaultPreset();
  }
}
