import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kirana_survey/core/brand_theme.dart';
import 'package:kirana_survey/pages/admin_dashboard_page.dart';
import 'package:kirana_survey/pages/survey_page.dart';

class KiranaSurveyApp extends StatelessWidget {
  const KiranaSurveyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lohiya Kirana Survey',
      debugShowCheckedModeBanner: false,
      theme: buildBrandTheme(),
      initialRoute: kIsWeb ? '/admin' : '/survey',
      routes: {
        '/survey': (_) => const SurveyPage(),
        '/admin': (_) => const AdminDashboardPage(),
      },
    );
  }
}
