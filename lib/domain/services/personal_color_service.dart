import '../../data/models/personal_color_result.dart';

abstract class PersonalColorService {
  Future<PersonalColorResult> analyze({String? faceImagePath});
}
