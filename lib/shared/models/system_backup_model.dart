class SystemBackup {
  final String id;
  final String filename;
  final int sizeBytes;
  final String status; // 'completed', 'in_progress', 'failed'
  final DateTime createdAt;
  final String createdBy;

  SystemBackup({
    required this.id,
    required this.filename,
    required this.sizeBytes,
    required this.status,
    required this.createdAt,
    required this.createdBy,
  });

  factory SystemBackup.fromMap(Map<String, dynamic> map) {
    return SystemBackup(
      id: map['id']?.toString() ?? '',
      filename: map['filename'] ?? '',
      sizeBytes: map['size_bytes'] ?? 0,
      status: map['status'] ?? 'completed',
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      createdBy: map['created_by'] ?? 'system',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filename': filename,
      'size_bytes': sizeBytes,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
