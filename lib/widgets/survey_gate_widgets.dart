import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kirana_survey/controllers/survey_controller.dart';
import 'package:kirana_survey/core/brand_theme.dart';
import 'package:kirana_survey/services/survey_repository.dart';

class SurveyorNameGate extends StatefulWidget {
  const SurveyorNameGate({super.key, required this.controller});

  final SurveyController controller;

  @override
  State<SurveyorNameGate> createState() => _SurveyorNameGateState();
}

class _SurveyorNameGateState extends State<SurveyorNameGate> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Who is taking surveys today?',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Enter the surveyor name once on this device. Their surveys and stats will be grouped together in Firestore.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Surveyor name',
                      hintText: 'Enter full name',
                    ),
                    onSubmitted: (_) => _saveName(),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _saveName,
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveName() async {
    final message = await widget.controller.saveSurveyorName(
      _nameController.text,
    );
    if (message != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

class SurveyStartGate extends StatefulWidget {
  const SurveyStartGate({
    super.key,
    required this.controller,
    required this.repository,
  });

  final SurveyController controller;
  final SurveyRepository repository;

  @override
  State<SurveyStartGate> createState() => _SurveyStartGateState();
}

class _SurveyStartGateState extends State<SurveyStartGate> {
  late final TextEditingController _storeController;

  @override
  void initState() {
    super.initState();
    _storeController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surveyorDocumentId = widget.controller.surveyorDocumentId;
    final draft = widget.controller.latestDraft;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start a new outlet survey',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Surveyor: ${widget.controller.surveyorName}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: BrandColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.controller.scoringEnabled
                          ? 'Surveyor scoring is enabled by Remote Config for this session.'
                          : 'Surveyor scoring is disabled by Remote Config, so the survey will move ahead without evaluator ratings.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _storeController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Store name',
                        hintText: 'Enter kirana store name',
                      ),
                    ),
                    if (draft != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: BrandColors.surfaceTint,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: BrandColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Resume last draft',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You have an unsent survey draft for ${draft.data()['storeName'] ?? 'the last outlet'}.',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Last saved ${DateFormat.yMMMd().add_jm().format(
                                  (draft.data()['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                                )}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _resumeDraft,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Resume draft'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                            'Device location',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: BrandColors.primary,
                            ),
                          ),
                          // const SizedBox(height: 6),
                          // Text(
                          //   'The app will capture the outlet location from this device when the survey starts, so the surveyor does not need to type it manually.',
                          //   style: theme.textTheme.bodyMedium,
                          // ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: _startSurvey,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start survey'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: widget.controller.clearSurveyorProfile,
                      child: const Text('Change surveyor'),
                    ),
                  ],
                ),
              ),
            ),
            if (surveyorDocumentId != null) ...[
              const SizedBox(height: 18),
              _SurveyorStatsPanel(
                stream: widget.repository.watchSurveyorSessions(
                  surveyorDocumentId,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startSurvey() async {
    final message = await widget.controller.beginSurvey(
      storeName: _storeController.text,
    );
    if (message != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _resumeDraft() async {
    final draft = widget.controller.latestDraft;
    if (draft == null) {
      return;
    }

    await widget.controller.resumeSession(draft);
  }

  @override
  void dispose() {
    _storeController.dispose();
    super.dispose();
  }
}

class _SurveyorStatsPanel extends StatelessWidget {
  const _SurveyorStatsPanel({required this.stream});

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final docs =
            (snapshot.data?.docs ?? const [])
                .where((doc) => doc.data()['status'] == 'submitted')
                .toList()
              ..sort((a, b) {
                final aTimestamp = a.data()['submittedAt'] as Timestamp?;
                final bTimestamp = b.data()['submittedAt'] as Timestamp?;
                return (bTimestamp?.millisecondsSinceEpoch ?? 0).compareTo(
                  aTimestamp?.millisecondsSinceEpoch ?? 0,
                );
              });

        final now = DateTime.now();
        final todayCount = docs.where((doc) {
          final timestamp = doc.data()['submittedAt'] as Timestamp?;
          if (timestamp == null) {
            return false;
          }
          final date = timestamp.toDate();
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        }).length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Surveyor stats', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatsPill(
                      label: 'Today',
                      value: '$todayCount surveys',
                      color: BrandColors.primary,
                    ),
                    _StatsPill(
                      label: 'Lifetime',
                      value: '${docs.length} surveys',
                      color: BrandColors.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Recent history', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                if (docs.isEmpty)
                  Text(
                    'No submitted surveys yet for this surveyor.',
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  ...docs.take(5).map((doc) {
                    final data = doc.data();
                    final submittedAt = data['submittedAt'] as Timestamp?;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: BrandColors.surfaceTint,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: BrandColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${data['storeName'] ?? 'Unknown store'}',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${data['storeLocation'] ?? 'Unknown location'}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              submittedAt == null
                                  ? 'Pending'
                                  : DateFormat(
                                      'dd MMM, hh:mm a',
                                    ).format(submittedAt.toDate()),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SurveyLoadingState extends StatelessWidget {
  const SurveyLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: BrandColors.primary),
          const SizedBox(height: 18),
          Text(
            'Preparing your survey session...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class SurveyInactiveState extends StatelessWidget {
  const SurveyInactiveState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.pause_circle_outline_rounded,
                    size: 48,
                    color: BrandColors.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No active surveys are undergoing.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'This state is controlled by Firebase Remote Config. Set isActive to true to resume surveying.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SurveyErrorState extends StatelessWidget {
  const SurveyErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 44,
                    color: BrandColors.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Unable to load the survey',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SurveyCompletionState extends StatelessWidget {
  const SurveyCompletionState({super.key, required this.controller});

  final SurveyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BrandColors.secondary.withValues(alpha: 0.14),
                    ),
                    child: const Icon(
                      Icons.cloud_done_rounded,
                      size: 40,
                      color: BrandColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Survey submitted successfully',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The survey has been stored under the surveyor profile with outlet start details and a meaningful session ID.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (controller.sessionId != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Session ID: ${controller.sessionId}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: BrandColors.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => controller.startAnotherSurvey(),
                      icon: const Icon(Icons.add_business_rounded),
                      label: const Text('Start another survey'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: controller.clearSurveyorProfile,
                      child: const Text('Change surveyor'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsPill extends StatelessWidget {
  const _StatsPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
