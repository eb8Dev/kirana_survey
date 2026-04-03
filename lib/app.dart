import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kirana_survey/core/brand_theme.dart';
import 'package:kirana_survey/pages/admin_analytics_page.dart';
import 'package:kirana_survey/pages/admin_dashboard_page.dart';
import 'package:kirana_survey/pages/admin_login_page.dart';
import 'package:kirana_survey/pages/survey_page.dart';
import 'package:kirana_survey/services/admin_auth_service.dart';

class KiranaSurveyApp extends StatelessWidget {
  const KiranaSurveyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lohiya Kirana Survey',
      debugShowCheckedModeBanner: false,
      theme: buildBrandTheme(),
      initialRoute: kIsWeb ? '/admin-login' : '/survey',
      routes: {
        '/survey': (_) => const SurveyPage(),
        '/admin-login': (_) => const AdminLoginPage(),
        '/admin': (_) => const _AdminGuard(child: AdminDashboardPage()),
        '/admin/analytics': (_) =>
            const _AdminGuard(child: AdminAnalyticsPage()),
      },
    );
  }
}

class _AdminGuard extends StatelessWidget {
  const _AdminGuard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AdminAuthService.instance.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: BrandColors.primary),
            ),
          );
        }

        if (snapshot.data == true) {
          return child;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.of(context).pushReplacementNamed('/admin-login');
          }
        });

        return const Scaffold(body: SizedBox.shrink());
      },
    );
  }
}
