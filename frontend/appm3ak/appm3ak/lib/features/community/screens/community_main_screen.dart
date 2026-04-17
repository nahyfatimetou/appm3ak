import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/volume/android_volume_hub.dart';
import '../../../providers/auth_providers.dart';
import '../logic/quick_help_volume_action.dart';
import 'community_locations_screen.dart';
import 'community_nearby_places_screen.dart';
import 'community_posts_screen.dart';
import 'help_requests_screen.dart';

/// Écran principal du module Communauté avec onglets pour naviguer entre
/// Lieux accessibles, Posts et Demandes d'aide.
class CommunityMainScreen extends ConsumerStatefulWidget {
  const CommunityMainScreen({super.key, this.initialTabIndex = 0});

  /// 0 = tous les lieux, 1 = posts, 2 = lieux à proximité, 3 = demandes d'aide.
  final int initialTabIndex;

  @override
  ConsumerState<CommunityMainScreen> createState() => _CommunityMainScreenState();
}

class _CommunityMainScreenState extends ConsumerState<CommunityMainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _lastVolumeHelpAt;

  @override
  void initState() {
    super.initState();
    final idx = widget.initialTabIndex.clamp(0, 3);
    _tabController = TabController(length: 4, vsync: this, initialIndex: idx);
    _tabController.addListener(_onTabControllerTick);
    AndroidVolumeHub.ensureInitialized();
    _bindHelpTabVolumeHandler();
  }

  void _onTabControllerTick() {
    if (!_tabController.indexIsChanging && mounted) {
      setState(() {});
    }
    _bindHelpTabVolumeHandler();
  }

  void _bindHelpTabVolumeHandler() {
    AndroidVolumeHub.onVolumeUpHelpTab =
        _tabController.index == 3 ? _runQuickHelpFromVolume : null;
  }

  Future<void> _runQuickHelpFromVolume() async {
    if (_tabController.index != 3) return;
    final now = DateTime.now();
    if (_lastVolumeHelpAt != null &&
        now.difference(_lastVolumeHelpAt!) < const Duration(seconds: 5)) {
      return;
    }
    _lastVolumeHelpAt = now;

    final err = await submitQuickHelpWithCurrentLocation(ref);
    if (!mounted) return;
    final user = ref.read(authStateProvider).valueOrNull;
    final strings =
        AppStrings.fromPreferredLanguage(user?.preferredLanguage?.name);
    final messenger = ScaffoldMessenger.of(context);
    if (err == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(strings.helpRequestCreatedSuccess),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    AndroidVolumeHub.onVolumeUpHelpTab = null;
    _tabController.removeListener(_onTabControllerTick);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CommunityMainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      final i = widget.initialTabIndex.clamp(0, 3);
      if (_tabController.index != i) {
        _tabController.animateTo(i);
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
        title: Text(strings.community),
        actions: [
          IconButton(
            tooltip: strings.communityCircleOfTrust,
            onPressed: () => context.push('/community-contacts'),
            icon: const Icon(Icons.group_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primary,
          labelColor: primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: [
            Tab(
              icon: const Icon(Icons.location_on),
              text: strings.places,
            ),
            Tab(
              icon: const Icon(Icons.forum),
              text: strings.communityPosts,
            ),
            Tab(
              icon: const Icon(Icons.near_me_outlined),
              text: strings.communityPlacesNearbyTab,
            ),
            Tab(
              icon: const Icon(Icons.help_outline),
              text: strings.helpRequests,
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // (Supprimé) Ancienne bannière "Accessibilité dans les posts".
          Expanded(
            child: TabBarView(
              controller: _tabController,
                           children: [
                const CommunityLocationsScreen(),
                const CommunityPostsScreen(),
                const CommunityNearbyPlacesScreen(embedded: true),
                const HelpRequestsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

