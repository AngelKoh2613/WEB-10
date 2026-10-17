import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secureplan_mobile/core/theme/app_theme.dart';
import 'package:secureplan_mobile/features/agenda/application/agenda_controller.dart';
import 'package:secureplan_mobile/features/agenda/domain/agenda_event.dart';
import 'package:secureplan_mobile/features/agenda/domain/reminder_plan.dart';
import 'package:secureplan_mobile/features/agenda/presentation/event_form_screen.dart';
import 'package:secureplan_mobile/features/agenda/presentation/event_style.dart';

class EventCard extends ConsumerWidget {
  const EventCard({super.key, required this.event});

  final AgendaEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = categoryColor(event.category);
    final end = event.endsAt == null ? null : formatEventTime(event.endsAt!);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatEventTime(event.startsAt),
                          style: theme.textTheme.titleSmall,
                        ),
                        if (end != null)
                          Text(
                            end,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(left: AppSpacing.md),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                      child: _EventDetails(event: event, accent: accent),
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        tooltip: 'Editar evento',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => EventFormScreen(event: event),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Eliminar evento',
                        onPressed: () => _confirmDelete(context, ref),
                        icon: Icon(Icons.delete_outline, color: scheme.error),
                      ),
                    ],
                  ),
                ],
              ),
              if (event.syncStatus != 'synced')
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                  ),
                  child: _SyncNotice(
                    status: event.syncStatus,
                    onResolve: (keepMine) =>
                        _resolve(context, ref, keepMine: keepMine),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref, {
    required bool keepMine,
  }) async {
    final message = await ref
        .read(agendaControllerProvider.notifier)
        .resolveConflict(event.id, keepMine: keepMine);
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    if (event.repeats) {
      final scope = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            icon: const Icon(Icons.event_repeat_outlined),
            title: const Text('Eliminar evento'),
            content: const Text(
              'Puedes quitar solo esta fecha o eliminar todas las repeticiones.',
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
                style: AppTheme.destructive(context),
                onPressed: () => Navigator.of(context).pop('series'),
                child: const Text('Toda la serie'),
              ),
            ],
          );
        },
      );
      if (scope == null || !context.mounted) {
        return;
      }
      final message = await ref
          .read(agendaControllerProvider.notifier)
          .delete(
            event.id,
            scope: scope,
            occurrenceStart: scope == 'occurrence' ? event.occurrenceKey : null,
            baseVersion: event.version,
          );
      if (message != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('Eliminar evento'),
          content: Text(
            'Se eliminará “${event.title}”. Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: AppTheme.destructive(context),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final message = await ref
        .read(agendaControllerProvider.notifier)
        .delete(event.id, baseVersion: event.version);
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _EventDetails extends StatelessWidget {
  const _EventDetails({required this.event, required this.accent});

  final AgendaEvent event;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final reminder = reminderLabels[event.reminderMinutes];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(event.title, style: theme.textTheme.titleMedium),
        if (event.description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.notes_outlined, size: 16, color: muted),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  event.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _Tag(
              icon: categoryIcon(event.category),
              label: categoryLabels[event.category] ?? event.category,
              color: accent,
            ),
            _Tag(
              icon: priorityIcon(event.priority),
              label:
                  'Prioridad ${(priorityLabels[event.priority] ?? event.priority).toLowerCase()}',
              color: event.priority == 'high' ? theme.colorScheme.error : muted,
            ),
            if (event.repeats)
              _Tag(icon: Icons.repeat, label: 'Se repite', color: muted),
            if (event.reminderMinutes != null && reminder != null)
              _Tag(
                icon: Icons.notifications_none,
                label: reminder,
                color: muted,
              ),
          ],
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _SyncNotice extends StatelessWidget {
  const _SyncNotice({required this.status, required this.onResolve});

  final String status;
  final ValueChanged<bool> onResolve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = syncStyle(status);
    final conflict = status == 'conflict';
    final detail = switch (status) {
      'pending' => 'Se enviará cuando haya conexión con el servidor.',
      'conflict' =>
        'El evento cambió en el servidor. Elige qué versión conservar.',
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(style.icon, size: 18, color: style.foreground),
              const SizedBox(width: AppSpacing.sm),
              Text(
                syncStatusLabels[status] ?? 'Pendiente',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: style.foreground,
                ),
              ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: style.foreground,
              ),
            ),
          ],
          if (conflict) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    backgroundColor: theme.colorScheme.surface,
                  ),
                  onPressed: () => onResolve(false),
                  child: const Text('Usar servidor'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => onResolve(true),
                  child: const Text('Usar mi versión'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
