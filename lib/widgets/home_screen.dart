import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../helpers/notification_store.dart';
import '../helpers/push_notifications.dart';
import '../routers/app_router.dart';
import 'app_drawer.dart';
import 'attendance_tab.dart';
import 'notifications_tab.dart';
import 'student_card_tab.dart';
import 'ueh_news_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  static const _notificationsIndex = 1;
  static const _attendanceIndex = 2;
  static const _accountIndex = 3;

  static const _tabs = [
    UehNewsTab(),
    NotificationsTab(),
    AttendanceTab(),
    StudentCardTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationStore.refreshUnreadCount();
    PushNotifications.openNotificationsTab.addListener(_openNotificationsTab);
    // App được mở bằng cách bấm thông báo: yêu cầu đã có từ trước.
    if (PushNotifications.openNotificationsTab.value) {
      _selectedIndex = _notificationsIndex;
      PushNotifications.openNotificationsTab.value = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PushNotifications.openNotificationsTab.removeListener(
      _openNotificationsTab,
    );
    super.dispose();
  }

  // Handler nền ghi thông báo ở isolate khác: quay lại app thì đếm lại.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationStore.refreshUnreadCount();
    }
  }

  void _openNotificationsTab() {
    if (!PushNotifications.openNotificationsTab.value) return;
    PushNotifications.openNotificationsTab.value = false;
    setState(() => _selectedIndex = _notificationsIndex);
    // Đóng các màn hình đang mở phía trên (vd bài viết) để thấy tab.
    context.go(AppRoutes.home);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF005F69),
        foregroundColor: Colors.white,
        title: switch (_selectedIndex) {
          _notificationsIndex => const Text('Thông báo'),
          _attendanceIndex => const Text('Điểm danh'),
          _accountIndex => const Text('Tài khoản'),
          _ => Image.asset(
            'asset/image/logo-header.png',
            height: 32,
            // Ảnh gốc rất lớn (7677x1987), giải mã ở kích thước nhỏ cho nhẹ máy
            cacheHeight: 128,
          ),
        },
        centerTitle: true,
        actions: [
          if (_selectedIndex == _notificationsIndex)
            IconButton(
              tooltip: 'Xóa tất cả',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => confirmClearNotifications(context),
            ),
          if (_selectedIndex == _accountIndex)
            IconButton(
              tooltip: 'Đăng xuất',
              icon: const Icon(Icons.logout),
              onPressed: () => confirmLogout(context),
            ),
        ],
      ),
      drawer: const AppDrawer(),
      // Giữ trạng thái các tab, không tải lại khi chuyển qua lại.
      body: IndexedStack(index: _selectedIndex, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.house),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: ValueListenableBuilder<int>(
              valueListenable: NotificationStore.unreadCount,
              builder: (context, count, child) => Badge(
                isLabelVisible: count > 0,
                label: Text(count > 99 ? '99+' : '$count'),
                backgroundColor: Colors.red,
                textColor: Colors.white,
                child: child,
              ),
              child: const FaIcon(FontAwesomeIcons.bell),
            ),
            label: 'Thông báo',
          ),
          const BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.clipboardCheck),
            label: 'Điểm danh',
          ),
          const BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.solidUser),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}
