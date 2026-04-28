import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../providers/auth_providers.dart';
import '../../../providers/community_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    required this.userId,
    this.userName,
    super.key,
  });

  final String userId;
  final String? userName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _listening = false;
  int _lastReadCount = 0;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.45);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _toggleDictation() async {
    if (_listening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _listening = false);
      return;
    }
    final ok = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!ok) return;
    setState(() => _listening = true);
    await _speech.listen(
      localeId: 'fr_FR',
      listenMode: stt.ListenMode.dictation,
      onResult: (result) {
        if (!mounted) return;
        setState(() => _ctrl.text = result.recognizedWords);
      },
    );
  }

  Future<void> _send() async {
    final me = ref.read(authStateProvider).valueOrNull;
    final meId = me?.id ?? 'me';
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    ref.read(communityMessagesProvider.notifier).sendMessage(
          currentUserId: meId,
          otherUserId: widget.userId,
          text: text,
        );
    _ctrl.clear();

    // Réponse mock pour MVP démo.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        ref.read(communityMessagesProvider.notifier).receiveMockMessage(
              currentUserId: meId,
              otherUserId: widget.userId,
              text: 'Merci pour votre message.',
            );
      }),
    );
  }

  Future<void> _readIncoming(List<CommunityChatMessage> items, String meId) async {
    if (items.length <= _lastReadCount) return;
    final newItems = items.skip(_lastReadCount);
    _lastReadCount = items.length;
    for (final m in newItems) {
      if (m.senderId == meId) continue;
      await _tts.stop();
      await _tts.speak('Nouveau message: ${m.text}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authStateProvider).valueOrNull;
    final meId = me?.id ?? 'me';
    final all = ref.watch(communityMessagesProvider);
    final messages = all.where((m) => m.otherUserId == widget.userId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readIncoming(messages, meId);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName?.trim().isNotEmpty == true
            ? widget.userName!
            : 'Conversation'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final m = messages[index];
                final mine = m.senderId == meId;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: mine
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(m.text),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Écrire un message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _toggleDictation,
                          icon: Icon(_listening ? Icons.hearing : Icons.mic_none),
                          label: Text(_listening ? 'Arrêter dictée' : 'Dicter'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _send,
                          icon: const Icon(Icons.send),
                          label: const Text('Envoyer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

