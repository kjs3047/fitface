import '../../core/constants/storage_keys.dart';
import '../local/local_file_storage.dart';
import '../models/personal_color_result.dart';

class PersonalColorRepository {
  PersonalColorRepository(this._storage);

  final LocalFileStorage _storage;

  Future<PersonalColorResult?> loadResult() async {
    final json =
        await _storage.readJsonMap(StorageKeys.personalColorResultJson);
    if (json == null) {
      return null;
    }
    return PersonalColorResult.fromJson(json);
  }

  Future<PersonalColorResult> saveResult(PersonalColorResult result) async {
    await _storage.writeJsonMap(
      StorageKeys.personalColorResultJson,
      result.toJson(),
    );
    return result;
  }

  Future<void> clearResult() async {
    await _storage.deleteMetadata(StorageKeys.personalColorResultJson);
  }
}
