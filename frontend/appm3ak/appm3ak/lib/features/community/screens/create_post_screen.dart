import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../data/models/post_model.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/community_providers.dart';

/// Écran de création d'un post dans la communauté.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({
    super.key,
    this.initialContent,
    this.autoOpenCamera = false,
    this.autoPublishAfterCamera = false,
  });

  final String? initialContent;
  final bool autoOpenCamera;
  final bool autoPublishAfterCamera;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contenuController = TextEditingController();
  final _imagePicker = ImagePicker();
  PostType _selectedType = PostType.general;
  bool _isLoading = false;
  final List<XFile> _images = [];
  static const int _maxImages = 10;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialContent?.trim();
    if (seed != null && seed.isNotEmpty) {
      _contenuController.text = seed;
    }

    if (widget.autoOpenCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _pickFromCamera();
        if (!mounted) return;
        if (widget.autoPublishAfterCamera && _images.isNotEmpty) {
          // Laisse le temps au form de se stabiliser.
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (!mounted) return;
          await _submitPost();
        }
      });
    }
  }

  @override
  void dispose() {
    _contenuController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
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
      await ref.read(createPostProvider((
        contenu: _contenuController.text.trim(),
        type: _selectedType.toApiString(),
        images: _images.isEmpty ? null : List<XFile>.from(_images),
      )).future);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.fromPreferredLanguage(user.preferredLanguage?.name)
                .postCreatedSuccess),
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

  Future<void> _pickFromGallery() async {
    var list = await _imagePicker.pickMultiImage(imageQuality: 85);
    // Sur le web, la sélection multiple peut échouer silencieusement : repli sur 1 fichier.
    if (kIsWeb && list.isEmpty) {
      final one = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (one != null) list = [one];
    }
    if (!mounted || list.isEmpty) return;
    setState(() {
      for (final x in list) {
        if (_images.length >= _maxImages) break;
        _images.add(x);
      }
    });
  }

  Future<void> _pickFromCamera() async {
    final x = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (!mounted || x == null) return;
    setState(() {
      if (_images.length < _maxImages) _images.add(x);
    });
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
        title: Text(strings.createPost),
        actions: [
          IconButton(
            tooltip: strings.addImages,
            onPressed: _isLoading ? null : _pickFromGallery,
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
          if (!kIsWeb)
            IconButton(
              tooltip: strings.fromCamera,
              onPressed: _isLoading ? null : _pickFromCamera,
              icon: const Icon(Icons.photo_camera_outlined),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Photos en premier : visible immédiatement (les puces « type » sont longues à scroller).
            Card(
              elevation: 2,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_photo_alternate, color: primary, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            strings.addImages,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Optionnel — jusqu’à $_maxImages photos',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _isLoading ? null : _pickFromGallery,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(strings.fromGallery),
                        ),
                        if (!kIsWeb)
                          FilledButton.tonalIcon(
                            onPressed: _isLoading ? null : _pickFromCamera,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: Text(strings.fromCamera),
                          ),
                      ],
                    ),
                    if (_images.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: FutureBuilder(
                                    future: _images[index].readAsBytes(),
                                    builder: (context, snap) {
                                      if (snap.hasData) {
                                        return Image.memory(
                                          snap.data!,
                                          width: 88,
                                          height: 88,
                                          fit: BoxFit.cover,
                                        );
                                      }
                                      return Container(
                                        width: 88,
                                        height: 88,
                                        color: theme.colorScheme
                                            .surfaceContainerHighest,
                                        alignment: Alignment.center,
                                        child: const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Material(
                                    color: Colors.black54,
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.close,
                                          color: Colors.white, size: 16),
                                      onPressed: _isLoading
                                          ? null
                                          : () => setState(
                                                () =>
                                                    _images.removeAt(index),
                                              ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              strings.createPostDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            // Type de post
            Text(
              strings.postType,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PostType.values.map((type) {
                final isSelected = _selectedType == type;
                return FilterChip(
                  label: Text(type.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedType = type);
                    }
                  },
                  selectedColor: primary.withValues(alpha: 0.2),
                  checkmarkColor: primary,
                  avatar: Icon(
                    _getTypeIcon(type),
                    size: 18,
                    color: isSelected ? primary : theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // Contenu
            TextFormField(
              controller: _contenuController,
              decoration: InputDecoration(
                labelText: strings.content,
                hintText: strings.postContentHint,
                prefixIcon: const Icon(Icons.edit),
                helperText: strings.shareYourThoughts,
              ),
              maxLines: 10,
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
            const SizedBox(height: 32),
            // Bouton publier
            ElevatedButton(
              onPressed: _isLoading ? null : _submitPost,
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
                      strings.publish,
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.postNote,
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

  IconData _getTypeIcon(PostType type) {
    switch (type) {
      case PostType.handicapMoteur:
        return Icons.accessible;
      case PostType.handicapVisuel:
        return Icons.visibility;
      case PostType.handicapAuditif:
        return Icons.hearing;
      case PostType.handicapCognitif:
        return Icons.psychology;
      case PostType.conseil:
        return Icons.lightbulb;
      case PostType.temoignage:
        return Icons.favorite;
      default:
        return Icons.forum;
    }
  }
}

