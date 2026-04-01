/// Réponse de `GET /community/posts/.../images/.../audio-description` (vision + TTS).
class ImageVisionDescription {
  const ImageVisionDescription({
    required this.audioDescription,
    required this.description,
    this.displaySummary,
    this.textDetected,
    required this.source,
  });

  factory ImageVisionDescription.fromJson(Map<String, dynamic> json) {
    String stripCodeFences(String s) {
      // Supprime les blocs Markdown (ex: ```json ... ```), fréquents en sortie IA.
      return s
          .replaceAll('```json', '')
          .replaceAll('```JSON', '')
          .replaceAll('```', '')
          .trim();
    }

    // Backend peut renvoyer des clés en camelCase ou snake_case.
    final String? visionDesc = json['description'] as String? ??
        json['vision_description'] as String? ??
        json['visionDescription'] as String?;

    final String? audioDesc = json['audioDescription'] as String? ??
        json['audio_description'] as String? ??
        // Certaines réponses peuvent encore utiliser ce nom.
        json['description_audio'] as String? ??
        json['audioDescriptionText'] as String?;

    final summary = json['displaySummary'] as String? ??
        json['display_summary'] as String?;

    final detectedText = json['textDetected'] as String? ??
        json['text_detected'] as String?;

    final src = json['source'] as String? ?? 'text_fallback';
    return ImageVisionDescription(
      // On ne mélange plus vision et audio.
      // - description: uniquement vision (si fournie)
      // - audioDescription: uniquement audio (si fournie)
      audioDescription: stripCodeFences((audioDesc ?? visionDesc ?? '').toString()),
      description: stripCodeFences((visionDesc ?? '').toString()),
      displaySummary:
          summary != null && summary.trim().isNotEmpty ? summary.trim() : null,
      textDetected: detectedText,
      source: src,
    );
  }

  final String audioDescription;
  final String description;
  /// Résumé court pour l’UI (ex. « Obstacle détecté : poubelle »).
  final String? displaySummary;
  final String? textDetected;
  /// `vision` | `text_fallback`
  final String source;

  /// Texte détaillé pour la synthèse vocale (pas le résumé court).
  String get textForSpeech =>
      description.isNotEmpty ? description : audioDescription;
}
