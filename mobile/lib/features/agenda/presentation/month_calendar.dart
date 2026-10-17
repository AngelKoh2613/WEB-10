import 'package:flutter/material.dart';
import 'package:secureplan_mobile/core/theme/app_theme.dart';

const monthNames = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const _weekdayHeaders = [
  ('LUN', 'lunes'),
  ('MAR', 'martes'),
  ('MIÉ', 'miércoles'),
  ('JUE', 'jueves'),
  ('VIE', 'viernes'),
  ('SÁB', 'sábado'),
  ('DOM', 'domingo'),
];

String capitalize(String value) {
  return value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.visibleDay,
    required this.markedDays,
    required this.onSelect,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime visibleDay;
  final Set<DateTime> markedDays;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(visibleDay.year, visibleDay.month, 1);
    final days = DateTime(visibleDay.year, visibleDay.month + 1, 0).day;
    final leading = first.weekday - 1;
    final label =
        '${capitalize(monthNames[visibleDay.month - 1])} ${visibleDay.year}';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(label, style: theme.textTheme.titleLarge),
                ),
              ),
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Column(
              children: [
                Row(
                  children: [
                    for (final (short, full) in _weekdayHeaders)
                      _Weekday(short: short, full: full),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cellWidth = constraints.maxWidth / 7;
                    return GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: cellWidth / 50,
                      children: [
                        for (var index = 0; index < leading; index++)
                          const SizedBox.shrink(),
                        for (var day = 1; day <= days; day++)
                          _DayButton(
                            day: DateTime(
                              visibleDay.year,
                              visibleDay.month,
                              day,
                            ),
                            selected: day == visibleDay.day,
                            today:
                                DateTime(
                                  visibleDay.year,
                                  visibleDay.month,
                                  day,
                                ) ==
                                today,
                            marked: markedDays.contains(
                              DateTime(visibleDay.year, visibleDay.month, day),
                            ),
                            onSelect: onSelect,
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Weekday extends StatelessWidget {
  const _Weekday({required this.short, required this.full});

  final String short;
  final String full;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Semantics(
        label: full,
        excludeSemantics: true,
        child: Text(
          short,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.day,
    required this.selected,
    required this.today,
    required this.marked,
    required this.onSelect,
  });

  final DateTime day;
  final bool selected;
  final bool today;
  final bool marked;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final month = monthNames[day.month - 1];
    final label = marked
        ? '${day.day} de $month de ${day.year}, con eventos'
        : '${day.day} de $month de ${day.year}';

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        key: ValueKey('day-${day.year}-${day.month}-${day.day}'),
        customBorder: const CircleBorder(),
        onTap: () => onSelect(day),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? scheme.primary : null,
                  shape: BoxShape.circle,
                  border: today && !selected
                      ? Border.all(color: scheme.primary, width: 1.5)
                      : null,
                ),
                child: Text(
                  '${day.day}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: selected || today
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: selected
                        ? scheme.onPrimary
                        : today
                        ? scheme.primary
                        : scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                key: marked
                    ? ValueKey('mark-${day.year}-${day.month}-${day.day}')
                    : null,
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: !marked
                      ? Colors.transparent
                      : selected
                      ? scheme.primary
                      : scheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
