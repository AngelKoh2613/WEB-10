import {
  occurrencesInRange,
  recurrenceError,
  seriesStarts,
} from "../src/events/recurrence.js";

const day = 86_400_000;

function at(iso: string): Date {
  return new Date(iso);
}

function iso(value: Date): string {
  return value.toISOString();
}

describe("recurrence", () => {
  it("keeps a single event inside the requested range", () => {
    const startsAt = at("2026-10-13T15:00:00.000Z");
    const endsAt = at("2026-10-14T01:00:00.000Z");

    const inside = occurrencesInRange({
      startsAt,
      endsAt,
      recurrence: null,
      exceptions: [],
      rangeStart: at("2026-10-14T00:00:00.000Z"),
      rangeEnd: at("2026-10-15T00:00:00.000Z"),
    });
    const outside = occurrencesInRange({
      startsAt,
      endsAt,
      recurrence: null,
      exceptions: [],
      rangeStart: at("2026-10-15T00:00:00.000Z"),
      rangeEnd: at("2026-10-16T00:00:00.000Z"),
    });

    expect(inside.map((item) => iso(item.startsAt))).toEqual(["2026-10-13T15:00:00.000Z"]);
    expect(outside).toEqual([]);
  });

  it("repeats daily by the given interval and stops at a count or an until date", () => {
    const startsAt = at("2026-10-13T15:00:00.000Z");
    const rule = {
      frequency: "daily" as const,
      interval: 2,
      weekdays: [],
      until: null,
      count: 3,
      offsetMinutes: 0,
    };

    expect(seriesStarts(startsAt, rule).map(iso)).toEqual([
      "2026-10-13T15:00:00.000Z",
      "2026-10-15T15:00:00.000Z",
      "2026-10-17T15:00:00.000Z",
    ]);

    const until = seriesStarts(startsAt, {
      ...rule,
      count: null,
      until: at("2026-10-16T15:00:00.000Z"),
    });
    expect(until.map(iso)).toEqual(["2026-10-13T15:00:00.000Z", "2026-10-15T15:00:00.000Z"]);
  });

  it("repeats weekly on several weekdays and keeps the week interval", () => {
    const startsAt = at("2026-10-13T15:00:00.000Z");
    const starts = seriesStarts(startsAt, {
      frequency: "weekly",
      interval: 2,
      weekdays: [2, 4],
      until: null,
      count: 4,
      offsetMinutes: 0,
    });

    expect(starts.map(iso)).toEqual([
      "2026-10-13T15:00:00.000Z",
      "2026-10-15T15:00:00.000Z",
      "2026-10-27T15:00:00.000Z",
      "2026-10-29T15:00:00.000Z",
    ]);
  });

  it("skips short months, including a non-leap February, and keeps leap day", () => {
    const jan31 = seriesStarts(at("2024-01-31T15:00:00.000Z"), {
      frequency: "monthly",
      interval: 1,
      weekdays: [],
      until: null,
      count: 4,
      offsetMinutes: 0,
    });
    expect(jan31.map(iso)).toEqual([
      "2024-01-31T15:00:00.000Z",
      "2024-03-31T15:00:00.000Z",
      "2024-05-31T15:00:00.000Z",
      "2024-07-31T15:00:00.000Z",
    ]);

    const leap = seriesStarts(at("2024-02-29T15:00:00.000Z"), {
      frequency: "monthly",
      interval: 1,
      weekdays: [],
      until: at("2025-02-28T15:00:00.000Z"),
      count: null,
      offsetMinutes: 0,
    });
    expect(leap.map(iso)).toContain("2024-02-29T15:00:00.000Z");
    expect(leap.map(iso)).toContain("2025-01-29T15:00:00.000Z");
    expect(leap.map(iso)).not.toContain("2025-02-28T15:00:00.000Z");
    expect(leap.some((item) => item.getUTCMonth() === 1 && item.getUTCFullYear() === 2025)).toBe(
      false,
    );
  });

  it("uses the series offset when the civil day differs from the UTC day", () => {
    const startsAt = at("2026-02-01T02:00:00.000Z");
    const starts = seriesStarts(startsAt, {
      frequency: "monthly",
      interval: 1,
      weekdays: [],
      until: null,
      count: 2,
      offsetMinutes: -360,
    });

    expect(starts.map(iso)).toEqual(["2026-02-01T02:00:00.000Z", "2026-04-01T02:00:00.000Z"]);
    expect(
      recurrenceError(startsAt, {
        frequency: "weekly",
        interval: 1,
        weekdays: [0],
        until: null,
        count: 2,
        offsetMinutes: -360,
      }),
    ).toBe("Elige un día de la semana que coincida con el inicio");
  });

  it("returns only the slice of a series that overlaps a range", () => {
    const startsAt = at("2026-10-01T15:00:00.000Z");
    const visible = occurrencesInRange({
      startsAt,
      endsAt: at("2026-10-01T16:00:00.000Z"),
      recurrence: {
        frequency: "daily",
        interval: 1,
        weekdays: [],
        until: null,
        count: 10,
        offsetMinutes: 0,
      },
      exceptions: [
        {
          originalStart: at("2026-10-04T15:00:00.000Z"),
          excluded: true,
          startsAt: null,
          endsAt: null,
        },
        {
          originalStart: at("2026-10-05T15:00:00.000Z"),
          excluded: false,
          startsAt: at("2026-10-05T18:00:00.000Z"),
          endsAt: at("2026-10-05T19:00:00.000Z"),
        },
      ],
      rangeStart: at("2026-10-04T00:00:00.000Z"),
      rangeEnd: at("2026-10-06T00:00:00.000Z"),
    });

    expect(visible.map((item) => iso(item.startsAt))).toEqual(["2026-10-05T18:00:00.000Z"]);
    expect(iso(visible[0]?.originalStart ?? at("1970-01-01T00:00:00.000Z"))).toBe(
      "2026-10-05T15:00:00.000Z",
    );
  });

  it("rejects an inverted limit, a missing limit and a series longer than one year", () => {
    const startsAt = at("2026-10-13T15:00:00.000Z");
    const base = {
      frequency: "daily" as const,
      interval: 1,
      weekdays: [],
      until: null,
      count: 2,
      offsetMinutes: 0,
    };

    expect(recurrenceError(startsAt, { ...base, count: null, until: startsAt })).toBe(
      "La fecha límite debe ser posterior al inicio",
    );
    expect(recurrenceError(startsAt, { ...base, count: null, until: null })).toBe(
      "Indica una fecha límite o un número de repeticiones",
    );
    expect(
      recurrenceError(startsAt, {
        ...base,
        count: null,
        until: new Date(startsAt.getTime() + 367 * day),
      }),
    ).toBe("La serie supera el máximo de un año");
    expect(recurrenceError(startsAt, null)).toBeNull();
  });
});
