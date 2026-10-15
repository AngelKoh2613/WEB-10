import 'package:secureplan_mobile/features/agenda/domain/reminder_plan.dart';

class AgendaChange {
  const AgendaChange({required this.userId, required this.reminders});

  final String userId;
  final List<PlannedReminder> reminders;
}

abstract interface class AgendaObserver {
  void onAgendaChanged(AgendaChange change);
}

class AgendaChangeHub {
  final _observers = <AgendaObserver>[];

  void watch(AgendaObserver observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
    }
  }

  void unwatch(AgendaObserver observer) {
    _observers.remove(observer);
  }

  void notify(AgendaChange change) {
    for (final observer in List<AgendaObserver>.of(_observers)) {
      observer.onAgendaChanged(change);
    }
  }
}

class ReminderObserver implements AgendaObserver {
  ReminderObserver(this.scheduler);

  final ReminderScheduler scheduler;

  @override
  void onAgendaChanged(AgendaChange change) {
    scheduler.replace(change.reminders);
  }
}
