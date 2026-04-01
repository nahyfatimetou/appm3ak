import 'package:flutter/material.dart';

import '../../../data/models/post_model.dart';
import 'tts_helper.dart';

/// Badge de vérification IA pour les posts avec analyse d'accessibilité.
class AIBadge extends StatelessWidget {
  const AIBadge({
    super.key,
    required this.analysis,
    this.compact = false,
  });

  final AccessibilityAnalysis analysis;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Déterminer le type de badge selon l'analyse
    final (color, icon, text, semanticLabel) = _getBadgeInfo(analysis);

    if (compact) {
      // Version compacte (petit badge)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    // Version complète (badge avec description)
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Bouton TTS pour l'accessibilité
                    TTSButton(analysis: analysis, iconSize: 20),
                  ],
                ),
                if (analysis.description != null && analysis.description!.isNotEmpty)
                  const SizedBox(height: 4),
                if (analysis.description != null && analysis.description!.isNotEmpty)
                  Text(
                    analysis.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (analysis.scoreAccessibilite != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Text(
                          'Score: ${analysis.scoreAccessibilite}/100',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (analysis.scoreAccessibilite ?? 0) / 100,
                            backgroundColor: color.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Retourne les informations du badge selon l'analyse
  (Color color, IconData icon, String text, String semanticLabel) _getBadgeInfo(
    AccessibilityAnalysis analysis,
  ) {
    // Badge vert : Accessible (rampe ou ascenseur détecté)
    if (analysis.isAccessible) {
      return (
        Colors.green,
        Icons.verified,
        '✅ Vérifié par Ma3ak AI',
        'Accessible : ${analysis.description ?? "Caractéristiques d\'accessibilité détectées"}',
      );
    }

    // Badge orange : Avertissement (obstacles détectés)
    if (analysis.hasWarnings) {
      return (
        Colors.orange,
        Icons.warning,
        '⚠️ Attention : Obstacles détectés',
        'Avertissement : ${analysis.description ?? "Des obstacles peuvent bloquer l\'accès"}',
      );
    }

    // Badge bleu : Analyse disponible mais résultats mitigés
    if (analysis.scoreAccessibilite != null && analysis.scoreAccessibilite! > 0) {
      return (
        Colors.blue,
        Icons.info_outline,
        'ℹ️ Analyse IA disponible',
        'Analyse : ${analysis.description ?? "Informations d\'accessibilité disponibles"}',
      );
    }

    // Badge gris : Analyse en cours ou non disponible
    return (
      Colors.grey,
      Icons.hourglass_empty,
      '⏳ Analyse en cours',
      'Analyse de l\'accessibilité en cours',
    );
  }
}

/// Badge compact pour afficher sur les images
class AIBadgeCompact extends StatelessWidget {
  const AIBadgeCompact({
    super.key,
    required this.analysis,
  });

  final AccessibilityAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    if (analysis == null) return const SizedBox.shrink();

    return Positioned(
      top: 8,
      right: 8,
      child: AIBadge(analysis: analysis!, compact: true),
    );
  }
}

