import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../helpers/student_api.dart';
import '../routers/app_router.dart';

const _primary = Color(0xFF005F69);

/// Hỏi "Bạn muốn đăng xuất ?"; chỉ khi bấm Xác nhận mới đăng xuất và về
/// màn hình đăng nhập.
Future<void> confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: const Text(
        'Bạn muốn đăng xuất ?',
        style: TextStyle(fontSize: 20, color: Colors.black87),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Hủy',
            style: TextStyle(
              fontSize: 16,
              color: _primary.withValues(alpha: 0.6),
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Xác nhận',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await StudentApi.logout();
  if (context.mounted) context.go(AppRoutes.login);
}

/// Tab "Tài khoản": thẻ sinh viên điện tử, dữ liệu lấy từ /api/student-info.
class StudentCardTab extends StatefulWidget {
  const StudentCardTab({super.key});

  @override
  State<StudentCardTab> createState() => _StudentCardTabState();
}

class _StudentCardTabState extends State<StudentCardTab> {
  late Future<StudentInfo> _infoFuture;

  @override
  void initState() {
    super.initState();
    _infoFuture = _load();
  }

  Future<StudentInfo> _load() async {
    try {
      return await StudentApi.fetchStudentInfo();
    } on ApiException catch (e) {
      // Refresh token cũng không còn dùng được: phải đăng nhập lại.
      if (e.isUnauthorized && mounted) context.go(AppRoutes.login);
      rethrow;
    }
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() => _infoFuture = future);
    try {
      await future;
    } catch (_) {
      // Lỗi đã được FutureBuilder hiển thị.
    }
  }

  Future<void> _logout() => confirmLogout(context);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StudentInfo>(
      future: _infoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: _primary),
          );
        }
        if (snapshot.hasError) {
          return _ErrorView(
            message: apiErrorMessage(snapshot.error!),
            onRetry: _reload,
            onLogout: _logout,
          );
        }
        return RefreshIndicator(
          color: _primary,
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [_StudentCard(info: snapshot.data!)],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.info});

  final StudentInfo info;

  static const _avatarSize = 168.0;

  static String _date(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Thẻ bắt đầu từ giữa ảnh đại diện.
        Container(
          margin: const EdgeInsets.only(top: _avatarSize / 2),
          padding: const EdgeInsets.fromLTRB(20, _avatarSize / 2 + 20, 20, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_primary, Color(0xFF00474F)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'SINH VIÊN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                info.hoVaTen,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'MSSV: ${info.mssv}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Field(
                      label: 'NGÀY SINH',
                      value: _date(info.ngaySinh),
                    ),
                  ),
                  Expanded(
                    child: _Field(
                      label: 'GIỚI TÍNH',
                      value: info.gioiTinhText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Field(label: 'KHOÁ', value: info.nienKhoa),
                  ),
                  Expanded(
                    child: _Field(label: 'NƠI SINH', value: info.noiSinh),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Field(
                label: 'HỆ ĐÀO TẠO - NIÊN HỌC',
                value: [
                  if (info.heDaoTao.isNotEmpty) info.heDaoTao,
                  if (info.nienHoc.isNotEmpty) 'Niên học: ${info.nienHoc}',
                ].join('\n'),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Image.asset(
                        'asset/image/logo-ueh.png',
                        height: 64,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (info.mssv.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: QrImageView(
                        data: info.mssv,
                        size: 104,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                        semanticsLabel: 'Mã QR của MSSV ${info.mssv}',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        _Avatar(url: info.hinhDaiDien, size: _avatarSize),
      ],
    );
  }
}

/// Ảnh đại diện tròn, viền trắng và một vòng mờ bên ngoài.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: Color(0xFFE8E8E8),
      child: Center(child: Icon(Icons.person, size: 80, color: Colors.grey)),
    );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _primary.withValues(alpha: 0.15),
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: ClipOval(
          child: url.isEmpty
              ? placeholder
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : placeholder,
                  errorBuilder: (context, error, stackTrace) => placeholder,
                ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value.isEmpty ? '—' : value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.logout),
      label: const Text('Đăng xuất'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        side: const BorderSide(color: _primary),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _LogoutButton(onPressed: onLogout),
            ],
          ),
        ),
      ),
    );
  }
}
