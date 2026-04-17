import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/community_action_plan_result.dart';
import '../../../providers/community_providers.dart';

enum _CommunityEntryIntent {
  publish,
  help,
  location,
  unknown,
}

class CommunityAiEntryScreen extends ConsumerStatefulWidget {
  const CommunityAiEntryScreen({super.key});

  @override
  ConsumerState<CommunityAiEntryScreen> createState() =>
      _CommunityAiEntryScreenState();
}

class _CommunityAiEntryScreenState extends ConsumerState<CommunityAiEntryScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FlutterTts _tts = FlutterTts();
  bool _didAutoSpeak = false;
  bool _isAnalyzing = false;
  bool _hasNavigatedFromAi = false;
  static const String _introSentence = 'Comment puis-je vous aider ?';
  static const double _highConfidenceThreshold = 0.85;

  static const List<String> _suggestions = <String>[
    'J’ai besoin d’aide',
    'Je suis perdu',
    'Je veux publier',
    'Je veux poster une photo',
    'Je veux signaler un obstacle',
    'Je cherche un lieu accessible',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakIntro(automatic: true);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _speakIntro({bool automatic = false}) async {
    if (automatic && _didAutoSpeak) return;
    if (automatic) _didAutoSpeak = true;

    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setLanguage('fr-FR');
      await _tts.stop();
      await _tts.speak(_introSentence);
    } catch (_) {
      // On garde un comportement silencieux si TTS indisponible.
    }
  }

  void _setSuggestion(String value) {
    setState(() {
      _inputController.text = value;
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _inputController.text.length),
      );
    });
    _runAiAnalysis(value);
  }

  Future<void> _onContinue() async {
    FocusScope.of(context).unfocus();
    await _runAiAnalysis(_inputController.text);
  }

  void _openClassicModule() {
    context.push('/community-posts');
  }

  void _onMicPressed() {
    // TODO: Brancher la capture vocale.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Micro à connecter prochainement.'),
      ),
    );
  }

  Future<void> _runAiAnalysis(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _isAnalyzing) return;
    final intent = _detectIntent(text);

    setState(() => _isAnalyzing = true);
    try {
      final result = await ref.read(
        communityActionPlanProvider((
          text: text,
          contextHint: _contextHintForIntent(intent),
          inputModeHint: null,
          isForAnotherPersonHint: null,
        )).future,
      );

      if (!mounted) return;
      await _handleAiNavigation(result, fallbackIntent: intent);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d’analyser pour le moment. Réessayez dans un instant.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<void> _handleAiNavigation(
    CommunityActionPlanResult result, {
    required _CommunityEntryIntent fallbackIntent,
  }) async {
    if (!mounted || _hasNavigatedFromAi) return;

    final route = result.recommendedRoute?.trim();
    if (route != null && route.isNotEmpty) {
      if (result.shouldAutoNavigate(minConfidence: _highConfidenceThreshold)) {
        _hasNavigatedFromAi = true;
        context.push(route, extra: result);
        return;
      }

      final reason = result.routeReason?.trim();
      final conf = result.confidence;
      final confidenceText = conf != null
          ? ' (confiance: ${(conf * 100).toStringAsFixed(0)}%)'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (reason != null && reason.isNotEmpty)
                ? '$reason$confidenceText'
                : 'Suggestion: ouvrir $route$confidenceText',
          ),
        ),
      );
      return;
    }

    final fallbackRoute = _fallbackRouteForIntent(fallbackIntent);
    if (fallbackRoute != null) {
      // Pas de route IA: fallback explicite par intention reconnue.
      _hasNavigatedFromAi = true;
      context.push(fallbackRoute, extra: result);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Analyse terminée. Vous pouvez continuer ici.'),
      ),
    );
  }

  _CommunityEntryIntent _detectIntent(String input) {
    final t = input.toLowerCase().trim();

    if (t.contains('je veux publier') ||
        t.contains('je veux poster') ||
        t.contains('je veux poster une photo') ||
        t.contains('je veux faire une publication') ||
        t.contains('je veux signaler un obstacle')) {
      return _CommunityEntryIntent.publish;
    }

    if (t.contains('j’ai besoin d’aide') ||
        t.contains('j'ai besoin d’aide') ||
        t.contains('j\'ai besoin d\'aide') ||
        t.contains('je suis perdu') ||
        t.contains('je suis bloqué') ||
        t.contains('urgence')) {
      return _CommunityEntryIntent.help;
    }

    if (t.contains('je cherche un lieu accessible') ||
        t.contains('je veux voir les lieux') ||
        t.contains('je veux un lieu proche')) {
      return _CommunityEntryIntent.location;
    }

    return _CommunityEntryIntent.unknown;
  }

  String _contextHintForIntent(_CommunityEntryIntent intent) {
    switch (intent) {
      case _CommunityEntryIntent.publish:
        return 'post';
      case _CommunityEntryIntent.help:
        return 'help';
      case _CommunityEntryIntent.location:
        return 'location';
      case _CommunityEntryIntent.unknown:
        return 'community_entry';
    }
  }

  String? _fallbackRouteForIntent(_CommunityEntryIntent intent) {
    switch (intent) {
      case _CommunityEntryIntent.publish:
        return '/create-post';
      case _CommunityEntryIntent.help:
        return '/create-help-request';
      case _CommunityEntryIntent.location:
        return '/community-locations';
      case _CommunityEntryIntent.unknown:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant intelligent'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _introSentence,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Semantics(
                      button: true,
                      label: 'Répéter la question',
                      child: TextButton.icon(
                        onPressed: _speakIntro,
                        icon: const Icon(Icons.volume_up_outlined),
                        label: const Text('Répéter'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    label: 'Démarrer la saisie vocale',
                    button: true,
                    child: Center(
                      child: SizedBox(
                        width: 112,
                        height: 112,
                        child: FilledButton(
                          onPressed: _onMicPressed,
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Icon(Icons.mic, size: 44),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    textField: true,
                    label: 'Saisissez votre demande',
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: 'Ex: Je veux publier un besoin urgent',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    button: true,
                    label: 'Continuer',
                    child: SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: _isAnalyzing ? null : _onContinue,
                        child: _isAnalyzing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Continuer'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Suggestions rapides',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _suggestions.map((suggestion) {
                      return Semantics(
                        button: true,
                        label: suggestion,
                        child: ActionChip(
                          label: Text(suggestion),
                          onPressed: () => _setSuggestion(suggestion),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Semantics(
                      button: true,
                      label: 'Ouvrir le module classique',
                      child: TextButton(
                        onPressed: _openClassicModule,
                        child: const Text('Ouvrir le module classique'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
