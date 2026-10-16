import 'package:flutter/material.dart';

import '../helpers/notification_store.dart';

const _primary = Color(0xFF005F69);

/// Hỏi xác nhận rồi xóa toàn bộ thông báo đã lưu.
Future<void> confirmClearNotifications(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: const Text(
        'Xóa tất cả thông báo ?',
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
  if (confirmed == true) await NotificationStore.clear();
}

/// Tab "Thông báo": danh sách thông báo FCM đã nhận, mới nhất ở trên.
class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab>
    with WidgetsBindingObserver {
  List<AppNotification>? _items;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationStore.changes.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    NotificationStore.changes.removeListener(_reload);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Thông báo nhận lúc app chạy nền được lưu từ isolate khác, nên tải lại
  // khi app quay lại màn hình.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    final items = await NotificationStore.load();
    if (mounted) setState(() => _items = items);
  }

  void _open(AppNotification item) {
    if (!item.read) NotificationStore.markRead(item.id);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          item.title.isEmpty ? 'Thông báo' : item.title,
          style: const TextStyle(fontWeight: FontWeight.bold, color: _primary),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _dateTime(item.receivedAt),
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
              if (item.body.isNotEmpty) ...[
                const SizedBox(height: 12),
                SelectableText(item.body, style: const TextStyle(fontSize: 16)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Đóng',
              style: TextStyle(fontWeight: FontWeight.bold, color: _primary),
            ),
          ),
        ],
      ),
    );
  }

  static String _dateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)} '
        '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    return RefreshIndicator(
      color: _primary,
      onRefresh: _reload,
      child: items.isEmpty
          // Vẫn phải cuộn được thì mới kéo xuống để tải lại được.
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 56,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Chưa có thông báo',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (items.any((n) => !n.read))
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TextButton.icon(
                        onPressed: NotificationStore.markAllRead,
                        icon: const Icon(Icons.done_all, color: _primary),
                        label: const Text(
                          'Đánh dấu tất cả đã đọc',
                          style: TextStyle(color: _primary),
                        ),
                      ),
                    ),
                  ),
                for (final (index, item) in items.indexed) ...[
                  if (index > 0) const Divider(height: 1),
                  _NotificationTile(
                    item: item,
                    time: _dateTime(item.receivedAt),
                    onTap: () => _open(item),
                  ),
                ],
              ],
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.time,
    required this.onTap,
  });

  final AppNotification item;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !item.read;
    return ListTile(
      onTap: onTap,
      tileColor: unread ? _primary.withValues(alpha: 0.05) : null,
      leading: const CircleAvatar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        child: Icon(Icons.notifications),
      ),
      title: Text(
        item.title.isEmpty ? 'Thông báo' : item.title,
        style: TextStyle(
          fontWeight: unread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.body.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
                color: unread ? Colors.black87 : null,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            time,
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
      trailing: unread
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}
