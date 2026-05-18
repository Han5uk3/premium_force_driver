import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:premium_force_driver/services/tracking_service.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';

class Bookingcard extends StatelessWidget {
  final String status;
  final String type;
  final String pickup;
  final String dropoff;
  final String date;
  final String time;
  final String ride;
  final String brand;
  final int passengers;
  final bool isFromReviewAndConfirm;
  final bool isChauffeur;
  final String? bookingId;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onComplete;
  final VoidCallback? onStartTracking;
  final VoidCallback? onStopTracking;
  final VoidCallback? onGetDirections;
  final VoidCallback? onPauseTracking;
  final VoidCallback? onResumeTracking;
  final double? rating;
  final String? reviewText;
  final bool isToday;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final double? pickupLatitude;
  final double? pickupLongitude;

  const Bookingcard({
    super.key,
    this.passengers = 1,
    this.isFromReviewAndConfirm = false,
    this.isChauffeur = false,
    required this.status,
    required this.type,
    required this.pickup,
    required this.dropoff,
    required this.date,
    required this.time,
    required this.ride,
    required this.brand,
    this.bookingId,
    this.onAccept,
    this.onReject,
    this.onComplete,
    this.onStartTracking,
    this.onStopTracking,
    this.onGetDirections,
    this.onPauseTracking,
    this.onResumeTracking,
    this.rating,
    this.reviewText,
    this.isToday = true,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.pickupLatitude,
    this.pickupLongitude,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFromReviewAndConfirm
              ? [Color(0xFF505050), Color(0xFF303030)]
              : [Color(0xFF666666), Color(0xFFC0C0C0), Color(0xFF666666)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),

        width: MediaQuery.of(context).size.width,
        child: Column(
          spacing: 10,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                isFromReviewAndConfirm
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.service,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            type,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        type,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                !isFromReviewAndConfirm
                    ? buildContainerText(true, false, loc)
                    : SizedBox.shrink(),
              ],
            ),

            isFromReviewAndConfirm
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [Divider(color: Color(0xFF505050), height: 5)],
                  )
                : SizedBox.shrink(),

            Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildContainerText(true, true, loc),
                      SizedBox(height: 8),
                      Text(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        pickup,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isChauffeur) ...[
                  const SizedBox(width: 4),
                  Image.asset(
                    "assets/icons/pixel_arrow.png",
                    height: 30,
                    width: 30,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildContainerText(false, true, loc),
                        const SizedBox(height: 8),
                        Text(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          dropoff,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            !isFromReviewAndConfirm ? Divider(color: Colors.white) : SizedBox(),

            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Color(0xFF404040),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 5),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(height: 20, width: 1, color: Colors.white),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 5),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(height: 20, width: 1, color: Colors.white),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.drive_eta_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 5),
                      Text(
                        ride,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),

