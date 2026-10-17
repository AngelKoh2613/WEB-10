import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secureplan_mobile/core/theme/app_theme.dart';
import 'package:secureplan_mobile/features/agenda/application/agenda_controller.dart';
import 'package:secureplan_mobile/features/agenda/domain/agenda_event.dart';
import 'package:secureplan_mobile/features/agenda/presentation/event_card.dart';
import 'package:secureplan_mobile/features/agenda/presentation/event_form_screen.dart';
import 'package:secureplan_mobile/features/agenda/presentation/month_calendar.dart';
import 'package:secureplan_mobile/shared/widgets/empty_view.dart';
import 'package:secureplan_mobile/shared/widgets/error_view.dart';
import 'package:secureplan_mobile/shared/widgets/loading_view.dart';
import 'package:secureplan_mobile/shared/widgets/section_header.dart';

class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(agendaControllerProvider);
    final selected = ref.watch(selectedDayProvider);

    return Scaffold(
      body: agenda.when(
        loading: () => const LoadingView(message: 'Cargando eventos'),
        error: (error, _) => ErrorView(
          title: 'No se pudieron cargar los eventos',
          message: 'Comprueba la conexión e inténtalo de nuevo.',
          onRetry: () => ref.invalidate(agendaControllerProvider),
        ),
        data: (events) {
          final marked = <DateTime>{
            for (
              var day = 1;
              day <= DateTime(selected.year, selected.month + 1, 0).day;
              day++
            )
              if (events.any(
                (event) => eventOverlapsDay(
                  event,
                  DateTime(selected.year, selected.month, day),
                ),
              ))
                DateTime(selected.year, selected.month, day),
          };
          final visible =
              events
                  .where((event) => eventOverlapsDay(event, selected))
                  .toList()
                ..sort(
                  (left, right) => left.startsAt.compareTo(right.startsAt),
                );

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: MonthCalendar(
                    visibleDay: selected,
                    markedDays: marked,
                    onSelect: ref.read(selectedDayProvider.notifier).select,
                    onPreviousMonth: () =>
                        ref.read(selectedDayProvider.notifier).shiftMonth(-1),
                    onNextMonth: () =>
                        ref.read(selectedDayProvider.notifier).shiftMonth(1),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(
                    title: _dayTitle(selected),
                    trailing: visible.length == 1
                        ? '1 evento'
                        : '${visible.length} eventos',
                  ),
                ),
              ),
              if (visible.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.only(bottom: 96),
                  sliver: SliverToBoxAdapter(
                    child: EmptyView(
                      title: 'No hay eventos este día',
                      message: 'Elige otra fecha o crea un evento.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    96,
                  ),
                  sliver: SliverList.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      return EventCard(event: visible[index]);
                    },
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: agenda.isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EventFormScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Nuevo evento'),
            ),
    );
  }
}

String _dayTitle(DateTime day) {
  final weekday = weekdayLabels[weekdayIndex(day)]!;
  return '$weekday, ${day.day} de ${monthNames[day.month - 1]}';
}
