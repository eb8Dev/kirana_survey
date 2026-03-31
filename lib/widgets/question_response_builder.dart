import 'package:flutter/material.dart';
import 'package:kirana_survey/core/brand_theme.dart';
import 'package:kirana_survey/models/survey_models.dart';

class QuestionResponseBuilder extends StatelessWidget {
  const QuestionResponseBuilder({
    super.key,
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final SurveyQuestion question;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case QuestionType.singleSelect:
        return _SelectList(
          options: question.options,
          selectedValues: value is String
              ? <String>[value as String]
              : const <String>[],
          multiSelect: false,
          onChanged: (selected) {
            final values = (selected as List).cast<String>();
            onChanged(values.isEmpty ? null : values.first);
          },
        );
      case QuestionType.multiSelect:
        return _SelectList(
          options: question.options,
          selectedValues: value is List
              ? (value as List).cast<String>()
              : const <String>[],
          multiSelect: true,
          onChanged: onChanged,
        );
      case QuestionType.scale:
        return _ScaleSelector(
          value: value is int ? value as int : null,
          helperText: question.helperText,
          onChanged: onChanged,
        );
      case QuestionType.rankTop3:
        return _RankSelector(
          options: question.options,
          selectedValues: value is List
              ? (value as List).cast<String>()
              : const <String>[],
          onChanged: onChanged,
        );
      case QuestionType.openText:
        return _OpenTextField(
          key: ValueKey(question.id),
          initialValue: value is String ? value as String : '',
          onChanged: (text) => onChanged(text),
        );
      case QuestionType.slider:
        return _SliderSelector(
          value: value is double ? value as double : 0.0,
          onChanged: onChanged,
        );
    }
  }
}

class _SliderSelector extends StatelessWidget {
  const _SliderSelector({
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: BrandColors.surfaceTint,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BrandColors.border),
          ),
          child: Column(
            children: [
              Text(
                '\u20b9 ${value.round()}',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: BrandColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value == 0
                    ? 'Not willing to pay'
                    : value == 2000
                        ? '\u20b9 2,000 or more'
                        : 'Monthly subscription',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: BrandColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: BrandColors.primary,
                  inactiveTrackColor: BrandColors.border,
                  trackHeight: 8.0,
                  thumbColor: BrandColors.secondary,
                  overlayColor: BrandColors.secondary.withValues(alpha: 0.12),
                  valueIndicatorColor: BrandColors.primary,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 14.0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 28.0,
                  ),
                ),
                child: Slider(
                  value: value,
                  min: 0,
                  max: 2000,
                  divisions: 20,
                  label: '\u20b9 ${value.round()}',
                  onChanged: (newValue) => onChanged(newValue),
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('\u20b9 0'),
                  Text('\u20b9 1,000'),
                  Text('\u20b9 2,000'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectList extends StatelessWidget {
  const _SelectList({
    required this.options,
    required this.selectedValues,
    required this.multiSelect,
    required this.onChanged,
  });

  final List<String> options;
  final List<String> selectedValues;
  final bool multiSelect;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options
          .map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OptionTile(
                label: option,
                selected: selectedValues.contains(option),
                trailing: multiSelect
                    ? Icon(
                        selectedValues.contains(option)
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        color: selectedValues.contains(option)
                            ? BrandColors.secondary
                            : BrandColors.muted,
                      )
                    : Icon(
                        selectedValues.contains(option)
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: selectedValues.contains(option)
                            ? BrandColors.primary
                            : BrandColors.muted,
                      ),
                onTap: () {
                  if (!multiSelect) {
                    onChanged(<String>[option]);
                    return;
                  }

                  final next = <String>[...selectedValues];
                  if (next.contains(option)) {
                    next.remove(option);
                  } else {
                    next.add(option);
                  }
                  onChanged(next);
                },
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ScaleSelector extends StatelessWidget {
  const _ScaleSelector({
    required this.value,
    required this.helperText,
    required this.onChanged,
  });

  final int? value;
  final String? helperText;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (helperText != null) ...[
          Text(helperText!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 18),
        ],
        Row(
          children: List.generate(5, (index) {
            final score = index + 1;
            final selected = value == score;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 4 ? 0 : 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onChanged(score),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: selected
                          ? BrandColors.primary.withValues(alpha: 0.12)
                          : BrandColors.surfaceTint,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? BrandColors.primary
                            : BrandColors.border,
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$score',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: selected
                                ? BrandColors.primary
                                : BrandColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          switch (score) {
                            1 => 'Low',
                            5 => 'High',
                            _ => ' ',
                          },
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: BrandColors.muted,
                          ),
                        ),
                      ],
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

class _RankSelector extends StatelessWidget {
  const _RankSelector({
    required this.options,
    required this.selectedValues,
    required this.onChanged,
  });

  final List<String> options;
  final List<String> selectedValues;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap exactly three options in order of importance.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        ...options.map((option) {
          final rank = selectedValues.indexOf(option);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OptionTile(
              label: option,
              selected: rank >= 0,
              trailing: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank >= 0
                      ? BrandColors.secondary
                      : BrandColors.surfaceTint,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  rank >= 0 ? '${rank + 1}' : '+',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: rank >= 0 ? Colors.white : BrandColors.muted,
                  ),
                ),
              ),
              onTap: () {
                final next = <String>[...selectedValues];
                if (rank >= 0) {
                  next.remove(option);
                } else if (next.length < 3) {
                  next.add(option);
                }
                onChanged(next);
              },
            ),
          );
        }),
      ],
    );
  }
}

class _OpenTextField extends StatefulWidget {
  const _OpenTextField({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_OpenTextField> createState() => _OpenTextFieldState();
}

class _OpenTextFieldState extends State<_OpenTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      minLines: 6,
      maxLines: 10,
      textInputAction: TextInputAction.newline,
      decoration: const InputDecoration(
        hintText:
            'Capture the outlet response, observation, and any useful field context...',
      ),
      onChanged: widget.onChanged,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trailingWidgets = trailing == null
        ? const <Widget>[]
        : <Widget>[trailing!];
    final children = <Widget>[
      Expanded(
        child: Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: BrandColors.ink,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
      ...trailingWidgets,
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? BrandColors.primary.withValues(alpha: 0.08)
                : BrandColors.surfaceTint,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? BrandColors.primary : BrandColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(children: children),
        ),
      ),
    );
  }
}
