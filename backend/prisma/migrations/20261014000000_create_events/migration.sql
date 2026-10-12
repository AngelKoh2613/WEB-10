-- CreateTable
CREATE TABLE "Event" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3),
    "category" TEXT NOT NULL,
    "priority" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Event_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "Event_category_check" CHECK ("category" IN ('personal', 'trabajo', 'estudio', 'otro')),
    CONSTRAINT "Event_priority_check" CHECK ("priority" IN ('low', 'medium', 'high')),
    CONSTRAINT "Event_interval_check" CHECK ("endsAt" IS NULL OR "endsAt" > "startsAt")
);

-- CreateIndex
CREATE INDEX "Event_userId_startsAt_idx" ON "Event"("userId", "startsAt");

-- AddForeignKey
ALTER TABLE "Event" ADD CONSTRAINT "Event_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
