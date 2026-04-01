import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../providers/auth_providers.dart';
import 'community_locations_screen.dart';
import 'community_posts_screen.dart';
import 'help_requests_screen.dart';

/// Écran principal du module Communauté avec onglets pour naviguer entre
/// Lieux accessibles, Posts et Demandes d'aide.
class CommunityMainScreen extends ConsumerStatefulWidget {
  const CommunityMainScreen({super.key});

  @override
  ConsumerState<CommunityMainScreen> createState() => _CommunityMainScreenState();
}

class _CommunityMainScreenState extends ConsumerState<CommunityMainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              icon: const Icon(Icons.help_outline),
              text: strings.helpRequests,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          CommunityLocationsScreen(),
          CommunityPostsScreen(),
          HelpRequestsScreen(),
        ],
      ),
    );
  }
}






