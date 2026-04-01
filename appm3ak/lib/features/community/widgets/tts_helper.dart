import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../data/models/post_model.dart';

/// Helper pour la synthèse vocale (TTS) des résultats IA.
class TTSHelper {
  static final FlutterTts _tts = FlutterTts();

  /// Initialise le TTS
  static Future<void> initialize() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  /// Lit les résultats de l'analyse IA
  static Future<void> speakAnalysis(AccessibilityAnalysis? analysis) async {
    if (analysis == null) return;

    await initialize();

    String text = 'Analyse d\'accessibilité par Ma3ak AI. ';

    if (analysis.isAccessible) {
      text += 'Lieu accessible. ';
      if (analysis.rampe == true) {
        text += 'Rampes d\'accès détectées. ';
      }
      if (analysis.ascenseur == true) {
        text += 'Ascenseur disponible. ';
      }
      if (analysis.toilettesAdaptees == true) {
        text += 'Toilettes adaptées présentes. ';
      }
      if (analysis.scoreAccessibilite != null) {
        text += 'Score d\'accessibilité : ${analysis.scoreAccessibilite} sur 100. ';
      }
    } else if (analysis.hasWarnings) {
      text += 'Attention : Des obstacles peuvent bloquer l\'accès. ';
      if (analysis.description != null && analysis.description!.isNotEmpty) {
        text += analysis.description!;
      }
    } else if (analysis.description != null && analysis.description!.isNotEmpty) {
      text += analysis.description!;
    }

    await _tts.speak(text);
  }

  /// Arrête la lecture
  static Future<void> stop() async {
    await _tts.stop();
  }

  /// Lit un texte personnalisé
  static Future<void> speak(String text) async {
    await initialize();
    await _tts.speak(text);
  }
}

/// Bouton pour activer la lecture vocale de l'analyse IA
class TTSButton extends StatelessWidget {
  const TTSButton({
    super.key,
    required this.analysis,
    this.iconSize = 24,
  });

  final AccessibilityAnalysis? analysis;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (analysis == null) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.volume_up),
      iconSize: iconSize,
      tooltip: 'Écouter l\'analyse d\'accessibilité',
      onPressed: () => TTSHelper.speakAnalysis(analysis),
      color: Theme.of(context).colorScheme.primary,
    );
  }
}


