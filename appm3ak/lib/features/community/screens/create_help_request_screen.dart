import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/community_providers.dart';

/// Écran de création d'une demande d'aide.
class CreateHelpRequestScreen extends ConsumerStatefulWidget {
  const CreateHelpRequestScreen({super.key});

  @override
  ConsumerState<CreateHelpRequestScreen> createState() =>
      _CreateHelpRequestScreenState();
}

class _CreateHelpRequestScreenState
    extends ConsumerState<CreateHelpRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  // Coordonnées par défaut (Tunis) - TODO: Remplacer par géolocalisation réelle
  double _latitude = 36.8065;
  double _longitude = 10.1815;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    // TODO: Implémenter la géolocalisation réelle avec geolocator
    // Pour l'instant, on utilise des coordonnées par défaut
    setState(() {
      _latitude = 36.8065; // Tunis
      _longitude = 10.1815;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Position actuelle utilisée (Tunis par défaut)'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitHelpRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.fr().errorGeneric)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(createHelpRequestProvider((
        description: _descriptionController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
      )).future);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.fromPreferredLanguage(user.preferredLanguage?.name)
                .helpRequestCreatedSuccess),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.fr().errorGeneric}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final strings =
        AppStrings.fromPreferredLanguage(user?.preferredLanguage?.name);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(strings.createHelpRequest),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              strings.createHelpRequestDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: strings.description,
                hintText: strings.helpRequestDescriptionHint,
                prefixIcon: const Icon(Icons.description),
                helperText: strings.describeYourNeed,
              ),
              maxLines: 6,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return strings.fieldRequired;
                }
                if (value.trim().length < 10) {
                  return strings.minimumCharacters(10);
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            // Localisation
            Text(
              strings.location,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.currentLocation,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _getCurrentLocation,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: Text(strings.useCurrentLocation),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              strings.locationHelpMessage,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Bouton soumettre
            ElevatedButton(
              onPressed: _isLoading ? null : _submitHelpRequest,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      strings.submit,
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.helpRequestNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

