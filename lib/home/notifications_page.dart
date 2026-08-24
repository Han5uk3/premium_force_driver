import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:premium_force_driver/common_widgets/snackbar.dart';
import 'package:premium_force_driver/home/home.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/main.dart' show navigatorKey;
import 'package:premium_force_driver/models/v2/notification_v2.dart';
import 'package:premium_force_driver/providers/notifications_provider.dart';
import 'package:premium_force_driver/trips/trip_details_page.dart';

/// The driver's notification centre, backed by `GET /notifications/driver`.
///
/// Read state and deletion live on the server, so a trip assignment the driver
/// opened on one device does not come back unread on another. Tapping an entry
/// marks it read and, when it names a trip, opens that trip.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<NotificationsProvider>();
      // The badge may already have warmed the feed; refresh silently so the list
      // stays readable while the newest page arrives.
      provider.refresh(
        silent: provider.status == NotificationFeedStatus.loaded,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      context.read<NotificationsProvider>().loadMore();
    }
  }

  Future<void> _openNotification(NotificationV2 notification) async {
    final provider = context.read<NotificationsProvider>();
    // Marking read is the whole action for a notification with nowhere to go,
    // and the first half of it for one that opens a trip. Cheap either way:
    // the provider returns without calling the API when it is already read.
    provider.markAsRead(notification.id);

    _logNotification(notification);

    final tripId = notification.bookingId;

    // Two kinds of notification have nowhere to go: one that names no booking,
    // and one saying the booking was taken off this driver — which still
    // carries the id, but opening it would load a ride they no longer hold.
    // Neither opens anything; the row is already showing its title and body,
    // and it greys out as read.
    if (tripId == null || tripId.isEmpty || notification.isTripUnassigned) {
      return;
    }

    // Land the driver in the stack they would have if they had opened the trip
    // from the shell: dashboard → trips → this trip. So this route closes and
    // the trips tab is selected underneath *before* the trip is pushed, leaving
    // back to read trip → trips → dashboard instead of dropping them back into
    // a notifications list they are finished with.
    //
    // Pushed through the root navigator rather than `context`, which is defunct
    // the moment this route pops.
    //
    // Which trips tab, though, is not knowable here: a notification carries a
    // booking id and no status. So the tab is set from the trip itself once
    // the detail page has it — a completed trip lands behind the Completed
    // tab, everything else behind Active. Before that it opens on Active,
    // which is where a trip worth notifying about usually is.
    Navigator.pop(context);
    HomeState.showTrips();
    await navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => TripDetailsPage(
          tripId: tripId,
          onTripLoaded: (trip) =>
              HomeState.showTrips(tabIndex: trip.status.isFinished ? 1 : 0),
        ),
      ),
    );
  }

  /// Dump the tapped notification, unredacted.
  ///
  /// Kept from the payload investigation that established `trip_assignment`
  /// covers both assignment and unassignment. The `data` map is where routing
  /// information lives and is what varies between senders, so it is printed
  /// whole rather than summarised — line by line, because `debugPrint`
  /// truncates long lines and would cut the payload in half.
  ///
  /// Debug builds only: a notification names the customer and the booking.
  void _logNotification(NotificationV2 notification) {
    if (!kDebugMode) return;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    debugPrint('🔔 notification tapped │ id=${notification.id}');
    debugPrint(
      '   notification │ type=${notification.type.wireValue} '
      'bookingId=${notification.bookingId ?? '-'} '
      'bookingNumber=${notification.bookingNumber ?? '-'} '
      'isRead=${notification.isRead} '
      'createdAt=${notification.createdAt?.toIso8601String() ?? '-'}',
    );
    debugPrint('   notification │ title=${notification.title}');
    debugPrint('   notification │ titleAr=${notification.titleAr ?? '-'}');
    debugPrint('   notification │ body=${notification.body}');
    debugPrint('   notification │ bodyAr=${notification.bodyAr ?? '-'}');
    debugPrint(
      '   notification │ shown=${notification.displayTitle(isArabic)} '
      '/ ${notification.displayBody(isArabic)}',
    );

    String rendered;
    try {
      rendered = const JsonEncoder.withIndent('  ').convert(notification.data);
    } catch (_) {
      rendered = notification.data.toString();
    }
    debugPrint('   notification │ data:');
    for (final line in rendered.split('\n')) {
      debugPrint('   notification │ $line');
    }
  }

  Future<void> _deleteNotification(
    AppLocalizations loc,
    NotificationsProvider provider,
    String notificationId,
  ) async {
    final deleted = await provider.deleteNotification(notificationId);
    if (!mounted || !deleted) return;
    AnimatedSnackBar.show(context, loc.notificationDeleted, 'S');
  }

  Future<void> _markAllAsRead(
    AppLocalizations loc,
    NotificationsProvider provider,
  ) async {
    final marked = await provider.markAllAsRead();
    if (!mounted || !marked) return;
    AnimatedSnackBar.show(context, loc.allMarkedAsRead, 'S');
  }

  Future<void> _clearAll(
    AppLocalizations loc,
    NotificationsProvider provider,
  ) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(loc.clearAll, style: const TextStyle(color: Colors.white)),
        content: Text(
          isArabic
              ? 'هل أنت متأكد أنك تريد مسح جميع الإشعارات؟'
              : 'Are you sure you want to clear all notifications?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              loc.cancel,
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isArabic ? 'مسح' : 'Clear',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final cleared = await provider.clearAll();
    if (!mounted || !cleared) return;
    AnimatedSnackBar.show(context, loc.allCleared, 'S');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final provider = context.watch<NotificationsProvider>();

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
            if (provider.unreadCount > 0)
              IconButton(
                tooltip: loc.markAllAsRead,
                icon: const Icon(Icons.done_all, color: Colors.white70),
                onPressed: () => _markAllAsRead(loc, provider),
              ),
            if (provider.notifications.isNotEmpty) ...[
              IconButton(
                tooltip: loc.clearAll,
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Colors.redAccent,
                ),
                onPressed: () => _clearAll(loc, provider),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => provider.refresh(silent: true),
          backgroundColor: Colors.grey.shade800,
          color: Colors.white,
          child: _buildBody(loc, provider, isArabic),
        ),
      ),
    );
  }

  Widget _buildBody(
    AppLocalizations loc,
    NotificationsProvider provider,
    bool isArabic,
  ) {
    if (provider.status == NotificationFeedStatus.initial ||
        provider.status == NotificationFeedStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE4A46B)),
      );
    }

    if (provider.status == NotificationFeedStatus.failure &&
        provider.notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.white24,
                ),
                const SizedBox(height: 16),
                Text(
                  provider.errorMessage ?? loc.pleaseTryAgain,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: provider.refresh,
                  child: Text(loc.retry),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (provider.notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Column(
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
        ],
      );
    }

    final notifications = provider.notifications;

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      // One extra row carries the "loading more" spinner at the tail.
      itemCount: notifications.length + (provider.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= notifications.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFE4A46B)),
            ),
          );
        }

        final notification = notifications[index];
        return _NotificationTile(
          notification: notification,
          isArabic: isArabic,
          onTap: () => _openNotification(notification),
          onDelete: () => _deleteNotification(loc, provider, notification.id),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.isArabic,
    required this.onTap,
    required this.onDelete,
  });

  final NotificationV2 notification;
  final bool isArabic;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// Icon per notification type, so a new assignment reads differently from a
  /// cancellation at a glance.
  IconData get _icon => switch (notification.type) {
    NotificationTypeV2.tripAssignment => Icons.local_taxi,
    NotificationTypeV2.bookingStatus => Icons.event_available_outlined,
    NotificationTypeV2.payment => Icons.payments_outlined,
    NotificationTypeV2.promotion => Icons.local_offer_outlined,
    NotificationTypeV2.general => Icons.notifications_active,
  };

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;
    final createdAt = notification.createdAt?.toLocal();
    final timeStr = createdAt == null
        ? ''
        : DateFormat(
            'hh:mm a, dd MMM',
            isArabic ? 'ar' : 'en',
          ).format(createdAt);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: isArabic ? Alignment.centerLeft : Alignment.centerRight,
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
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isRead
                        ? Colors.white.withAlpha(10)
                        : Colors.amber.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _icon,
                    color: isRead ? Colors.white38 : Colors.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.displayTitle(isArabic),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timeStr.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              timeStr,
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
                        notification.displayBody(isArabic),
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
  }
}
