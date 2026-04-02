import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/models/booking.dart';
import 'package:premium_force_driver/providers/bookings_provider.dart';
import 'package:premium_force_driver/common_widgets/snackbar.dart';
import 'package:premium_force_driver/common_widgets/voice_player.dart';
import 'package:premium_force_driver/services/tracking_service.dart';
import 'package:geolocator/geolocator.dart';

class BookingDetailsPage extends StatefulWidget {
  final BookingModel booking;
  const BookingDetailsPage({super.key, required this.booking});

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  late BookingModel _currentBooking;

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
  }

  void _updateBooking(BookingModel? updated) {
    if (updated != null && mounted) {
      setState(() {
        _currentBooking = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final dateFormat = DateFormat('dd MMM, yyyy');
    final timeFormat = DateFormat('h:mm a');

    final displayDateTime =
        (_currentBooking.pickupdatetime != null &&
            _currentBooking.pickupdatetime!.isNotEmpty)
        ? DateTime.tryParse(_currentBooking.pickupdatetime!)
        : (_currentBooking.arrival != null &&
              _currentBooking.arrival!.isNotEmpty)
        ? DateTime.tryParse(_currentBooking.arrival!)
        : _currentBooking.createdAt;

    final effectiveDateTime = displayDateTime ?? _currentBooking.createdAt;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          loc.bookingInfo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Badge
            Center(child: _buildStatusBadge(_currentBooking.status, loc)),
            const SizedBox(height: 24),

            // Main Info Card
            _buildSectionCard(
              child: Column(
                children: [
                  _buildDetailRow(
                    loc.service,
                    _currentBooking.rideType,
                    Icons.drive_eta,
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  _buildDetailRow(
                    loc.passengers,
                    _currentBooking.passengerCount.toString(),
                    Icons.groups_outlined,
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  _buildDetailRow(
                    loc.pickup,
                    _currentBooking.pickupLocation,
                    Icons.location_on,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    loc.dropoff,
                    _currentBooking.dropoffLocation,
                    Icons.location_on,
                    color: Colors.red,
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailRow(
                          loc.date,
                          dateFormat.format(effectiveDateTime),
                          Icons.calendar_today,
                        ),
                      ),
                      Expanded(
                        child: _buildDetailRow(
                          loc.time,
                          timeFormat.format(effectiveDateTime),
                          Icons.access_time,
                        ),
                      ),
                    ],
                  ),
                  if ((_currentBooking.specialRequestText != null &&
                          _currentBooking.specialRequestText!.isNotEmpty) ||
                      (_currentBooking.specialRequestAudio != null &&
                          _currentBooking.specialRequestAudio!.isNotEmpty)) ...[
                    const Divider(color: Colors.white10, height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.notes,
                              color: Color(0xFFE4A46B),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              loc.specialRequests,
                              style: const TextStyle(
                                color: Color(0xFFE4A46B),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_currentBooking.specialRequestText != null &&
                            _currentBooking.specialRequestText!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _currentBooking.specialRequestText!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        if (_currentBooking.specialRequestAudio != null &&
                            _currentBooking.specialRequestAudio!.isNotEmpty)
                          VoicePlayer(
                            audioUrl: _currentBooking.specialRequestAudio!,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Customer Info
            if (_currentBooking.customer != null) ...[
              _buildSectionTitle(loc.customerInfo),
              _buildSectionCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundImage:
                          _currentBooking.customer!.profileImageUrl != null
                          ? NetworkImage(
                              _currentBooking.customer!.profileImageUrl!,
                            )
                          : null,
                      child: _currentBooking.customer!.profileImageUrl == null
                          ? const Icon(Icons.person, color: Colors.white54)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentBooking.customer!.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${_currentBooking.customer!.countryCode} ${_currentBooking.customer!.phoneNumber}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _makePhoneCall(
                        _currentBooking.customer!.countryCode +
                            _currentBooking.customer!.phoneNumber,
                      ),
                      icon: const Icon(Icons.phone, color: Color(0xFFE4A46B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Actions
            _buildActions(context, loc),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, AppLocalizations loc) {
    Color color;
    String text;
    status = status.toLowerCase().trim();

    switch (status) {
      case "p":
      case "pending":
        color = Colors.orange;
        text = loc.pending;
        break;
      case "ac":
      case "accepted":
      case "assigned":
        color = Colors.blue;
        text = loc.assigned;
        break;
      case "og":
      case "ongoing":
        color = Colors.indigo;
        text = loc.ongoing;
        break;
      case "starttracking":
        color = Colors.teal;
        text = loc.tracking;
        break;
      case "c":
      case "completed":
        color = Colors.green;
        text = loc.completed;
        break;
      case "ca":
      case "cancelled":
      case "x":
        color = Colors.red;
        text = loc.cancelled;
        break;
      default:
        color = Colors.grey;
        text = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: child,
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color ?? Colors.white54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isHighlight = false,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isHighlight ? const Color(0xFFE4A46B) : Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isHighlight ? const Color(0xFFE4A46B) : Colors.white,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, AppLocalizations loc) {
    final status = _currentBooking.status.toLowerCase().trim();
    final provider = context.read<BookingsProvider>();

    if (status == 'p' || status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: _buildActionButton(loc.reject, Colors.red, () async {
              final confirm = await _showConfirmationDialog(
                context,
                loc.rejectBooking,
                loc.rejectBookingConfirm,
              );
              if (confirm != true) return;
              final success = await provider.rejectBooking(_currentBooking.id);
              if (success && mounted) {
                AnimatedSnackBar.show(
                  context,
                  provider.actionMessage ?? loc.bookingRejected,
                  'E',
                );
                Navigator.pop(context);
              }
            }),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(loc.accept, Colors.green, () async {
              final confirm = await _showConfirmationDialog(
                context,
                loc.acceptBooking,
                loc.acceptBookingConfirm,
              );
              if (confirm != true) return;
              final success = await provider.acceptBooking(_currentBooking.id);
              if (success && mounted) {
                AnimatedSnackBar.show(
                  context,
                  provider.actionMessage ?? loc.bookingAccepted,
                  'S',
                );
                _updateBooking(provider.getBookingById(_currentBooking.id));
              }
            }),
          ),
        ],
      );
    }

    if (status == 'ac' || status == 'accepted' || status == 'assigned') {
      return _buildActionButton(loc.startTracking, Colors.blue, () async {
        final confirm = await _showConfirmationDialog(
          context,
          loc.startTracking,
          loc.startTrackingConfirm,
        );
        if (confirm != true) return;

        // Check for location permissions (foreground & background)
        final hasPermissions =
            await TrackingService().handleLocationPermissions(context);
        if (!hasPermissions) return;

        final success = await provider.startTracking(_currentBooking.id);
        if (success && mounted) {
          await TrackingService().startTracking(
            bookingId: _currentBooking.id,
            customerId: _currentBooking.customerId,
            driverId: _currentBooking.driverId ?? '',
            isChauffeur: _currentBooking.isHourly,
            bookedHours: _currentBooking.estimatedDuration,
          );
          AnimatedSnackBar.show(
            context,
            provider.actionMessage ?? loc.trackingStarted,
            'S',
          );
          _updateBooking(provider.getBookingById(_currentBooking.id));
          _openMaps();
        }
      });
    }

    if (status == 'starttracking') {
      return Column(
        children: [
          _buildActionButton(
            loc.getDirections,
            Colors.orange.shade800,
            _openMaps,
            icon: Icons.directions,
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: TrackingService(),
            builder: (context, _) {
              return _buildActionButton(
                TrackingService().isPaused ? loc.resumeTracking : loc.pauseTracking,
                TrackingService().isPaused ? Colors.green.shade700 : Colors.orange.shade700,
                () async {
                  if (TrackingService().isPaused) {
                    await TrackingService().resumeTracking(
                      bookingId: _currentBooking.id,
                    );
                  } else {
                    await TrackingService().pauseTracking(
                      bookingId: _currentBooking.id,
                    );
                  }
                  if (mounted) {
                    AnimatedSnackBar.show(
                      context,
                      TrackingService().isPaused ? loc.trackingPaused : loc.trackingResumed,
                      'S',
                    );
                  }
                },
                icon: TrackingService().isPaused ? Icons.play_arrow : Icons.pause,
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<Position>(
            stream: TrackingService().positionStream,
            builder: (context, snapshot) {
              bool canStop = false;
              if (_currentBooking.dropoffLatitude != 0 && snapshot.hasData) {
                final pos = snapshot.data!;
                final distance = Geolocator.distanceBetween(
                  pos.latitude,
                  pos.longitude,
                  _currentBooking.dropoffLatitude,
                  _currentBooking.dropoffLongitude,
                );
                if (distance <= 500) canStop = true;
              } else if (_currentBooking.dropoffLatitude == 0 ||
                  _currentBooking.isHourly) {
                canStop = true;
              }

              return _buildActionButton(
                loc.stopTracking,
                Colors.red,
                canStop
                    ? () async {
                        final confirm = await _showConfirmationDialog(
                          context,
                          loc.stopTracking,
                          loc.stopTrackingConfirm,
                        );
                        if (confirm != true) return;
                        if (_currentBooking.isHourly) {
                          final success = await provider.stopTracking(
                            _currentBooking.id,
                          );
                          if (mounted) {
                            AnimatedSnackBar.show(
                              context,
                              success
                                  ? (provider.actionMessage ?? loc.tripEnded)
                                  : loc.trackingStoppedSyncPending,
                              success ? 'S' : 'E',
                            );
                            _updateBooking(
                              provider.getBookingById(_currentBooking.id),
                            );
                          }
                        } else {
                          await TrackingService().stopTracking();
                          final success = await provider.completeBooking(
                            _currentBooking.id,
                          );
                          if (success && mounted) {
                            AnimatedSnackBar.show(
                              context,
                              provider.actionMessage ?? loc.bookingCompleted,
                              'S',
                            );
                            _updateBooking(
                              provider.getBookingById(_currentBooking.id),
                            );
                          }
                        }
                      }
                    : null,
                icon: Icons.stop_circle,
              );
            },
          ),
        ],
      );
    }

    if (status == 'og' || status == 'ongoing') {
      return _buildActionButton(loc.complete, Colors.blue, () async {
        final confirm = await _showConfirmationDialog(
          context,
          loc.completeBooking,
          loc.completeBookingConfirm,
        );
        if (confirm != true) return;
        final success = await provider.completeBooking(_currentBooking.id);
        if (success && mounted) {
          AnimatedSnackBar.show(
            context,
            provider.actionMessage ?? loc.bookingCompleted,
            'S',
          );
          _updateBooking(provider.getBookingById(_currentBooking.id));
        }
      }, icon: Icons.check_circle);
    }

    return const SizedBox.shrink();
  }

  Widget _buildActionButton(
    String label,
    Color color,
    VoidCallback? onPressed, {
    IconData? icon,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade800,
        disabledForegroundColor: Colors.white24,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _openMaps() async {
    final loc = AppLocalizations.of(context)!;
    final pickupLat = _currentBooking.pickupLatitude;
    final pickupLong = _currentBooking.pickupLongitude;
    final dropoffLat = _currentBooking.dropoffLatitude;
    final dropoffLong = _currentBooking.dropoffLongitude;

    final currentPos = TrackingService().currentPosition;
    final origin = currentPos != null
        ? '${currentPos.latitude},${currentPos.longitude}'
        : 'Current+Location';

    String url;
    if (_currentBooking.isHourly || dropoffLat == 0) {
      url =
          "https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$pickupLat,$pickupLong";
    } else {
      url =
          "https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$dropoffLat,$dropoffLong&waypoints=$pickupLat,$pickupLong";
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        AnimatedSnackBar.show(context, loc.couldNotLaunchMaps, 'E');
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
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
