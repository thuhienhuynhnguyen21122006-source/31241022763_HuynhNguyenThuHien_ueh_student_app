import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../helpers/student_api.dart';
import '../routers/app_router.dart';

const _primary = Color(0xFF005F69);

/// Không lấy được toạ độ; [message] hiển thị được cho người dùng.
class _LocationException implements Exception {
  const _LocationException(this.message);

  final String message;
}

/// Tab "Điểm danh": quét QR hoặc nhập tay mã đợt rồi gửi lên /api/attendance.
class AttendanceTab extends StatefulWidget {
  const AttendanceTab({super.key});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _loading = false;
  String? _error;
  AttendanceResult? _result;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _scan({required bool barcode}) async {
    FocusScope.of(context).unfocus();
    final code = await Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(builder: (context) => _ScannerPage(barcode: barcode)),
    );
    if (code == null || !mounted) return;
    setState(() {
      _codeController.text = code.trim().toUpperCase();
      _error = null;
      _result = null;
    });
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    AttendanceResult? result;
    String? error;
    try {
      result = await _checkIn(_codeController.text);
    } on _LocationException catch (e) {
      error = e.message;
    } on ApiException catch (e) {
      // Refresh token cũng không còn dùng được: phải đăng nhập lại.
      if (e.isUnauthorized && mounted) {
        context.go(AppRoutes.login);
        return;
      }
      error = e.message;
    } catch (e) {
      error = apiErrorMessage(e);
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
      _error = error;
    });
  }

  /// Gửi mã không kèm vị trí trước; chỉ khi server báo đợt yêu cầu vị trí mới
  /// lấy toạ độ rồi gửi lại. Trả về null nếu người dùng cần bật GPS/cấp quyền
  /// (đã có hộp thoại hướng dẫn).
  Future<AttendanceResult?> _checkIn(String code) async {
    try {
      return await StudentApi.checkIn(code);
    } on ApiException catch (e) {
      if (!e.requiresLocation) rethrow;
    }
    final position = await _currentPosition();
    if (position == null) return null;
    return StudentApi.checkIn(
      code,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<Position?> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await _showSettingsDialog(
        title: 'Chưa bật GPS',
        content:
            'Đợt điểm danh này yêu cầu vị trí. Vui lòng bật GPS (dịch vụ '
            'vị trí) rồi bấm Điểm danh lại.',
        onOpenSettings: Geolocator.openLocationSettings,
      );
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      await _showSettingsDialog(
        title: 'Chưa cấp quyền vị trí',
        content:
            'Đợt điểm danh này yêu cầu vị trí. Vui lòng cấp quyền vị trí cho '
            'ứng dụng trong phần cài đặt rồi bấm Điểm danh lại.',
        onOpenSettings: Geolocator.openAppSettings,
      );
      return null;
    }
    if (permission == LocationPermission.denied) {
      throw const _LocationException(
        'Đợt điểm danh này yêu cầu vị trí. Vui lòng cho phép ứng dụng dùng '
        'vị trí rồi thử lại.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      throw const _LocationException(
        'Không lấy được vị trí hiện tại. Vui lòng ra chỗ thoáng và thử lại.',
      );
    }
  }

  Future<void> _showSettingsDialog({
    required String title,
    required String content,
    required Future<bool> Function() onOpenSettings,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng', style: TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onOpenSettings();
            },
            child: const Text('Mở cài đặt', style: TextStyle(color: _primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final error = _error;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Vui lòng nhập hoặc quét mã để điểm danh',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primary,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                const Text(
                  'Nhập mã điểm danh',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                TextFormField(
                  controller: _codeController,
                  enabled: !_loading,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  cursorColor: _primary,
                  style: const TextStyle(fontSize: 18, letterSpacing: 2),
                  decoration: const InputDecoration(
                    hintText: 'Nhập mã ở đây',
                    hintStyle: TextStyle(
                      color: Colors.black26,
                      letterSpacing: 0,
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: _primary, width: 2),
                    ),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Vui lòng nhập mã điểm danh'
                      : null,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Hoặc',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.black38),
                ),
                const SizedBox(height: 16),
                _OptionButton(
                  icon: Icons.qr_code_scanner,
                  label: 'Quét mã QR Code',
                  onPressed: _loading ? null : () => _scan(barcode: false),
                ),
                const SizedBox(height: 14),
                _OptionButton(
                  icon: Icons.barcode_reader,
                  label: 'Quét mã Barcode',
                  onPressed: _loading ? null : () => _scan(barcode: true),
                ),
                const SizedBox(height: 36),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    disabledBackgroundColor: _primary.withValues(alpha: 0.6),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                    elevation: 4,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Điểm danh',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 20),
                  _MessageBox(
                    icon: Icons.error_outline,
                    color: Colors.red,
                    child: Text(
                      error,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                ],
                if (result != null) ...[
                  const SizedBox(height: 20),
                  _SuccessBox(result: result),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút viền bo tròn: icon bên trái, chữ ở giữa.
class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _primary),
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const StadiumBorder(),
      ),
      child: Row(
        children: [
          Icon(icon, size: 26),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(fontSize: 18, letterSpacing: 2),
              ),
            ),
          ),
          // Cân với icon bên trái để chữ nằm giữa nút.
          const SizedBox(width: 26),
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.icon,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final MaterialColor color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SuccessBox extends StatelessWidget {
  const _SuccessBox({required this.result});

  final AttendanceResult result;

  /// [d] đã là giờ Việt Nam do server ghi nhận nên không đổi múi giờ.
  static String _dateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)} '
        '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final checkedInAt = result.checkedInAt;
    final distance = result.distanceMeters;
    final lines = [
      if (result.sessionName.isNotEmpty) 'Đợt: ${result.sessionName}',
      if (checkedInAt != null) 'Thời gian: ${_dateTime(checkedInAt)}',
      if (distance != null)
        'Khoảng cách: ${distance.toStringAsFixed(1)} m',
    ];

    return _MessageBox(
      icon: Icons.check_circle_outline,
      color: Colors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.message.isEmpty ? 'Điểm danh thành công.' : result.message,
            style: TextStyle(
              color: Colors.green.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
          for (final line in lines) ...[
            const SizedBox(height: 4),
            Text(line, style: TextStyle(color: Colors.green.shade900)),
          ],
        ],
      ),
    );
  }
}

