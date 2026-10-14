export const recurrenceFrequencies = ["daily", "weekly", "monthly"] as const;

export type RecurrenceFrequency = (typeof recurrenceFrequencies)[number];

export type RecurrenceRule = {
  frequency: RecurrenceFrequency;
  interval: number;
  weekdays: number[];
  until: Date | null;
  count: number | null;
  offsetMinutes: number;
};

export type SeriesException = {
  originalStart: Date;
  excluded: boolean;
  startsAt: Date | null;
  endsAt: Date | null;
};

export type ExpandedOccurrence = {
  originalStart: Date;
  startsAt: Date;
  endsAt: Date | null;
};

const dayMs = 86_400_000;
const maxSpanMs = 366 * dayMs;

type Clock = { hour: number; minute: number; second: number; ms: number };
type Civil = Clock & { year: number; month: number; day: number; weekday: number };

function civilOf(instant: Date, offsetMinutes: number): Civil {
  const shifted = new Date(instant.getTime() + offsetMinutes * 60_000);
  return {
    year: shifted.getUTCFullYear(),
    month: shifted.getUTCMonth() + 1,
    day: shifted.getUTCDate(),
    weekday: shifted.getUTCDay(),
    hour: shifted.getUTCHours(),
    minute: shifted.getUTCMinutes(),
    second: shifted.getUTCSeconds(),
    ms: shifted.getUTCMilliseconds(),
  };
}

function instantFromCivil(
  year: number,
  month: number,
  day: number,
  clock: Clock,
  offsetMinutes: number,
): Date | null {
  const utc = new Date(Date.UTC(year, month - 1, day, clock.hour, clock.minute, clock.second, clock.ms));
  if (utc.getUTCFullYear() !== year || utc.getUTCMonth() !== month - 1 || utc.getUTCDate() !== day) {
    return null;
  }
  return new Date(utc.getTime() - offsetMinutes * 60_000);
}

function addMonths(year: number, month: number, delta: number): { year: number; month: number } {
  const index = year * 12 + (month - 1) + delta;
  return { year: Math.floor(index / 12), month: (index % 12) + 1 };
}

function weekIndex(year: number, month: number, day: number): number {
  const dayNumber = Math.floor(Date.UTC(year, month - 1, day) / dayMs);
  const weekday = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  return Math.floor((dayNumber - weekday) / 7);
}

export function seriesStarts(startsAt: Date, rule: RecurrenceRule): Date[] {
  const civil = civilOf(startsAt, rule.offsetMinutes);
  const clock: Clock = {
    hour: civil.hour,
    minute: civil.minute,
    second: civil.second,
    ms: civil.ms,
  };
  const horizon = startsAt.getTime() + maxSpanMs;
  const starts: Date[] = [];
  const done = (occurrence: Date): boolean => {
    if (occurrence.getTime() > horizon) {
      return true;
    }
    if (rule.until && occurrence.getTime() > rule.until.getTime()) {
      return true;
    }
    starts.push(occurrence);
    return rule.count !== null && starts.length >= rule.count;
  };

  if (rule.frequency === "daily") {
    for (let step = 0; step < 400; step += 1) {
      const cursor = new Date(Date.UTC(civil.year, civil.month - 1, civil.day) + step * rule.interval * dayMs);
      const occurrence = instantFromCivil(
        cursor.getUTCFullYear(),
        cursor.getUTCMonth() + 1,
        cursor.getUTCDate(),
        clock,
        rule.offsetMinutes,
      );
      if (!occurrence || done(occurrence)) {
        break;
      }
    }
  }

  if (rule.frequency === "weekly") {
    const startWeek = weekIndex(civil.year, civil.month, civil.day);
    for (let offset = 0; offset <= 366; offset += 1) {
      const cursor = new Date(Date.UTC(civil.year, civil.month - 1, civil.day) + offset * dayMs);
      const year = cursor.getUTCFullYear();
      const month = cursor.getUTCMonth() + 1;
      const day = cursor.getUTCDate();
      const weekday = cursor.getUTCDay();
      if (!rule.weekdays.includes(weekday)) {
        continue;
      }
      if ((weekIndex(year, month, day) - startWeek) % rule.interval !== 0) {
        continue;
      }
      const occurrence = instantFromCivil(year, month, day, clock, rule.offsetMinutes);
      if (!occurrence || done(occurrence)) {
        break;
      }
    }
  }

  if (rule.frequency === "monthly") {
    for (let step = 0; step < 400; step += 1) {
      const next = addMonths(civil.year, civil.month, step * rule.interval);
      const occurrence = instantFromCivil(next.year, next.month, civil.day, clock, rule.offsetMinutes);
      if (!occurrence) {
        const probe = instantFromCivil(next.year, next.month, 1, clock, rule.offsetMinutes);
        if (!probe || probe.getTime() > horizon || (rule.until && probe.getTime() > rule.until.getTime())) {
          break;
        }
        continue;
      }
      if (done(occurrence)) {
        break;
      }
    }
  }

  return starts;
}

