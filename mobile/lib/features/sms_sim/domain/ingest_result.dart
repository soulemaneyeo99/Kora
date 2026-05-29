/// Resultat d'une ingestion de SMS / notification mobile money.
/// Miroir de `IngestResult` cote backend (`app/schemas/ingestion.py`).
class IngestResult {
  const IngestResult({
    required this.success,
    required this.parserName,
    this.reason,
    this.transactionId,
    this.duplicate = false,
  });

  final bool success;
  final String parserName;
  final String? reason;
  final String? transactionId;
  final bool duplicate;

  factory IngestResult.fromJson(Map<String, dynamic> json) {
    final decision = (json['decision'] as Map).cast<String, dynamic>();
    return IngestResult(
      success: decision['success'] as bool,
      reason: decision['reason'] as String?,
      transactionId: decision['transaction_id'] as String?,
      parserName: json['parser_name'] as String? ?? 'inconnu',
      duplicate: json['duplicate'] as bool? ?? false,
    );
  }
}
