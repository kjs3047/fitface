import 'package:flutter/material.dart';

import '../screens/camera_match/camera_match_screen.dart';
import '../screens/compare/compare_screen.dart';
import '../screens/compare/snapshot_detail_screen.dart';
import '../screens/face_register/face_capture_screen.dart';
import '../screens/face_register/face_crop_screen.dart';
import '../screens/face_register/face_preview_screen.dart';
import '../screens/face_register/face_register_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/personal_color/personal_color_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/splash/splash_screen.dart';
import 'route_names.dart';

class FacePreviewArgs {
  const FacePreviewArgs({
    required this.originalImagePath,
    required this.croppedImagePath,
  });

  final String originalImagePath;
  final String croppedImagePath;
}

class AppRoutes {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) {
        switch (settings.name) {
          case RouteNames.splash:
            return const SplashScreen();
          case RouteNames.onboarding:
            return const OnboardingScreen();
          case RouteNames.faceRegister:
            return const FaceRegisterScreen();
          case RouteNames.faceCapture:
            return const FaceCaptureScreen();
          case RouteNames.faceCrop:
            return FaceCropScreen(imagePath: settings.arguments! as String);
          case RouteNames.facePreview:
            return FacePreviewScreen(
              args: settings.arguments! as FacePreviewArgs,
            );
          case RouteNames.cameraMatch:
            return const CameraMatchScreen();
          case RouteNames.compare:
            return const CompareScreen();
          case RouteNames.snapshotDetail:
            return SnapshotDetailScreen(
              snapshotId: settings.arguments! as String,
            );
          case RouteNames.personalColor:
            return const PersonalColorScreen();
          case RouteNames.settings:
            return const SettingsScreen();
          default:
            return const OnboardingScreen();
        }
      },
    );
  }
}
