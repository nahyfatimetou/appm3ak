import 'package:equatable/equatable.dart';

/// Modèle pour la vidéo LSF (Langue des Signes Française)
class LSFVideoModel extends Equatable {
  const LSFVideoModel({
    required this.videoUrl,
    required this.signedText,
    required this.duration,
    this.status,
  });

  factory LSFVideoModel.fromJson(Map<String, dynamic> json) {
    return LSFVideoModel(
      videoUrl: json['videoUrl'] as String? ?? '',
      signedText: json['signedText'] as String? ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      status: json['status'] as String?,
    );
  }

  final String videoUrl;
  final String signedText;
  final int duration;
  final String? status;

  Map<String, dynamic> toJson() => {
        'videoUrl': videoUrl,
        'signedText': signedText,
        'duration': duration,
        'status': status,
      };

  @override
  List<Object?> get props => [videoUrl, signedText, duration, status];
}

/// Modèle pour le résumé flash (handicap moteur)
class FlashSummaryModel extends Equatable {
  const FlashSummaryModel({
    required this.summary,
    required this.keyPoints,
    required this.readingTimeSeconds,
    required this.wordReduction,
  });

  factory FlashSummaryModel.fromJson(Map<String, dynamic> json) {
    return FlashSummaryModel(
      summary: json['summary'] as String? ?? '',
      keyPoints: (json['keyPoints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      readingTimeSeconds: (json['readingTimeSeconds'] as num?)?.toInt() ?? 0,
      wordReduction: (json['wordReduction'] as num?)?.toInt() ?? 0,
    );
  }

  final String summary;
  final List<String> keyPoints;
  final int readingTimeSeconds;
  final int wordReduction;

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'keyPoints': keyPoints,
        'readingTimeSeconds': readingTimeSeconds,
        'wordReduction': wordReduction,
      };

  @override
  List<Object?> get props => [summary, keyPoints, readingTimeSeconds, wordReduction];
}


