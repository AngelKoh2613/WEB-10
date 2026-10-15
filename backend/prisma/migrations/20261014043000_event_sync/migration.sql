-- AlterTable
ALTER TABLE "Event" ADD COLUMN "version" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN "reminderMinutes" INTEGER;

ALTER TABLE "Event" ADD CONSTRAINT "Event_version_check" CHECK ("version" >= 1);
ALTER TABLE "Event" ADD CONSTRAINT "Event_reminder_check" CHECK (
    "reminderMinutes" IS NULL OR "reminderMinutes" IN (5, 15, 60, 1440)
);

-- CreateTable
CREATE TABLE "EventTombstone" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "deletedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EventTombstone_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "EventTombstone_version_check" CHECK ("version" >= 1)
);

-- CreateIndex
CREATE INDEX "EventTombstone_userId_idx" ON "EventTombstone"("userId");

-- AddForeignKey
ALTER TABLE "EventTombstone" ADD CONSTRAINT "EventTombstone_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