export function recurrenceError(startsAt: Date, rule: RecurrenceRule | null): string | null {
  if (!rule) {
    return null;
  }
  const hasUntil = rule.until !== null;
  const hasCount = rule.count !== null;
  if (hasUntil === hasCount) {
    return "Indica una fecha límite o un número de repeticiones";
  }
  if (rule.interval < 1 || rule.interval > 99) {
    return "La recurrencia no es válida";
  }
  if (rule.offsetMinutes < -840 || rule.offsetMinutes > 840) {
    return "La recurrencia no es válida";
  }
  if (rule.until && rule.until.getTime() <= startsAt.getTime()) {
    return "La fecha límite debe ser posterior al inicio";
  }
  if (rule.until && rule.until.getTime() > startsAt.getTime() + maxSpanMs) {
    return "La serie supera el máximo de un año";
  }
  const uniqueDays = new Set(rule.weekdays);
  if (uniqueDays.size !== rule.weekdays.length || rule.weekdays.some((day) => day < 0 || day > 6)) {
    return "La recurrencia no es válida";
  }
  if (rule.frequency === "weekly") {
    if (rule.weekdays.length === 0) {
      return "La recurrencia no es válida";
    }
    if (!rule.weekdays.includes(civilOf(startsAt, rule.offsetMinutes).weekday)) {
      return "Elige un día de la semana que coincida con el inicio";
    }
  } else if (rule.weekdays.length > 0) {
    return "La recurrencia no es válida";
  }
  if (rule.count !== null && (rule.count < 1 || rule.count > 366)) {
    return "La recurrencia no es válida";
  }
  if (rule.count !== null && seriesStarts(startsAt, rule).length < rule.count) {
    return "La serie supera el máximo de un año";
  }
  return null;
}

export function occurrencesInRange(input: {
  startsAt: Date;
  endsAt: Date | null;
  recurrence: RecurrenceRule | null;
  exceptions: SeriesException[];
  rangeStart: Date;
  rangeEnd: Date;
}): ExpandedOccurrence[] {
  const originals = input.recurrence ? seriesStarts(input.startsAt, input.recurrence) : [input.startsAt];
  const duration = input.endsAt ? input.endsAt.getTime() - input.startsAt.getTime() : null;
  const exceptions = new Map(input.exceptions.map((item) => [item.originalStart.getTime(), item]));
  const visible: ExpandedOccurrence[] = [];

  for (const original of originals) {
    const exception = exceptions.get(original.getTime());
    if (exception?.excluded) {
      continue;
    }
    const startsAt = exception?.startsAt ?? original;
    const endsAt = exception
      ? exception.endsAt
      : duration === null
        ? null
        : new Date(original.getTime() + duration);
    const starts = startsAt.getTime();
    const rangeStart = input.rangeStart.getTime();
    const rangeEnd = input.rangeEnd.getTime();
    const overlaps =
      endsAt === null
        ? starts >= rangeStart && starts < rangeEnd
        : starts < rangeEnd && endsAt.getTime() > rangeStart;
    if (overlaps) {
      visible.push({ originalStart: original, startsAt, endsAt });
    }
  }

  return visible;
}
