import 'package:shared_preferences/shared_preferences.dart';

class SurveyorProfileService {
  static const _surveyorNameKey = 'surveyor_name';
  static const _surveyorPhoneKey = 'surveyor_phone';

  Future<String?> loadSurveyorName() async {
    final preferences = await SharedPreferences.getInstance();
    final name = preferences.getString(_surveyorNameKey)?.trim();
    if (name == null || name.isEmpty) {
      return null;
    }
    return name;
  }

  Future<String?> loadSurveyorPhoneNumber() async {
    final preferences = await SharedPreferences.getInstance();
    final phone = preferences.getString(_surveyorPhoneKey)?.trim();
    if (phone == null || phone.isEmpty) {
      return null;
    }
    return phone;
  }

  Future<void> saveSurveyorProfile(String name, String phoneNumber) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_surveyorNameKey, name.trim());
    await preferences.setString(_surveyorPhoneKey, phoneNumber.trim());
  }

  Future<void> clearSurveyorProfile() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_surveyorNameKey);
    await preferences.remove(_surveyorPhoneKey);
  }
}
