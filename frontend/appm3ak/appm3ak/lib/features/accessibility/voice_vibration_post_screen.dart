import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vibration/vibration.dart';

import '../../core/volume/android_volume_hub.dart';
import '../../data/models/post_model.dart';
import 'accessibility_post_handoff.dart';
import 'back_tap_sensors.dart';

/// Dictée vocale + « lecture » par vibrations (1 impulsion / mot) + validation au dos du téléphone.
class VoiceVibrationPostScreen extends StatefulWidget {
  const VoiceVibrationPostScreen({super.key});

  @override
  State<VoiceVibrationPostScreen> createState() =>
      _VoiceVibrationPostScreenState();
}

enum _Phase {
  idle,
  listening,
  playingVibrations,
  awaitingBackTap,
}

class _VoiceVibrationPostScreenState extends State<VoiceVibrationPostScreen> {
  static const int _maxWordPulses = 28;
  /// Court mais exploitable ; évite les posts d’un seul caractère.
  static const int _minChars = 5;
  static const Duration _confirmTapWindow = Duration(seconds: 45);

  static bool _messageMeetsMinimum(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (t.length >= _minChars) return true;
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return words >= 2;
  }

  final stt.SpeechToText _speech = stt.SpeechToText();
  final ImagePicker _imagePicker = ImagePicker();
  Timer? _partialDebounce;
  String _speechStatus = '';
  String _speechError = '';

