class DocumentProcessResult {
  const DocumentProcessResult(
      {required this.asset,
      required this.text,
      required this.chunkCount,
      required this.citationCount,
      required this.previewPath,
      required this.thumbnailPath,
      required this.warnings});
  final Map<String, dynamic> asset;
  final String text;
  final int chunkCount;
  final int citationCount;
  final String previewPath;
  final String thumbnailPath;
  final List<String> warnings;

  factory DocumentProcessResult.fromJson(Map<String, dynamic> json) =>
      DocumentProcessResult(
          asset: json['asset'] is Map
              ? Map<String, dynamic>.from(json['asset'] as Map)
              : const {},
          text: '${json['text'] ?? ''}',
          chunkCount: _int(json['chunk_count']),
          citationCount: _int(json['citation_count']),
          previewPath: '${json['preview_path'] ?? ''}',
          thumbnailPath: '${json['thumbnail_path'] ?? ''}',
          warnings: json['warnings'] is List
              ? (json['warnings'] as List).whereType<String>().toList()
              : const []);
}

class CoreSearchHit {
  const CoreSearchHit(
      {required this.documentId,
      required this.title,
      required this.score,
      required this.snippet,
      required this.sourceType,
      required this.sourceUrl,
      required this.metadata});
  final String documentId;
  final String title;
  final double score;
  final String snippet;
  final String sourceType;
  final String sourceUrl;
  final Map<String, dynamic> metadata;

  factory CoreSearchHit.fromJson(Map<String, dynamic> json) => CoreSearchHit(
      documentId: '${json['document_id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      snippet: '${json['snippet'] ?? ''}',
      sourceType: '${json['source_type'] ?? ''}',
      sourceUrl: '${json['source_url'] ?? ''}',
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {});
}

class CoreCapabilities {
  const CoreCapabilities(
      {required this.modules,
      required this.documentEngine,
      required this.telemetryDefault});
  final List<String> modules;
  final List<String> documentEngine;
  final bool telemetryDefault;

  factory CoreCapabilities.fromJson(Map<String, dynamic> json) {
    final privacy = json['privacy'];
    return CoreCapabilities(
        modules: _strings(json['modules']),
        documentEngine: _strings(json['document_engine']),
        telemetryDefault:
            privacy is Map && privacy['telemetry_default'] == true);
  }
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
List<String> _strings(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];
