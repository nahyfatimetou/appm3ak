import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../data/models/location_model.dart';
import '../../../data/repositories/location_repository.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/community_providers.dart';

/// Écran de détails d'un lieu accessible.
class LocationDetailScreen extends ConsumerWidget {
  const LocationDetailScreen({required this.locationId, super.key});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final strings =
        AppStrings.fromPreferredLanguage(user?.preferredLanguage?.name);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final locationAsync = ref.watch(locationByIdProvider(locationId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: locationAsync.when(
        data: (location) {
          IconData categoryIcon;
          Color categoryColor;
          switch (location.categorie) {
            case LocationCategory.pharmacy:
              categoryIcon = Icons.local_pharmacy;
              categoryColor = Colors.red;
              break;
            case LocationCategory.restaurant:
              categoryIcon = Icons.restaurant;
              categoryColor = Colors.orange;
              break;
            case LocationCategory.hospital:
              categoryIcon = Icons.local_hospital;
              categoryColor = Colors.red.shade700;
              break;
            case LocationCategory.school:
              categoryIcon = Icons.school;
              categoryColor = Colors.blue;
              break;
            case LocationCategory.shop:
              categoryIcon = Icons.shopping_bag;
              categoryColor = Colors.purple;
              break;
            case LocationCategory.publicTransport:
              categoryIcon = Icons.directions_bus;
              categoryColor = Colors.green;
              break;
            case LocationCategory.park:
              categoryIcon = Icons.park;
              categoryColor = Colors.green.shade700;
              break;
            case LocationCategory.other:
              categoryIcon = Icons.place;
              categoryColor = primary;
              break;
          }

          return CustomScrollView(
            slivers: [
              // AppBar avec image
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: location.images != null &&
                          location.images!.isNotEmpty
                      ? Image.network(
                          LocationRepository.imageUrl(location.images!.first),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: categoryColor.withValues(alpha: 0.1),
                            child: Icon(categoryIcon, size: 64, color: categoryColor),
                          ),
                        )
                      : Container(
                          color: categoryColor.withValues(alpha: 0.1),
                          child: Icon(categoryIcon, size: 64, color: categoryColor),
                        ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
              ),
              // Contenu
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre et catégorie
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(categoryIcon, size: 16, color: categoryColor),
                                const SizedBox(width: 6),
                                Text(
                                  location.categorie.displayName,
                                  style: TextStyle(
                                    color: categoryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (location.isApproved)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    strings.approved,
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        location.nom,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Adresse
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  location.fullAddress,
                                  style: theme.textTheme.bodyLarge,
                                ),
                                if (location.telephone != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        size: 16,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        location.telephone!,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (location.description != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          strings.description,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          location.description!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      if (location.horaires != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          strings.openingHours,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              location.horaires!,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                      if (location.amenities != null &&
                          location.amenities!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          strings.amenities,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: location.amenities!.map((amenity) {
                            return Chip(
                              label: Text(amenity),
                              avatar: const Icon(Icons.check, size: 18),
                            );
                          }).toList(),
                        ),
                      ],
                      if (location.submittedByName != null) ...[
                        const SizedBox(height: 24),
                        Divider(color: theme.colorScheme.outline),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${strings.submittedBy} ${location.submittedByName}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  strings.errorLoadingPlace,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: Text(strings.goBack),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

