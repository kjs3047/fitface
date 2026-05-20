import 'background_removal_service.dart';

class MockBackgroundRemovalService implements BackgroundRemovalService {
  @override
  Future<String> removeBackground(String inputImagePath) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return inputImagePath;
  }
}
