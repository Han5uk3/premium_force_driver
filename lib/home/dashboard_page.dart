import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_driver/providers/auth_provider.dart';
import 'package:premium_force_driver/providers/trips_provider.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';
import 'package:premium_force_driver/api/apis.dart';
import 'package:premium_force_driver/trips/trip_actions.dart';
import 'package:premium_force_driver/trips/trip_card.dart';
import 'package:premium_force_driver/trips/trip_details_page.dart';
import 'package:premium_force_driver/providers/notifications_provider.dart';
import 'package:premium_force_driver/home/notifications_page.dart';
import 'package:premium_force_driver/common_widgets/sharing_restore_banner.dart';
import 'package:premium_force_driver/services/tracking_service.dart';
import 'package:premium_force_driver/common_widgets/snackbar.dart';
import 'package:premium_force_driver/home/home.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  bool _isLoadingFleets = false;
  List<dynamic> _availableFleets = [];
  bool _isTogglingStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load profile and trips on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().fetchDriverProfile();
        context.read<TripsProvider>().refresh();
        // Populates the unread badge in the app bar; the notification centre
        // re-reads the feed itself when opened.
        context.read<NotificationsProvider>().refresh();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;

    // Re-read the active list on every return to the app, because reading it is
    // what reconciles location sharing — `refreshFilter` hands it to
    // `TrackingService.syncWithActiveTrips`. Without this the reconcile only
    // ran when this page was first built, so a driver who left the app, had
    // their location permission revoked or their foreground service killed by
    // the OS, and came back, resumed nothing and was told nothing.
    context.read<TripsProvider>().refreshFilter(
      TripFilterV2.active,
      silent: true,
    );
  }

  Future<void> _handleRefresh() async {
    await context.read<AuthProvider>().fetchDriverProfile();
    await context.read<TripsProvider>().refresh(silent: true);
  }

  Future<void> _fetchAvailableFleets(BuildContext context) async {
    setState(() {
      _isLoadingFleets = true;
    });

    try {
      final api = ApiService();
      final response = await api.getAvailableFleets();
      if (response['success'] == true) {
        setState(() {
          _availableFleets = response['data'] ?? [];
        });
      } else {
        if (mounted) {
          AnimatedSnackBar.show(
            context,
            response['message'] ?? 'Failed to load fleets',
            'E',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AnimatedSnackBar.show(
          context,
          'Error loading available fleets: $e',
          'E',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFleets = false;
        });
      }
    }
  }

  void _showPickupVehicleBottomSheet(BuildContext context) async {
    // Show a premium loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final dialogLoc = AppLocalizations.of(context)!;
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Color(0xFFC0C0C0),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      dialogLoc.fetchingFleetsForTakeout,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      await _fetchAvailableFleets(context);
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        final loc = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    loc.selectVehicle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (_isLoadingFleets)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 30.0),
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  else if (_availableFleets.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30.0),
                        child: Text(
                          loc.noVehiclesAvailable,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availableFleets.length,
                        itemBuilder: (context, index) {
                          final item = _availableFleets[index];
                          final carId = item['carID'] ?? {};
                          final carName = carId['carName'] ?? 'Unknown Vehicle';
                          final model = carId['model'] ?? '';
                          final licenseNumber =
                              item['carLicenseNumber'] ?? 'N/A';

                          final brandRaw = carId['brandID'] ?? carId['brand'];
                          final brandName = (brandRaw is Map)
                              ? (brandRaw['brandName'] ?? '')
                              : (brandRaw is String ? brandRaw : '');
                          final displayName =
                              '${brandName.isNotEmpty ? "$brandName " : ""}$carName $model'
                                  .trim();

                          return Card(
                            color: const Color(0xFF292929),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade800,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.directions_car_outlined,
                                  color: Colors.white70,
                                ),
                              ),
                              title: Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${loc.licensePlate}: $licenseNumber',
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                                onPressed: () => _confirmAndTakeOutFleet(
                                  context,
                                  item['_id'].toString(),
                                  displayName,
                                ),
                              ),
                              onTap: () => _confirmAndTakeOutFleet(
                                context,
                                item['_id'].toString(),
                                displayName,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAndTakeOutFleet(
    BuildContext sheetContext,
    String fleetId,
    String vehicleName,
  ) async {
    Navigator.pop(sheetContext); // Close bottom sheet first

    if (!mounted) return;

    final pageContext = this.context;
    final loc = AppLocalizations.of(pageContext)!;
    final confirm = await showDialog<bool>(
      context: pageContext,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            loc.confirmTakeOut,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            '${loc.confirmTakeOutMessage}$vehicleName?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                loc.cancel,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC0C0C0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                loc.confirm,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (!mounted) return;

    final authProvider = pageContext.read<AuthProvider>();
    final success = await authProvider.takeOutFleet(fleetId);

    if (!mounted) return;

    if (success) {
      AnimatedSnackBar.show(
        pageContext,
        loc.vehiclePickupSuccess,
        'S',
        isFullWidth: true,
      );
    } else {
      AnimatedSnackBar.show(
        pageContext,
        authProvider.errorMessage ?? loc.failedToPickUpVehicle,
        'E',
      );
    }
  }

  Future<void> _handleReturnVehicle() async {
    if (!mounted) return;

    final currentContext = this.context;
    final loc = AppLocalizations.of(currentContext)!;

    final confirm = await showDialog<bool>(
      context: currentContext,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            loc.confirmReturn,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            loc.confirmReturnMessage,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                loc.cancel,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                loc.confirm,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    if (!mounted) return;

    final authProvider = this.context.read<AuthProvider>();
    final success = await authProvider.returnFleet();

    if (!mounted) return;

    if (success) {
      AnimatedSnackBar.show(
        this.context,
        loc.vehicleReturnSuccess,
        'S',
        isFullWidth: true,
      );
    } else {
      AnimatedSnackBar.show(
        this.context,
        authProvider.errorMessage ?? loc.failedToReturnVehicle,
        'E',
      );
    }
  }

  Future<void> _handleToggleWorkStatus(
    BuildContext context,
    bool isWorkstarted,
  ) async {
    if (!isWorkstarted) {
      if (context.read<TripsProvider>().hasLiveTrip) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        AnimatedSnackBar.show(
          context,
          isArabic
              ? 'لا يمكنك تغيير حالة العمل إلى غير متصل أثناء وجود حجز نشط'
              : 'Cannot toggle work status to offline while having an active booking',
          'E',
        );
        return;
      }
    }

    if (_isTogglingStatus) return;

    setState(() {
      _isTogglingStatus = true;
    });

    try {
      final loc = AppLocalizations.of(context)!;
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.toggleWorkStatus(isWorkstarted);

      if (!mounted) return;

      if (!success) {
        AnimatedSnackBar.show(
          context,
          authProvider.errorMessage ?? loc.failedToUpdateStatus,
          'E',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingStatus = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();
    final tripsProvider = context.watch<TripsProvider>();

    final driver = authProvider.driver;
    final username = driver?.fullName ?? 'Driver';
    final profileImageUrl = driver?.profileImageUrl;

    // Availability status
    final isOnline = driver?.isWorkstarted ?? false;

    // Vehicle status
    final hasActiveVehicle = driver?.hasActiveVehicle ?? false;
    final activeVehicle = driver?.activeVehicle;

    // Counts — one per trips tab, so tapping a card lands on the list it counts.
    final activeCount = tripsProvider.activeCount;
    final completedCount = tripsProvider.completedCount;

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
          centerTitle: false,
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade800,
                backgroundImage: profileImageUrl != null
                    ? NetworkImage(profileImageUrl)
                    : null,
                child: profileImageUrl == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.hello,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // The badge tracks the server-side unread count, which is what
            // the notification centre reconciles read state against.
            Consumer<NotificationsProvider>(
              builder: (context, notifications, _) {
                final unreadCount = notifications.unreadCount;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsPage(),
                          ),
                        );
                      },
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF303030),
                              width: 1.5,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          backgroundColor: Colors.grey.shade800,
          color: Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Status and Vehicle Card
                Text(
                  loc.workStatus,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Availability status row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: isOnline
                                        ? Colors.green
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isOnline ? loc.activeAndOnline : loc.offline,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: isOnline,
                              activeThumbColor: Colors.green,
                              inactiveTrackColor: Colors.grey.shade800,
                              onChanged: _isTogglingStatus
                                  ? null
                                  : (val) =>
                                        _handleToggleWorkStatus(context, val),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 24),

                        // Vehicle controls section
                        if (hasActiveVehicle && activeVehicle != null) ...[
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade800,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: activeVehicle.car?.carImageUrl != null
                                    ? Image.network(
                                        activeVehicle.car!.carImageUrl!,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(
                                        Icons.directions_car_outlined,
                                        color: Colors.white70,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (activeVehicle.car != null
                                          ? '${activeVehicle.car!.brandName != null && activeVehicle.car!.brandName!.isNotEmpty ? "${activeVehicle.car!.brandName!} " : ""}${activeVehicle.car!.carName} ${activeVehicle.car!.model}'
                                                .trim()
                                          : loc.activeVehicle),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${loc.licensePlate}: ${activeVehicle.carLicenseNumber}',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _handleReturnVehicle(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade400,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                loc.returnVehicle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  loc.noVehicleTakenOut,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isOnline) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () =>
                                    _showPickupVehicleBottomSheet(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC0C0C0),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  loc.pickupVehicle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Summary counts section title
                Text(
                  loc.bookingSummary,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Summary Row
                Row(
                  children: [
                    _buildStatCard(
                      label: loc.active,
                      count: activeCount,
                      gradientColors: [
                        const Color(0xFF6B5330),
                        const Color(0xFF4D3D27),
                      ],
                      onTap: () {
                        final homeState = context
                            .findAncestorStateOfType<HomeState>();
                        homeState?.navigateToBookings(0);
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildStatCard(
                      label: loc.completed,
                      count: completedCount,
                      gradientColors: [
                        const Color(0xFF324D39),
                        const Color(0xFF233628),
                      ],
                      onTap: () {
                        final homeState = context
                            .findAncestorStateOfType<HomeState>();
                        homeState?.navigateToBookings(1);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 3. Current active booking title
                Text(
                  loc.activeRide,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Above the card it is about: a live ride whose position is
                // not reaching the customer, with the one action that fixes
                // it. Draws nothing in the ordinary case.
                SharingRestoreBanner(liveTrip: tripsProvider.liveTrip),

                // The ride under way, or the empty state.
                //
                // Both branches sit inside the builder because the condition —
                // `activeRide` — reads TrackingService, which notifies
                // separately from the provider. Deciding outside it would leave
                // the card stale when sharing starts or stops.
                ListenableBuilder(
                  listenable: TrackingService(),
                  builder: (context, _) {
                    final ride = tripsProvider.activeRide;
                    if (ride != null) {
                      return TripCard(
                        trip: ride,
                        onTap: () => _openTrip(ride),
                        onAction: () => TripActions.advance(context, ride),
                        isUpdating: tripsProvider.updatingTripId == ride.id,
                      );
                    }

                    return Card(
                      color: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 30,
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade800,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.map_outlined,
                                  size: 30,
                                  color: Colors.white60,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                loc.noActiveRide,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                loc.activeRideTip,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(
                  height: 100,
                ), // extra padding for bottom navigation
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required int count,
    required List<Color> gradientColors,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Open the trip detail screen, where the ride can be driven forward.
  Future<void> _openTrip(TripV2 trip) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TripDetailsPage(tripId: trip.id, initialTrip: trip),
      ),
    );

    if ((changed ?? false) && mounted) {
      await context.read<TripsProvider>().refresh(silent: true);
    }
  }
}
