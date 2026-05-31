import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/phone_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/goals/presentation/goals_screen.dart';
import '../../features/insights/presentation/badges_screen.dart';
import '../../features/learn/presentation/learn_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/premium/presentation/premium_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/sms_sim/presentation/sms_simulator_screen.dart';
import '../../features/transactions/domain/transaction.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import 'app_shell.dart';
import 'splash_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

/// GoRouter avec redirection basée sur l'état d'authentification + onboarding.
final routerProvider = Provider<GoRouter>((ref) {
  // Pont Riverpod -> Listenable pour rafraîchir les redirections.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final inAuth = loc.startsWith('/auth');
      final inSplash = loc == '/splash';
      final inOnboarding = loc == '/onboarding';

      // Session pas encore restaurée : on reste sur le splash.
      if (!auth.isKnown) return inSplash ? null : '/splash';

      if (!auth.isAuthenticated) return inAuth ? null : '/auth';

      // Authentifie : on filtre par etat onboarding.
      if (auth.onboardingStatus == OnboardingStatus.needed) {
        return inOnboarding ? null : '/onboarding';
      }

      // Onboarding complete : on sort du splash / de l'auth / de l'onboarding.
      if (inSplash || inAuth || inOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/auth', builder: (_, __) => const PhoneScreen()),
      GoRoute(
        path: '/auth/otp',
        builder: (_, state) {
          final extra = (state.extra as Map?) ?? const {};
          return OtpScreen(
            phone: extra['phone'] as String? ?? '',
            debugOtp: extra['debugOtp'] as String?,
            demoMode: (extra['demoMode'] as bool?) ?? false,
          );
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/transactions',
        builder: (_, state) {
          final extra = (state.extra as Map?) ?? const {};
          return TransactionsScreen(
            initialFilter: extra['kind'] as TxKind?,
          );
        },
      ),
      GoRoute(
        path: '/profile/badges',
        builder: (_, __) => const BadgesScreen(),
      ),
      GoRoute(
        path: '/profile/premium',
        builder: (_, __) => const PremiumScreen(),
      ),
      GoRoute(
        path: '/profile/learn',
        builder: (_, __) => const LearnScreen(),
      ),
      GoRoute(
        path: '/profile/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/sms-sim',
        builder: (_, __) => const SmsSimulatorScreen(),
      ),
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (_, __, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(navigatorKey: _shellKey, routes: [
            GoRoute(path: '/home', builder: (_, __) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/goals', builder: (_, __) => const GoalsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/analytics',
                builder: (_, __) => const AnalyticsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/community',
                builder: (_, __) => const CommunityScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});
