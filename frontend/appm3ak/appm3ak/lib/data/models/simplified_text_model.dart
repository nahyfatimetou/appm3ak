import 'package:equatable/equatable.dart';

/// Modèle correspondant à la réponse backend de:
/// POST /accessibility/simplify-text
class SimplifiedTextModel extends Equatable {
  const SimplifiedTextModel({
    required this.simplifiedText,
    required this.keyPoints,
    required this.level,
    required this.originalWordCount,
    required this.simplifiedWordCount,
    this.source,
  });

  factory SimplifiedTextModel.fromJson(Map<String, dynamic> json) {
    final text = json['simplifiedText'] as String? ??
        json['simplified_text'] as String? ??
        '';
    final keys = json['keyPoints'] as List<dynamic>? ??
        json['key_points'] as List<dynamic>?;
    return SimplifiedTextModel(
      simplifiedText: text,
      keyPoints: keys?.map((e) => e.toString()).toList() ?? const [],
      level: json['level'] as String? ?? 'facile',
      originalWordCount: (json['originalWordCount'] as num?)?.toInt() ??
          (json['original_word_count'] as num?)?.toInt() ??
          0,
      simplifiedWordCount:
          (json['simplifiedWordCount'] as num?)?.toInt() ??
              (json['simplified_word_count'] as num?)?.toInt() ??
              0,
      source: json['source'] as String?,
    );
  }

  final String simplifiedText;
  final List<String> keyPoints;
  final String level;
  final int originalWordCount;
  final int simplifiedWordCount;

  /// `ollama` | `heuristic` (réponse Nest si présente).
  final String? source;

  @override
  List<Object?> get props => [
        simplifiedText,
        keyPoints,
        level,
        originalWordCount,
        simplifiedWordCount,
        source,
      ];
}

