import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secureplan_mobile/core/theme/app_theme.dart';
import 'package:secureplan_mobile/features/agenda/application/agenda_controller.dart';
import 'package:secureplan_mobile/features/agenda/domain/agenda_event.dart';
import 'package:secureplan_mobile/features/agenda/domain/reminder_plan.dart';
import 'package:secureplan_mobile/features/agenda/presentation/event_style.dart';
import 'package:secureplan_mobile/shared/widgets/inline_message.dart';
import 'package:secureplan_mobile/shared/widgets/section_header.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.event});

  final AgendaEvent? event;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _date;
  late final TextEditingController _time;
  late final TextEditingController _endDate;
  late final TextEditingController _endTime;
  late final TextEditingController _interval;
  late final TextEditingController _count;
  late final TextEditingController _until;
  late String _category;
  late String _priority;
  late String _frequency;
  late String _limit;
  late Set<int> _weekdays;
  late bool _hasEnd;
  late int? _reminder;
  var _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final start = event?.startsAt.toLocal();
    final end = event?.endsAt?.toLocal();
    final selected = ref.read(selectedDayProvider);
    _title = TextEditingController(text: event?.title ?? '');
    _description = TextEditingController(text: event?.description ?? '');
    _date = TextEditingController(text: formatEventDate(start ?? selected));
    _time = TextEditingController(
      text: start == null ? '09:00' : formatEventTime(start),
    );
    _endDate = TextEditingController(
      text: formatEventDate(end ?? start ?? selected),
    );
    _endTime = TextEditingController(
      text: end == null ? '10:00' : formatEventTime(end),
    );
    _interval = TextEditingController(
      text: '${event?.recurrence?.interval ?? 1}',
    );
    _count = TextEditingController(text: '${event?.recurrence?.count ?? 10}');
    _until = TextEditingController(
      text: formatEventDate(event?.recurrence?.until?.toLocal() ?? selected),
    );
    _category = event?.category ?? 'personal';
    _priority = event?.priority ?? 'medium';
    _frequency = event?.recurrence?.frequency ?? 'none';
    _limit = event?.recurrence?.until != null ? 'until' : 'count';
    _weekdays = {...?event?.recurrence?.weekdays};
    _hasEnd = end != null;
    _reminder = event?.reminderMinutes ?? 15;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _date.dispose();
    _time.dispose();
    _endDate.dispose();
    _endTime.dispose();
    _interval.dispose();
    _count.dispose();
    _until.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final startsAt = parseEventDateTime(_date.text, _time.text);
    final endsAt = _hasEnd
        ? parseEventDateTime(_endDate.text, _endTime.text)
        : null;
    if (startsAt == null || (_hasEnd && endsAt == null)) {
      setState(() => _error = 'La fecha o la hora no son válidas');
      return;
    }
    final intervalError = validateEventInterval(startsAt, endsAt);
    if (intervalError != null) {
      setState(() => _error = intervalError);
      return;
    }
    final recurrenceError = validateRecurrence(
      frequency: _frequency,
      startsAt: startsAt,
      interval: int.tryParse(_interval.text.trim()),
      weekdays: _weekdays,
      untilLimit: _limit == 'until',
      count: int.tryParse(_count.text.trim()),
      until: _untilDate(),
    );
    if (recurrenceError != null) {
      setState(() => _error = recurrenceError);
      return;
    }

    final scope = widget.event?.repeats == true ? await _chooseScope() : null;
    if (!mounted || (widget.event?.repeats == true && scope == null)) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final draft = EventDraft(
      title: _title.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      startsAt: startsAt,
      endsAt: endsAt,
      category: _category,
      priority: _priority,
      recurrence: _recurrence(startsAt, scope),
      clearRecurrence: scope == 'series' && _frequency == 'none',
      scope: scope,
      occurrenceStart: scope == 'occurrence'
          ? widget.event?.occurrenceKey
          : null,
      baseVersion: widget.event?.version,
      reminderMinutes: _reminder,
    );
    final notifier = ref.read(agendaControllerProvider.notifier);
    final message = widget.event == null
        ? await notifier.create(draft)
        : await notifier.save(widget.event!.id, draft);
    if (!mounted) {
      return;
    }
    if (message == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _error = message;
    });
  }

  DateTime? _untilDate() {
    final parsed = parseEventDateTime(_until.text, '23:59');
    if (parsed == null) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day, 23, 59, 59, 999);
  }

  EventRecurrence? _recurrence(DateTime startsAt, String? scope) {
    if (scope == 'occurrence' || _frequency == 'none') {
      return null;
    }
    final until = _limit == 'until' ? _untilDate() : null;
    return EventRecurrence(
      frequency: _frequency,
      interval: int.parse(_interval.text.trim()),
      weekdays: _frequency == 'weekly' ? _weekdays.toList() : const [],
      until: until?.toUtc(),
      count: _limit == 'count' ? int.parse(_count.text.trim()) : null,
      offsetMinutes: startsAt.timeZoneOffset.inMinutes,
    );
  }

  Future<String?> _chooseScope() {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.event_repeat_outlined),
          title: const Text('Guardar cambios'),
          content: const Text(
            'Puedes cambiar solo esta fecha o aplicar los cambios a toda la serie.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              key: const Key('scope-occurrence'),
              onPressed: () => Navigator.of(context).pop('occurrence'),
              child: const Text('Solo este evento'),
            ),
            FilledButton(
              key: const Key('scope-series'),
              onPressed: () => Navigator.of(context).pop('series'),
              child: const Text('Toda la serie'),
            ),
          ],
        );
      },
    );
  }

  void _selectFrequency(String value) {
    setState(() {
      _frequency = value;
      if (value == 'weekly' && _weekdays.isEmpty) {
        final startsAt = parseEventDateTime(_date.text, _time.text);
        if (startsAt != null) {
          _weekdays.add(weekdayIndex(startsAt));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.event != null;
    const gap = SizedBox(height: AppSpacing.lg);
    const sectionGap = SizedBox(height: AppSpacing.xl);

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar evento' : 'Nuevo evento')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(title: 'Detalles'),
                    TextFormField(
                      key: const Key('event-title'),
                      controller: _title,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Título'),
                      validator: validateEventTitle,
                      textInputAction: TextInputAction.next,
                    ),
                    gap,
                    TextFormField(
                      key: const Key('event-description'),
                      controller: _description,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        alignLabelWithHint: true,
                      ),
                      validator: validateEventDescription,
                    ),
                    sectionGap,
                    const SectionHeader(title: 'Fecha y hora'),
                    _FieldPair(
                      first: _dateField(
                        key: const Key('event-date'),
                        controller: _date,
                        label: 'Fecha de inicio',
                      ),
                      second: _timeField(
                        key: const Key('event-time'),
                        controller: _time,
                        label: 'Hora de inicio',
                      ),
                    ),
                    SwitchListTile(
                      key: const Key('event-has-end'),
                      contentPadding: EdgeInsets.zero,
                      value: _hasEnd,
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() => _hasEnd = value),
                      title: const Text('Añadir hora de fin'),
                    ),
                    if (_hasEnd)
                      _FieldPair(
                        first: _dateField(
                          key: const Key('event-end-date'),
                          controller: _endDate,
                          label: 'Fecha de fin',
                        ),
                        second: _timeField(
                          key: const Key('event-end-time'),
                          controller: _endTime,
                          label: 'Hora de fin',
                        ),
                      ),
                    sectionGap,
                    const SectionHeader(title: 'Repetición'),
                    ..._recurrenceFields(context),
                    sectionGap,
                    const SectionHeader(title: 'Clasificación'),
                    _FieldPair(
                      first: DropdownButtonFormField<String>(
                        initialValue: _category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                        ),
                        items: [
                          for (final category in eventCategories)
                            DropdownMenuItem(
                              value: category,
                              child: Row(
                                children: [
                                  Icon(
                                    categoryIcon(category),
                                    size: 18,
                                    color: categoryColor(category),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Flexible(
                                    child: Text(categoryLabels[category]!),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        onChanged: _submitting
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _category = value);
                                }
                              },
                      ),
                      second: DropdownButtonFormField<String>(
                        initialValue: _priority,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Prioridad',
                        ),
                        items: [
                          for (final priority in eventPriorities)
                            DropdownMenuItem(
                              value: priority,
                              child: Text(priorityLabels[priority]!),
                            ),
                        ],
                        onChanged: _submitting
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _priority = value);
                                }
                              },
                      ),
                    ),
                    sectionGap,
                    const SectionHeader(title: 'Aviso'),
                    DropdownButtonFormField<int?>(
                      initialValue: _reminder,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Recordatorio',
                        prefixIcon: Icon(Icons.notifications_none),
                      ),
                      items: [
                        for (final choice in reminderChoices)
                          DropdownMenuItem(
                            value: choice,
                            child: Text(reminderLabels[choice]!),
                          ),
                      ],
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() => _reminder = value),
                    ),
                    if (_error != null) ...[
                      sectionGap,
                      InlineMessage.error(_error!),
                    ],
                    sectionGap,
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(editing ? 'Guardar cambios' : 'Guardar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _recurrenceFields(BuildContext context) {
    final theme = Theme.of(context);
    const gap = SizedBox(height: AppSpacing.lg);

    return [
      DropdownButtonFormField<String>(
        key: const Key('event-recurrence'),
        initialValue: _frequency,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Frecuencia',
          prefixIcon: Icon(Icons.repeat),
        ),
        items: const [
          DropdownMenuItem(value: 'none', child: Text('No se repite')),
          DropdownMenuItem(value: 'daily', child: Text('Cada día')),
          DropdownMenuItem(value: 'weekly', child: Text('Cada semana')),
          DropdownMenuItem(value: 'monthly', child: Text('Cada mes')),
        ],
        onChanged: _submitting
            ? null
            : (value) {
                if (value != null) {
                  _selectFrequency(value);
                }
              },
      ),
      if (_frequency != 'none') ...[
        gap,
        TextFormField(
          key: const Key('event-interval'),
          controller: _interval,
          enabled: !_submitting,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _frequency == 'daily'
                ? 'Cada cuántos días'
                : _frequency == 'weekly'
                ? 'Cada cuántas semanas'
                : 'Cada cuántos meses',
          ),
        ),
        if (_frequency == 'weekly') ...[
          gap,
          Text('Días de la semana', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final day in [1, 2, 3, 4, 5, 6, 0])
                FilterChip(
                  label: Text(weekdayLabels[day]!),
                  selected: _weekdays.contains(day),
                  onSelected: _submitting
                      ? null
                      : (selected) {
                          setState(() {
                            if (selected) {
                              _weekdays.add(day);
                            } else {
                              _weekdays.remove(day);
                            }
                          });
                        },
                ),
            ],
          ),
        ],
        gap,
        Text('Termina', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: const Text('Número de repeticiones'),
              selected: _limit == 'count',
              onSelected: _submitting
                  ? null
                  : (_) => setState(() => _limit = 'count'),
            ),
            ChoiceChip(
              label: const Text('Hasta una fecha'),
              selected: _limit == 'until',
              onSelected: _submitting
                  ? null
                  : (_) => setState(() => _limit = 'until'),
            ),
          ],
        ),
        gap,
        if (_limit == 'count')
          TextFormField(
            key: const Key('event-count'),
            controller: _count,
            enabled: !_submitting,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Repeticiones'),
          )
        else
          _dateField(
            key: const Key('event-until'),
            controller: _until,
            label: 'Fecha límite',
          ),
      ],
    ];
  }

  Widget _dateField({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      enabled: !_submitting,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(labelText: label, hintText: 'aaaa-mm-dd'),
      validator: (value) => parseEventDateTime(value ?? '', '00:00') == null
          ? 'Usa el formato aaaa-mm-dd'
          : null,
    );
  }

  Widget _timeField({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      enabled: !_submitting,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(labelText: label, hintText: 'hh:mm'),
      validator: (value) =>
          parseEventDateTime('2000-01-01', value ?? '') == null
          ? 'Usa el formato hh:mm'
          : null,
    );
  }
}

class _FieldPair extends StatelessWidget {
  const _FieldPair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              const SizedBox(height: AppSpacing.lg),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
