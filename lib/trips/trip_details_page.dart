import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:premium_force_driver/common_widgets/snackbar.dart';
import 'package:premium_force_driver/common_widgets/voice_player.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';
import 'package:premium_force_driver/providers/auth_provider.dart';
import 'package:premium_force_driver/providers/trips_provider.dart';
import 'package:premium_force_driver/services/tracking_service.dart';
import 'package:premium_force_driver/trips/complete_trip_sheet.dart';
import 'package:premium_force_driver/trips/trip_card.dart' show TripFare;
import 'package:premium_force_driver/trips/trip_status_style.dart';

/// Detail view for one trip, backed by `GET /driver/bookings/:id`.
///
/// This is where the ride is driven forward. The backend only accepts the next
/// status in the chain, so the screen offers exactly one action at a time —
/// "Start Driving", "I have Arrived", "Start Trip", "Complete Trip" — and
/// completing opens the extra-charges sheet first, since that transition is the
/// only one that can carry money.
///
/// Live location sharing is tied to the same transitions: it starts when the
/// driver goes en route (which is when the customer's tracking screen opens up)
/// and stops when the trip completes.
class TripDetailsPage extends StatefulWidget {
  const TripDetailsPage({super.key, required this.tripId, this.initialTrip});

  final String tripId;

  /// The list's copy of the trip, shown while the full detail loads.
  final TripV2? initialTrip;

