import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kirana_survey/core/brand_theme.dart';
import 'package:kirana_survey/models/survey_models.dart';

class QuestionAssessmentCard extends StatelessWidget {
  const QuestionAssessmentCard({
    super.key,
    required this.assessment,
    required this.onCustomerRatingChanged,
    required this.onBusinessImpactChanged,
    required this.onAiFitChanged,
  });

  final QuestionAssessment assessment;
  final ValueChanged<int> onCustomerRatingChanged;
  final ValueChanged<int> onBusinessImpactChanged;
  final ValueChanged<int> onAiFitChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weightedScore = assessment.weightedScore;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BrandColors.surfaceTint,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Surveyor scoring', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Score this response using the interview evidence you collected. '
            'Weighted score = (Customer Rating x 45%) + (Business Impact x 35%) + (AI Fit x 20%).',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          _AssessmentSelector(
            label: 'Customer rating (1-5)',
            value: assessment.customerRating,
            onChanged: onCustomerRatingChanged,
          ),
          const SizedBox(height: 16),
          _AssessmentSelector(
            label: 'Business impact (1-5)',
            value: assessment.businessImpact,
            onChanged: onBusinessImpactChanged,
          ),
          const SizedBox(height: 16),
          _AssessmentSelector(
            label: 'AI fit / feasibility (1-5)',
            value: assessment.aiFit,
            onChanged: onAiFitChanged,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ResultPill(
                label: 'Weighted score',
                value: weightedScore == null
                    ? 'Pending'
                    : NumberFormat('0.00').format(weightedScore),
                accent: BrandColors.primary,
              ),
              _ResultPill(
                label: 'Priority',
                value: assessment.priorityBucket ?? 'Pending',
                accent: BrandColors.secondary,
              ),
              _ResultPill(
                label: 'Action',
                value: assessment.recommendedAction ?? 'Pending',
                accent: BrandColors.accent,
                foreground: BrandColors.ink,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssessmentSelector extends StatelessWidget {
  const _AssessmentSelector({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Row(
          children: List.generate(5, (index) {
            final score = index + 1;
            final selected = value == score;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 4 ? 0 : 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onChanged(score),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected
                          ? BrandColors.primary.withValues(alpha: 0.10)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? BrandColors.primary
                            : BrandColors.border,
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$score',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: selected
                              ? BrandColors.primary
                              : BrandColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({
    required this.label,
    required this.value,
    required this.accent,
    this.foreground = Colors.white,
  });

  final String label;
  final String value;
  final Color accent;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: foreground),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
