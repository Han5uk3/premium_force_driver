import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:premium_force_driver/common_widgets/voice_player.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';
import 'package:premium_force_driver/providers/trips_provider.dart';
import 'package:premium_force_driver/trips/trip_actions.dart';
import 'package:premium_force_driver/trips/trip_card.dart' show TripFare;
import 'package:premium_force_driver/trips/trip_controls.dart';
import 'package:premium_force_driver/utils/trip_display.dart';

/// Detail view for one trip, backed by `GET /driver/bookings/:id`.
///
/// This is where the ride is driven forward. The backend only accepts the next
/// status in the chain, so the screen offers exactly one action at a time —
/// "Start Driving", "I have Arrived", "Start Trip", "Complete Trip" — and
/// completing opens the extra-charges sheet first, since that transition is the
/// only one that can carry money. That control leads the screen rather than
/// closing it: a driver opening a ride at the kerb is here to act on it, not to
/// scroll past the fare to find the button.
///
/// The status is not restated in a badge of its own — the appbar's action
/// already says what stage the ride is at, and the timeline lower down says how
/// it got there.
///
/// Live location sharing is tied to the same transitions: it starts when the
/// driver goes en route (which is when the customer's tracking screen opens up)
/// and stops when the trip completes. [TripActions] owns all of that, so the
/// trip card enforces exactly the same rules.
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

    setState(() => _isUpdating = true);
    final updated = await TripActions.advance(context, trip);
    if (!mounted) return;

    setState(() {
      _isUpdating = false;
      if (updated != null) {
        _trip = updated;
        _didChange = true;
      }
    });
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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final pickup = formatTripPickup(context, trip);
    final durationLabel = tripDurationLabel(loc, trip);
    final notes = trip.rideNotes?.trim();
    final voiceNote = trip.voiceNoteUrl?.trim();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The ride controls lead the screen: this is what the driver came to
          // the page to press. Directions are not repeated here — they sit
          // beside the trip-info heading, next to the addresses.
          TripControls(
            trip: trip,
            onAdvance: _advance,
            isUpdating: _isUpdating,
            showDirections: false,
          ),
          const SizedBox(height: 20),

          _buildCard(
            child: Column(
              children: [
                _buildRow(
                  loc.service,
                  tripServiceLabel(loc, trip),
                  Icons.drive_eta,
                ),
                _buildRow(
                  loc.passengers,
                  trip.passengersCount.toString(),
                  Icons.groups_outlined,
                  divided: true,
                ),
                // Hourly hire is booked by the hour rather than to a
                // destination, so the booked hours are what the driver owes.
                if (durationLabel != null)
                  _buildRow(
                    loc.duration,
                    durationLabel,
                    Icons.timer_outlined,
                    divided: true,
                  ),
                _buildRow(
                  loc.pickupDateAndTime,
                  pickup.time.isEmpty
                      ? pickup.date
                      : '${pickup.date}  ·  ${pickup.time}',
                  Icons.event_outlined,
                  divided: true,
                ),
                if (trip.route?.flightNumber?.trim().isNotEmpty ?? false)
                  _buildRow(
                    loc.flightNumber,
                    trip.route!.flightNumber!,
                    Icons.flight_takeoff,
                    divided: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildVehicleSection(loc, trip),

          _buildSectionHeader(
            loc.tripInfo,
            // Directions belong with the addresses they lead to, so the button
            // sits across from the heading rather than under the card.
            trailing: trip.status.isFinished
                ? null
                : _buildDirectionsButton(loc, trip),
          ),
          _buildCard(
            child: Column(
              children: [
                _buildRow(
                  loc.pickup,
                  trip.pickupAddress ?? '—',
                  Icons.trip_origin,
                ),
                if (trip.dropOffAddress != null)
                  _buildRow(
                    loc.dropoff,
                    trip.dropOffAddress!,
                    Icons.place_outlined,
                    divided: true,
                  ),
              ],
            ),
          ),

          // What the customer asked for comes before who they are: the driver
          // needs to have read it before they pick up, not after.
          if (notes?.isNotEmpty ?? false) ...[
            const SizedBox(height: 16),
            _buildSectionHeader(loc.specialRequests),
            _buildCard(
              child: Text(
                notes!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],

          if (voiceNote?.isNotEmpty ?? false) ...[
            const SizedBox(height: 16),
            _buildSectionHeader(loc.voiceNote),
            _buildCard(child: VoicePlayer(audioUrl: voiceNote!)),
          ],

          const SizedBox(height: 16),
          _buildCustomerSection(loc, trip),

          if (trip.timeline.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionHeader(loc.tripProgress),
            _buildCard(child: _buildTimeline(trip, isArabic)),
          ],

          const SizedBox(height: 16),
          _buildPaymentSummary(loc, trip),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// The car dispatch put on this ride, and the class it was booked as.
  ///
  /// The two are separate records — the fleet vehicle carries the plate the
  /// driver is actually holding keys to, the booked class is what the customer
  /// paid for — so they are read and shown separately rather than merged into
  /// one row that could show either.
  Widget _buildVehicleSection(AppLocalizations loc, TripV2 trip) {
    final fleet = trip.fleet;
    final vehicle = trip.vehicle;

    final hasFleet = fleet != null && !fleet.isEmpty;
    final hasVehicle = vehicle != null && !vehicle.isEmpty;
    if (!hasFleet && !hasVehicle) return const SizedBox.shrink();

    final rows = <Widget>[];

    void add(String label, String value, IconData icon) {
      rows.add(_buildRow(label, value, icon, divided: rows.isNotEmpty));
    }

    // The assigned car first — that is the one at the kerb.
    if (hasFleet) {
      if (fleet.label.isNotEmpty) {
        add(loc.assignedVehicle, fleet.label, Icons.directions_car_filled);
      }
      if (fleet.licensePlate?.trim().isNotEmpty ?? false) {
        add(
          loc.licensePlate,
          fleet.licensePlate!.trim(),
          Icons.confirmation_number_outlined,
        );
      }
      if (fleet.colour?.trim().isNotEmpty ?? false) {
        add(loc.vehicleColor, fleet.colour!.trim(), Icons.palette_outlined);
      }
    }

    // The booked class, named only when it says something the fleet row did
    // not — otherwise it just repeats the car above it.
    if (hasVehicle &&
        vehicle.label.isNotEmpty &&
        vehicle.label != fleet?.label) {
      add(
        loc.bookedVehicleClass,
        vehicle.label,
        Icons.directions_car_outlined,
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(loc.vehicleType),
        _buildCard(child: Column(children: rows)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDirectionsButton(AppLocalizations loc, TripV2 trip) {
    if (!TripActions.canOpenDirections(trip)) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: () => TripActions.openDirections(context, trip),
      icon: const Icon(Icons.directions, size: 16),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFE4A46B),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      label: Text(
        loc.getDirections,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildCustomerSection(AppLocalizations loc, TripV2 trip) {
    final customer = trip.customer;
    final phone = customer?.phone?.trim();
    final hasPhone = phone != null && phone.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(loc.customerInfo),
        _buildCard(
          child: Column(
            children: [
              _buildRow(
                loc.passengerName,
                customer?.name ?? '—',
                Icons.person_outline,
              ),
              if (hasPhone)
                _buildRow(
                  loc.phoneNumber,
                  phone,
                  Icons.phone_outlined,
                  divided: true,
                  // Calling is one tap from the number itself rather than a
                  // full-width button below the card.
                  trailing: _buildCallButton(loc, phone),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCallButton(AppLocalizations loc, String phone) {
    return Semantics(
      button: true,
      label: loc.callCustomer,
      child: Material(
        color: Colors.black,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => TripActions.callCustomer(phone),
          child: const Padding(
            padding: EdgeInsets.all(9),
            child: Icon(Icons.phone, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSummary(AppLocalizations loc, TripV2 trip) {
    final pricing = trip.pricing;
    final extras = trip.extraCharges;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(loc.paymentSummary),
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
  ///
  /// The connector between two steps is what carries the sense of progress, and
  /// it used to be drawn in the same faint grey the whole way down however far
  /// the ride had got — so the stepper read as empty no matter the status. It
  /// now takes the colour of the step above it, which leaves a filled track
  /// behind the ride and a grey one ahead of it.
  Widget _buildTimeline(TripV2 trip, bool isArabic) {
    final languageCode = Localizations.localeOf(context).languageCode;

    return Column(
      children: List.generate(trip.timeline.length, (index) {
        final step = trip.timeline[index];
        final isLast = index == trip.timeline.length - 1;
        final isReached = step.isCompleted || step.isCurrent;

        final color = step.isCancelled
            ? Colors.red
            : step.isCurrent
            ? const Color(0xFFE4A46B)
            : step.isCompleted
            ? Colors.green
            : Colors.white24;

        // The step below is only behind the ride if it has been reached too;
        // the current step is the head of the track, so the line leaving it is
        // still ahead.
        final nextReached =
            !isLast &&
            (trip.timeline[index + 1].isCompleted ||
                trip.timeline[index + 1].isCurrent ||
                trip.timeline[index + 1].isCancelled);
        final connectorColor = step.isCancelled
            ? Colors.red
            : nextReached
            ? Colors.green
            : Colors.white12;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isReached ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
                if (!isLast)
                  Container(width: 2, height: 32, color: connectorColor),
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
                        color: isReached ? Colors.white : Colors.white38,
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
                          languageCode,
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

  /// A section heading, optionally with a control across from it.
  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ?trailing,
        ],
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

  /// One labelled value inside a card.
  ///
  /// [divided] draws the rule above it, so a card built from a conditional list
  /// of rows never opens or closes on a stray divider.
  Widget _buildRow(
    String label,
    String value,
    IconData icon, {
    bool divided = false,
    Widget? trailing,
  }) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        if (trailing != null) ...[const SizedBox(width: 12), trailing],
      ],
    );

    if (!divided) return row;

    return Column(
      children: [const Divider(color: Colors.white10, height: 24), row],
    );
  }
}
