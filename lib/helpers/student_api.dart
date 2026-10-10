import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Dữ liệu trả về từ GET /api/student-info.
class StudentInfo {
  const StudentInfo({
    required this.uid,
    required this.mssv,
    required this.hoVaTen,
    this.ngaySinh,
    this.gioiTinh,
    this.nienKhoa = '',
    this.noiSinh = '',
    this.heDaoTao = '',
    this.nienHoc = '',
    this.hinhDaiDien = '',
  });

  factory StudentInfo.fromJson(Map<String, dynamic> json) => StudentInfo(
    uid: (json['uid'] as num?)?.toInt() ?? 0,
    mssv: json['mssv']?.toString() ?? '',
    hoVaTen: json['hoVaTen']?.toString() ?? '',
    ngaySinh: DateTime.tryParse(json['ngaySinh']?.toString() ?? ''),
    gioiTinh: json['gioiTinh'] as bool?,
    nienKhoa: json['nienKhoa']?.toString() ?? '',
    noiSinh: json['noiSinh']?.toString() ?? '',
    heDaoTao: json['heDaoTao']?.toString() ?? '',
    nienHoc: json['nienHoc']?.toString() ?? '',
    hinhDaiDien: json['hinhDaiDien']?.toString() ?? '',
  );

  final int uid;
  final String mssv;
  final String hoVaTen;
  final DateTime? ngaySinh;

  /// true là Nam, false là Nữ; null nếu server không trả về.
  final bool? gioiTinh;
  final String nienKhoa;
  final String noiSinh;
  final String heDaoTao;
  final String nienHoc;
  final String hinhDaiDien;

  String get gioiTinhText => switch (gioiTinh) {
    true => 'Nam',
    false => 'Nữ',
    null => '',
  };
}

/// Dữ liệu trả về khi POST /api/attendance thành công.
class AttendanceResult {
  const AttendanceResult({
    required this.message,
    required this.sessionName,
    required this.mssv,
    required this.hoVaTen,
    this.checkedInAt,
    this.distanceMeters,
  });

  factory AttendanceResult.fromJson(Map<String, dynamic> json) =>
      AttendanceResult(
        message: json['message']?.toString() ?? '',
        sessionName: json['sessionName']?.toString() ?? '',
        mssv: json['mssv']?.toString() ?? '',
        hoVaTen: json['hoVaTen']?.toString() ?? '',
        checkedInAt: DateTime.tryParse(json['checkedInAt']?.toString() ?? ''),
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      );

  final String message;
  final String sessionName;
  final String mssv;
  final String hoVaTen;

  /// Giờ do server ghi nhận, theo giờ Việt Nam (UTC+7), không kèm múi giờ.
  final DateTime? checkedInAt;

  /// Khoảng cách tới địa điểm (mét); null nếu đợt không yêu cầu vị trí.
  final double? distanceMeters;
}

/// Lỗi do server trả về (status khác 2xx). [message] hiển thị được cho
/// người dùng.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  /// Phiên đã hết hạn hoặc chưa đăng nhập: cần mở lại màn hình đăng nhập.
  bool get isUnauthorized => statusCode == 401;

  /// Đợt điểm danh yêu cầu vị trí nhưng request chưa kèm toạ độ. Server
  /// không có mã lỗi riêng nên phải dựa vào câu message.
  bool get requiresLocation =>
      statusCode == 400 && message.toLowerCase().contains('yêu cầu vị trí');

  @override
  String toString() => message;
}

/// Đổi lỗi khi gọi [StudentApi] thành câu hiển thị được cho người dùng:
/// lỗi server lấy message, còn lại là lỗi mạng.
String apiErrorMessage(Object error) => switch (error) {
  ApiException e => e.message,
  TimeoutException _ => 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.',
  http.ClientException _ =>
    'Không kết nối được máy chủ. Vui lòng kiểm tra Internet.',
  _ => 'Có lỗi xảy ra. Vui lòng thử lại.',
};

class StudentApi {
  StudentApi._();

  static const baseUrl = 'https://api.ngoisaoviet.info';
  static const _refreshTokenKey = 'student_refresh_token';
  static const _timeout = Duration(seconds: 20);

  // token chỉ giữ trong bộ nhớ; refresh_token chỉ ghi xuống máy khi người
  // dùng chọn "Lưu phiên đăng nhập".
  static String? _token;
  static String? _refreshToken;
  static bool _remember = false;

  /// Lần refresh đang chạy. Mỗi refresh token chỉ dùng được một lần nên các
  /// request cùng gặp 401 phải chờ chung một lần refresh.
  static Future<bool>? _refreshing;

