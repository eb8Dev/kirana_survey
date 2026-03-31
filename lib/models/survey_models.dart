enum QuestionType { singleSelect, multiSelect, scale, rankTop3, openText }

enum QuestionMode { survey, interviewProbe }

class SurveyStage {
  const SurveyStage({
    required this.number,
    required this.title,
    required this.description,
  });

  final int number;
  final String title;
  final String description;
}

class SurveyQuestion {
  const SurveyQuestion({
    required this.id,
    required this.stageNumber,
    required this.stageLabel,
    required this.mode,
    required this.section,
    required this.prompt,
    required this.type,
    this.options = const <String>[],
    this.helperText,
  });

  final String id;
  final int stageNumber;
  final String stageLabel;
  final QuestionMode mode;
  final String section;
  final String prompt;
  final QuestionType type;
  final List<String> options;
  final String? helperText;
}

class QuestionAssessment {
  const QuestionAssessment({
    this.customerRating,
    this.businessImpact,
    this.aiFit,
  });

  final int? customerRating;
  final int? businessImpact;
  final int? aiFit;

  bool get isComplete =>
      customerRating != null && businessImpact != null && aiFit != null;

  double? get weightedScore {
    if (!isComplete) {
      return null;
    }

    return (customerRating! * 0.45) +
        (businessImpact! * 0.35) +
        (aiFit! * 0.20);
  }

  String? get priorityBucket {
    final score = weightedScore;
    if (score == null) {
      return null;
    }
    if (score >= 4.2) {
      return 'P1 - Immediate';
    }
    if (score >= 3.4) {
      return 'P2 - Near Term';
    }
    if (score >= 2.5) {
      return 'P3 - Observe';
    }
    return 'P4 - Later';
  }

  String? get recommendedAction {
    final bucket = priorityBucket;
    if (bucket == null) {
      return null;
    }
    return bucket == 'P1 - Immediate' || bucket == 'P2 - Near Term'
        ? 'Discuss for MVP / Pilot'
        : 'Keep for later phase';
  }

  QuestionAssessment copyWith({
    int? customerRating,
    int? businessImpact,
    int? aiFit,
  }) {
    return QuestionAssessment(
      customerRating: customerRating ?? this.customerRating,
      businessImpact: businessImpact ?? this.businessImpact,
      aiFit: aiFit ?? this.aiFit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerRating': customerRating,
      'businessImpact': businessImpact,
      'aiFit': aiFit,
      'weightedScore': weightedScore,
      'priorityBucket': priorityBucket,
      'recommendedAction': recommendedAction,
    };
  }
}
