import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/common_widgets/bookingcard.dart';
import 'package:premium_force_driver/providers/bookings_provider.dart';
import 'package:intl/intl.dart';

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
        appBar: buidAppBar(context),
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
    if (provider.status == BookingStatus.loading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
        ),
      );
    }

    if (provider.status == BookingStatus.failure) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 50, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error loading bookings',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              provider.errorMessage ?? 'Please try again',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                provider.fetchBookings();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (bookings.isEmpty) {
      return _EmptyBookingState(
        icon: Icons.bookmark_outline,
        message: _getEmptyMessage(_tabController.index, loc),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refreshBookings(),
      backgroundColor: Colors.grey.shade800,
      color: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          final dateFormat = DateFormat('dd MMM, yyyy');
          final timeFormat = DateFormat('h:mm a');

          return Column(
            children: [
              Bookingcard(
                status: booking.status,
                type: booking.rideType,
                pickup: booking.pickupLocation,
                dropoff: booking.dropoffLocation,
                date: dateFormat.format(booking.createdAt),
                time: timeFormat.format(booking.createdAt),
                ride: booking.vehicleType.split(' ')[0],
                brand: booking.vehicleType,
                passengers: booking.passengerCount,
                bookingId: booking.id,
                onAccept: () async {
                  final success = await provider.acceptBooking(booking.id);
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.actionMessage ?? 'Booking accepted',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                onReject: () async {
                  final success = await provider.rejectBooking(booking.id);
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.actionMessage ?? 'Booking rejected',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                onComplete: () async {
                  final success = await provider.completeBooking(booking.id);
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.actionMessage ?? 'Booking completed',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              if (index < bookings.length - 1) const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  /// Get appropriate empty message based on tab index
  String _getEmptyMessage(int tabIndex, AppLocalizations loc) {
    switch (tabIndex) {
      case 0:
        return 'No upcoming bookings yet.\nWait for new ride requests!';
      case 1:
        return 'No ongoing rides right now.\nStart a booking to begin!';
      case 2:
        return 'You haven\'t completed any rides yet.\nComplete bookings to see them here!';
      default:
        return 'No bookings found.';
    }
  }

  PreferredSizeWidget buidAppBar(BuildContext context) {
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
              fontSize: 20,
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
                fontSize: 16,
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
                  fontSize: 16,
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
                  fontSize: 16,
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
