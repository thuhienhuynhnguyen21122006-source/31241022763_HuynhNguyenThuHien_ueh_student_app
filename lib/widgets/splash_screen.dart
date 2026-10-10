import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../helpers/student_api.dart';
import '../routers/app_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final (loggedIn, _) = await (
      _restoreSession(),
      Future.delayed(const Duration(seconds: 3)),
    ).wait;
    if (mounted) context.go(loggedIn ? AppRoutes.home : AppRoutes.login);
  }

  /// Có refresh token đã lưu thì khôi phục phiên. Lỗi mạng cũng coi như chưa
  /// đăng nhập (refresh token đã lưu vẫn được giữ cho lần mở app sau).
  Future<bool> _restoreSession() async {
    try {
      return await StudentApi.restoreSession();
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'asset/image/nso-splash-landscape-1499x999.png',
            fit: BoxFit.cover,
          ),
          Container(color: Colors.black.withValues(alpha: 0.4)),
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
