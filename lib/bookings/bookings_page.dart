import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/common_widgets/bookingcard.dart';
import 'package:premium_force_driver/providers/bookings_provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:premium_force_driver/services/tracking_service.dart';
import 'package:premium_force_driver/common_widgets/snackbar.dart';
import 'booking_details_page.dart';
import 'package:premium_force_driver/common_widgets/booking_shimmer.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Fetch bookings when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BookingsProvider>().fetchBookings();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
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
        appBar: buildAppBar(context),
        body: Consumer<BookingsProvider>(
          builder: (context, bookingsProvider, _) {
            return Column(
              children: [
                TabBar(
                  controller: _tabController,
                  dividerColor: Colors.grey.shade800,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                  ),
                  indicator: const _GradientTabIndicator(
                    gradient: _tabGradient,
                    height: 3.0,
                  ),
                  unselectedLabelColor: Colors.grey.shade300,
                  tabs: [
                    _GradientTab(
                      text: loc.upcoming,
                      controller: _tabController,
                      index: 0,
                      gradient: _tabGradient,
                    ),
                    _GradientTab(
                      text: loc.ongoing,
                      controller: _tabController,
                      index: 1,
                      gradient: _tabGradient,
                    ),
                    _GradientTab(
                      text: loc.completed,
                      controller: _tabController,
                      index: 2,
                      gradient: _tabGradient,
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Upcoming bookings
                      _buildBookingsListView(
                        bookingsProvider,
                        bookingsProvider.upcomingBookings,
                        loc,
                      ),
                      // Ongoing bookings
                      _buildBookingsListView(
                        bookingsProvider,
                        bookingsProvider.ongoingBookings,
                        loc,
                      ),
                      // Completed bookings
                      _buildBookingsListView(
                        bookingsProvider,
                        bookingsProvider.completedBookings,
                        loc,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Build a booking list view with loading/error states
  Widget _buildBookingsListView(
    BookingsProvider provider,
    List<dynamic> bookings,
    AppLocalizations loc,
  ) {
    return RefreshIndicator(
      onRefresh: () => provider.refreshBookings(),
      backgroundColor: Colors.grey.shade800,
      color: Colors.white,
      child: _buildBookingsContent(provider, bookings, loc),
    );
  }

  Widget _buildBookingsContent(
    BookingsProvider provider,
    List<dynamic> bookings,
    AppLocalizations loc,
  ) {
    if (provider.status == BookingStatus.loading) {
      return const BookingShimmer();
    }

    if (provider.status == BookingStatus.failure) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 50, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              loc.errorLoadingBookings,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              provider.errorMessage ?? loc.pleaseTryAgain,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                provider.fetchBookings();
              },
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      );
    }

    if (bookings.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          _EmptyBookingState(
            icon: Icons.bookmark_outline,
            message: _getEmptyMessage(_tabController.index, loc),
          ),
        ],
      );
    }

    return ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          final dateFormat = DateFormat('dd MMM, yyyy');
          final timeFormat = DateFormat('h:mm a');

          // Prioritize pickupdatetime then arrival, then fallback to createdAt
          final displayDateTime =
              (booking.pickupdatetime != null &&
                  booking.pickupdatetime!.isNotEmpty)
              ? DateTime.tryParse(booking.pickupdatetime!)
              : (booking.arrival != null && booking.arrival!.isNotEmpty)
              ? DateTime.tryParse(booking.arrival!)
              : booking.createdAt;

          final effectiveDateTime = displayDateTime ?? booking.createdAt;
          final isToday =
              effectiveDateTime.year == DateTime.now().year &&
              effectiveDateTime.month == DateTime.now().month &&
              effectiveDateTime.day == DateTime.now().day;

          return Column(
            children: [
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BookingDetailsPage(booking: booking),
                    ),
                  );
                  // Refresh bookings when coming back, in case status changed
                  if (context.mounted) {
                    context.read<BookingsProvider>().refreshBookings();
                  }
                },
                child: Bookingcard(
                  status: booking.status,
                  type: booking.isHourly
                      ? loc.chauffeur
                      : booking.pickupLocation.toLowerCase().contains('airport')
                      ? loc.airportArrival
                      : booking.dropoffLocation.toLowerCase().contains(
                          'airport',
                        )
                      ? loc.airportDeparture
                      : loc.privateTransfer,
                  pickup: booking.pickupLocation,
                  dropoff: booking.dropoffLocation ?? '',
                  date: dateFormat.format(effectiveDateTime),
                  time: timeFormat.format(effectiveDateTime),
                  ride: booking.displayRideType,
                  brand: booking.displayBrand,
                  passengers: booking.passengerCount,
                  bookingId: booking.id,
                  rating: booking.rating,
                  reviewText: booking.review,
                  isChauffeur: booking.isHourly,
                  isToday: isToday,
                  pickupLatitude: booking.pickupLatitude,
                  pickupLongitude: booking.pickupLongitude,
                  dropoffLatitude: booking.dropoffLatitude,
                  dropoffLongitude: booking.dropoffLongitude,
                  onAccept: () async {
                    final confirm = await _showConfirmationDialog(
                      context,
                      loc.acceptBooking,
                      loc.acceptBookingConfirm,
                    );
                    if (confirm != true) return;
                    final success = await provider.acceptBooking(booking.id);
                    if (success && context.mounted) {
                      AnimatedSnackBar.show(
                        context,
                        provider.actionMessage ?? loc.bookingAccepted,
                        'S',
                      );
                    }
                  },
                  onReject: () async {
                    final confirm = await _showConfirmationDialog(
                      context,
                      loc.rejectBooking,
                      loc.rejectBookingConfirm,
                    );
                    if (confirm != true) return;
                    final success = await provider.rejectBooking(booking.id);
                    if (success && context.mounted) {
                      AnimatedSnackBar.show(
                        context,
                        provider.actionMessage ?? loc.bookingRejected,
                        'E',
                      );
                    }
                  },
                  onComplete: () async {
                    final confirm = await _showConfirmationDialog(
                      context,
                      loc.completeBooking,
                      loc.completeBookingConfirm,
                    );
                    if (confirm != true) return;
                    await TrackingService().stopTracking();
                    final success = await provider.completeBooking(booking.id);
                    if (success && context.mounted) {
                      if (context.mounted) {
                        AnimatedSnackBar.show(
                          context,
                          provider.actionMessage ?? loc.bookingCompleted,
                          success ? 'S' : 'E',
                        );
                      }
                    }
                  },
                  onStartTracking: () async {
                    final confirm = await _showConfirmationDialog(
                      context,
                      loc.startRide,
                      loc.startRideConfirm,
                    );
                    if (confirm != true) return;

                    // Check for location permissions (foreground & background)
                    final hasPermissions = await TrackingService()
                        .handleLocationPermissions(context);
                    if (!hasPermissions) return;

                    final success = await provider.startTracking(booking.id);
                    if (success && context.mounted) {
                      await TrackingService().startTracking(
                        bookingId: booking.id,
                        customerId: booking.customerId,
                        driverId: booking.driverId ?? '',
                        isChauffeur: booking.isHourly,
                        bookedHours:
                            booking.estimatedDuration, // hours from booking
                      );
                      if (context.mounted) {
                        AnimatedSnackBar.show(
                          context,
                          provider.actionMessage ?? loc.rideStarted,
                          'S',
                        );
                        _openMaps(booking);
                      }
                    }
                  },
                  onStopTracking: () async {
                    final confirm = await _showConfirmationDialog(
                      context,
                      loc.endRide,
                      loc.endRideConfirm,
                    );
                    if (confirm != true) return;

                    final success = await provider.stopTracking(booking.id);
                    if (context.mounted) {
                      AnimatedSnackBar.show(
                        context,
                        success
                            ? (provider.actionMessage ?? loc.tripEnded)
                            : (provider.actionMessage ??
                                  loc.rideStoppedSyncPending),
                        success ? 'S' : 'E',
                      );
                    }
                  },
                  onGetDirections: () {
                    _openMaps(booking);
                  },
                  onPauseTracking: () async {
                    await TrackingService().pauseTracking(
                      bookingId: booking.id,
                    );
                    if (context.mounted) {
                      setState(() {});
                      AnimatedSnackBar.show(
                        context,
                        AppLocalizations.of(context)!.ridePaused,
                        'S',
                      );
                    }
                  },
                  onResumeTracking: () async {
                    await TrackingService().resumeTracking(
                      bookingId: booking.id,
                    );
                    if (context.mounted) {
                      setState(() {});
                      AnimatedSnackBar.show(
                        context,
                        AppLocalizations.of(context)!.rideResumed,
                        'S',
                      );
                    }
                  },
                ),
              ),
              if (index < bookings.length - 1) const SizedBox(height: 16),
            ],
          );
        },
      );
  }

  void _openMaps(dynamic booking) async {
    final pickupLat = booking.pickupLatitude;
    final pickupLong = booking.pickupLongitude;
    final dropoffLat = booking.dropoffLatitude;
    final dropoffLong = booking.dropoffLongitude;

    final currentPos = TrackingService().currentPosition;
    final origin = currentPos != null
        ? '${currentPos.latitude},${currentPos.longitude}'
        : 'Current+Location';

    String url;
    if (booking.rideType.toLowerCase().contains('chauffeur') ||
        dropoffLat == 0) {
      // Chauffeur booking has only pickup
      url =
          "https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$pickupLat,$pickupLong";
    } else {
      // Regular booking: Origin (Driver) -> Pickup (Waypoint) -> Dropoff (Destination)
      url =
          "https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$dropoffLat,$dropoffLong&waypoints=$pickupLat,$pickupLong";
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        AnimatedSnackBar.show(
          context,
          AppLocalizations.of(context)!.couldNotLaunchMaps,
          'E',
        );
      }
    }
  }

  /// Get appropriate empty message based on tab index
  String _getEmptyMessage(int tabIndex, AppLocalizations loc) {
    switch (tabIndex) {
      case 0:
        return loc.noUpcomingBookingsMessage;
      case 1:
        return loc.noOngoingRidesMessage;
      case 2:
        return loc.noCompletedRidesMessage;
      default:
        return loc.noBookingsFound;
    }
  }

  PreferredSizeWidget buildAppBar(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(100), Colors.transparent],
          ),
        ),
        child: AppBar(
          centerTitle: true,
          title: Text(
            loc.bookings,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
        ),
      ),
    );
  }

  Future<bool?> _showConfirmationDialog(
    BuildContext context,
    String title,
    String content,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final loc = AppLocalizations.of(context)!;
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(content, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                loc.cancel,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC0C0C0),
              ),
              child: Text(
                loc.confirm,
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }
}

