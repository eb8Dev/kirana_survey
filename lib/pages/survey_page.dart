import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kirana_survey/controllers/survey_controller.dart';
import 'package:kirana_survey/core/brand_theme.dart';
import 'package:kirana_survey/data/survey_definition.dart';
import 'package:kirana_survey/models/survey_models.dart';
import 'package:kirana_survey/services/auth_service.dart';
import 'package:kirana_survey/services/device_location_service.dart';
import 'package:kirana_survey/services/remote_config_service.dart';
import 'package:kirana_survey/services/survey_repository.dart';
import 'package:kirana_survey/services/surveyor_profile_service.dart';
import 'package:kirana_survey/widgets/question_assessment_card.dart';
import 'package:kirana_survey/widgets/question_response_builder.dart';
import 'package:kirana_survey/widgets/survey_gate_widgets.dart';

class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  late final SurveyRepository _repository;
  late final SurveyController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _repository = SurveyRepository(FirebaseFirestore.instance);
    _controller = SurveyController(
      authService: AuthService(FirebaseAuth.instance),
      repository: _repository,
      surveyorProfileService: SurveyorProfileService(),
      deviceLocationService: DeviceLocationService(),
      remoteConfigService: RemoteConfigService(FirebaseRemoteConfig.instance),
    )..initialize();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return PopScope(
          canPop: !_controller.isBusy,
          child: Scaffold(
            body: Container(
              color: Colors.white,
              child: SafeArea(
                child: Stack(
                  children: [
                    const _AmbientBackground(),
                    if (_controller.lifecycle == SurveyLifecycle.loading)
                      const SurveyLoadingState()
                    else if (_controller.lifecycle == SurveyLifecycle.inactive)
                      const SurveyInactiveState()
                    else if (_controller.needsSurveyorName)
                      SurveyorNameGate(controller: _controller)
                    else if (_controller.needsSurveyStart)
                      SurveyStartGate(
                        controller: _controller,
                        repository: _repository,
                      )
                    else if (_controller.lifecycle == SurveyLifecycle.error)
                      SurveyErrorState(
                        message:
                            _controller.errorMessage ?? 'Something went wrong.',
                        onRetry: _controller.initialize,
                      )
                    else if (_controller.isSubmitted)
                      SurveyCompletionState(controller: _controller)
                    else
                      _SurveyScaffold(
                        controller: _controller,
                        scrollController: _scrollController,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class _SurveyScaffold extends StatelessWidget {
  const _SurveyScaffold({
    required this.controller,
    required this.scrollController,
  });

  final SurveyController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final question = controller.currentQuestion;
    final isLast =
        controller.currentQuestionIndex == controller.questions.length - 1;
    final assessment = controller.assessmentFor(question.id);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: _TopHeader(controller: controller),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, animation) {
                    final offset =
                        Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        );
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: offset, child: child),
                    );
                  },
                  child: Column(
                    key: ValueKey(question.id),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StageBanner(
                        stage: controller.currentStage,
                        controller: controller,
                      ),
                      const SizedBox(height: 18),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _MetaChip(
                                    label: question.mode == QuestionMode.survey
                                        ? 'Structured survey'
                                        : 'Interview probe',
                                    color: question.mode == QuestionMode.survey
                                        ? BrandColors.primary
                                        : BrandColors.secondary,
                                  ),
                                  _MetaChip(
                                    label: question.section,
                                    color: BrandColors.accent,
                                    foreground: BrandColors.ink,
                                  ),
                                  _MetaChip(
                                    label:
                                        'Q ${controller.currentQuestionIndex + 1} of ${controller.questions.length}',
                                    color: BrandColors.surfaceTint,
                                    foreground: BrandColors.muted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                question.id,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: BrandColors.primary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                question.prompt,
                                style: theme.textTheme.headlineSmall,
                              ),
                              if (question.helperText != null &&
                                  question.type != QuestionType.scale) ...[
                                const SizedBox(height: 12),
                                Text(
                                  question.helperText!,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                              const SizedBox(height: 24),
                              QuestionResponseBuilder(
                                question: question,
                                value: controller.answerFor(question.id),
                                onChanged: (value) =>
                                    controller.updateAnswer(question, value),
                              ),
                              if (controller.scoringEnabled) ...[
                                const SizedBox(height: 24),
                                QuestionAssessmentCard(
                                  assessment: assessment,
                                  onCustomerRatingChanged: (value) =>
                                      controller.updateAssessment(
                                        question,
                                        customerRating: value,
                                      ),
                                  onBusinessImpactChanged: (value) =>
                                      controller.updateAssessment(
                                        question,
                                        businessImpact: value,
                                      ),
                                  onAiFitChanged: (value) => controller
                                      .updateAssessment(question, aiFit: value),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: BrandColors.surfaceTint.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: BrandColors.border),
                        ),
                        child: Wrap(
                          spacing: 18,
                          runSpacing: 10,
                          children: [
                            Text(
                              '${controller.answeredCount} of ${controller.questions.length} responses captured',
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              controller.lastSavedAt == null
                                  ? 'Draft will auto-save to Firebase.'
                                  : 'Last saved ${DateFormat.jm().format(controller.lastSavedAt!)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: BrandColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: controller.currentQuestionIndex == 0
                              ? null
                              : () async {
                                  await controller.goPrevious();
                                  if (scrollController.hasClients) {
                                    await scrollController.animateTo(
                                      0,
                                      duration: const Duration(
                                        milliseconds: 260,
                                      ),
                                      curve: Curves.easeOutCubic,
                                    );
                                  }
                                },
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Previous'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final message = isLast
                                ? await controller.submit()
                                : await controller.goNext();
                            if (message != null && context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(message)));
                            }
                            if (!isLast && scrollController.hasClients) {
                              await scrollController.animateTo(
                                0,
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          },
                          icon: Icon(
                            isLast
                                ? Icons.cloud_upload_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                          label: Text(isLast ? 'Submit Survey' : 'Continue'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.controller});

  final SurveyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completion = controller.answeredCount / controller.questions.length;

    return Container(
      padding: const EdgeInsets.all(20),
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
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [BrandColors.primary, BrandColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lohiya Outlet AI Survey',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Survey tool for collecting outlet insights with guided questions and automatic saving.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (controller.surveyorName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Surveyor: ${controller.surveyorName}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: BrandColors.primary,
                        ),
                      ),
                    ],
                    if (controller.storeName != null &&
                        controller.storeLocation != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Outlet: ${controller.storeName} | ${controller.storeLocation}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: completion,
                    backgroundColor: BrandColors.surfaceTint,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      BrandColors.secondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '${(completion * 100).round()}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: BrandColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: surveyStages
                  .map(
                    (stage) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _StageChip(
                        label: 'Stage ${stage.number}',
                        active: stage.number == controller.currentStage.number,
                        completed:
                            controller.answeredInStage(stage.number) ==
                                controller.totalInStage(stage.number) &&
                            controller.totalInStage(stage.number) > 0,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageBanner extends StatelessWidget {
  const _StageBanner({required this.stage, required this.controller});

  final SurveyStage stage;
  final SurveyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answered = controller.answeredInStage(stage.number);
    final total = controller.totalInStage(stage.number);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandColors.primary.withValues(alpha: 0.12),
            BrandColors.secondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stage ${stage.number}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: BrandColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(stage.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(stage.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 14),
          Text(
            '$answered of $total prompts completed in this stage',
            style: theme.textTheme.titleMedium?.copyWith(
              color: BrandColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.label,
    required this.active,
    required this.completed,
  });

  final String label;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final background = active
        ? BrandColors.primary
        : completed
        ? BrandColors.secondary
        : BrandColors.surfaceTint;
    final foreground = active || completed ? Colors.white : BrandColors.muted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: foreground),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.color,
    this.foreground = Colors.white,
  });

  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BrandColors.primary.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            top: 180,
            left: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BrandColors.accent.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: 20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BrandColors.secondary.withValues(alpha: 0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