  static bool get isLoggedIn => _token != null;

  /// Đăng nhập. [remember] là lựa chọn "Lưu phiên đăng nhập".
  /// Ném [ApiException] nếu sai MSSV hoặc mật khẩu.
  static Future<void> login(
    String mssv,
    String matKhau, {
    bool remember = false,
  }) async {
    final res = await _send('POST', '/api/login', {
      'mssv': mssv.trim(),
      'mat_khau': matKhau,
    });
    if (res.statusCode != 200) throw _error(res);
    _remember = remember;
    await _saveTokens(_json(res));
  }

  /// Gọi khi mở app: nếu lần trước có lưu phiên thì dùng refresh token đã lưu
  /// để lấy token mới. Trả về false nếu phải đăng nhập lại.
  static Future<bool> restoreSession() async {
    if (_token != null) return true;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_refreshTokenKey);
    if (saved == null || saved.isEmpty) return false;
    _refreshToken = saved;
    _remember = true;
    return _refresh();
  }

  static Future<void> logout() async {
    _token = null;
    _refreshToken = null;
    _remember = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_refreshTokenKey);
  }

  static Future<StudentInfo> fetchStudentInfo() async {
    final res = await _authorized('GET', '/api/student-info');
    if (res.statusCode != 200) throw _error(res);
    return StudentInfo.fromJson(_json(res));
  }

  /// [code] là mã đợt 6 ký tự (quét từ QR hoặc nhập tay). Toạ độ chỉ bắt buộc
  /// khi đợt điểm danh yêu cầu vị trí.
  static Future<AttendanceResult> checkIn(
    String code, {
    double? latitude,
    double? longitude,
  }) async {
    final res = await _authorized('POST', '/api/attendance', {
      'code': code.trim(),
      'latitude': ?latitude,
      'longitude': ?longitude,
    });
    if (res.statusCode != 200) throw _error(res);
    return AttendanceResult.fromJson(_json(res));
  }

  static Future<http.Response> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
    String? token,
  ]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);
    return request.send().then(http.Response.fromStream).timeout(_timeout);
  }

  /// Gọi API cần đăng nhập. Gặp 401 thì refresh token rồi gọi lại một lần.
  static Future<http.Response> _authorized(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final token = _token;
    if (token == null) {
      throw const ApiException(401, 'Bạn chưa đăng nhập.');
    }
    final res = await _send(method, path, body, token);
    if (res.statusCode != 401) return res;

    // Nếu request khác đã refresh xong trong lúc chờ thì dùng luôn token mới.
    final refreshed = _token != null && _token != token || await _refresh();
    if (!refreshed) return res;
    return _send(method, path, body, _token);
  }

  static Future<bool> _refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  static Future<bool> _doRefresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return false;
    // Lỗi mạng sẽ ném ra ngoài và giữ nguyên phiên; chỉ xoá phiên khi server
    // từ chối refresh token.
    final res = await _send('POST', '/api/refresh-token', {
      'refresh_token': refreshToken,
    });
    if (res.statusCode != 200) {
      await logout();
      return false;
    }
    await _saveTokens(_json(res));
    return true;
  }

  /// Lưu ngay cặp token mới và bỏ cặp cũ.
  static Future<void> _saveTokens(Map<String, dynamic> json) async {
    _token = json['token'] as String?;
    _refreshToken = json['refresh_token'] as String?;
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = _refreshToken;
    if (_remember && refreshToken != null) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    } else {
      await prefs.remove(_refreshTokenKey);
    }
  }

  static Map<String, dynamic> _json(http.Response res) {
    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is Map<String, dynamic>) return data;
    } on FormatException {
      // Body rỗng hoặc không phải JSON (vd 401).
    }
    return const {};
  }

  /// Lỗi nghiệp vụ nằm ở trường message; lỗi 400 thiếu/sai dữ liệu theo chuẩn
  /// ASP.NET Core nằm ở errors; 401 của API cần token thì body rỗng.
  static ApiException _error(http.Response res) {
    final data = _json(res);
    final message = data['message'];
    if (message is String && message.isNotEmpty) {
      return ApiException(res.statusCode, message);
    }
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final details = errors.values
          .expand((e) => e is List ? e : [e])
          .join('\n');
      return ApiException(res.statusCode, details);
    }
    return ApiException(res.statusCode, switch (res.statusCode) {
      401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      400 => 'Dữ liệu gửi lên không hợp lệ.',
      _ => 'Có lỗi xảy ra (HTTP ${res.statusCode}).',
    });
  }
}
