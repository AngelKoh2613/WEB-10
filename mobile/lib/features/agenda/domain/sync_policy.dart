enum SyncDisposition { synced, retry, conflict, failed, unauthenticated }

class SyncDecision {
  const SyncDecision(this.disposition, {this.attempts = 0});

  final SyncDisposition disposition;
  final int attempts;
}

const maxSyncAttempts = 5;

SyncDecision decideSync({
  required int? statusCode,
  required bool networkError,
  required int attempts,
}) {
  final nextAttempts = attempts + 1;
  if (networkError || (statusCode != null && statusCode >= 500)) {
    if (nextAttempts >= maxSyncAttempts) {
      return SyncDecision(SyncDisposition.failed, attempts: nextAttempts);
    }
    return SyncDecision(SyncDisposition.retry, attempts: nextAttempts);
  }
  if (statusCode == 401) {
    return SyncDecision(SyncDisposition.unauthenticated, attempts: nextAttempts);
  }
  if (statusCode == 409) {
    return SyncDecision(SyncDisposition.conflict, attempts: nextAttempts);
  }
  if (statusCode == 200 || statusCode == 201 || statusCode == 204) {
    return SyncDecision(SyncDisposition.synced, attempts: nextAttempts);
  }
  return SyncDecision(SyncDisposition.failed, attempts: nextAttempts);
}
