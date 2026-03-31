import 'package:flutter_test/flutter_test.dart';
import 'package:kirana_survey/data/survey_definition.dart';

void main() {
  test('survey definition includes all 7 stages and 55 questions', () {
    expect(surveyStages.length, 7);
    expect(surveyQuestions.length, 55);
  });
}
