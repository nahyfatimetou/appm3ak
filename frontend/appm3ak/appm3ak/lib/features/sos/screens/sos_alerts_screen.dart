import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/sos_alert_model.dart';
import '../../../providers/api_providers.dart';
import '../../../providers/auth_providers.dart';

/// Écran Alertes SOS : bouton d'envoi + liste de mes alertes.
class SosAlertsScreen extends ConsumerStatefulWidget {
  const SosAlertsScreen({super.key});

  @override
  ConsumerState<SosAlertsScreen> createState() => _SosAlertsScreenState();
}

class _SosAlertsScreenState extends ConsumerState<SosAlertsScreen> {
  List<SosAlertModel> _alerts = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(sosRepositoryProvider);
      final list = await repo.getMyAlerts();
      if (mounted) setState(() => _alerts = list);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _sendSos() async {
    setState(() => _sending = true);
    try {
      final repo = ref.read(sosRepositoryProvider);
      // En production : récupérer la position GPS. Ici valeur par défaut (Tunis).
      await repo.create(latitude: 36.8065, longitude: 10.1815);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alerte SOS envoyée')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi')),
        );
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Alertes SOS')),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 16),
                  Center(
                    child: Material(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(28),
                      elevation: 4,
                      child: InkWell(
                        onTap: _sending ? null : _sendSos,
                        borderRadius: BorderRadius.circular(28),
                        child: const SizedBox(
                          width: 56,
                          height: 56,
                          child: Icon(Icons.star, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Envoyer une alerte SOS',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Mes alertes',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_alerts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Aucune alerte envoyée',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._alerts.map((a) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.emergency, color: Colors.red),
                            title: Text('${a.latitude.toStringAsFixed(4)}, ${a.longitude.toStringAsFixed(4)}'),
                            subtitle: a.createdAt != null
                                ? Text(a.createdAt!.toIso8601String())
                                : null,
                          ),
                        )),
                ],
              ),
            ),
          if (_sending)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
