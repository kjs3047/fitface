class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SnapshotLimitException extends AppException {
  const SnapshotLimitException() : super('저장 가능한 후보는 최대 3개입니다. 기존 후보를 교체해주세요.');
}