  _Phase _phase = _Phase.idle;
  bool _speechReady = false;
  String _selectedLocaleId = 'fr_FR';
  String _livePartial = '';
  String _finalText = '';
  /// Texte figé après « Terminer la dictée » (pour vibrations + publication).
  String _lockedMessage = '';
  String _status = '';
  bool _confirmListening = false;
  final List<XFile> _extraImages = [];
  static const int _maxImages = 10;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _status =
          'Non disponible sur le web (micro + vibrations + capteur de choc requis). Utilisez l’app sur téléphone.';
      return;
    }
    AndroidVolumeHub.ensureInitialized();
    AndroidVolumeHub.onVolumeUpPriority = _onVolumeUp;
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (mounted) {
        setState(() {
          _speechReady = false;
          _speechStatus = '';
          _speechError = 'microphone_permission_denied';
          _status =
              'Microphone refusé. Autorisez-le pour démarrer la dictée.';
        });
      }
      return;
    }
    String? lastStatus;
    String? lastError;
    final ok = await _speech.initialize(
      onError: (e) {
        lastError = e.errorMsg;
        if (!mounted) return;
        setState(() {
          _speechReady = false;
          _speechError = e.errorMsg;
          _status =
              'Erreur reconnaissance vocale: ${e.errorMsg}. Réessayez ou vérifiez Google Speech.';
        });
      },
      onStatus: (s) {
        lastStatus = s;
        if (!mounted) return;
        setState(() => _speechStatus = s);
      },
    );

    // Choisir une locale FR si dispo, sinon garder celle par défaut.
    try {
      final locales = await _speech.locales();
      final fr = locales.firstWhere(
        (l) => l.localeId.toLowerCase().startsWith('fr'),
        orElse: () => locales.isNotEmpty ? locales.first : stt.LocaleName('fr_FR', 'French'),
      );
      _selectedLocaleId = fr.localeId;
    } catch (_) {
      _selectedLocaleId = 'fr_FR';
    }

    if (mounted) {
      setState(() {
        _speechReady = ok;
        if (!ok) {
          _speechStatus = lastStatus ?? '';
          _speechError = lastError ?? 'speech_initialize_failed';
          _status = 'Reconnaissance vocale indisponible sur cet appareil.'
              '${lastStatus != null ? ' (status: $lastStatus)' : ''}'
              '${lastError != null ? ' (error: $lastError)' : ''}';
        } else {
          _speechError = '';
          _status = '';
        }
      });
    }
  }

  @override
  void dispose() {
    _partialDebounce?.cancel();
    unawaited(_speech.stop());
    if (AndroidVolumeHub.onVolumeUpPriority == _onVolumeUp) {
      AndroidVolumeHub.onVolumeUpPriority = null;
    }
    super.dispose();
  }

  static bool _containsPublishIntent(String text) {
    final t = text.toLowerCase().trim();
    if (t.isEmpty) return false;
    return t.contains('publier') ||
        t.contains('publie') ||
        t.contains('envoyer') ||
        t.contains('envoie') ||
        t.contains('confirmer') ||
        t.contains('valider');
  }

  Future<void> _startConfirmListening() async {
    if (!_speechReady || kIsWeb) return;
    if (_confirmListening) return;
    if (_phase != _Phase.awaitingBackTap) return;

    _confirmListening = true;
    try {
      await _speech.listen(
        onResult: (r) {
          if (!mounted) return;
          if (_phase != _Phase.awaitingBackTap) return;
          if (!r.finalResult) return;
          final said = r.recognizedWords;
          if (_containsPublishIntent(said)) {
            _popHandoff();
          }
        },
        listenFor: _confirmTapWindow,
        pauseFor: const Duration(seconds: 2),
        localeId: _selectedLocaleId,
        listenOptions: stt.SpeechListenOptions(
          partialResults: false,
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    } catch (_) {
      // Si l’écoute échoue, volume+ et back tap restent utilisables.
    }
  }

  Future<bool> _onVolumeUp() async {
    if (!mounted || kIsWeb) return false;

    final listening = _phase == _Phase.listening;
    final busy =
        _phase == _Phase.playingVibrations || _phase == _Phase.awaitingBackTap;
    final canManualPublish = _messageMeetsMinimum(_lockedMessage) &&
        _phase != _Phase.listening &&
        _phase != _Phase.playingVibrations;

    // Consomme toujours l’événement volume+ pendant cet écran.
    if (busy) {
      // En attente de confirmation: volume+ = publier.
      if (canManualPublish) _popHandoff();
      return true;
    }

    if (listening) {
      await _finishDictationAndConfirm();
      return true;
    }

    await _startDictation();
    return true;
  }

  Future<void> _startDictation() async {
    if (kIsWeb || _phase == _Phase.listening) return;
    if (!_speechReady) {
      await _initSpeech();
      if (!mounted || !_speechReady) return;
    }
    await _speech.stop();
    _partialDebounce?.cancel();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.listening;
      _livePartial = '';
      _finalText = '';
      _lockedMessage = '';
      _status = '';
    });
    try {
      await _speech.listen(
        onResult: (r) {
          if (!mounted) return;
          setState(() {
            _livePartial = r.recognizedWords;
            if (r.finalResult) _finalText = r.recognizedWords;
          });

          // Sur certains appareils, `finalResult` peut ne jamais arriver.
          // On “fige” le texte après une courte pause.
          _partialDebounce?.cancel();
          final t = r.recognizedWords.trim();
          if (t.length >= 3 && _phase == _Phase.listening) {
            _partialDebounce = Timer(const Duration(milliseconds: 1400), () {
              if (!mounted) return;
              if (_phase != _Phase.listening) return;
              setState(() => _finalText = _livePartial);
            });
          }
        },
        listenFor: const Duration(seconds: 120),
        pauseFor: const Duration(seconds: 4),
        localeId: _selectedLocaleId,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.idle;
          _speechError = '$e';
          _status =
              'Impossible de démarrer l’écoute.\n${e.runtimeType}: $e\nVérifiez “Services Google de reconnaissance vocale”.';
        });
      }
    }
  }

  Future<void> _finishDictationAndConfirm() async {
    if (_phase != _Phase.listening) return;
    _partialDebounce?.cancel();
    await _speech.stop();
    if (!mounted) return;

    final text = (_finalText.trim().isNotEmpty ? _finalText : _livePartial)
        .trim();
    if (!_messageMeetsMinimum(text)) {
      setState(() {
        _phase = _Phase.idle;
        _status = 'Message trop court.';
      });
      return;
    }

    setState(() {
      _lockedMessage = text;
      _phase = _Phase.playingVibrations;
      _status = '';
    });

    await _playWordVibrations(text);
    if (!mounted) return;

    setState(() {
      _phase = _Phase.awaitingBackTap;
      _status = '';
    });
    unawaited(_startConfirmListening());

    final tapped = await waitForBackTap(
      window: _confirmTapWindow,
      isListening: () => mounted && _phase == _Phase.awaitingBackTap,
    );
    if (!mounted) return;

    if (tapped) {
      _popHandoff();
      return;
    }

    setState(() {
      _phase = _Phase.idle;
      _status = 'Délai écoulé.';
    });
  }

  Future<void> _playWordVibrations(String text) async {
    final words =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final has = await Vibration.hasVibrator();
    if (has != true) {
      if (mounted) {
        setState(() {
          _status = 'Vibrations indisponibles.';
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return;
    }
    final n = math.min(words.length, _maxWordPulses);
    for (var i = 0; i < n; i++) {
      await Vibration.vibrate(duration: 48);
      await Future<void>.delayed(const Duration(milliseconds: 125));
    }
    if (words.length > _maxWordPulses) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      await Vibration.vibrate(duration: 240);
    }
  }

  void _popHandoff() {
    final t = _lockedMessage.trim();
    if (!_messageMeetsMinimum(t)) return;
    context.pop(
      AccessibilityPostHandoff(
        content: t,
        images: List<XFile>.from(_extraImages),
        suggestedPostType: PostType.autre,
        // Retourne vers le formulaire pour laisser l'utilisateur
        // ajouter une photo/changer le mode avant publication finale.
        autoPublish: false,
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    if (kIsWeb) return;
    if (_extraImages.length >= _maxImages) return;
    final x = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (!mounted || x == null) return;
    setState(() {
      if (_extraImages.length < _maxImages) {
        _extraImages.add(x);
      }
    });
  }

  Future<void> _openHeadGestureFromVoice() async {
    final handoff =
        await context.push<AccessibilityPostHandoff?>('/create-post-head-gesture');
    if (!mounted || handoff == null) return;
    setState(() {
      if (handoff.content.trim().isNotEmpty) {
        _lockedMessage = handoff.content.trim();
      }
      for (final img in handoff.images) {
        if (_extraImages.length >= _maxImages) break;
        _extraImages.add(img);
      }
    });
  }

  Future<void> _cancelListening() async {
    _partialDebounce?.cancel();
    await _speech.stop();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _status = 'Dictée annulée.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Voix + vibrations')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _status,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    final listening = _phase == _Phase.listening;
    final busy = _phase == _Phase.playingVibrations ||
        _phase == _Phase.awaitingBackTap;
    final canManualPublish = _messageMeetsMinimum(_lockedMessage) &&
        _phase != _Phase.listening &&
        _phase != _Phase.playingVibrations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voix + vibrations'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: busy ? null : () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_speechStatus.isNotEmpty || _speechError.isNotEmpty) ...[
            Text(
              'STT: ${_speechReady ? 'prêt' : 'non prêt'}'
              '${_speechStatus.isNotEmpty ? ' · status=$_speechStatus' : ''}'
              '${_speechError.isNotEmpty ? ' · err=$_speechError' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_status.isNotEmpty) ...[
            Text(_status, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: busy || listening ? null : _initSpeech,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer micro'),
              ),
              OutlinedButton.icon(
                onPressed: () => openAppSettings(),
                icon: const Icon(Icons.settings),
                label: const Text('Réglages'),
              ),
              OutlinedButton.icon(
                onPressed: (busy || listening) ? null : _openHeadGestureFromVoice,
                icon: const Icon(Icons.face_retouching_natural),
                label: const Text('Tête & yeux'),
              ),
              OutlinedButton.icon(
                onPressed: (busy || listening || _extraImages.length >= _maxImages)
                    ? null
                    : _pickFromCamera,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(_extraImages.isEmpty
                    ? 'Ajouter photo'
                    : 'Photos: ${_extraImages.length}'),
              ),
            ],
          ),
          if (_phase == _Phase.awaitingBackTap) ...[
            const SizedBox(height: 20),
            Text(
              'Sans toucher: dites “publier” ou appuyez sur Volume+ (Android) ou faites un back tap.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _popHandoff,
              icon: const Icon(Icons.send),
              label: const Text('Publier maintenant'),
            ),
          ],
          const SizedBox(height: 16),
          if (listening || _livePartial.isNotEmpty || _finalText.isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  listening
                      ? (_livePartial.isEmpty ? '…' : _livePartial)
                      : _lockedMessage.isNotEmpty
                          ? _lockedMessage
                          : (_finalText.isNotEmpty ? _finalText : _livePartial),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: (listening || busy) ? null : _startDictation,
            icon: const Icon(Icons.mic),
            label: const Text('Démarrer la dictée'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: !listening || busy ? null : _finishDictationAndConfirm,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Terminer la dictée → vibrations'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: !listening || busy ? null : _cancelListening,
            icon: const Icon(Icons.close),
            label: const Text('Annuler la dictée'),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: canManualPublish ? _popHandoff : null,
            icon: const Icon(Icons.send),
            label: const Text('Publier'),
          ),
        ],
      ),
    );
  }
}
