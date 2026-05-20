class FitFaceDateUtils {
  static String fileStamp(DateTime value) {
    return value.toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
  }
}