  @override
  State<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage> {
  TripV2? _trip;
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _errorMessage;

  /// Set once a status has changed, so popping refreshes the list behind.
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _trip = widget.initialTrip;
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final trip = await context.read<TripsProvider>().reloadTrip(widget.tripId);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      // Keep the list's copy on screen if the detail read failed, so the driver
      // still sees where they are going.
      _trip = trip ?? _trip;
      _errorMessage = trip == null && _trip == null
          ? AppLocalizations.of(context)!.tripCouldNotBeLoaded
          : null;
    });
  }

  // ---------------------------------------------------------------------------
  // Status progression
  // ---------------------------------------------------------------------------

  /// Advance the trip one step, after confirming and — on completion — after
  /// collecting any extra charges.
  Future<void> _advance() async {
    final trip = _trip;
    if (trip == null || _isUpdating) return;

    final loc = AppLocalizations.of(context)!;
    final provider = context.read<TripsProvider>();
    final next = trip.status.next;
    final actionLabel = trip.status.actionLabel(loc);
    if (next == null || actionLabel == null) return;

    // Going en route is the point of no return for dispatch, and the app's own
    // rules gate it: the driver must be on shift, holding a vehicle.
    if (next == TripStatusV2.driverEnRoute) {
      final blockedReason = _startBlockedReason(loc, provider, trip);
      if (blockedReason != null) {
        AnimatedSnackBar.show(context, blockedReason, 'E');
        return;
      }
    }

    final confirmed = await _confirm(actionLabel, loc.confirmStatusUpdate);
    if (confirmed != true || !mounted) return;

    // Location sharing needs permission before the customer starts watching.
    if (next == TripStatusV2.driverEnRoute) {
      final hasPermissions = await TrackingService().handleLocationPermissions(
        context,
      );
      if (!hasPermissions || !mounted) return;
    }

    ExtraChargesInput? extras;
    if (next == TripStatusV2.completed) {
      extras = await CompleteTripSheet.show(context, currency: trip.currency);
      // A dismissed sheet means the driver changed their mind about completing.
      if (extras == null || !mounted) return;
    }

    setState(() => _isUpdating = true);

    final updated = await provider.advance(
      trip,
      extraAmount: extras?.amount,
      extraPaymentMethod: extras?.paymentMethod,
      extraNotes: extras?.notes,
    );

    if (!mounted) return;
    setState(() => _isUpdating = false);

    final message = provider.consumeActionMessage();

    if (updated == null) {
      AnimatedSnackBar.show(context, message ?? loc.failedToUpdateStatus, 'E');
      return;
    }

    setState(() {
      _trip = updated;
      _didChange = true;
    });

    await _syncTracking(updated, previous: trip);
    if (!mounted) return;

    AnimatedSnackBar.show(context, message ?? loc.tripStatusUpdated, 'S');
  }

  /// Why the driver cannot go en route yet, or null when they can.
  String? _startBlockedReason(
    AppLocalizations loc,
    TripsProvider provider,
    TripV2 trip,
  ) {
    final driver = context.read<AuthProvider>().driver;

    if (!(driver?.isWorkstarted ?? false)) return loc.goOnlineToStartTrip;
    if (!(driver?.hasActiveVehicle ?? false)) {
      return loc.takeOutVehicleToStartTrip;
    }

    // Only one ride can be under way: the tracking session is keyed by booking,
    // and the customer of the other ride would stop seeing their driver.
    final live = provider.liveTrip;
    if (live != null && live.id != trip.id) return loc.finishActiveTripFirst;

    return null;
  }

  /// Start or stop location sharing to match the trip's new status.
  ///
  /// Sharing begins when the driver goes en route — that is when the customer's
  /// tracking screen unlocks — and ends when the trip completes.
  Future<void> _syncTracking(TripV2 trip, {required TripV2 previous}) async {
    final tracking = TrackingService();

    if (trip.status == TripStatusV2.driverEnRoute &&
        !previous.status.isLive &&
        mounted) {
      await tracking.startTracking(
        bookingId: trip.id,
        // The tracking session is addressed by booking; the ids are metadata the
        // customer app reads to confirm it is watching the right ride.
        customerId: trip.customerId ?? '',
        driverId: context.read<AuthProvider>().driver?.uid ?? '',
        isChauffeur: trip.isChauffeur,
        bookedHours: trip.route?.durationHours ?? 0,
      );
      return;
    }

    if (trip.status.isFinished) {
      await tracking.stopTracking();
    }
  }

  Future<bool?> _confirm(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final loc = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
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

  // ---------------------------------------------------------------------------
  // External apps
  // ---------------------------------------------------------------------------

  /// Open turn-by-turn directions: to the pickup before the passenger is on
  /// board, and to the drop-off once the trip has started.
  Future<void> _openMaps() async {
    final trip = _trip;
    if (trip == null) return;

    final loc = AppLocalizations.of(context)!;
    final position = TrackingService().currentPosition;
    final origin = position != null
        ? '${position.latitude},${position.longitude}'
        : 'Current+Location';

    final headingToDropOff =
        trip.status == TripStatusV2.tripStarted &&
        trip.dropOffLat != null &&
        trip.dropOffLng != null;

    final destination = headingToDropOff
        ? '${trip.dropOffLat},${trip.dropOffLng}'
        : (trip.pickupLat != null && trip.pickupLng != null)
        ? '${trip.pickupLat},${trip.pickupLng}'
        : null;

    if (destination == null) {
      AnimatedSnackBar.show(context, loc.couldNotLaunchMaps, 'E');
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      AnimatedSnackBar.show(context, loc.couldNotLaunchMaps, 'E');
    }
  }

  Future<void> _callCustomer(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final trip = _trip;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _didChange);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            loc.tripInfo,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context, _didChange),
          ),
        ),
        body: trip == null
            ? _buildPlaceholder(loc)
            : RefreshIndicator(
                onRefresh: _loadTrip,
                backgroundColor: Colors.grey.shade800,
                color: Colors.white,
                child: _buildContent(loc, trip),
              ),
      ),
    );
  }

  Widget _buildPlaceholder(AppLocalizations loc) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE4A46B)),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? loc.tripCouldNotBeLoaded,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadTrip, child: Text(loc.retry)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppLocalizations loc, TripV2 trip) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final isArabic = languageCode == 'ar';
    final pickupAt = trip.pickupDateTime?.toLocal();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _buildStatusBadge(loc, trip)),
          const SizedBox(height: 20),

          _buildCard(
            child: Column(
              children: [
                _buildRow(
                  loc.service,
                  trip.isChauffeur ? loc.chauffeur : loc.serviceType,
                  Icons.drive_eta,
                ),
                if (trip.vehicle?.label.isNotEmpty ?? false) ...[
                  const Divider(color: Colors.white10, height: 24),
                  _buildRow(
                    loc.vehicleType,
                    trip.vehicle!.label,
                    Icons.directions_car_outlined,
                  ),
                ],
                if (trip.vehicle?.licensePlate != null) ...[
                  const Divider(color: Colors.white10, height: 24),
                  _buildRow(
                    loc.licensePlate,
                    trip.vehicle!.licensePlate!,
                    Icons.confirmation_number_outlined,
                  ),
                ],
                const Divider(color: Colors.white10, height: 24),
                _buildRow(
                  loc.passengers,
                  trip.passengersCount.toString(),
                  Icons.groups_outlined,
                ),
                if ((trip.route?.durationHours ?? 0) > 0) ...[
                  const Divider(color: Colors.white10, height: 24),
                  _buildRow(
                    loc.duration,
                    '${trip.route!.durationHours} ${loc.hrs}',
                    Icons.timer_outlined,
                  ),
                ],
                if (pickupAt != null) ...[
                  const Divider(color: Colors.white10, height: 24),
                  _buildRow(
                    loc.pickupDateAndTime,
                    DateFormat(
                      'dd MMM, yyyy  ·  h:mm a',
                      languageCode,
                    ).format(pickupAt),
                    Icons.event_outlined,
                  ),
                ],
                if (trip.route?.flightNumber != null) ...[
                  const Divider(color: Colors.white10, height: 24),
                  _buildRow(
                    loc.flightNumber,
                    trip.route!.flightNumber!,
                    Icons.flight_takeoff,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionTitle(loc.tripInfo),
          _buildCard(
            child: Column(
              children: [
                _buildRow(
                  loc.pickup,
                  trip.pickupAddress ?? '—',
                  Icons.trip_origin,
                ),
                if (trip.dropOffAddress != null) ...[
                  const Divider(color: Colors.white10, height: 24),
                  _buildRow(
                    loc.dropoff,
                    trip.dropOffAddress!,
                    Icons.place_outlined,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openMaps,
            icon: const Icon(Icons.directions, size: 18),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE4A46B),
              side: const BorderSide(color: Color(0xFFE4A46B)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            label: Text(loc.getDirections),
          ),
          const SizedBox(height: 16),

          _buildCustomerSection(loc, trip),

          if (trip.rideNotes?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 16),
            _buildSectionTitle(loc.specialRequests),
            _buildCard(
              child: Text(
                trip.rideNotes!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],

          if (trip.voiceNoteUrl?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 16),
            _buildSectionTitle(loc.voiceNote),
            _buildCard(child: VoicePlayer(audioUrl: trip.voiceNoteUrl!)),
          ],

          if (trip.timeline.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionTitle(loc.tripProgress),
            _buildCard(child: _buildTimeline(trip, isArabic)),
          ],

          const SizedBox(height: 16),
          _buildPaymentSummary(loc, trip),

          const SizedBox(height: 24),
          _buildAction(loc, trip),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(AppLocalizations loc, TripV2 trip) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: trip.status.color.withAlpha(50),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: trip.status.color),
      ),
      child: Text(
        trip.status.label(loc),
        style: TextStyle(
          color: trip.status.color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCustomerSection(AppLocalizations loc, TripV2 trip) {
    final customer = trip.customer;
    final phone = customer?.phone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(loc.customerInfo),
        _buildCard(
          child: Column(
            children: [
              _buildRow(
                loc.passengerName,
                customer?.name ?? '—',
                Icons.person_outline,
              ),
              if (phone != null && phone.trim().isNotEmpty) ...[
                const Divider(color: Colors.white10, height: 24),
                _buildRow(loc.phoneNumber, phone, Icons.phone_outlined),
              ],
            ],
          ),
        ),
        if (phone != null && phone.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _callCustomer(phone),
            icon: const Icon(Icons.call, size: 18),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.greenAccent,
              side: const BorderSide(color: Colors.greenAccent),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            label: Text(loc.callCustomer),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentSummary(AppLocalizations loc, TripV2 trip) {
    final pricing = trip.pricing;
    final extras = trip.extraCharges;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(loc.paymentSummary),
        _buildCard(
          child: Column(
            children: [
              if (pricing?.totalAmount != null)
                _buildAmountRow(loc.total, pricing!.totalAmount!),
              if (extras != null && !extras.isEmpty) ...[
                const SizedBox(height: 8),
                _buildAmountRow(loc.extras, extras.amount),
                if (extras.notes?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      extras.notes!,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
              const Divider(color: Colors.white10, height: 24),
              _buildAmountRow(
                loc.grandTotal,
                pricing?.payable ?? 0,
                emphasise: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountRow(
    String label,
    double amount, {
    bool emphasise = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: emphasise ? Colors.white : Colors.white54,
            fontSize: emphasise ? 14 : 13,
            fontWeight: emphasise ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        TripFare(
          amount: amount,
          color: emphasise ? const Color(0xFFE4A46B) : Colors.white70,
          fontSize: emphasise ? 15 : 13,
        ),
      ],
    );
  }

  /// The progress stepper, rendered from the timeline the API returns so the
  /// wording matches what the customer sees.
  Widget _buildTimeline(TripV2 trip, bool isArabic) {
    return Column(
      children: List.generate(trip.timeline.length, (index) {
        final step = trip.timeline[index];
        final isLast = index == trip.timeline.length - 1;
        final color = step.isCancelled
            ? Colors.red
            : step.isCurrent
            ? const Color(0xFFE4A46B)
            : step.isCompleted
            ? Colors.green
            : Colors.white24;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: step.isCompleted || step.isCurrent
                        ? color
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
                if (!isLast)
                  Container(width: 2, height: 32, color: Colors.white12),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.displayLabel(isArabic),
                      style: TextStyle(
                        color: step.isCompleted || step.isCurrent
                            ? Colors.white
                            : Colors.white38,
                        fontSize: 13,
                        fontWeight: step.isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (step.timestamp != null)
                      Text(
                        DateFormat(
                          'dd MMM, h:mm a',
                          Localizations.localeOf(context).languageCode,
                        ).format(step.timestamp!.toLocal()),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  /// The one action available from the current status, or an explanation of why
  /// there is none.
  Widget _buildAction(AppLocalizations loc, TripV2 trip) {
    final actionLabel = trip.status.actionLabel(loc);

    if (actionLabel == null) {
      // Before assignment the trip is dispatch's to move; afterwards it is done.
      if (trip.status.isFinished) return const SizedBox.shrink();
      return Center(
        child: Text(
          loc.waitingForDispatch,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    return ElevatedButton(
      onPressed: _isUpdating ? null : _advance,
      style: ElevatedButton.styleFrom(
        backgroundColor: trip.status.color,
        disabledBackgroundColor: trip.status.color.withAlpha(120),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isUpdating
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              actionLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  Widget _buildRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
