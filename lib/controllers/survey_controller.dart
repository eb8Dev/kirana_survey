import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:kirana_survey/data/survey_definition.dart';
import 'package:kirana_survey/models/survey_models.dart';
import 'package:kirana_survey/services/auth_service.dart';
import 'package:kirana_survey/services/device_location_service.dart';
import 'package:kirana_survey/services/remote_config_service.dart';
import 'package:kirana_survey/services/survey_repository.dart';
import 'package:kirana_survey/services/surveyor_profile_service.dart';

enum SurveyLifecycle {
  loading,
  inactive,
  awaitingSurveyorName,
  awaitingSurveyStart,
  ready,
  submitting,
  submitted,
  error,
}

class SurveyController extends ChangeNotifier {
  SurveyController({
    required AuthService authService,
    required SurveyRepository repository,
    required SurveyorProfileService surveyorProfileService,
    required DeviceLocationService deviceLocationService,
    required RemoteConfigService remoteConfigService,
  }) : _authService = authService,
       _repository = repository,
       _surveyorProfileService = surveyorProfileService,
       _deviceLocationService = deviceLocationService,
       _remoteConfigService = remoteConfigService;

  final AuthService _authService;
  final SurveyRepository _repository;
  final SurveyorProfileService _surveyorProfileService;
  final DeviceLocationService _deviceLocationService;
  final RemoteConfigService _remoteConfigService;

  final Map<String, Object?> _answers = <String, Object?>{};
  final Map<String, QuestionAssessment> _assessments =
      <String, QuestionAssessment>{};

  SurveyLifecycle _lifecycle = SurveyLifecycle.loading;
  int _currentQuestionIndex = 0;
  String? _sessionId;
  String? _surveyorDocumentId;
  String? _userId;
  String? _surveyorName;
  String? _storeName;
  String? _storeLocation;
  CapturedSurveyLocation? _capturedLocation;
  String? _errorMessage;
  DateTime? _lastSavedAt;
  Timer? _autosaveTimer;
  bool _isSaving = false;

  SurveyLifecycle get lifecycle => _lifecycle;
  int get currentQuestionIndex => _currentQuestionIndex;
  String? get errorMessage => _errorMessage;
  DateTime? get lastSavedAt => _lastSavedAt;
  String? get sessionId => _sessionId;
  String? get surveyorName => _surveyorName;
  String? get surveyorDocumentId => _surveyorDocumentId;
  String? get storeName => _storeName;
  String? get storeLocation => _storeLocation;
  CapturedSurveyLocation? get capturedLocation => _capturedLocation;
  bool get isReady => _lifecycle == SurveyLifecycle.ready;
  bool get isSubmitted => _lifecycle == SurveyLifecycle.submitted;
  bool get needsSurveyorName =>
      _lifecycle == SurveyLifecycle.awaitingSurveyorName;
  bool get needsSurveyStart =>
      _lifecycle == SurveyLifecycle.awaitingSurveyStart;
  bool get isActive => _remoteConfigService.isActive;
  bool get scoringEnabled => _remoteConfigService.scoringEnabled;
  bool get isBusy =>
      _lifecycle == SurveyLifecycle.loading ||
      _lifecycle == SurveyLifecycle.submitting;

  List<SurveyQuestion> get questions => surveyQuestions;
  SurveyQuestion get currentQuestion => questions[_currentQuestionIndex];
  SurveyStage get currentStage => surveyStages.firstWhere(
    (stage) => stage.number == currentQuestion.stageNumber,
  );
  int get answeredCount =>
      questions.where((question) => hasAnswer(question.id)).length;

  Object? answerFor(String questionId) => _answers[questionId];
  QuestionAssessment assessmentFor(String questionId) =>
      _assessments[questionId] ?? const QuestionAssessment();

  bool hasAnswer(String questionId) {
    final value = _answers[questionId];
    if (value == null) {
      return false;
    }
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    if (value is List) {
      return value.isNotEmpty;
    }
    return true;
  }

  Future<void> initialize() async {
    _lifecycle = SurveyLifecycle.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _remoteConfigService.initialize();
      if (!_remoteConfigService.isActive) {
        _lifecycle = SurveyLifecycle.inactive;
        notifyListeners();
        return;
      }

      final user = await _authService.ensureAnonymousSession();
      _userId = user.uid;
      _surveyorName = await _surveyorProfileService.loadSurveyorName();
      _surveyorDocumentId = _surveyorName == null
          ? null
          : SurveyRepository.buildSurveyorDocumentId(_surveyorName!);

      _lifecycle = _surveyorName == null
          ? SurveyLifecycle.awaitingSurveyorName
          : SurveyLifecycle.awaitingSurveyStart;
    } catch (error) {
      _lifecycle = SurveyLifecycle.error;
      _errorMessage = _friendlyErrorMessage(error);
    }

