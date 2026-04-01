import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/web_file_helper.dart';
import '../../../data/models/post_model.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/community_providers.dart';

/// Écran de création d'un post dans la communauté.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contenuController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  PostType _selectedType = PostType.general;
  bool _isLoading = false;
  final List<XFile> _selectedImages = [];
  final Map<String, Uint8List> _imageBytes = {};
  static const int _maxImages = 10;

  String _cacheKey(XFile x) => '${x.name}_${x.path}';

  @override
  void dispose() {
    _contenuController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    try {
      var list = await _imagePicker.pickMultiImage(imageQuality: 85);
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
          if (_selectedImages.length >= _maxImages) break;
          _selectedImages.add(x);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.fr().errorGeneric}: $e')),
        );
      }
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (!mounted || image == null) return;
      setState(() {
        if (_selectedImages.length < _maxImages) {
          _selectedImages.add(image);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.fr().errorGeneric}: $e')),
        );
      }
    }
  }

  void _removeImageAt(int index) {
    final imageToRemove = _selectedImages[index];
    setState(() {
      _selectedImages.removeAt(index);
      _imageBytes.remove(_cacheKey(imageToRemove));
    });
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
        images:
            _selectedImages.isEmpty ? null : List<XFile>.from(_selectedImages),
      )).future);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.fromPreferredLanguage(
                    user.preferredLanguage?.name)
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
            content: Text('Erreur lors de la publication: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
            // Toujours visible en haut (évite de scroller après les 8 types).
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
                        Icon(Icons.image_outlined, color: primary, size: 28),
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
                    if (_selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final image = _selectedImages[index];
                            final key = _cacheKey(image);
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: FutureBuilder<Uint8List?>(
                                    key: ValueKey(key),
                                    future: () async {
                                      if (_imageBytes.containsKey(key)) {
                                        return _imageBytes[key];
                                      }
                                      try {
                                        final bytes = await readXFileBytes(image);
                                        if (mounted) {
                                          _imageBytes[key] = bytes;
                                        }
                                        return bytes;
                                      } catch (_) {
                                        return null;
                                      }
                                    }(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData &&
                                          snapshot.data != null) {
                                        return Image.memory(
                                          snapshot.data!,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        );
                                      }
                                      return Container(
                                        width: 100,
                                        height: 100,
                                        color: theme.colorScheme
                                            .surfaceContainerHighest,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
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
                                          : () => _removeImageAt(index),
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
                    color: isSelected
                        ? primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
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
