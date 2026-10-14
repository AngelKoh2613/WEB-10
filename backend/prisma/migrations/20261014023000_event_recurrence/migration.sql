-- AlterTable
ALTER TABLE "Event" ADD COLUMN "recurrenceFrequency" TEXT,
ADD COLUMN "recurrenceInterval" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN "recurrenceWeekdays" INTEGER[] NOT NULL DEFAULT ARRAY[]::INTEGER[],
ADD COLUMN "recurrenceUntil" TIMESTAMP(3),
ADD COLUMN "recurrenceCount" INTEGER,
ADD COLUMN "recurrenceOffsetMinutes" INTEGER;

ALTER TABLE "Event" ADD CONSTRAINT "Event_recurrence_check" CHECK (
    (
        "recurrenceFrequency" IS NULL
        AND "recurrenceUntil" IS NULL
        AND "recurrenceCount" IS NULL
        AND "recurrenceOffsetMinutes" IS NULL
        AND cardinality("recurrenceWeekdays") = 0
        AND "recurrenceInterval" BETWEEN 1 AND 99
    )
    OR (
        "recurrenceFrequency" IN ('daily', 'weekly', 'monthly')
        AND "recurrenceInterval" BETWEEN 1 AND 99
        AND "recurrenceOffsetMinutes" BETWEEN -840 AND 840
        AND "recurrenceWeekdays" <@ ARRAY[0, 1, 2, 3, 4, 5, 6]::INTEGER[]
        AND (
            (
                "recurrenceFrequency" = 'weekly'
                AND cardinality("recurrenceWeekdays") BETWEEN 1 AND 7
            )
            OR (
                "recurrenceFrequency" <> 'weekly'
                AND cardinality("recurrenceWeekdays") = 0
            )
        )
        AND (
            (
                "recurrenceUntil" IS NOT NULL
                AND "recurrenceCount" IS NULL
                AND "recurrenceUntil" > "startsAt"
            )
            OR (
                "recurrenceCount" IS NOT NULL
                AND "recurrenceUntil" IS NULL
                AND "recurrenceCount" BETWEEN 1 AND 366
            )
        )
    )
);

-- CreateTable
CREATE TABLE "EventException" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "originalStart" TIMESTAMP(3) NOT NULL,
    "excluded" BOOLEAN NOT NULL,
    "title" TEXT,
    "description" TEXT,
    "startsAt" TIMESTAMP(3),
    "endsAt" TIMESTAMP(3),
    "category" TEXT,
    "priority" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "EventException_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "EventException_shape_check" CHECK (
        (
            "excluded" = TRUE
            AND "title" IS NULL
            AND "description" IS NULL
            AND "startsAt" IS NULL
            AND "endsAt" IS NULL
            AND "category" IS NULL
            AND "priority" IS NULL
        )
        OR (
            "excluded" = FALSE
            AND "title" IS NOT NULL
            AND "startsAt" IS NOT NULL
            AND "category" IN ('personal', 'trabajo', 'estudio', 'otro')
            AND "priority" IN ('low', 'medium', 'high')
            AND ("endsAt" IS NULL OR "endsAt" > "startsAt")
        )
    )
);

-- CreateIndex
CREATE INDEX "EventException_eventId_idx" ON "EventException"("eventId");

-- CreateIndex
CREATE UNIQUE INDEX "EventException_eventId_originalStart_key" ON "EventException"("eventId", "originalStart");

-- AddForeignKey
ALTER TABLE "EventException" ADD CONSTRAINT "EventException_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE CASCADE ON UPDATE CASCADE;