const Gradient _tabGradient = LinearGradient(
  colors: [Color(0xFF4A4A4A), Color(0xFFC0C0C0), Color(0xFF666666)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class _GradientTabIndicator extends Decoration {
  final double height;
  final Gradient gradient;

  const _GradientTabIndicator({this.height = 3.0, required this.gradient});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _GradientPainter(this, onChanged);
  }
}

class _GradientPainter extends BoxPainter {
  final _GradientTabIndicator decoration;

  _GradientPainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Rect rect =
        Offset(
          offset.dx,
          (configuration.size?.height ?? 0) - decoration.height,
        ) &
        Size(configuration.size?.width ?? 0, decoration.height);
    final Paint paint = Paint()
      ..shader = decoration.gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }
}

class _GradientTab extends AnimatedWidget implements PreferredSizeWidget {
  final String text;
  final TabController controller;
  final int index;
  final Gradient gradient;

  _GradientTab({
    required this.text,
    required this.controller,
    required this.index,
    required this.gradient,
  }) : super(listenable: controller.animation!);

  @override
  Widget build(BuildContext context) {
    double animationValue = controller.animation?.value ?? index.toDouble();
    double isSelectedValue =
        1.0 - (animationValue - index).abs().clamp(0.0, 1.0);

    return Tab(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 1.0 - isSelectedValue,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          Opacity(
            opacity: isSelectedValue,
            child: ShaderMask(
              shaderCallback: (bounds) => gradient.createShader(
                Rect.fromLTWH(0, 0, bounds.width, bounds.height),
              ),
              blendMode: BlendMode.srcIn,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(46.0);
}

class _EmptyBookingState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyBookingState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with gradient background
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF606060),
                      Color(0xFFC0C0C0),
                      Color(0xFF808080),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(150),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(icon, size: 50, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 32),

              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white60,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
              ),

              // Decorative element
              // Container(
              //   width: 60,
              //   height: 2,
              //   decoration: BoxDecoration(
              //     gradient: const LinearGradient(
              //       colors: [
              //         Color(0xFF606060),
              //         Color(0xFFC0C0C0),
              //         Color(0xFF606060),
              //       ],
              //     ),
              //     borderRadius: BorderRadius.circular(1),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