/// Mở camera với khung quét, quét được mã nào thì đóng trang và trả về chuỗi
/// trong mã. [barcode] = true thì chỉ nhận mã vạch, ngược lại chỉ nhận QR.
class _ScannerPage extends StatefulWidget {
  const _ScannerPage({required this.barcode});

  final bool barcode;

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage>
    with SingleTickerProviderStateMixin {
  static const _barcodeFormats = [
    BarcodeFormat.code128,
    BarcodeFormat.code39,
    BarcodeFormat.code93,
    BarcodeFormat.codabar,
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.itf14,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
  ];

  late final _controller = MobileScannerController(
    formats: widget.barcode ? _barcodeFormats : const [BarcodeFormat.qrCode],
  );
  late final _scanLine = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  bool _done = false;

  @override
  void dispose() {
    _scanLine.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim() ?? '';
      if (value.isEmpty) continue;
      _done = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(widget.barcode ? 'Quét mã Barcode' : 'Quét mã QR Code'),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, child) => IconButton(
              tooltip: 'Đèn flash',
              icon: Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
              ),
              onPressed: state.torchState == TorchState.unavailable
                  ? null
                  : _controller.toggleTorch,
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final width = (size.width * 0.7).clamp(0.0, 320.0);
          final window = Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.42),
            width: width,
            height: widget.barcode ? width * 0.55 : width,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                scanWindow: window,
                onDetect: _onDetect,
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      error.errorCode == MobileScannerErrorCode.permissionDenied
                          ? 'Ứng dụng chưa được cấp quyền camera. Vui lòng '
                                'cấp quyền trong phần cài đặt, hoặc quay lại '
                                'và nhập mã bằng tay.'
                          : 'Không mở được camera. Vui lòng quay lại và nhập '
                                'mã bằng tay.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _ScanFramePainter(window: window, line: _scanLine),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                top: window.bottom + 24,
                child: Text(
                  widget.barcode
                      ? 'Đưa mã vạch vào trong khung để quét'
                      : 'Đưa mã QR vào trong khung để quét',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Phủ tối phần ngoài ô quét, vẽ 4 góc khung và vạch quét chạy lên xuống.
class _ScanFramePainter extends CustomPainter {
  _ScanFramePainter({required this.window, required this.line})
    : super(repaint: line);

  final Rect window;
  final Animation<double> line;

  static const _radius = Radius.circular(16);
  static const _corner = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(window, _radius);

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(frame),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    // Chỉ giữ lại 4 góc của viền khung.
    canvas.save();
    canvas.clipPath(
      Path()
        ..addRect(
          Rect.fromLTWH(window.left - 4, window.top - 4, _corner, _corner),
        )
        ..addRect(
          Rect.fromLTWH(
            window.right + 4 - _corner,
            window.top - 4,
            _corner,
            _corner,
          ),
        )
        ..addRect(
          Rect.fromLTWH(
            window.left - 4,
            window.bottom + 4 - _corner,
            _corner,
            _corner,
          ),
        )
        ..addRect(
          Rect.fromLTWH(
            window.right + 4 - _corner,
            window.bottom + 4 - _corner,
            _corner,
            _corner,
          ),
        ),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.white,
    );
    canvas.restore();

    final y = window.top + 12 + (window.height - 24) * line.value;
    canvas.drawLine(
      Offset(window.left + 12, y),
      Offset(window.right - 12, y),
      Paint()
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = _primary,
    );
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) =>
      oldDelegate.window != window;
}
