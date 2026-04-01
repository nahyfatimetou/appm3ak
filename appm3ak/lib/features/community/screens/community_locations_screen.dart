import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/distance_utils.dart';
import '../../../data/models/location_model.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/community_providers.dart';

/// Écran principal du module Communauté : liste des lieux accessibles avec filtres.
class CommunityLocationsScreen extends ConsumerStatefulWidget {
  const CommunityLocationsScreen({super.key});

  @override
  ConsumerState<CommunityLocationsScreen> createState() =>
      _CommunityLocationsScreenState();
}

class _CommunityLocationsScreenState
    extends ConsumerState<CommunityLocationsScreen> {
  LocationCategory? _selectedCategory;
  String _searchQuery = '';
  bool _useNearbySearch = false;
  double _maxDistance = 10.0; // Distance maximale en km
  Position? _currentPosition;
  bool _isGettingLocation = false;
  String? _locationError;

  /// Obtient la position actuelle de l'utilisateur.
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });

    try {
      // Vérifier si les services de localisation sont activés
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'locationServiceDisabled';
          _isGettingLocation = false;
        });
        return;
      }

      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'locationPermissionDenied';
            _isGettingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'locationPermissionDeniedPermanently';
          _isGettingLocation = false;
        });
        return;
      }

      // Obtenir la position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isGettingLocation = false;
        _useNearbySearch = true;
      });
      
      // Invalider le provider pour charger les lieux à proximité
      ref.invalidate(nearbyLocationsProvider((
        lat: position.latitude,
        lng: position.longitude,
        maxDistance: _maxDistance,
      )));
    } catch (e) {
      print('❌ [CommunityLocationsScreen] Erreur géolocalisation: $e');
      setState(() {
        _locationError = 'Erreur: $e';
        _isGettingLocation = false;
      });
    }
  }

  /// Désactive la recherche par proximité.
  void _disableNearbySearch() {
    setState(() {
      _useNearbySearch = false;
      _currentPosition = null;
      _locationError = null;
    });
    // Revenir à la liste complète
    ref.invalidate(locationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final strings =
        AppStrings.fromPreferredLanguage(user?.preferredLanguage?.name);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // Utiliser nearbyLocationsProvider si la recherche par proximité est activée
    final locationsAsync = _useNearbySearch && _currentPosition != null
        ? ref.watch(nearbyLocationsProvider((
            lat: _currentPosition!.latitude,
            lng: _currentPosition!.longitude,
            maxDistance: _maxDistance,
          )))
        : ref.watch(locationsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Barre d'actions (remplace AppBar) - Fixe en haut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  strings.communityPlaces,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => context.push('/submit-location'),
                  tooltip: strings.submitNewPlace,
                ),
              ],
            ),
          ),
          // Barre de recherche et toggle proximité - Fixe
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: strings.searchAccessiblePlaces,
                    prefixIcon: Icon(Icons.search, color: primary),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Toggle recherche par proximité
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: Text(
                          _useNearbySearch
                              ? strings.nearbyPlaces
                              : strings.findNearbyPlaces,
                          style: theme.textTheme.bodyMedium,
                        ),
                        subtitle: _useNearbySearch && _currentPosition != null
                            ? Text(
                                '${strings.maxDistance}: ${_maxDistance.toStringAsFixed(1)} ${strings.km}',
                                style: theme.textTheme.bodySmall,
                              )
                            : null,
                        value: _useNearbySearch,
                        onChanged: (value) {
                          if (value) {
                            _getCurrentLocation();
                          } else {
                            _disableNearbySearch();
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (_isGettingLocation)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (_locationError != null)
                      IconButton(
                        icon: const Icon(Icons.error_outline, color: Colors.red),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_getLocationErrorText(strings)),
                              backgroundColor: Colors.red,
                            ),
                          );
                        },
                        tooltip: _getLocationErrorText(strings),
                      ),
                  ],
                ),
                // Slider distance maximale (visible uniquement si recherche proximité activée)
                if (_useNearbySearch && _currentPosition != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${strings.maxDistance}: ',
                        style: theme.textTheme.bodySmall,
                      ),
                      Expanded(
                        child: Slider(
                          value: _maxDistance,
                          min: 1.0,
                          max: 50.0,
                          divisions: 49,
                          label: '${_maxDistance.toStringAsFixed(1)} ${strings.km}',
                          onChanged: (value) {
                            setState(() {
                              _maxDistance = value;
                            });
                            // Invalider le provider pour recharger avec la nouvelle distance
                            if (_currentPosition != null) {
                              ref.invalidate(nearbyLocationsProvider((
                                lat: _currentPosition!.latitude,
                                lng: _currentPosition!.longitude,
                                maxDistance: _maxDistance,
                              )));
                            }
                          },
                        ),
                      ),
                      Text(
                        '${_maxDistance.toStringAsFixed(1)} ${strings.km}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Filtres par catégorie - Fixe
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryChip(
                  label: strings.allCategories,
                  selected: _selectedCategory == null,
                  onTap: () => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 8),
                ...LocationCategory.values.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _CategoryChip(
                      label: category.displayName,
                      selected: _selectedCategory == category,
                      onTap: () => setState(() => _selectedCategory = category),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Liste des lieux - Scrollable
          Expanded(
            child: locationsAsync.when(
              data: (locations) {
                // Filtrer par catégorie et recherche
                // Note: Pour l'instant, on affiche tous les lieux (le backend ne gère pas encore le statut)
                var filtered = locations.toList();
                if (_selectedCategory != null) {
                  filtered = filtered
                      .where((loc) => loc.categorie == _selectedCategory)
                      .toList();
                }
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  filtered = filtered
                      .where((loc) =>
                          loc.nom.toLowerCase().contains(query) ||
                          loc.ville.toLowerCase().contains(query) ||
                          loc.adresse.toLowerCase().contains(query))
                      .toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _useNearbySearch && _currentPosition != null
                                ? Icons.location_searching
                                : Icons.location_off,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            strings.noPlacesFound,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _useNearbySearch && _currentPosition != null
                                ? 'Aucun lieu approuvé trouvé dans un rayon de ${_maxDistance.toStringAsFixed(1)} km.\n\nVérifiez que :\n• Des lieux sont approuvés dans le backoffice\n• La distance maximale est suffisante\n• Votre position GPS est correcte'
                                : strings.tryDifferentFilters,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_useNearbySearch && _currentPosition != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Position actuelle:\nLat: ${_currentPosition!.latitude.toStringAsFixed(6)}\nLng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontFamily: 'monospace',
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Augmenter la distance maximale à 50 km
                                setState(() {
                                  _maxDistance = 50.0;
                                });
                                ref.invalidate(nearbyLocationsProvider((
                                  lat: _currentPosition!.latitude,
                                  lng: _currentPosition!.longitude,
                                  maxDistance: 50.0,
                                )));
                              },
                              icon: const Icon(Icons.search),
                              label: const Text('Rechercher jusqu\'à 50 km'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                // Trier par distance si recherche par proximité activée
                if (_useNearbySearch && _currentPosition != null) {
                  filtered.sort((a, b) {
                    final distA = DistanceUtils.calculateDistance(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                      a.latitude,
                      a.longitude,
                    );
                    final distB = DistanceUtils.calculateDistance(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                      b.latitude,
                      b.longitude,
                    );
                    return distA.compareTo(distB);
                  });
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    if (_useNearbySearch && _currentPosition != null) {
                      ref.invalidate(nearbyLocationsProvider((
                        lat: _currentPosition!.latitude,
                        lng: _currentPosition!.longitude,
                        maxDistance: _maxDistance,
                      )));
                    } else {
                      ref.invalidate(locationsProvider);
                    }
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final location = filtered[index];
                      // Calculer la distance si recherche par proximité activée
                      double? distance;
                      if (_useNearbySearch && _currentPosition != null) {
                        distance = DistanceUtils.calculateDistance(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                          location.latitude,
                          location.longitude,
                        );
                      }
                      return _LocationCard(
                        location: location,
                        distance: distance,
                        onTap: () => context.push(
                          '/location-detail/${location.id}',
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                print('❌ [CommunityLocationsScreen] Erreur chargement lieux: $error');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
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
                          strings.errorLoadingPlaces,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (_useNearbySearch && _currentPosition != null) {
                              ref.invalidate(nearbyLocationsProvider((
                                lat: _currentPosition!.latitude,
                                lng: _currentPosition!.longitude,
                                maxDistance: _maxDistance,
                              )));
                            } else {
                              ref.invalidate(locationsProvider);
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(strings.retry),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/submit-location'),
        icon: const Icon(Icons.add),
        label: Text(strings.submitNewPlace),
      ),
    );
  }

  /// Retourne le texte d'erreur de localisation.
  String _getLocationErrorText(AppStrings strings) {
    switch (_locationError) {
      case 'locationPermissionDenied':
        return strings.locationPermissionDenied;
      case 'locationPermissionDeniedPermanently':
        return strings.locationPermissionDeniedPermanently;
      case 'locationServiceDisabled':
        return strings.locationServiceDisabled;
      default:
        return _locationError ?? strings.errorLoadingPlaces;
    }
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: selected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    this.distance,
    required this.onTap,
  });

  final LocationModel location;
  final double? distance; // Distance en km (si disponible)
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône catégorie - Réduite
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(categoryIcon, color: categoryColor, size: 22),
              ),
              const SizedBox(width: 12),
              // Informations
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      location.nom,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            location.fullAddress,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // Afficher la distance si disponible
                    if (distance != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.near_me,
                            size: 12,
                            color: primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            DistanceUtils.formatDistance(distance!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Description - Masquée pour économiser l'espace
                    // if (location.description != null) ...[
                    //   const SizedBox(height: 4),
                    //   Text(
                    //     location.description!,
                    //     style: theme.textTheme.bodySmall?.copyWith(
                    //       color: theme.colorScheme.onSurfaceVariant,
                    //     ),
                    //     maxLines: 1,
                    //     overflow: TextOverflow.ellipsis,
                    //   ),
                    // ],
                    // Amenities - Masquées pour économiser l'espace
                    // if (location.amenities != null &&
                    //     location.amenities!.isNotEmpty) ...[
                    //   const SizedBox(height: 6),
                    //   Wrap(
                    //     spacing: 3,
                    //     runSpacing: 3,
                    //     children: location.amenities!.take(2).map((amenity) {
                    //       return Chip(
                    //         label: Text(
                    //           amenity,
                    //           style: const TextStyle(fontSize: 9),
                    //         ),
                    //         padding: EdgeInsets.zero,
                    //         materialTapTargetSize:
                    //             MaterialTapTargetSize.shrinkWrap,
                    //         visualDensity: VisualDensity.compact,
                    //       );
                    //     }).toList(),
                    //   ),
                    // ],
                  ],
                ),
              ),
              // Badge approuvé - Réduit
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '✓',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

