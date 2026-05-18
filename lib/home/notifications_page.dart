import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:premium_force_driver/storage/user_local_storage.dart';
import 'package:premium_force_driver/services/notification_service.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/common_widgets/snackbar.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    setState(() {
      _notifications = UserLocalStorage.getNotifications();
    });
  }

  Future<void> _markAllAsRead() async {
    if (_notifications.isEmpty) return;
    await UserLocalStorage.markAllNotificationsAsRead();
    NotificationService.instance.updateUnreadCount();
    _loadNotifications();
    if (mounted) {
      final loc = AppLocalizations.of(context)!;
      AnimatedSnackBar.show(context, loc.allMarkedAsRead, 'S');
    }
  }

  Future<void> _clearAll() async {
    if (_notifications.isEmpty) return;

    // Show a confirm dialog first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final loc = AppLocalizations.of(context)!;
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isArabic ? 'مسح الكل' : 'Clear All',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            isArabic
                ? 'هل أنت متأكد أنك تريد مسح جميع الإشعارات؟'
                : 'Are you sure you want to clear all notifications?',
            style: const TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                isArabic ? 'إلغاء' : 'Cancel',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                isArabic ? 'مسح' : 'Clear',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await UserLocalStorage.clearNotifications();
      NotificationService.instance.updateUnreadCount();
      _loadNotifications();
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        AnimatedSnackBar.show(context, loc.allCleared, 'S');
      }
    }
  }

  Future<void> _deleteNotification(String id) async {
    await UserLocalStorage.deleteNotification(id);
    NotificationService.instance.updateUnreadCount();
    _loadNotifications();
    if (mounted) {
      final loc = AppLocalizations.of(context)!;
      AnimatedSnackBar.show(context, loc.notificationDeleted, 'S');
    }
  }

  Future<void> _showNotificationDetail(Map<String, dynamic> notification) async {
    final id = notification['id'] as String?;
    if (id != null && !(notification['read'] as bool? ?? false)) {
      await UserLocalStorage.markNotificationAsRead(id);
      NotificationService.instance.updateUnreadCount();
      _loadNotifications();
    }

    if (!mounted) return;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final timestampStr = notification['timestamp'] as String?;
        String formattedTime = '';
        if (timestampStr != null) {
          try {
            final dt = DateTime.parse(timestampStr);
            formattedTime = DateFormat('hh:mm a, dd MMM yyyy').format(dt);
          } catch (_) {
            formattedTime = timestampStr;
          }
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.notifications, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notification['title'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (formattedTime.isNotEmpty) ...[
                  Text(
                    formattedTime,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  notification['body'] ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isArabic ? 'إغلاق' : 'Close',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF303030),
            Color(0xFF303030),
            Color(0xFF1A1A1A),
            Color(0xFF1A1A1A),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            loc.notificationsTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          actions: [
            if (_notifications.isNotEmpty) ...[
              IconButton(
                tooltip: loc.markAllAsRead,
                icon: const Icon(Icons.done_all, color: Colors.white70),
                onPressed: _markAllAsRead,
              ),
              IconButton(
                tooltip: loc.clearAll,
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                onPressed: _clearAll,
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        body: _notifications.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_outlined,
                        size: 64,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      loc.noNotifications,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final item = _notifications[index];
                  final id = item['id'] as String;
                  final isRead = item['read'] as bool? ?? false;
                  final timestampStr = item['timestamp'] as String?;

                  String timeAgo = '';
                  if (timestampStr != null) {
                    try {
                      final dt = DateTime.parse(timestampStr);
                      timeAgo = DateFormat('hh:mm a, dd MMM').format(dt);
                    } catch (_) {
                      timeAgo = timestampStr;
                    }
                  }

                  return Dismissible(
                    key: Key(id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) => _deleteNotification(id),
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withAlpha(200),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: Card(
                      color: isRead ? const Color(0xFF1E1E1E) : const Color(0xFF282828),
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isRead ? 0 : 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isRead ? Colors.transparent : Colors.amber.withAlpha(100),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _showNotificationDetail(item),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Indicator dot / Bell Icon
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isRead
                                      ? Colors.white.withAlpha(10)
                                      : Colors.amber.withAlpha(30),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isRead ? Icons.notifications_none : Icons.notifications_active,
                                  color: isRead ? Colors.white38 : Colors.amber,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Text Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['title'] ?? '',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (timeAgo.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            timeAgo,
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item['body'] ?? '',
                                      style: TextStyle(
                                        color: isRead ? Colors.white38 : Colors.white70,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
