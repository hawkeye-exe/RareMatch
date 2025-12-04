import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rarematch/features/auth/login_screen.dart';
import 'package:rarematch/features/auth/signup_screen.dart';
import 'package:rarematch/features/auth/forgot_password_screen.dart';
import 'package:rarematch/features/timeline/timeline_screen.dart';
import 'package:rarematch/features/results/results_screen.dart';
import 'package:rarematch/features/profile/profile_screen.dart';
import 'package:rarematch/features/home/home_screen.dart';
import 'package:rarematch/features/chat/chat_screen.dart';
import 'package:rarematch/core/widgets/scaffold_with_navbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Home Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Timeline Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/timeline',
                builder: (context, state) => const TimelineScreen(),
                routes: [
                  GoRoute(
                    path: 'results/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return ResultsScreen(timelineId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Chat Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatScreen(),
              ),
            ],
          ),
          // Profile Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final path = state.uri.toString();
      final isAuthRoute =
          path == '/login' || path == '/signup' || path == '/forgot-password';

      // Allow access to timeline and results for demo purposes even if no session
      if (path.startsWith('/timeline') || path.startsWith('/results')) {
        return null;
      }

      if (session == null && !isAuthRoute) return '/login';
      if (session != null && isAuthRoute) {
        return '/home'; // Redirect to home on login
      }

      return null;
    },
  );
});
