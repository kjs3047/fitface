import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'presentation/routes/app_routes.dart';
import 'presentation/routes/route_names.dart';

class FitFaceApp extends StatelessWidget {
  const FitFaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitFace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: RouteNames.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
