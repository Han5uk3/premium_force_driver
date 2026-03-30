import 'package:flutter/material.dart';
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
  final double? rating;
  final String? reviewText;

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
    this.rating,
    this.reviewText,
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
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            type,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        type,
                        style: TextStyle(
                          fontSize: 14,
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 4),
                Image.asset(
                  "assets/icons/pixel_arrow.png",
                  height: 30,
                  width: 30,
                  fit: BoxFit.contain,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildContainerText(false, true, loc),
                      SizedBox(height: 8),
                      Text(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        dropoff,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
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
                          fontSize: 12,
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
                          fontSize: 12,
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
                        "$ride - $brand",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Divider(color: Color(0xFF505050), height: 5),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      loc.passengers,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),

                    Text(
                      "$passengers",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
              ],
            ),
            if (rating != null && (status.toLowerCase().trim() == 'completed' || status.toLowerCase().trim() == 'c')) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Customer Review",
                            style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
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
                            fontSize: 12,
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
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (status == 'P') // Pending - show Accept and Reject
                      ..._buildPendingActions(loc)
                    else if (status == 'AC') // Accepted - show Start Tracking
                      ..._buildAcceptedActions(loc)
                    else if (status == 'starttracking') // Tracking
                      ...(isChauffeur
                          ? _buildChauffeurTrackingActions(loc)
                          : _buildTrackingActions(loc))
                    else if (status == 'OG') // Ongoing - show Complete
                      ..._buildOngoingActions(loc),
                  ],
                ),
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
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  String getStatusText(String status, AppLocalizations loc) {
    switch (status) {
      case "Completed":
      case "C":
      case "c":
        return loc.completed;
      case "Pending":
      case "P":
      case "p":
        return loc.pending;
      case "Cancelled":
      case "CA":
      case "X":
      case "x":
        return loc.cancelled;
      case "Accepted":
      case "AC":
        return "Accepted"; // Replace with loc.accepted if available
      case "Ongoing":
      case "OG":
        return "Ongoing";
      case "starttracking":
        return "Tracking";
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

  Color getColorByStatus(String status) {
    switch (status) {
      case "Completed":
      case "C":
      case "c":
        return Colors.green;
      case "Pending":
      case "P":
      case "p":
        return Colors.orange;
      case "Accepted":
      case "AC":
        return Colors.blue;
      case "Ongoing":
      case "OG":
        return Colors.indigo;
      case "starttracking":
        return Colors.teal;
      case "Cancelled":
      case "CA":
      case "X":
      case "x":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool _shouldShowActions() {
    return bookingId != null &&
        (status == 'P' || status == 'AC' || status == 'OG' || status == 'starttracking');
  }

  List<Widget> _buildPendingActions(AppLocalizations loc) {
    return [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: onReject,
          icon: const Icon(Icons.close, size: 16),
          label: Text(loc.reject),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: onAccept,
          icon: const Icon(Icons.check, size: 16),
          label: Text(loc.accept),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildAcceptedActions(AppLocalizations loc) {
    return [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: onStartTracking,
          icon: const Icon(Icons.location_searching, size: 16),
          label: Text(loc.startTracking),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildTrackingActions(AppLocalizations loc) {
    return [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: onGetDirections,
          icon: const Icon(Icons.directions, size: 16),
          label: Text(loc.getDirections),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: onComplete,
          icon: const Icon(Icons.stop_circle, size: 16),
          label: Text(loc.stopTracking),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    ];
  }

  /// Chauffeur in starttracking: driver navigates to pickup, timer is running.
  /// Show "Get Directions" + "Stop Tracking" (which also saves timing data).
  List<Widget> _buildChauffeurTrackingActions(AppLocalizations loc) {
    return [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: onGetDirections,
          icon: const Icon(Icons.directions, size: 16),
          label: Text(loc.getDirections),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: onStopTracking,
          icon: const Icon(Icons.stop_circle, size: 16),
          label: Text(loc.stopTracking),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildOngoingActions(AppLocalizations loc) {
    return [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: onComplete,
          icon: const Icon(Icons.check_circle, size: 16),
          label: Text(loc.complete),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    ];
  }
}
