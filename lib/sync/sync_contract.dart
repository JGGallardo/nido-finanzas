/// Future REST adapter must authenticate and authorize household membership on the server.
/// Amounts are decimal strings in transport (BIGINT safe); UTC timestamps and UUID entity IDs.
abstract interface class SyncTransport {
  Future<SyncBatch> pull({required String householdId, String? cursor});
  Future<List<String>> push({
    required String householdId,
    required List<SyncChange> changes,
  });
}

class SyncChange {
  const SyncChange({
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.baseRevision,
    required this.payload,
  });
  final String operationId, entityType, entityId, operation;
  final int baseRevision;
  final Map<String, dynamic> payload;
}

class SyncBatch {
  const SyncBatch(this.cursor, this.changes);
  final String cursor;
  final List<SyncChange> changes;
}
// No network synchronization is enabled in the MVP. Outbox is durable and transactional.
