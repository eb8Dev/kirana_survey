import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class SurveySessionRef {
  const SurveySessionRef({
    required this.surveyorDocumentId,
    required this.sessionId,
  });

  final String surveyorDocumentId;
  final String sessionId;
}

class SurveyRepository {
  SurveyRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _surveyors =>
      _firestore.collection('surveyors');

  static String buildSurveyorDocumentId(String surveyorName) {
    return _slugify(surveyorName);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSubmittedSessions() {
    return _firestore.collectionGroup('surveys').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSurveyorSessions(
    String surveyorDocumentId,
  ) {
    return _surveyors.doc(surveyorDocumentId).collection('surveys').snapshots();
  }

  Future<SurveySessionRef> createSession({
    required String userId,
    required String surveyorName,
    required String storeName,
    required String storeLocation,
    required Map<String, dynamic> locationCapture,
    required int totalQuestions,
  }) async {
    final surveyorDocumentId = buildSurveyorDocumentId(surveyorName);
    final sessionId = _buildSessionId(
      surveyorName: surveyorName,
      storeName: storeName,
    );

    await _surveyors.doc(surveyorDocumentId).set({
      'surveyorName': surveyorName,
      'surveyorDocumentId': surveyorDocumentId,
      'userId': userId,
      'platform': _platformLabel,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _surveyors
        .doc(surveyorDocumentId)
        .collection('surveys')
        .doc(sessionId)
        .set({
          'sessionId': sessionId,
          'surveyorDocumentId': surveyorDocumentId,
          'surveyorName': surveyorName,
          'userId': userId,
          'storeName': storeName,
          'storeLocation': storeLocation,
          'locationCapture': locationCapture,
          'status': 'draft',
          'surveyVersion': 'v3',
          'totalQuestions': totalQuestions,
          'responseCount': 0,
          'completionRatio': 0.0,
          'responses': <String, dynamic>{},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'platform': _platformLabel,
        });

    return SurveySessionRef(
      surveyorDocumentId: surveyorDocumentId,
      sessionId: sessionId,
    );
  }

  Future<void> saveDraft({
    required String surveyorDocumentId,
    required String sessionId,
    required Map<String, dynamic> payload,
  }) {
    return _surveyors
        .doc(surveyorDocumentId)
        .collection('surveys')
        .doc(sessionId)
        .set({
          ...payload,
          'status': 'draft',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> submit({
    required String surveyorDocumentId,
    required String sessionId,
    required Map<String, dynamic> payload,
  }) async {
    await _surveyors
        .doc(surveyorDocumentId)
        .collection('surveys')
        .doc(sessionId)
        .set({
          ...payload,
          'status': 'submitted',
          'submittedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    await _surveyors.doc(surveyorDocumentId).set({
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSubmittedAt': FieldValue.serverTimestamp(),
      'lastSessionId': sessionId,
    }, SetOptions(merge: true));
  }

  static String _buildSessionId({
    required String surveyorName,
    required String storeName,
  }) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return '${_slugify(surveyorName)}_${_slugify(storeName)}_$timestamp';
  }

  static String _slugify(String value) {
    final normalized = value.trim().toLowerCase();
    final slug = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return slug.isEmpty ? 'unknown' : slug;
  }

  String get _platformLabel {
    if (kIsWeb) {
      return 'web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }
}