            if (rating != null &&
                (status.toLowerCase().trim() == 'completed' ||
                    status.toLowerCase().trim() == 'c')) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(13),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withAlpha(77)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            loc.customerReview,
                            style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < rating!.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 14,
                              );
                            }),
                          ),
                        ],
                      ),
                      if (reviewText != null && reviewText!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          reviewText!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            // Action buttons based on status
            if (!isFromReviewAndConfirm && _shouldShowActions())
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (status.toLowerCase() == 'p' ||
                      status.toLowerCase() == 'pending')
                    ..._buildPendingActions(loc)
                  else if (status.toLowerCase() == 'ac' ||
                      status.toLowerCase() == 'accepted' ||
                      status.toLowerCase() == 'assigned')
                    ..._buildAcceptedActions(loc)
                  else if (status.toLowerCase() == 'starttracking' ||
                      status.toLowerCase() == 'started')
                    ...(isChauffeur
                        ? _buildChauffeurTrackingActions(loc)
                        : _buildTrackingActions(loc))
                  else if (status.toLowerCase() == 'og' ||
                      status.toLowerCase() == 'ongoing')
                    ..._buildOngoingActions(loc),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget buildContainerText(bool isPickup, bool isGrey, AppLocalizations loc) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isGrey ? Color(0xFF505050) : getColorByStatus(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isGrey
            ? isPickup
                  ? loc.pickup
                  : loc.dropoff
            : getStatusText(status, loc),
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  String getStatusText(String statusLocal, AppLocalizations loc) {
    statusLocal = statusLocal.toLowerCase().trim();
    switch (statusLocal) {
      case "completed":
      case "c":
        return loc.completed;
      case "pending":
      case "p":
        return loc.pending;
      case "cancelled":
      case "ca":
      case "x":
        return loc.cancelled;
      case "assigned":
      case "ac":
        return loc.assigned;
      case "paymentpending":
        return loc.paymentPending;
      case "reviewed":
        return loc.reviewed;
      case "ongoing":
      case "og":
        return loc.ongoing;
      case "starttracking":
      case "started":
        return loc.tracking;
      case "q":
      case "Q":
        return loc.pickup;
      case "w":
      case "W":
        return loc.dropoff;
      default:
        return status; // Return the raw status if unknown, better for debugging
    }
  }

  Color getColorByStatus(String statusLocal) {
    statusLocal = statusLocal.toLowerCase().trim();
    switch (statusLocal) {
      case "completed":
      case "c":
        return Colors.green;
      case "pending":
      case "p":
        return Colors.orange;
      case "assigned":
      case "ac":
        return Colors.blue;
      case "ongoing":
      case "og":
        return Colors.indigo;
      case "starttracking":
      case "started":
        return Colors.teal;
      case "paymentpending":
        return Colors.amber;
      case "reviewed":
        return Colors.purple;
      case "cancelled":
      case "ca":
      case "x":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool _shouldShowActions() {
    final s = status.toLowerCase().trim();
    return bookingId != null &&
        (s == 'pending' ||
            s == 'p' ||
            s == 'assigned' ||
            s == 'ac' ||
            s == 'accepted' ||
            s == 'starttracking' ||
            s == 'started' ||
            s == 'ongoing' ||
            s == 'og');
  }

  List<Widget> _buildPendingActions(AppLocalizations loc) {
    return [
      Expanded(
        child: ElevatedButton(
          onPressed: onReject,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(loc.reject, style: const TextStyle(fontSize: 10)),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ElevatedButton(
          onPressed: onAccept,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(loc.accept, style: const TextStyle(fontSize: 10)),
        ),
      ),
    ];
  }

  List<Widget> _buildAcceptedActions(AppLocalizations loc) {
    if (!isToday) {
      return [
        Expanded(
          child: Center(
            child: Text(
              loc.startRideAvailableOnDate,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ),
      ];
    }
    return [
      Expanded(
        child: ElevatedButton(
          onPressed: onStartTracking,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(loc.startRide, style: const TextStyle(fontSize: 10)),
        ),
      ),
    ];
  }

  List<Widget> _buildTrackingActions(AppLocalizations loc) {
    return [
      Expanded(
        child: ElevatedButton(
          onPressed: onGetDirections,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(loc.directions, style: const TextStyle(fontSize: 10)),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ListenableBuilder(
          listenable: TrackingService(),
          builder: (context, child) {
            return ElevatedButton(
              onPressed: TrackingService().isPaused
                  ? onResumeTracking
                  : onPauseTracking,
              style: ElevatedButton.styleFrom(
                backgroundColor: TrackingService().isPaused
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                TrackingService().isPaused ? loc.resumeRide : loc.pauseRide,
                style: const TextStyle(fontSize: 10),
              ),
            );
          },
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: StreamBuilder<Position>(
          stream: TrackingService().positionStream,
          builder: (context, snapshot) {
            bool canStop = false;
            if (dropoffLatitude != null &&
                dropoffLongitude != null &&
                snapshot.hasData) {
              final pos = snapshot.data!;
              final distance = Geolocator.distanceBetween(
                pos.latitude,
                pos.longitude,
                dropoffLatitude!,
                dropoffLongitude!,
              );
              if (distance <= 100) {
                // 100 meters threshold
                canStop = true;
              }
            } else if (dropoffLatitude == null) {
              canStop = true; // fallback
            }

            if (!canStop) {
              return ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(loc.endRide, style: const TextStyle(fontSize: 10)),
              );
            }

            return ElevatedButton(
              onPressed: onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(loc.endRide, style: const TextStyle(fontSize: 10)),
            );
          },
        ),
      ),
    ];
  }

  /// Chauffeur in starttracking: driver navigates to pickup, timer is running.
  /// Show "Get Directions" + "Stop Tracking" (which also saves timing data).
  List<Widget> _buildChauffeurTrackingActions(AppLocalizations loc) {
    return [
      Expanded(
        child: ElevatedButton(
          onPressed: onGetDirections,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(loc.getDirections, style: const TextStyle(fontSize: 10)),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ListenableBuilder(
          listenable: TrackingService(),
          builder: (context, child) {
            return ElevatedButton(
              onPressed: TrackingService().isPaused
                  ? onResumeTracking
                  : onPauseTracking,
              style: ElevatedButton.styleFrom(
                backgroundColor: TrackingService().isPaused
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                TrackingService().isPaused ? loc.resumeRide : loc.pauseRide,
                style: const TextStyle(fontSize: 10),
              ),
            );
          },
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: StreamBuilder<Position>(
          stream: TrackingService().positionStream,
          builder: (context, snapshot) {
            bool canStop = false;
            if (pickupLatitude != null &&
                pickupLongitude != null &&
                snapshot.hasData) {
              final pos = snapshot.data!;
              final distance = Geolocator.distanceBetween(
                pos.latitude,
                pos.longitude,
                pickupLatitude!,
                pickupLongitude!,
              );
              if (distance <= 100) {
                // 100 meters threshold
                canStop = true;
              }
            } else if (pickupLatitude == null) {
              canStop = true; // fallback
            }

            if (!canStop) {
              return ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(loc.endRide, style: const TextStyle(fontSize: 10)),
              );
            }

            return ElevatedButton(
              onPressed: onStopTracking,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(loc.endRide, style: const TextStyle(fontSize: 10)),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _buildOngoingActions(AppLocalizations loc) {
    return [
      Expanded(
        child: ElevatedButton(
          onPressed: onComplete,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(loc.complete, style: const TextStyle(fontSize: 10)),
        ),
      ),
    ];
  }
}
