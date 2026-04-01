import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/accompaniment/screens/emergency_contacts_screen.dart';
import '../features/accompaniment/screens/transport_requests_screen.dart';
import '../features/admin/screens/admin_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/community/screens/community_locations_screen.dart';
import '../features/community/screens/community_posts_screen.dart';
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
import '../features/profile/screens/profile_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
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
        builder: (_, __) => const CommunityPostsScreen(),
      ),
      GoRoute(
        path: '/create-post',
        builder: (_, __) => const CreatePostScreen(),
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
      // Route Admin
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page non trouvée: ${state.uri}'),
      ),
    ),
  );
});
