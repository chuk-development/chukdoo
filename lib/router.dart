import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/presentation/confirm_email_page.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/unlock_page.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/onboarding/presentation/onboarding_page.dart';
import 'features/todos/presentation/pages/home_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/loading',
    redirect: (context, state) {
      final status = authState.status;
      final location = state.matchedLocation;

      // While checking auth state, stay on loading
      if (status == AuthStatus.initial) {
        if (location != '/loading') return '/loading';
        return null;
      }

      // Don't stay on loading once we know the state
      if (location == '/loading') {
        if (status == AuthStatus.authenticated) return '/';
        if (status == AuthStatus.localMode) {
          // First-time user needs onboarding
          if (!authState.hasCompletedOnboarding) return '/onboarding';
          return '/';
        }
        if (status == AuthStatus.unauthenticated) return '/login';
        if (status == AuthStatus.needsPassword) return '/unlock';
        if (status == AuthStatus.needsEmailConfirmation) return '/confirm-email';
      }

      // Handle local mode (offline-first users)
      if (status == AuthStatus.localMode) {
        // First-time user needs onboarding
        if (!authState.hasCompletedOnboarding && location != '/onboarding') {
          return '/onboarding';
        }
        // After onboarding, can access home or login (to connect account)
        if (location == '/loading' || location == '/unlock' || location == '/confirm-email') {
          return '/';
        }
        return null;
      }

      // Handle email confirmation needed
      if (status == AuthStatus.needsEmailConfirmation) {
        if (location != '/confirm-email') return '/confirm-email';
        return null;
      }

      // Handle needs password for encryption
      if (status == AuthStatus.needsPassword) {
        if (location != '/unlock') return '/unlock';
        return null;
      }

      // Handle authenticated
      if (status == AuthStatus.authenticated) {
        if (location == '/login' || location == '/unlock' || location == '/confirm-email' || location == '/onboarding') {
          return '/';
        }
        return null;
      }

      // Handle unauthenticated
      if (status == AuthStatus.unauthenticated) {
        if (location != '/login') return '/login';
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const _LoadingPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/confirm-email',
        builder: (context, state) => const ConfirmEmailPage(),
      ),
      GoRoute(
        path: '/unlock',
        builder: (context, state) => const UnlockPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
    ],
  );
});

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
