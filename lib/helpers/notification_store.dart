import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Một thông báo FCM đã nhận và lưu trong máy.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.read = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        receivedAt:
            DateTime.tryParse(json['receivedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        // Thông báo lưu trước khi có trường này thì coi là đã đọc.
        read: json['read'] as bool? ?? true,
      );

  /// messageId của FCM (dùng để không lưu trùng); không có thì tự tạo.
  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final bool read;

  AppNotification markedRead() => AppNotification(
    id: id,
    title: title,
    body: body,
    receivedAt: receivedAt,
    read: true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'receivedAt': receivedAt.toIso8601String(),
    'read': read,
  };
}

/// Danh sách thông báo đã nhận, lưu bằng shared_preferences, mới nhất ở đầu.
class NotificationStore {
  NotificationStore._();

  static const _key = 'fcm_notifications';
  static const _maxItems = 200;

  /// Tăng lên mỗi khi danh sách thay đổi trong isolate chính, để giao diện
  /// tự tải lại.
  static final changes = ValueNotifier<int>(0);

  /// Số thông báo chưa đọc, cập nhật mỗi lần đọc/ghi danh sách.
  static final unreadCount = ValueNotifier<int>(0);

  // Hàm xử lý nền ghi từ isolate khác nên phải reload trước khi đọc/ghi,
  // nếu không sẽ đọc bản cũ trong bộ nhớ đệm và ghi đè mất dữ liệu.
  static Future<SharedPreferences> _prefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  static List<AppNotification> _read(SharedPreferences prefs) {
    final items = <AppNotification>[];
    for (final raw in prefs.getStringList(_key) ?? const <String>[]) {
      try {
        items.add(
          AppNotification.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {
        // Bỏ qua dòng hỏng.
      }
    }
    unreadCount.value = items.where((n) => !n.read).length;
    return items;
  }

  static Future<void> _write(
    SharedPreferences prefs,
    List<AppNotification> items,
  ) async {
    final kept = items.take(_maxItems).toList();
    await prefs.setStringList(_key, [
      for (final n in kept) jsonEncode(n.toJson()),
    ]);
    unreadCount.value = kept.where((n) => !n.read).length;
    changes.value++;
  }

  static Future<List<AppNotification>> load() async => _read(await _prefs());

  /// Đọc lại số chưa đọc từ máy, vd khi app quay lại từ nền.
  static Future<void> refreshUnreadCount() async => _read(await _prefs());

  /// Lưu thông báo từ [message]. Bỏ qua nếu không có tiêu đề lẫn nội dung
  /// hoặc đã lưu rồi (cùng messageId).
  static Future<void> add(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString() ?? '';
    final body =
        message.notification?.body ?? message.data['body']?.toString() ?? '';
    if (title.isEmpty && body.isEmpty) return;

    final prefs = await _prefs();
    final items = _read(prefs);
    final messageId = message.messageId ?? '';
    if (messageId.isNotEmpty && items.any((n) => n.id == messageId)) return;

    final now = DateTime.now();
    items.insert(
      0,
      AppNotification(
        id: messageId.isNotEmpty
            ? messageId
            : 'local-${now.microsecondsSinceEpoch}',
        title: title,
        body: body,
        receivedAt: now,
      ),
    );
    await _write(prefs, items);
  }

  static Future<void> markRead(String id) async {
    final prefs = await _prefs();
    final items = _read(prefs);
    if (!items.any((n) => n.id == id && !n.read)) return;
    await _write(prefs, [
      for (final n in items) n.id == id ? n.markedRead() : n,
    ]);
  }

  static Future<void> markAllRead() async {
    final prefs = await _prefs();
    final items = _read(prefs);
    if (items.every((n) => n.read)) return;
    await _write(prefs, [for (final n in items) n.markedRead()]);
  }

  static Future<void> clear() async {
    final prefs = await _prefs();
    await prefs.remove(_key);
    unreadCount.value = 0;
    changes.value++;
  }
}
