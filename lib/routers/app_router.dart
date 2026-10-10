import 'package:go_router/go_router.dart';

import '../helpers/student_api.dart';
import '../helpers/ueh_news_service.dart';
import '../widgets/home_screen.dart';
import '../widgets/login_screen.dart';
import '../widgets/splash_screen.dart';
import '../widgets/ueh_news_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
  // vd: /news?title=Cuộc sống UEH&url=https://ueh.edu.vn/cuoc-song-ueh/
  static const news = '/news';
  // vd: /news/detail?url=https://ueh.edu.vn/cuoc-song-ueh/tin-tuc/...-78881
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
        url: state.uri.queryParameters['url'] ?? UehNewsService.cuocSongUehUrl,
      ),
    ),
    GoRoute(
      path: AppRoutes.newsDetail,
      builder: (context, state) =>
          UehNewsDetailScreen(url: state.uri.queryParameters['url'] ?? ''),
    ),
  ],
);
