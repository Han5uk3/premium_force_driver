// `intl` exports its own TextDirection, so the framework's is aliased to keep
// the booking reference laid out left-to-right inside an Arabic screen.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:premium_force_driver/common_widgets/riyal_symbol.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';
import 'package:premium_force_driver/trips/trip_status_style.dart';

/// One trip in the driver's list.
///
/// Deliberately read-only: every state change happens on the detail screen,
/// where the driver can see who they are collecting and from where before they
/// advance the ride. The card carries [onTap] and, when the trip is actionable,
/// [onAction] for the single next step.
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
    final languageCode = Localizations.localeOf(context).languageCode;

    final pickupAt = trip.pickupDateTime?.toLocal();
    final dateStr = pickupAt == null
        ? '—'
        : DateFormat('dd MMM, yyyy', languageCode).format(pickupAt);
    final timeStr = pickupAt == null
        ? '—'
        : DateFormat('h:mm a', languageCode).format(pickupAt);

    final actionLabel = onAction == null ? null : trip.status.actionLabel(loc);

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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trip.isChauffeur ? loc.chauffeur : loc.serviceType,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$dateStr  ·  $timeStr',
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
                  ] else if ((trip.route?.durationHours ?? 0) > 0) ...[
                    const SizedBox(height: 8),
                    _locationRow(
                      icon: Icons.timer_outlined,
                      color: Colors.white38,
                      label: loc.duration,
                      value: '${trip.route!.durationHours} ${loc.hrs}',
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
                      TripFare(amount: trip.pricing?.payable ?? 0),
                    ],
                  ),

                  if (actionLabel != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isUpdating ? null : onAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: trip.status.color,
                          disabledBackgroundColor: trip.status.color.withAlpha(
                            120,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isUpdating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                actionLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
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
/// Used wherever the driver sees money — the trip list, the detail screen's
/// payment summary and the extras it collected — so the symbol, spacing and
/// rounding stay identical across all of them.
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
