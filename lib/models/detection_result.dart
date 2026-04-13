class DetectionResult {
  final String status;
  final String filename;
  final String originalFilename;
  final String docType;
  final String action;
  final int piiCount;
  final List<String> piiDetected;
  final String redactionSummary;
  final String processedAt;

  DetectionResult({
    required this.status,
    required this.filename,
    required this.originalFilename,
    required this.docType,
    required this.action,
    required this.piiCount,
    required this.piiDetected,
    required this.redactionSummary,
    required this.processedAt,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      status: json['status'] ?? 'success',
      filename: json['filename'] ?? '',
      originalFilename: json['original_filename'] ?? '',
      docType: json['doc_type'] ?? 'general',
      action: json['action'] ?? 'redact',
      piiCount: (json['pii_detected'] as List<dynamic>?)?.length ?? 0,
      piiDetected: (json['pii_detected'] as List<dynamic>?)?.cast<String>() ?? [],
      redactionSummary: json['redaction_summary'] ?? '',
      processedAt: json['processed_at'] ?? '',
    );
  }
}
