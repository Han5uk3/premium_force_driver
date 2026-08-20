import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:premium_force_driver/common_widgets/booking_shimmer.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';
import 'package:premium_force_driver/providers/trips_provider.dart';
import 'package:premium_force_driver/trips/trip_card.dart';
import 'package:premium_force_driver/trips/trip_details_page.dart';

/// The driver's trips, backed by `GET /driver/bookings/my-trips`.
///
/// The two tabs are the two filters the endpoint accepts — `active` and
/// `completed` — rather than slices of one response, so each pages on its own and
/// the bucketing rules stay with the backend.
///
/// Cards here are read-only: tapping one opens the detail screen, which is where
/// a trip is driven forward.
class TripsPage extends StatefulWidget {
  const TripsPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage>
    with SingleTickerProviderStateMixin {
  static const List<TripFilterV2> _filters = [
    TripFilterV2.active,
    TripFilterV2.completed,
  ];

  late TabController _tabController;

  /// The filter currently on screen — the only one this page fetches.
  TripFilterV2 get _visibleFilter => _filters[_tabController.index];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _filters.length,
      vsync: this,
      initialIndex: widget.initialIndex.clamp(0, _filters.length - 1),
    );
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<TripsProvider>();
      final filter = _visibleFilter;
      // Keep a warm list on screen; the dashboard may have loaded it already.
      provider.refreshFilter(
        filter,
        silent: provider.statusFor(filter) == TripsStatus.loaded,
      );
    });
  }

  /// Fetch the tab the driver just moved to, the first time they look at it.
  ///
  /// Coming back to a tab that already has trips on it costs nothing — pulling
  /// down refreshes it when they want that.
  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final provider = context.read<TripsProvider>();
    if (provider.needsLoad(_visibleFilter)) {
      provider.refreshFilter(_visibleFilter);
    }
  }

  @override
  void didUpdateWidget(TripsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      _tabController.animateTo(
        widget.initialIndex.clamp(0, _filters.length - 1),
      );
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openTrip(TripV2 trip) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TripDetailsPage(tripId: trip.id, initialTrip: trip),
      ),
    );

    // The detail screen already folded its update into the provider; a full
    // refresh is only worth it when something actually changed.
    if ((changed ?? false) && mounted) {
      await context.read<TripsProvider>().refreshFilter(
        _visibleFilter,
        silent: true,
      );
    }
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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            loc.myTrips,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: Consumer<TripsProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                TabBar(
                  controller: _tabController,
                  dividerColor: Colors.grey.shade800,
                  indicatorColor: const Color(0xFFE4A46B),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey.shade400,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  tabs: [
                    Tab(text: '${loc.active} (${provider.activeCount})'),
                    Tab(text: loc.completed),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(loc, provider, TripFilterV2.active),
                      _buildList(loc, provider, TripFilterV2.completed),
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

  Widget _buildList(
    AppLocalizations loc,
    TripsProvider provider,
    TripFilterV2 filter,
  ) {
    return RefreshIndicator(
      onRefresh: () => provider.refreshFilter(filter, silent: true),
      backgroundColor: Colors.grey.shade800,
      color: Colors.white,
      child: _buildListBody(loc, provider, filter),
    );
  }

  Widget _buildListBody(
    AppLocalizations loc,
    TripsProvider provider,
    TripFilterV2 filter,
  ) {
    final status = provider.statusFor(filter);

    if (status == TripsStatus.initial || status == TripsStatus.loading) {
      return const BookingShimmer();
    }

    if (status == TripsStatus.failure) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  loc.errorLoadingBookings,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  provider.errorFor(filter) ?? loc.pleaseTryAgain,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.refreshFilter(filter),
                  child: Text(loc.retry),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final trips = provider.tripsFor(filter);

    if (trips.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Column(
            children: [
              Icon(
                filter == TripFilterV2.active
                    ? Icons.local_taxi_outlined
                    : Icons.history,
                size: 56,
                color: Colors.white24,
              ),
              const SizedBox(height: 16),
              Text(
                filter == TripFilterV2.active
                    ? loc.noActiveTrips
                    : loc.noCompletedTrips,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (filter == TripFilterV2.active) ...[
                const SizedBox(height: 8),
                Text(
                  loc.noActiveTripsMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ],
          ),
        ],
      );
    }

    final isLoadingMore = provider.isLoadingMore(filter);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          provider.loadMore(filter);
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        // One extra row carries the "loading more" spinner at the tail.
        itemCount: trips.length + (isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index >= trips.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFE4A46B)),
              ),
            );
          }

          final trip = trips[index];
          return TripCard(trip: trip, onTap: () => _openTrip(trip));
        },
      ),
    );
  }
}
