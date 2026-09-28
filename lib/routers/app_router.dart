import 'package:go_router/go_router.dart';

import '../helpers/ueh_news_service.dart';
import '../widgets/home_screen.dart';
import '../widgets/splash_screen.dart';
import '../widgets/ueh_news_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  // vd: /news?title=Cuộc sống UEH&url=https://ueh.edu.vn/cuoc-song-ueh/
  static const news = '/news';
  // vd: /news/detail?url=https://ueh.edu.vn/cuoc-song-ueh/tin-tuc/...-78881
  static const newsDetail = '/news/detail';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
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
