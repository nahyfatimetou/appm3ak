import 'package:equatable/equatable.dart';

/// Modèle représentant un texte simplifié selon la méthode FALC
class SimplifiedTextModel extends Equatable {
  const SimplifiedTextModel({
    required this.simplifiedText,
    required this.keyPoints,
    required this.level,
    required this.originalWordCount,
    required this.simplifiedWordCount,
  });

  factory SimplifiedTextModel.fromJson(Map<String, dynamic> json) {
    return SimplifiedTextModel(
      simplifiedText: json['simplifiedText'] as String? ?? '',
      keyPoints: (json['keyPoints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      level: json['level'] as String? ?? 'facile',
      originalWordCount: (json['originalWordCount'] as num?)?.toInt() ?? 0,
      simplifiedWordCount: (json['simplifiedWordCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String simplifiedText;
  final List<String> keyPoints;
  final String level;
  final int originalWordCount;
  final int simplifiedWordCount;

  Map<String, dynamic> toJson() => {
        'simplifiedText': simplifiedText,
        'keyPoints': keyPoints,
        'level': level,
        'originalWordCount': originalWordCount,
        'simplifiedWordCount': simplifiedWordCount,
      };

  @override
  List<Object?> get props => [
        simplifiedText,
        keyPoints,
        level,
        originalWordCount,
        simplifiedWordCount,
      ];
}


