// `intl` exports its own TextDirection, so the framework's is aliased to keep
// the booking reference laid out left-to-right inside an Arabic screen.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:premium_force_driver/common_widgets/riyal_symbol.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';
import 'package:premium_force_driver/trips/trip_controls.dart';
import 'package:premium_force_driver/trips/trip_status_style.dart';
import 'package:premium_force_driver/utils/trip_display.dart';

/// One trip in the driver's list.
///
/// Tapping opens the detail screen; the controls under the customer's name drive
/// the ride from here, so a driver moving between pickups does not have to open
/// a ride to say they have arrived. Both surfaces go through [TripControls], so
/// the guards and the wording are the same either way.
///
/// The fare is deliberately absent: the driver collects nothing at the kerb
/// except the extras they record on completion, and the card is read over a
/// shoulder often enough that the ride's price does not belong on it.
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
    this.onAction,
    this.isUpdating = false,
  });

  final TripV2 trip;
  final VoidCallback onTap;

  /// Advance the trip one step. Omitted on lists where acting makes no sense
  /// (completed trips), and ignored while [isUpdating].
  final VoidCallback? onAction;

  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final pickup = formatTripPickup(context, trip);
    final durationLabel = tripDurationLabel(loc, trip);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status strip, so the stage of the ride reads at a glance while
            // scrolling.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: trip.status.color.withAlpha(45),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: trip.status.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.status.label(loc),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Text(
                      trip.bookingNumber,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The product, not the name of the field — an arrival, a
                  // departure, hourly hire or a private transfer.
                  Text(
                    tripServiceLabel(loc, trip),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // The pickup the ride was booked for. Given its own line
                  // rather than squeezed beside the service, so a long date and
                  // a translated product name cannot crowd each other out.
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        pickup.date,
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time_outlined,
                        size: 12,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        pickup.time,
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _locationRow(
                    icon: Icons.trip_origin,
                    color: const Color(0xFFE4A46B),
                    label: loc.pickup,
                    value: trip.pickupAddress ?? '—',
                  ),
                  if (trip.dropOffAddress != null) ...[
                    const SizedBox(height: 8),
                    _locationRow(
                      icon: Icons.place_outlined,
                      color: Colors.white38,
                      label: loc.dropoff,
                      value: trip.dropOffAddress!,
                    ),
                  ] else if (durationLabel != null) ...[
                    const SizedBox(height: 8),
                    _locationRow(
                      icon: Icons.timer_outlined,
                      color: Colors.white38,
                      label: loc.duration,
                      value: durationLabel,
                    ),
                  ],

                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          trip.customer?.name ?? loc.customer,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${trip.passengersCount}',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.groups_outlined,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),

                  if (onAction != null) ...[
                    const SizedBox(height: 14),
                    TripControls(
                      trip: trip,
                      onAdvance: onAction!,
                      isUpdating: isUpdating,
                      isCompact: true,
                    ),
                  ],

                  if (trip.isRated) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFE4A46B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trip.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (trip.reviewText?.trim().isNotEmpty ?? false) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              trip.reviewText!,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// An amount with the Saudi riyal symbol, formatted to two decimals.
///
/// Used wherever the driver sees money — the detail screen's payment summary
/// and the extras it collected — so the symbol, spacing and rounding stay
/// identical across all of them. The trip card no longer shows a fare.
class TripFare extends StatelessWidget {
  const TripFare({
    super.key,
    required this.amount,
    this.color = Colors.white,
    this.fontSize = 12,
    this.fontWeight = FontWeight.bold,
  });

  final double amount;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RiyalSymbol(color: color, size: fontSize),
        const SizedBox(width: 4),
        Text(
          amount.toStringAsFixed(2),
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        ),
      ],
    );
  }
}
