import 'package:go_router/go_router.dart';

import '../helpers/student_api.dart';
import '../helpers/news_api.dart';
import '../widgets/home_screen.dart';
import '../widgets/login_screen.dart';
import '../widgets/splash_screen.dart';
import '../widgets/ueh_news_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
  // vd: /news?title=Cuộc sống UEH&cat_uid=219
  static const news = '/news';
  // vd: /news/detail?uid=101
  static const newsDetail = '/news/detail';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  // Chưa đăng nhập thì chỉ vào được splash và login.
  redirect: (context, state) {
    final path = state.uri.path;
    if (path == AppRoutes.splash) return null;
    final atLogin = path == AppRoutes.login;
    if (!StudentApi.isLoggedIn) return atLogin ? null : AppRoutes.login;
    return atLogin ? AppRoutes.home : null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.news,
      builder: (context, state) => UehNewsScreen(
        title: state.uri.queryParameters['title'] ?? 'Cuộc sống UEH',
        catUid:
            int.tryParse(state.uri.queryParameters['cat_uid'] ?? '') ??
            NewsApi.cuocSongUehCatUid,
      ),
    ),
    GoRoute(
      path: AppRoutes.newsDetail,
      builder: (context, state) => UehNewsDetailScreen(
        uid: int.tryParse(state.uri.queryParameters['uid'] ?? '') ?? 0,
      ),
    ),
  ],
);
