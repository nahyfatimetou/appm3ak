import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../data/models/location_model.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../providers/api_providers.dart';
import '../../../providers/auth_providers.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  int _selectedTab = 0; // 0: Pending, 1: All

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final theme = Theme.of(context);

    // Vérifier que l'utilisateur est admin
    if (user == null || !user.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Accès réservé aux administrateurs'),
              backgroundColor: Colors.red,
            ),
          );
          context.go('/home');
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outline),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    label: 'En attente',
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                ),
                Expanded(
                  child: _TabButton(
                    label: 'Tous les lieux',
                    isSelected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _selectedTab == 0
                ? _PendingLocationsTab()
                : _AllLocationsTab(),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _PendingLocationsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(adminRepositoryProvider);
    final theme = Theme.of(context);

    return FutureBuilder<List<LocationModel>>(
      future: repository.getPendingLocations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Erreur: ${snapshot.error}',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Retry
                    (context as Element).markNeedsBuild();
                  },
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        final locations = snapshot.data ?? [];

        if (locations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Aucun lieu en attente',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tous les lieux ont été modérés',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: locations.length,
          itemBuilder: (context, index) {
            final location = locations[index];
            return _LocationModerationCard(location: location);
          },
        );
      },
    );
  }
}

class _AllLocationsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AllLocationsTab> createState() => _AllLocationsTabState();
}

class _AllLocationsTabState extends ConsumerState<_AllLocationsTab> {
  String? _selectedStatut;
  int _currentPage = 1;
  final int _limit = 20;

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(adminRepositoryProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        // Filtres
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outline),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedStatut,
                  hint: const Text('Tous les statuts'),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tous')),
                    DropdownMenuItem(value: 'PENDING', child: Text('En attente')),
                    DropdownMenuItem(value: 'APPROVED', child: Text('Approuvé')),
                    DropdownMenuItem(value: 'REJECTED', child: Text('Rejeté')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatut = value;
                      _currentPage = 1;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        // Liste
        Expanded(
          child: FutureBuilder<({
            List<LocationModel> locations,
            int total,
            int page,
            int totalPages,
          })>(
            future: repository.getAllLocations(
              statut: _selectedStatut,
              page: _currentPage,
              limit: _limit,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Erreur: ${snapshot.error}',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                );
              }

              final data = snapshot.data!;
              final locations = data.locations;

              if (locations.isEmpty) {
                return const Center(child: Text('Aucun lieu trouvé'));
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: locations.length,
                      itemBuilder: (context, index) {
                        final location = locations[index];
                        return _LocationModerationCard(location: location);
                      },
                    ),
                  ),
                  // Pagination
                  if (data.totalPages > 1)
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 1
                                ? () => setState(() => _currentPage--)
                                : null,
                          ),
                          Text('Page $_currentPage / ${data.totalPages}'),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _currentPage < data.totalPages
                                ? () => setState(() => _currentPage++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LocationModerationCard extends ConsumerWidget {
  const _LocationModerationCard({required this.location});

  final LocationModel location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(adminRepositoryProvider);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    location.nom,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusChip(status: location.statut),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              location.fullAddress,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (location.description != null) ...[
              const SizedBox(height: 8),
              Text(
                location.description!,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (location.statut == LocationStatus.pending) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Rejeter'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () => _showRejectDialog(context, ref, location),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approuver'),
                    onPressed: () => _approveLocation(context, ref, location),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: () {
                      // Voir les détails
                      context.push('/location-detail/${location.id}');
                    },
                    child: const Text('Voir détails'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveLocation(
    BuildContext context,
    WidgetRef ref,
    LocationModel location,
  ) async {
    final repository = ref.read(adminRepositoryProvider);

    try {
      await repository.approveLocation(location.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lieu "${location.nom}" approuvé'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh
        (context as Element).markNeedsBuild();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(
    BuildContext context,
    WidgetRef ref,
    LocationModel location,
  ) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter le lieu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Êtes-vous sûr de vouloir rejeter "${location.nom}" ?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Raison du rejet (optionnel)',
                hintText: 'Ex: Informations incomplètes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final repository = ref.read(adminRepositoryProvider);
      try {
        await repository.rejectLocation(
          location.id,
          reason: reasonController.text.trim().isEmpty
              ? null
              : reasonController.text.trim(),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lieu "${location.nom}" rejeté'),
              backgroundColor: Colors.orange,
            ),
          );
          // Refresh
          (context as Element).markNeedsBuild();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final LocationStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color;
    String label;

    switch (status) {
      case LocationStatus.pending:
        color = Colors.orange;
        label = 'En attente';
        break;
      case LocationStatus.approved:
        color = Colors.green;
        label = 'Approuvé';
        break;
      case LocationStatus.rejected:
        color = Colors.red;
        label = 'Rejeté';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}


