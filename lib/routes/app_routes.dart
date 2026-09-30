import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/splash_screen.dart';

class AppRoutes {
  static const splashPath = '/';
  static const loginPath = '/login';
  static const homePath = '/home';
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  return GoRouter(
    initialLocation: AppRoutes.splashPath,
    redirect: (context, state) {
      final isLogin = state.matchedLocation == AppRoutes.loginPath;
      if (authState.isInitializing) return AppRoutes.splashPath;
      if (!authState.isAuthenticated) return isLogin ? null : AppRoutes.loginPath;
      return isLogin || state.matchedLocation == AppRoutes.splashPath
          ? AppRoutes.homePath
          : null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splashPath,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.loginPath,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.homePath,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});
