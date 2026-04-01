import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/app_strings.dart';
import '../features/accompaniment/screens/emergency_contacts_screen.dart';
import '../features/accompaniment/screens/transport_requests_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/community/screens/community_locations_screen.dart';
import '../features/community/screens/community_main_screen.dart';
import '../features/community/screens/create_help_request_screen.dart';
import '../features/community/screens/create_post_screen.dart';
import '../features/community/screens/help_requests_screen.dart';
import '../features/community/screens/location_detail_screen.dart';
import '../features/community/screens/post_detail_screen.dart';
import '../features/community/screens/submit_location_screen.dart';
import '../features/medical/screens/medical_record_screen.dart';
import '../features/sos/screens/sos_alerts_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/home/screens/main_shell.dart';
import '../features/health/models/health_chat_launch.dart';
import '../features/health/screens/health_ai_chat_screen.dart';
import '../features/medical/screens/activity_posture_detection_screen.dart';
import '../features/m3ak/m3ak_inclusion_page.dart';
import '../features/profile/screens/profile_screen.dart';
import '../m3ak_assist/m3ak_nav_key.dart';
import '../m3ak_assist/m3ak_create_post_launch.dart';
import '../providers/auth_providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: m3akRootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/sante',
        redirect: (_, __) => '/home?tab=1',
      ),
      GoRoute(
        path: '/home',
        builder: (c, state) => MainShell(
          initialIndex: state.uri.queryParameters['tab'] != null
              ? int.tryParse(state.uri.queryParameters['tab']!) ?? 0
              : 0,
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const MainShell(initialIndex: 4),
      ),
      GoRoute(
        path: '/profile-edit',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/accompagnants',
        builder: (_, __) => const EmergencyContactsScreen(),
      ),
      GoRoute(
        path: '/beneficiaires',
        builder: (_, __) => const TransportRequestsScreen(),
      ),
      GoRoute(
        path: '/medical-record',
        builder: (_, __) => const MedicalRecordScreen(),
      ),
      GoRoute(
        path: '/activity-posture-detection',
        builder: (_, __) => const ActivityPostureDetectionScreen(),
      ),
      GoRoute(
        path: '/sos-alerts',
        builder: (_, __) => const SosAlertsScreen(),
      ),
      GoRoute(
        path: '/community-locations',
        builder: (_, __) => const CommunityLocationsScreen(),
      ),
      GoRoute(
        path: '/location-detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return LocationDetailScreen(locationId: id);
        },
      ),
      GoRoute(
        path: '/submit-location',
        builder: (_, __) => const SubmitLocationScreen(),
      ),
      // Routes pour Posts
      GoRoute(
        path: '/community-posts',
        builder: (_, __) => const CommunityMainScreen(initialTabIndex: 1),
      ),
      GoRoute(
        path: '/create-post',
        builder: (_, state) {
          final extra = state.extra;
          if (extra is M3akCreatePostLaunch) {
            return CreatePostScreen(
              initialContent: extra.initialContent,
              autoOpenCamera: extra.autoOpenCamera,
              autoPublishAfterCamera: extra.autoPublishAfterCamera,
            );
          }
          final initial = extra is String ? extra : null;
          return CreatePostScreen(initialContent: initial);
        },
      ),
      GoRoute(
        path: '/post-detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return PostDetailScreen(postId: id);
        },
      ),
      // Routes pour Help Requests
      GoRoute(
        path: '/help-requests',
        builder: (_, __) => const HelpRequestsScreen(),
      ),
      GoRoute(
        path: '/create-help-request',
        builder: (_, __) => const CreateHelpRequestScreen(),
      ),
      GoRoute(
        path: '/m3ak-inclusion',
        builder: (_, __) => const M3akInclusionPage(),
      ),
      GoRoute(
        path: '/health-chat',
        builder: (context, state) {
          final extra = state.extra;
          String? initial;
          if (extra is HealthChatLaunch) {
            initial = extra.initialMessage;
          } else if (extra is String) {
            initial = extra;
          }
          return Consumer(
            builder: (context, ref, _) {
              final auth = ref.watch(authStateProvider);
              return auth.when(
                data: (user) {
                  if (user == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) context.go('/login');
                    });
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final strings = AppStrings.fromPreferredLanguage(
                    user.preferredLanguage?.name,
                  );
                  final launchUser =
                      extra is HealthChatLaunch ? extra.user : null;
                  return HealthAiChatScreen(
                    strings: strings,
                    initialUserMessage: initial,
                    userProfile: launchUser ?? user,
                  );
                },
                loading: () => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => Scaffold(
                  body: Center(child: Text(AppStrings.fr().errorGeneric)),
                ),
              );
            },
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page non trouvée: ${state.uri}'),
      ),
    ),
  );
});
