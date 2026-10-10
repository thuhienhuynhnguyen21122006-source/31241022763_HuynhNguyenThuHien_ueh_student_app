import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'app_drawer.dart';
import 'attendance_tab.dart';
import 'student_card_tab.dart';
import 'ueh_news_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _attendanceIndex = 2;
  static const _accountIndex = 3;

  static const _tabs = [
    UehNewsTab(),
    _PlaceholderTab(title: 'Thông báo', icon: FontAwesomeIcons.bell),
    AttendanceTab(),
    StudentCardTab(),
  ];

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
        items: const [
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.house),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.bell),
            label: 'Thông báo',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.clipboardCheck),
            label: 'Điểm danh',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.solidUser),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title, required this.icon});

  final String title;
  final FaIconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}
