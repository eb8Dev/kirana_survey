import 'package:shared_preferences/shared_preferences.dart';

class SurveyorProfileService {
  static const _surveyorNameKey = 'surveyor_name';

  Future<String?> loadSurveyorName() async {
    final preferences = await SharedPreferences.getInstance();
    final name = preferences.getString(_surveyorNameKey)?.trim();
    if (name == null || name.isEmpty) {
      return null;
    }
    return name;
  }

  Future<void> saveSurveyorName(String name) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_surveyorNameKey, name.trim());
  }

  Future<void> clearSurveyorName() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_surveyorNameKey);
  }
}
