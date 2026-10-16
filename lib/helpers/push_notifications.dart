import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import 'notification_store.dart';

/// Chạy ở isolate riêng khi có thông báo đến lúc app chạy nền hoặc đã tắt,
/// nên phải là hàm cấp cao nhất và tự khởi tạo Firebase.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationStore.add(message);
}

/// Gắn vào MaterialApp để hiện SnackBar thông báo ở bất kỳ màn hình nào.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Thông báo đẩy qua Firebase Cloud Messaging.
class PushNotifications {
  PushNotifications._();

  /// Bật lên khi người dùng bấm vào thông báo trên thanh hệ thống; HomeScreen
  /// thấy thì chuyển sang tab "Thông báo" rồi tắt đi.
  static final openNotificationsTab = ValueNotifier<bool>(false);

  /// Gọi trước runApp. Trả về false nếu nền tảng chưa được cấu hình Firebase
  /// (firebase_options.dart chỉ có Android và iOS).
  static Future<bool> initFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      return true;
    } catch (e) {
      debugPrint('Không khởi tạo được Firebase: $e');
      return false;
    }
  }

  /// Xin quyền thông báo, in FCM token, lưu thông báo nhận được và theo dõi
  /// việc bấm vào thông báo.
  static Future<void> start() async {
    final messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onMessage.listen((message) {
      NotificationStore.add(message);
      _showSnackBar(message);
    });
    // Bấm thông báo lúc app chạy nền / lúc app đã tắt.
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
    messaging.getInitialMessage().then((message) {
      if (message != null) _onOpened(message);
    });
    messaging.onTokenRefresh.listen(
      (token) => debugPrint('FCM TOKEN: $token'),
    );

    try {
      // Android 13+ sẽ hiện hộp thoại xin quyền POST_NOTIFICATIONS.
      await messaging.requestPermission();
      debugPrint('FCM TOKEN: ${await messaging.getToken()}');
    } catch (e) {
      debugPrint('Không lấy được FCM token: $e');
    }
  }

  static void _onOpened(RemoteMessage message) {
    // Phòng khi hàm xử lý nền chưa kịp lưu; trùng messageId thì bỏ qua.
    NotificationStore.add(message);
    openNotificationsTab.value = true;
  }

  static void _showSnackBar(RemoteMessage message) {
    final notification = message.notification;
    final text = [
      notification?.title,
      notification?.body,
    ].where((s) => s != null && s.isNotEmpty).join('\n');
    if (text.isEmpty) return;
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}
