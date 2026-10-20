import 'package:flutter_test/flutter_test.dart';
import 'package:secureplan_mobile/features/agenda/domain/agenda_event.dart';

void main() {
  test(
    'rejects an empty title, a long description and an impossible interval',
    () {
      expect(validateEventTitle('  '), isNotNull);
      expect(validateEventTitle('Clase'), isNull);
      expect(validateEventDescription('x' * 4001), isNotNull);
      expect(parseEventDateTime('2026-02-31', '09:00'), isNull);
      expect(parseEventDateTime('2026-10-13', '09:00'), isNotNull);

      final start = DateTime(2026, 10, 13, 10);
      expect(
        validateEventInterval(start, DateTime(2026, 10, 13, 10)),
        isNotNull,
      );
      expect(validateEventInterval(start, DateTime(2026, 10, 13, 11)), isNull);
      expect(
        validateRecurrence(
          frequency: 'weekly',
          startsAt: start,
          interval: 1,
          weekdays: {0},
          untilLimit: false,
          count: 4,
          until: null,
        ),
        isNotNull,
      );
      expect(
        eventOverlapsDay(
          AgendaEvent(
            id: 'night',
            title: 'Turno',
            description: null,
            startsAt: DateTime(2026, 10, 13, 23),
            endsAt: DateTime(2026, 10, 14, 1),
            category: 'trabajo',
            priority: 'low',
            createdAt: start,
            updatedAt: start,
          ),
          DateTime(2026, 10, 14),
        ),
        isTrue,
      );
    },
  );
}