    notifyListeners();
  }

  Future<String?> saveSurveyorName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'Please enter the surveyor name to continue.';
    }

    try {
      await _surveyorProfileService.saveSurveyorName(trimmed);
      _surveyorName = trimmed;
      _surveyorDocumentId = SurveyRepository.buildSurveyorDocumentId(trimmed);
      _lifecycle = SurveyLifecycle.awaitingSurveyStart;
      notifyListeners();
      return null;
    } catch (error) {
      _lifecycle = SurveyLifecycle.error;
      _errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
      return _errorMessage;
    }
  }

  Future<String?> beginSurvey({required String storeName}) async {
    final trimmedStoreName = storeName.trim();

    if (trimmedStoreName.isEmpty) {
      return 'Please enter the store name.';
    }

    if (_surveyorName == null || _userId == null) {
      return 'Surveyor profile is not ready yet.';
    }

    _lifecycle = SurveyLifecycle.loading;
    _errorMessage = null;
    _answers.clear();
    _assessments.clear();
    _currentQuestionIndex = 0;
    _lastSavedAt = null;
    notifyListeners();

    try {
      final capturedLocation = await _deviceLocationService
          .captureCurrentLocation();
      _storeName = trimmedStoreName;
      _capturedLocation = capturedLocation;
      _storeLocation = capturedLocation.label;
      await _createFreshSession();
      return null;
    } catch (error) {
      _lifecycle = SurveyLifecycle.error;
      _errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
      return _errorMessage;
    }
  }

  Future<String?> startAnotherSurvey() async {
    _sessionId = null;
    _storeName = null;
    _storeLocation = null;
    _capturedLocation = null;
    _answers.clear();
    _assessments.clear();
    _currentQuestionIndex = 0;
    _lastSavedAt = null;
    _errorMessage = null;
    _lifecycle = _surveyorName == null
        ? SurveyLifecycle.awaitingSurveyorName
        : SurveyLifecycle.awaitingSurveyStart;
    notifyListeners();
    return null;
  }

  Future<void> clearSurveyorProfile() async {
    await _surveyorProfileService.clearSurveyorName();
    _surveyorName = null;
    _surveyorDocumentId = null;
    await startAnotherSurvey();
  }

  Future<void> goPrevious() async {
    if (_currentQuestionIndex == 0 || isBusy) {
      return;
    }

    await _saveDraft();
    _currentQuestionIndex -= 1;
    notifyListeners();
  }

  Future<String?> goNext() async {
    if (isBusy) {
      return null;
    }

    final validation = validateQuestion(currentQuestion);
    if (validation != null) {
      return validation;
    }

    await _saveDraft();
    if (_currentQuestionIndex < questions.length - 1) {
      _currentQuestionIndex += 1;
      notifyListeners();
    }
    return null;
  }

  Future<String?> submit() async {
    final validation = validateQuestion(currentQuestion);
    if (validation != null) {
      return validation;
    }

    _autosaveTimer?.cancel();
    _lifecycle = SurveyLifecycle.submitting;
    notifyListeners();

    try {
      await _repository.submit(
        surveyorDocumentId: _surveyorDocumentId!,
        sessionId: _sessionId!,
        payload: _buildPersistencePayload(),
      );
      _lifecycle = SurveyLifecycle.submitted;
      _errorMessage = null;
    } catch (error) {
      _lifecycle = SurveyLifecycle.error;
      _errorMessage = _friendlyErrorMessage(error);
    }

    notifyListeners();
    return _errorMessage;
  }

  void updateAnswer(SurveyQuestion question, Object? value) {
    if (value == null) {
      _answers.remove(question.id);
    } else {
      _answers[question.id] = value;
    }

    notifyListeners();
    _scheduleAutosave();
  }

  void updateAssessment(
    SurveyQuestion question, {
    int? customerRating,
    int? businessImpact,
    int? aiFit,
  }) {
    final current = assessmentFor(question.id);
    _assessments[question.id] = current.copyWith(
      customerRating: customerRating,
      businessImpact: businessImpact,
      aiFit: aiFit,
    );

    notifyListeners();
    _scheduleAutosave();
  }

  String? validateQuestion(SurveyQuestion question) {
    final value = _answers[question.id];
    switch (question.type) {
      case QuestionType.singleSelect:
      case QuestionType.openText:
        if (value is! String || value.trim().isEmpty) {
          return 'Please answer this question before continuing.';
        }
        break;
      case QuestionType.multiSelect:
        if (value is! List || value.isEmpty) {
          return 'Please choose at least one option.';
        }
        break;
      case QuestionType.scale:
        if (value is! int) {
          return 'Please select a rating from 1 to 5.';
        }
        break;
      case QuestionType.rankTop3:
        if (value is! List || value.length != 3) {
          return 'Please select exactly three priorities in rank order.';
        }
        break;
    }

    if (scoringEnabled && !assessmentFor(question.id).isComplete) {
      return 'Please complete customer rating, business impact, and AI fit before continuing.';
    }

    return null;
  }

  int answeredInStage(int stageNumber) => questions
      .where((question) => question.stageNumber == stageNumber)
      .where((question) => hasAnswer(question.id))
      .length;

  int totalInStage(int stageNumber) =>
      questions.where((question) => question.stageNumber == stageNumber).length;

  Future<void> _createFreshSession() async {
    final surveyorName = _surveyorName;
    final storeName = _storeName;
    final storeLocation = _storeLocation;
    final capturedLocation = _capturedLocation;
    final userId = _userId;
    if (surveyorName == null ||
        storeName == null ||
        storeLocation == null ||
        capturedLocation == null ||
        userId == null) {
      throw StateError('Survey session context is incomplete.');
    }

    final ref = await _repository.createSession(
      userId: userId,
      surveyorName: surveyorName,
      storeName: storeName,
      storeLocation: storeLocation,
      locationCapture: capturedLocation.toMap(),
      totalQuestions: questions.length,
    );
    _surveyorDocumentId = ref.surveyorDocumentId;
    _sessionId = ref.sessionId;
    _lifecycle = SurveyLifecycle.ready;
    notifyListeners();
  }

  Future<void> _saveDraft() async {
    if (!isReady ||
        _surveyorDocumentId == null ||
        _sessionId == null ||
        _isSaving) {
      return;
    }

    _autosaveTimer?.cancel();
    _isSaving = true;
    notifyListeners();

    try {
      await _repository.saveDraft(
        surveyorDocumentId: _surveyorDocumentId!,
        sessionId: _sessionId!,
        payload: _buildPersistencePayload(),
      );
      _lastSavedAt = DateTime.now();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _scheduleAutosave() {
    if (!isReady) {
      return;
    }

    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 500), () async {
      await _saveDraft();
    });
  }

  Map<String, dynamic> _buildPersistencePayload() {
    final responses = <String, dynamic>{};
    var totalWeightedScore = 0.0;
    var weightedScoreCount = 0;

    for (final question in questions) {
      if (!hasAnswer(question.id)) {
        continue;
      }

      final assessment = assessmentFor(question.id);
      final weightedScore = assessment.weightedScore;
      if (weightedScore != null) {
        totalWeightedScore += weightedScore;
        weightedScoreCount += 1;
      }

      responses[question.id] = {
        'stageNumber': question.stageNumber,
        'stageLabel': question.stageLabel,
        'mode': question.mode.name,
        'section': question.section,
        'prompt': question.prompt,
        'type': question.type.name,
        'answer': _answers[question.id],
        if (scoringEnabled) 'assessment': assessment.toMap(),
      };
    }

    final averageWeightedScore = weightedScoreCount == 0
        ? null
        : totalWeightedScore / weightedScoreCount;

    return {
      'sessionId': _sessionId,
      'surveyorDocumentId': _surveyorDocumentId,
      'surveyorName': _surveyorName,
      'userId': _userId,
      'storeName': _storeName,
      'storeLocation': _storeLocation,
      'locationCapture': _capturedLocation?.toMap(),
      'currentQuestionIndex': _currentQuestionIndex,
      'currentQuestionId': currentQuestion.id,
      'currentStage': currentQuestion.stageNumber,
      'responseCount': responses.length,
      'completionRatio': responses.length / questions.length,
      'averageWeightedScore': averageWeightedScore,
      'scoringEnabled': scoringEnabled,
      'responses': responses,
      'stageProgress': {
        for (final stage in surveyStages)
          'stage_${stage.number}': {
            'answered': answeredInStage(stage.number),
            'total': totalInStage(stage.number),
            'title': stage.title,
          },
      },
    };
  }

  String _friendlyErrorMessage(Object error) {
    if (error is FirebaseException) {
      if (error.plugin == 'cloud_firestore' && error.code == 'not-found') {
        return 'Cloud Firestore is not created for project "kirana-survey" yet. '
            'Open Firebase Console or Google Cloud Console, create the default '
            'Firestore database, then run the app again.';
      }

      if (error.plugin == 'cloud_firestore' &&
          error.code == 'permission-denied') {
        return 'Cloud Firestore denied access. Check your Firestore rules and '
            'make sure anonymous users are allowed to write survey sessions.';
      }

      if (error.plugin == 'cloud_firestore' && error.code == 'unavailable') {
        return 'Cloud Firestore is temporarily unavailable. Please check the '
            'network connection and try again.';
      }

      if (error.plugin == 'firebase_auth') {
        return 'Anonymous sign-in failed. Please confirm Anonymous auth is '
            'enabled in Firebase Authentication.';
      }

      if (error.plugin == 'firebase_remote_config') {
        return 'Remote Config could not be fetched. Please check Firebase setup and try again.';
      }
    }

    return error.toString();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }
}
