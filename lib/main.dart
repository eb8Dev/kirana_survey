import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:kirana_survey/app.dart';
import 'package:kirana_survey/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const KiranaSurveyApp());
}
