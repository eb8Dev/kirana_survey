import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kirana_survey/core/brand_theme.dart';
import 'package:kirana_survey/core/download_utils.dart';
import 'package:kirana_survey/data/survey_definition.dart';
import 'package:kirana_survey/models/survey_models.dart';
import 'package:kirana_survey/services/auth_service.dart';
import 'package:kirana_survey/services/survey_repository.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  final SurveyRepository _repository = SurveyRepository(
    FirebaseFirestore.instance,
  );
  final AuthService _authService = AuthService(FirebaseAuth.instance);
  late final Future<User> _authFuture;
  int _selectedSectionIndex = 0;
  int? _selectedQuestionStage;
  QuestionMode? _selectedQuestionMode;

  static const List<_AnalyticsSection> _sections = [
    _AnalyticsSection(
      title: 'Overview',
      subtitle: 'Business snapshot and KPI summary',
      icon: Icons.space_dashboard_rounded,
    ),
    _AnalyticsSection(
      title: 'Surveyors',
      subtitle: 'Team activity and productivity',
      icon: Icons.groups_rounded,
    ),
    _AnalyticsSection(
      title: 'Locations',
      subtitle: 'Outlet coverage and field spread',
      icon: Icons.location_on_rounded,
    ),
    _AnalyticsSection(
      title: 'Questions',
      subtitle: 'Demand signals and response patterns',
      icon: Icons.quiz_rounded,
    ),
    _AnalyticsSection(
      title: 'Top Answers',
      subtitle: 'Most selected answer for every question',
      icon: Icons.emoji_events_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _authFuture = _authService.ensureAnonymousSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<User>(
          future: _authFuture,
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: BrandColors.primary),
              );
            }

            if (authSnapshot.hasError) {
              return _AdminErrorState(
                message: _friendlyAdminError(authSnapshot.error),
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _repository.watchSubmittedSessions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: BrandColors.primary,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _AdminErrorState(
                    message: _friendlyAdminError(snapshot.error),
                  );
                }

                final docs =
                    (snapshot.data?.docs ?? const [])
                        .where((doc) => doc.data()['status'] == 'submitted')
                        .toList()
                      ..sort((a, b) {
                        final aTimestamp =
                            a.data()['submittedAt'] as Timestamp?;
                        final bTimestamp =
                            b.data()['submittedAt'] as Timestamp?;
                        final aMillis = aTimestamp?.millisecondsSinceEpoch ?? 0;
                        final bMillis = bTimestamp?.millisecondsSinceEpoch ?? 0;
                        return bMillis.compareTo(aMillis);
                      });

                final analytics = AdminAnalytics.fromDocuments(docs);

                return Column(
                  children: [
                    _AnalyticsTopBar(
                      onBack: () => Navigator.of(context).pop(),
                      sections: _sections,
                      selectedSectionIndex: _selectedSectionIndex,
                      onSectionSelected: (index) {
                        setState(() {
                          _selectedSectionIndex = index;
                        });
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          child: _AnalyticsSectionView(
                            key: ValueKey(_selectedSectionIndex),
                            sectionIndex: _selectedSectionIndex,
                            analytics: analytics,
                            sections: _sections,
                            selectedQuestionStage: _selectedQuestionStage,
                            selectedQuestionMode: _selectedQuestionMode,
                            onExportTopAnswers: () =>
                                _exportTopAnswersCsv(analytics),
                            onQuestionStageChanged: (value) {
                              setState(() {
                                _selectedQuestionStage = value;
                              });
                            },
                            onQuestionModeChanged: (value) {
                              setState(() {
                                _selectedQuestionMode = value;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _friendlyAdminError(Object? error) {
    if (error is FirebaseException) {
      if (error.plugin == 'firebase_auth') {
        return 'Admin analytics could not create an anonymous session. '
            'Please make sure Anonymous authentication is enabled in Firebase Authentication.';
      }

      if (error.plugin == 'cloud_firestore' &&
          error.code == 'permission-denied') {
        return 'Firestore denied access to the admin analytics page. '
            'Check your Firestore security rules for web reads.';
      }

      if (error.plugin == 'cloud_firestore' &&
          error.code == 'failed-precondition') {
        return 'This Firestore query needs an index. '
            'Open the browser console or Firebase error details to create it.';
      }

      return '${error.plugin}: ${error.message ?? error.code}';
    }

    return '${error ?? 'Unknown admin analytics error'}';
  }

  Future<void> _exportTopAnswersCsv(AdminAnalytics analytics) async {
    final csv = _buildTopAnswersCsv(analytics);
    final fileName =
        'top_answers_export_${DateTime.now().toIso8601String().replaceAll(':', '-')}.csv';
    final downloaded = await downloadCsv(fileName, csv);

    if (!downloaded) {
      await Clipboard.setData(ClipboardData(text: csv));
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          downloaded
              ? 'Download started: $fileName'
              : 'CSV copied to clipboard as fallback. Paste into a file to save it.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _buildTopAnswersCsv(AdminAnalytics analytics) {
    final rows = <List<String>>[
      [
        'Question ID',
        'Stage',
        'Mode',
        'Section',
        'Question',
        'Question Type',
        'Top Answer',
        'Top Answer Count',
        'Total Answered',
      ],
    ];

    for (final questionAnalytics in analytics.questions) {
      final topOption = questionAnalytics.topOption;
      final topTextAnswer = questionAnalytics.topTextAnswer;
      final isOpenText =
          questionAnalytics.question.type == QuestionType.openText;

      rows.add([
        questionAnalytics.question.id,
        'Stage ${questionAnalytics.question.stageNumber}',
        questionAnalytics.question.mode == QuestionMode.survey
            ? 'Survey'
            : 'Interview Probe',
        questionAnalytics.question.section,
        questionAnalytics.question.prompt,
        questionAnalytics.question.type.name,
        isOpenText ? (topTextAnswer ?? '') : (topOption?.option ?? ''),
        isOpenText
            ? '${questionAnalytics.topTextAnswerCount}'
            : '${topOption?.count ?? 0}',
        '${questionAnalytics.totalAnswered}',
      ]);
    }

    return rows.map((row) => row.map(_csvEscape).join(',')).join('\n');
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}

class _AnalyticsTopBar extends StatelessWidget {
  const _AnalyticsTopBar({
    required this.onBack,
    required this.sections,
    required this.selectedSectionIndex,
    required this.onSectionSelected,
  });

  final VoidCallback onBack;
  final List<_AnalyticsSection> sections;
  final int selectedSectionIndex;
  final ValueChanged<int> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: BrandColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                Text('Survey Analytics', style: theme.textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'A sectioned analytics view for clearer presentation and stakeholder walkthroughs.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(sections.length, (index) {
                final section = sections[index];
                final selected = index == selectedSectionIndex;
                return _SectionChip(
                  section: section,
                  selected: selected,
                  onTap: () => onSectionSelected(index),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsSectionView extends StatelessWidget {
  const _AnalyticsSectionView({
    super.key,
    required this.sectionIndex,
    required this.analytics,
    required this.sections,
    required this.selectedQuestionStage,
    required this.selectedQuestionMode,
    required this.onExportTopAnswers,
    required this.onQuestionStageChanged,
    required this.onQuestionModeChanged,
  });

  final int sectionIndex;
  final AdminAnalytics analytics;
  final List<_AnalyticsSection> sections;
  final int? selectedQuestionStage;
  final QuestionMode? selectedQuestionMode;
  final VoidCallback onExportTopAnswers;
  final ValueChanged<int?> onQuestionStageChanged;
  final ValueChanged<QuestionMode?> onQuestionModeChanged;

  @override
  Widget build(BuildContext context) {
    switch (sectionIndex) {
      case 0:
        return ListView(
          children: [
            const SizedBox(height: 20),
            _SectionIntroCard(
              section: sections[0],
              description:
                  'Use this section as the opening slide area: overall coverage, productivity, and scoring quality in one place.',
            ),
            const SizedBox(height: 18),
            _AnalyticsSummaryGrid(analytics: analytics),
            const SizedBox(height: 18),
            _OverviewHighlightsSection(analytics: analytics),
          ],
        );
      case 1:
        return ListView(
          children: [
            const SizedBox(height: 20),
            _SectionIntroCard(
              section: sections[1],
              description:
                  'This section is focused on surveyor performance, store reach, and who is driving the most coverage.',
            ),
            const SizedBox(height: 18),
            _SurveyorAnalyticsSection(analytics: analytics),
          ],
        );
      case 2:
        return ListView(
          children: [
            const SizedBox(height: 20),
            _SectionIntroCard(
              section: sections[2],
              description:
                  'This section summarizes where surveys are being collected and which outlet zones are appearing most often.',
            ),
            const SizedBox(height: 18),
            _LocationAnalyticsSection(analytics: analytics),
          ],
        );
      case 3:
        return ListView(
          children: [
            const SizedBox(height: 20),
            _SectionIntroCard(
              section: sections[3],
              description:
                  'This section helps present recurring responses, high-frequency options, and question-level evidence from the field.',
            ),
            const SizedBox(height: 18),
            _QuestionAnalyticsSection(
              analytics: analytics,
              selectedStage: selectedQuestionStage,
              selectedMode: selectedQuestionMode,
              onStageChanged: onQuestionStageChanged,
              onModeChanged: onQuestionModeChanged,
            ),
          ],
        );
      case 4:
        return ListView(
          children: [
            const SizedBox(height: 20),
            _SectionIntroCard(
              section: sections[4],
              description:
                  'This section is a quick summary of the leading answer for each question, useful when stakeholders want the headline outcome without the full distribution.',
            ),
            const SizedBox(height: 18),
            _TopAnswersSection(
              analytics: analytics,
              selectedStage: selectedQuestionStage,
              selectedMode: selectedQuestionMode,
              onExport: onExportTopAnswers,
              onStageChanged: onQuestionStageChanged,
              onModeChanged: onQuestionModeChanged,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _AnalyticsSummaryGrid extends StatelessWidget {
  const _AnalyticsSummaryGrid({required this.analytics});

  final AdminAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _AnalyticsCard(
        width: 0,
        label: 'Submitted surveys',
        value: '${analytics.totalSurveys}',
        color: BrandColors.primary,
      ),
      _AnalyticsCard(
        width: 0,
        label: 'Active surveyors',
        value: '${analytics.surveyorCount}',
        color: BrandColors.secondary,
      ),
      _AnalyticsCard(
        width: 0,
        label: 'Stores covered',
        value: '${analytics.storeCount}',
        color: BrandColors.accent,
        foreground: BrandColors.ink,
      ),
      _AnalyticsCard(
        width: 0,
        label: 'Locations covered',
        value: '${analytics.locationCount}',
        color: BrandColors.surfaceTint,
        foreground: BrandColors.ink,
      ),
      _AnalyticsCard(
        width: 0,
        label: 'Average weighted score',
        value: analytics.averageScore == null
            ? 'Pending'
            : NumberFormat('0.00').format(analytics.averageScore),
        color: BrandColors.surfaceTint,
        foreground: BrandColors.ink,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth > 1200
            ? (constraints.maxWidth - 36) / 4
            : constraints.maxWidth > 900
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth > 600
            ? (constraints.maxWidth - 24) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (card) => _AnalyticsCard(
                  width: cardWidth,
                  label: card.label,
                  value: card.value,
                  color: card.color,
                  foreground: card.foreground,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _OverviewHighlightsSection extends StatelessWidget {
  const _OverviewHighlightsSection({required this.analytics});

  final AdminAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topSurveyor = analytics.surveyors.isEmpty
        ? null
        : analytics.surveyors.first;
    final topLocations = analytics.locationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topLocation = topLocations.isEmpty ? null : topLocations.first;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Presentation highlights', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          _AnalyticsDetailRow(
            label: 'Top surveyor',
            value: topSurveyor == null
                ? 'No submissions yet'
                : '${topSurveyor.name} (${topSurveyor.surveyCount} surveys)',
          ),
          _AnalyticsDetailRow(
            label: 'Top location',
            value: topLocation == null
                ? 'No location data yet'
                : '${topLocation.key} (${topLocation.value} surveys)',
          ),
          _AnalyticsDetailRow(
            label: 'Average weighted score',
            value: analytics.averageScore == null
                ? 'Pending'
                : NumberFormat('0.00').format(analytics.averageScore),
          ),
          _AnalyticsDetailRow(
            label: 'Coverage breadth',
            value:
                '${analytics.storeCount} stores across ${analytics.locationCount} locations',
          ),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.width,
    required this.label,
    required this.value,
    required this.color,
    this.foreground = Colors.white,
  });

  final double width;
  final String label;
  final String value;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: foreground),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _SurveyorAnalyticsSection extends StatelessWidget {
  const _SurveyorAnalyticsSection({required this.analytics});

  final AdminAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Surveyor analytics', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: analytics.surveyors.map((surveyor) {
            return Container(
              width: 320,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: BrandColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(surveyor.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  _AnalyticsDetailRow(
                    label: 'Surveys submitted',
                    value: '${surveyor.surveyCount}',
                  ),
                  _AnalyticsDetailRow(
                    label: 'Unique stores',
                    value: '${surveyor.uniqueStoreCount}',
                  ),
                  _AnalyticsDetailRow(
                    label: 'Average score',
                    value: surveyor.averageScore == null
                        ? 'Pending'
                        : NumberFormat('0.00').format(surveyor.averageScore!),
                  ),
                  _AnalyticsDetailRow(
                    label: 'Latest submission',
                    value: surveyor.latestSubmittedAt == null
                        ? 'None'
                        : DateFormat(
                            'dd MMM, hh:mm a',
                          ).format(surveyor.latestSubmittedAt!),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _QuestionAnalyticsSection extends StatelessWidget {
  const _QuestionAnalyticsSection({
    required this.analytics,
    required this.selectedStage,
    required this.selectedMode,
    required this.onStageChanged,
    required this.onModeChanged,
  });

  final AdminAnalytics analytics;
  final int? selectedStage;
  final QuestionMode? selectedMode;
  final ValueChanged<int?> onStageChanged;
  final ValueChanged<QuestionMode?> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredQuestions = analytics.questions.where((questionAnalytics) {
      final stageMatches =
          selectedStage == null ||
          questionAnalytics.question.stageNumber == selectedStage;
      final modeMatches =
          selectedMode == null ||
          questionAnalytics.question.mode == selectedMode;
      return stageMatches && modeMatches;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Question analytics', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BrandColors.border),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int?>(
                  initialValue: selectedStage,
                  decoration: const InputDecoration(
                    labelText: 'Filter by stage',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All stages'),
                    ),
                    ...surveyStages.map(
                      (stage) => DropdownMenuItem<int?>(
                        value: stage.number,
                        child: Text('Stage ${stage.number}'),
                      ),
                    ),
                  ],
                  onChanged: onStageChanged,
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<QuestionMode?>(
                  initialValue: selectedMode,
                  decoration: const InputDecoration(
                    labelText: 'Filter by mode',
                  ),
                  items: const [
                    DropdownMenuItem<QuestionMode?>(
                      value: null,
                      child: Text('All question modes'),
                    ),
                    DropdownMenuItem<QuestionMode?>(
                      value: QuestionMode.survey,
                      child: Text('Survey only'),
                    ),
                    DropdownMenuItem<QuestionMode?>(
                      value: QuestionMode.interviewProbe,
                      child: Text('Interview probe only'),
                    ),
                  ],
                  onChanged: onModeChanged,
                ),
              ),
              _FilterSummaryPill(
                label: 'Questions shown',
                value: '${filteredQuestions.length}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: filteredQuestions.map((questionAnalytics) {
            final topOption = questionAnalytics.topOption;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: BrandColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${questionAnalytics.question.id}: ${questionAnalytics.question.prompt}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MiniTag(
                        label:
                            'Mode: ${questionAnalytics.question.mode == QuestionMode.survey ? 'Survey' : 'Interview probe'}',
                      ),
                      _MiniTag(
                        label:
                            'Stage ${questionAnalytics.question.stageNumber}',
                      ),
                      _MiniTag(
                        label:
                            'Top response: ${topOption == null ? 'Pending' : '${topOption.option} (${topOption.count})'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _AnalyticsDetailRow(
                    label: 'Section',
                    value: questionAnalytics.question.section,
                  ),
                  _AnalyticsDetailRow(
                    label: 'Answered',
                    value: '${questionAnalytics.totalAnswered}',
                  ),
                  if (questionAnalytics.question.type ==
                          QuestionType.singleSelect ||
                      questionAnalytics.question.type ==
                          QuestionType.multiSelect ||
                      questionAnalytics.question.type == QuestionType.rankTop3)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: questionAnalytics.sortedOptionCounts
                            .where((optionCount) => optionCount.count > 0)
                            .take(6)
                            .map(
                              (optionCount) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _OptionBar(
                                  label: optionCount.option,
                                  value: optionCount.count,
                                  maxValue:
                                      questionAnalytics.maxOptionCount == 0
                                      ? 1
                                      : questionAnalytics.maxOptionCount,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (questionAnalytics.question.type == QuestionType.scale ||
                      questionAnalytics.question.type == QuestionType.slider)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: questionAnalytics.sortedOptionCounts
                            .where((optionCount) => optionCount.count > 0)
                            .map(
                              (optionCount) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _OptionBar(
                                  label: optionCount.option,
                                  value: optionCount.count,
                                  maxValue:
                                      questionAnalytics.maxOptionCount == 0
                                      ? 1
                                      : questionAnalytics.maxOptionCount,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (questionAnalytics.question.type == QuestionType.openText)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        title: Text(
                          'Interview responses (${questionAnalytics.textAnswers.length})',
                          style: theme.textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          'Expand to review captured answers.',
                          style: theme.textTheme.bodySmall,
                        ),
                        children: questionAnalytics.textAnswers.isEmpty
                            ? [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'No open-text answers captured yet.',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ]
                            : questionAnalytics.textAnswers
                                  .take(12)
                                  .map(
                                    (answer) => Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: BrandColors.surfaceTint,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: BrandColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        answer,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                  )
                                  .toList(),
                      ),
                    ),
                  if (questionAnalytics.unknownResponses > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Other / untracked responses: ${questionAnalytics.unknownResponses}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _TopAnswersSection extends StatelessWidget {
  const _TopAnswersSection({
    required this.analytics,
    required this.selectedStage,
    required this.selectedMode,
    required this.onExport,
    required this.onStageChanged,
    required this.onModeChanged,
  });

  final AdminAnalytics analytics;
  final int? selectedStage;
  final QuestionMode? selectedMode;
  final VoidCallback onExport;
  final ValueChanged<int?> onStageChanged;
  final ValueChanged<QuestionMode?> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredQuestions = analytics.questions.where((questionAnalytics) {
      final stageMatches =
          selectedStage == null ||
          questionAnalytics.question.stageNumber == selectedStage;
      final modeMatches =
          selectedMode == null ||
          questionAnalytics.question.mode == selectedMode;
      return stageMatches && modeMatches;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Top selected answer by question',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Export Top Answers'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: BrandColors.border),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int?>(
                  initialValue: selectedStage,
                  decoration: const InputDecoration(
                    labelText: 'Filter by stage',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All stages'),
                    ),
                    ...surveyStages.map(
                      (stage) => DropdownMenuItem<int?>(
                        value: stage.number,
                        child: Text('Stage ${stage.number}'),
                      ),
                    ),
                  ],
                  onChanged: onStageChanged,
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<QuestionMode?>(
                  initialValue: selectedMode,
                  decoration: const InputDecoration(
                    labelText: 'Filter by mode',
                  ),
                  items: const [
                    DropdownMenuItem<QuestionMode?>(
                      value: null,
                      child: Text('All question modes'),
                    ),
                    DropdownMenuItem<QuestionMode?>(
                      value: QuestionMode.survey,
                      child: Text('Survey only'),
                    ),
                    DropdownMenuItem<QuestionMode?>(
                      value: QuestionMode.interviewProbe,
                      child: Text('Interview probe only'),
                    ),
                  ],
                  onChanged: onModeChanged,
                ),
              ),
              _FilterSummaryPill(
                label: 'Questions shown',
                value: '${filteredQuestions.length}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...filteredQuestions.map((questionAnalytics) {
          final topOption = questionAnalytics.topOption;
          final topTextAnswer = questionAnalytics.topTextAnswer;
          final isOpenText =
              questionAnalytics.question.type == QuestionType.openText;
          final primaryLabel = isOpenText
              ? (topTextAnswer ?? 'No repeated answer captured yet')
              : (topOption?.option ?? 'No answer captured yet');
          final countLabel = isOpenText
              ? '${questionAnalytics.textAnswers.length} text responses'
              : (topOption == null
                    ? 'Pending'
                    : '${topOption.count} selections');

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: BrandColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${questionAnalytics.question.id}: ${questionAnalytics.question.prompt}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MiniTag(
                      label:
                          'Mode: ${questionAnalytics.question.mode == QuestionMode.survey ? 'Survey' : 'Interview probe'}',
                    ),
                    _MiniTag(
                      label: 'Stage ${questionAnalytics.question.stageNumber}',
                    ),
                    _MiniTag(
                      label: 'Answered: ${questionAnalytics.totalAnswered}',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BrandColors.surfaceTint,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: BrandColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top selected answer',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: BrandColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(primaryLabel, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(countLabel, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _LocationAnalyticsSection extends StatelessWidget {
  const _LocationAnalyticsSection({required this.analytics});

  final AdminAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topLocations = analytics.locationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topStates = analytics.stateCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCities = analytics.cityCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topAreas = analytics.areaCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Location analytics', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _AnalyticsCard(
              width: 320,
              label: 'Unique locations',
              value: '${analytics.locationCount}',
              color: BrandColors.primary,
            ),
            _AnalyticsCard(
              width: 320,
              label: 'States covered',
              value: '${analytics.stateCounts.length}',
              color: BrandColors.secondary,
            ),
            _AnalyticsCard(
              width: 320,
              label: 'Cities covered',
              value: '${analytics.cityCounts.length}',
              color: BrandColors.accent,
              foreground: BrandColors.ink,
            ),
            _AnalyticsCard(
              width: 320,
              label: 'Areas covered',
              value: '${analytics.areaCounts.length}',
              color: BrandColors.surfaceTint,
              foreground: BrandColors.ink,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _LocationBreakdownCard(
              title: 'Top states',
              subtitle: topStates.isEmpty
                  ? 'No state data yet'
                  : topStates.first.key,
              entries: topStates.take(6).toList(),
            ),
            _LocationBreakdownCard(
              title: 'Top cities',
              subtitle: topCities.isEmpty
                  ? 'No city data yet'
                  : topCities.first.key,
              entries: topCities.take(6).toList(),
            ),
            _LocationBreakdownCard(
              title: 'Top areas / localities',
              subtitle: topAreas.isEmpty
                  ? 'No area data yet'
                  : topAreas.first.key,
              entries: topAreas.take(6).toList(),
            ),
            _LocationBreakdownCard(
              title: 'Top full location labels',
              subtitle: topLocations.isEmpty
                  ? 'No labels yet'
                  : topLocations.first.key,
              entries: topLocations.take(6).toList(),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnalyticsDetailRow extends StatelessWidget {
  const _AnalyticsDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSummaryPill extends StatelessWidget {
  const _FilterSummaryPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BrandColors.surfaceTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BrandColors.border),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BrandColors.border),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _OptionBar extends StatelessWidget {
  const _OptionBar({
    required this.label,
    required this.value,
    required this.maxValue,
  });

  final String label;
  final int value;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue == 0 ? 0.0 : value / maxValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            const SizedBox(width: 12),
            Text(
              '$value',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: BrandColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: ratio.clamp(0, 1),
            backgroundColor: BrandColors.surfaceTint,
            valueColor: const AlwaysStoppedAnimation<Color>(
              BrandColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationBreakdownCard extends StatelessWidget {
  const _LocationBreakdownCard({
    required this.title,
    required this.subtitle,
    required this.entries,
  });

  final String title;
  final String subtitle;
  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = entries.isEmpty
        ? 1
        : entries.map((entry) => entry.value).reduce((a, b) => a > b ? a : b);

    return Container(
      width: 420,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text(
              'No breakdown available yet.',
              style: theme.textTheme.bodyMedium,
            )
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _OptionBar(
                  label: entry.key,
                  value: entry.value,
                  maxValue: maxValue,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionIntroCard extends StatelessWidget {
  const _SectionIntroCard({required this.section, required this.description});

  final _AnalyticsSection section;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandColors.primary.withValues(alpha: 0.10),
            BrandColors.secondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BrandColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(section.icon, color: BrandColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(section.subtitle, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(description, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _AnalyticsSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected ? BrandColors.primary : BrandColors.surfaceTint;
    final foreground = selected ? Colors.white : BrandColors.ink;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? BrandColors.primary : BrandColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(section.icon, size: 18, color: foreground),
            const SizedBox(width: 8),
            Text(
              section.title,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsSection {
  const _AnalyticsSection({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class AdminAnalytics {
  AdminAnalytics({
    required this.totalSurveys,
    required this.surveyorCount,
    required this.storeCount,
    required this.locationCount,
    required this.locationCounts,
    required this.stateCounts,
    required this.cityCounts,
    required this.areaCounts,
    required this.averageScore,
    required this.surveyors,
    required this.questions,
  });

  final int totalSurveys;
  final int surveyorCount;
  final int storeCount;
  final int locationCount;
  final Map<String, int> locationCounts;
  final Map<String, int> stateCounts;
  final Map<String, int> cityCounts;
  final Map<String, int> areaCounts;
  final double? averageScore;
  final List<SurveyorAnalytics> surveyors;
  final List<QuestionAnalytics> questions;

  factory AdminAnalytics.fromDocuments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final surveyorBuckets = <String, SurveyorAnalytics>{};
    final storeNames = <String>{};
    final locationCounts = <String, int>{};
    final stateCounts = <String, int>{};
    final cityCounts = <String, int>{};
    final areaCounts = <String, int>{};
    final questionBuckets = <String, QuestionAnalytics>{};
    final questionDefinition = {
      for (final question in surveyQuestions) question.id: question,
    };
    final scoreValues = <double>[];

    for (final question in surveyQuestions) {
      questionBuckets[question.id] = QuestionAnalytics(question: question);
    }

    for (final doc in docs) {
      final data = doc.data();
      final surveyorName = '${data['surveyorName'] ?? 'Unknown'}';
      final storeName = '${data['storeName'] ?? 'Unknown'}';
      final storeLocation = '${data['storeLocation'] ?? 'Unknown'}';
      final score = (data['averageWeightedScore'] as num?)?.toDouble();
      final locationParts = _LocationParts.fromLabel(storeLocation);

      storeNames.add(storeName);
      locationCounts[storeLocation] = (locationCounts[storeLocation] ?? 0) + 1;
      if (locationParts.state.isNotEmpty) {
        stateCounts[locationParts.state] =
            (stateCounts[locationParts.state] ?? 0) + 1;
      }
      if (locationParts.city.isNotEmpty) {
        cityCounts[locationParts.city] =
            (cityCounts[locationParts.city] ?? 0) + 1;
      }
      if (locationParts.area.isNotEmpty) {
        areaCounts[locationParts.area] =
            (areaCounts[locationParts.area] ?? 0) + 1;
      }
      if (score != null) {
        scoreValues.add(score);
      }

      surveyorBuckets
          .putIfAbsent(
            surveyorName,
            () => SurveyorAnalytics(name: surveyorName),
          )
          .addSurvey(doc, score);

      final responses = (data['responses'] as Map<String, dynamic>? ?? {});
      for (final entry in responses.entries) {
        final questionId = entry.key;
        final response = entry.value as Map<String, dynamic>?;
        if (response == null) {
          continue;
        }

        final answer = response['answer'];
        final analytics = questionBuckets.putIfAbsent(
          questionId,
          () => QuestionAnalytics(
            question:
                questionDefinition[questionId] ??
                SurveyQuestion(
                  id: questionId,
                  stageNumber: 0,
                  stageLabel: 'Unknown',
                  mode: QuestionMode.survey,
                  section: 'Unknown',
                  prompt: questionId,
                  type: QuestionType.openText,
                ),
          ),
        );
        analytics.addAnswer(answer);
      }
    }

    final averageScore = scoreValues.isEmpty
        ? null
        : scoreValues.reduce((value, element) => value + element) /
              scoreValues.length;

    return AdminAnalytics(
      totalSurveys: docs.length,
      surveyorCount: surveyorBuckets.length,
      storeCount: storeNames.length,
      locationCount: locationCounts.length,
      locationCounts: locationCounts,
      stateCounts: stateCounts,
      cityCounts: cityCounts,
      areaCounts: areaCounts,
      averageScore: averageScore,
      surveyors: surveyorBuckets.values.toList()
        ..sort((a, b) => b.surveyCount.compareTo(a.surveyCount)),
      questions: surveyQuestions
          .map((question) => questionBuckets[question.id]!)
          .toList(),
    );
  }
}

class SurveyorAnalytics {
  SurveyorAnalytics({required this.name});

  final String name;
  int surveyCount = 0;
  double scoreSum = 0;
  int scoreCount = 0;
  DateTime? latestSubmittedAt;
  final Set<String> stores = <String>{};

  int get uniqueStoreCount => stores.length;
  double? get averageScore => scoreCount == 0 ? null : scoreSum / scoreCount;

  void addSurvey(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    double? score,
  ) {
    surveyCount += 1;
    final data = doc.data();
    final storeName = '${data['storeName'] ?? 'Unknown'}';
    stores.add(storeName);
    if (score != null) {
      scoreSum += score;
      scoreCount += 1;
    }

    final submittedAt = data['submittedAt'] as Timestamp?;
    if (submittedAt != null) {
      final submittedDate = submittedAt.toDate();
      if (latestSubmittedAt == null ||
          submittedDate.isAfter(latestSubmittedAt!)) {
        latestSubmittedAt = submittedDate;
      }
    }
  }
}

class QuestionAnalytics {
  QuestionAnalytics({required this.question});

  final SurveyQuestion question;
  int totalAnswered = 0;
  int unknownResponses = 0;
  final Map<String, int> counts = <String, int>{};
  final List<String> textAnswers = <String>[];

  void addAnswer(dynamic answer) {
    if (answer == null) {
      return;
    }

    totalAnswered += 1;

    if (answer is List) {
      for (final item in answer) {
        if (item is String) {
          counts[item] = (counts[item] ?? 0) + 1;
          if (question.type == QuestionType.openText &&
              item.trim().isNotEmpty) {
            textAnswers.add(item.trim());
          }
        } else {
          unknownResponses += 1;
        }
      }
      return;
    }

    if (answer is String || answer is num) {
      final key = '$answer';
      counts[key] = (counts[key] ?? 0) + 1;
      if (question.type == QuestionType.openText &&
          answer is String &&
          answer.trim().isNotEmpty) {
        textAnswers.add(answer.trim());
      }
      return;
    }

    unknownResponses += 1;
  }

  List<OptionCount> get sortedOptionCounts {
    final options = <OptionCount>[];

    for (final option in question.options) {
      final count = counts[option] ?? 0;
      options.add(OptionCount(option: option, count: count));
    }

    for (final entry in counts.entries) {
      if (!question.options.contains(entry.key)) {
        options.add(OptionCount(option: entry.key, count: entry.value));
      }
    }

    options.sort((a, b) => b.count.compareTo(a.count));
    return options;
  }

  OptionCount? get topOption {
    final populated = sortedOptionCounts
        .where((item) => item.count > 0)
        .toList();
    return populated.isEmpty ? null : populated.first;
  }

  String? get topTextAnswer {
    if (textAnswers.isEmpty) {
      return null;
    }

    final textCounts = <String, int>{};
    for (final answer in textAnswers) {
      textCounts[answer] = (textCounts[answer] ?? 0) + 1;
    }

    final sorted = textCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  int get topTextAnswerCount {
    final topAnswer = topTextAnswer;
    if (topAnswer == null) {
      return 0;
    }
    return textAnswers.where((answer) => answer == topAnswer).length;
  }

  int get maxOptionCount {
    if (counts.isEmpty) {
      return 0;
    }
    return counts.values.reduce((a, b) => a > b ? a : b);
  }
}

class OptionCount {
  const OptionCount({required this.option, required this.count});

  final String option;
  final int count;
}

class _LocationParts {
  const _LocationParts({
    required this.area,
    required this.city,
    required this.state,
  });

  final String area;
  final String city;
  final String state;

  factory _LocationParts.fromLabel(String rawLabel) {
    final parts = rawLabel
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return const _LocationParts(area: '', city: '', state: '');
    }

    if (parts.length == 1) {
      return _LocationParts(area: parts.first, city: '', state: '');
    }

    if (parts.length == 2) {
      return _LocationParts(area: parts.first, city: '', state: parts.last);
    }

    return _LocationParts(
      area: parts.first,
      city: parts[parts.length - 2],
      state: parts.last,
    );
  }
}

class _AdminErrorState extends StatelessWidget {
  const _AdminErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
