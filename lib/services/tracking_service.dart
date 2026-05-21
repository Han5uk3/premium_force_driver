import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';

class TrackingService with ChangeNotifier {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _positionStreamController = StreamController<Position>.broadcast();
  Position? _lastPosition;
  Position? get currentPosition => _lastPosition;
  FirebaseDatabase get _database => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://premium-force-default-rtdb.asia-southeast1.firebasedatabase.app',
      );
      

  Stream<Position> get positionStream => _positionStreamController.stream;

  // Store current session info for stop tracking
  String? _currentBookingId;
  bool _isChauffeur = false;
  int _bookedHours = 0; // booked hours for chauffeur trips
  DateTime? _startTime;

  bool get isTracking => _positionStreamSubscription != null;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  Future<void> pauseTracking({String? bookingId}) async {
    final targetId = bookingId ?? _currentBookingId;
    debugPrint('🟠 [TrackingService] Requesting pause for $targetId');
    if (targetId == null || _isPaused) return;
    _isPaused = true;
    await _database
        .ref('bookings/$targetId/tracking_session')
        .update({
          'isPaused': true,
          'pausedAt': ServerValue.timestamp,
        });
    debugPrint('🟠 [TrackingService] Tracking paused for $targetId');
    notifyListeners();
  }

  Future<void> resumeTracking({String? bookingId}) async {
    final targetId = bookingId ?? _currentBookingId;
    debugPrint('🟢 [TrackingService] Requesting resume for $targetId');
    if (targetId == null || !_isPaused) return;
    _isPaused = false;
    await _database
        .ref('bookings/$targetId/tracking_session')
        .update({
          'isPaused': false,
          'resumedAt': ServerValue.timestamp,
        });
    debugPrint('🟢 [TrackingService] Tracking resumed for $targetId');
    notifyListeners();
  }

  /// Ensure location permissions are granted, including background permission.
  ///
  /// Returns [true] if all permissions are granted, [false] otherwise.
  Future<bool> handleLocationPermissions(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        _showErrorDialog(
          context,
          loc.enableLocationServices,
          loc.locationServicesDisabledMessage,
          openLocationSettings: true,
        );
      }
      return false;
    }

    // 2. Check current permission status
    permission = await Geolocator.checkPermission();

    // 3. Handle 'denied' - Request foreground permission first
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // User denied again
        return false;
      }
    }

    // 4. Handle 'deniedForever' - Must go to settings
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        _showErrorDialog(
          context,
          loc.locationBackgroundDisclosureTitle,
          loc.locationPermissionsPermanentlyDenied,
          openAppSettings: true,
        );
      }
      return false;
    }

    // 5. Check for 'always' (background) permission
    if (permission != LocationPermission.always) {
      // For Android 10+ and iOS, we need to explicitly ask for 'Always'
      // First show disclosure
      if (context.mounted) {
        bool? proceed = await _showBackgroundDisclosureDialog(context);
        if (proceed != true) return false;

        // Request 'always' permission
        permission = await Geolocator.requestPermission();
        
        if (permission != LocationPermission.always) {
           // Still not 'always', redirect to settings as a final attempt
           if (context.mounted) {
             _showErrorDialog(
               context,
               loc.locationBackgroundDisclosureTitle,
               loc.locationPermissionAlwaysRequired,
               openAppSettings: true,
             );
           }
           return false;
        }
      }
    }

    return true;
  }

  Future<bool?> _showBackgroundDisclosureDialog(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.locationBackgroundDisclosureTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          loc.locationBackgroundDisclosureMessage,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC0C0C0),
              foregroundColor: Colors.black,
            ),
            child: Text(loc.allowAllTheTime),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(
    BuildContext context,
    String title,
    String message, {
    bool openAppSettings = false,
    bool openLocationSettings = false,
  }) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.ok, style: const TextStyle(color: Colors.grey)),
          ),
          if (openAppSettings || openLocationSettings)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (openLocationSettings) {
                  Geolocator.openLocationSettings();
                } else if (openAppSettings) {
                  Geolocator.openAppSettings();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC0C0C0),
                foregroundColor: Colors.black,
              ),
              child: Text(loc.openSettings),
            ),
        ],
      ),
    );
  }

  /// Start tracking for a booking.
  ///
  /// Writes full metadata to RTDB under:
  ///   `bookings/{bookingId}/tracking_session`
  /// and streams driver location under:
  ///   `bookings/{bookingId}/driver_location`
  ///
  /// For chauffeur bookings, also stores [startTime] in RTDB.
  Future<void> startTracking({
    required String bookingId,
    required String customerId,
    required String driverId,
    required bool isChauffeur,
    int bookedHours = 0, // booked chauffeur hours (0 if not chauffeur)
  }) async {
    // Stop any existing stream first
    stopTracking();

    // Save session info
    _currentBookingId = bookingId;
    _isChauffeur = isChauffeur;
    _bookedHours = isChauffeur ? bookedHours : 0;
    _startTime = DateTime.now();
    _isPaused = false;

    // Write session metadata to RTDB
    final sessionRef = _database.ref('bookings/$bookingId/tracking_session');
    final sessionData = <String, dynamic>{
      'bookingId': bookingId,
      'customerId': customerId,
      'driverId': driverId,
      'isActive': true,
      'isChauffeur': isChauffeur,
      'startTime': _startTime!.toIso8601String(),
      'startedAt': ServerValue.timestamp,
    };
    debugPrint('🚀 [TrackingService] Initiating tracking for Booking ID: $bookingId');
    debugPrint('📦 [TrackingService] Initial session metadata: $sessionData');
    await sessionRef.set(sessionData);
    debugPrint('✅ [TrackingService] Tracking session successfully registered in Realtime Database.');
    notifyListeners();

    // Configure location settings
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _updateLocationInFirebase(bookingId, position);
      if (!_positionStreamController.isClosed) {
        _positionStreamController.add(position);
      }
    });
  }

  /// Stop tracking. For chauffeur bookings, writes [stopTime] and [tripDuration] to RTDB.
  Future<int> stopTracking() async {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    if (_currentBookingId == null) return 0;

    final bookingId = _currentBookingId!;
    final stopTime = DateTime.now();

    int extraHours = 0;

    // Mark session inactive in RTDB
    try {
      final sessionRef = _database.ref('bookings/$bookingId/tracking_session');
      final updateData = <String, dynamic>{
        'isActive': false,
        'stopTime': stopTime.toIso8601String(),
        'stoppedAt': ServerValue.timestamp,
      };

      if (_isChauffeur && _startTime != null) {
        final durationSeconds = stopTime.difference(_startTime!).inSeconds;
        updateData['tripDurationSeconds'] = durationSeconds;

        // Calculate extra hours: actual hours – booked hours, rounded
        // e.g. 1.56 extra → 2 h, 1.48 extra → 1 h (standard round)
        final actualHoursDecimal = durationSeconds / 3600.0;
        
        if (_bookedHours > 0 && actualHoursDecimal > _bookedHours) {
          final overDecimal = actualHoursDecimal - _bookedHours;
          extraHours = overDecimal.round(); // ≥0.5 → up, <0.5 → down
          if (extraHours > 0) {
            updateData['extraHours'] = extraHours;
            debugPrint('⏱️ Extra hours over booked: $extraHours');
          }
        }

        debugPrint('⏱️ Chauffeur trip — booked: ${_bookedHours}h, actual: ${actualHoursDecimal.toStringAsFixed(2)}h, extra: ${extraHours}h');
      }

      await sessionRef.update(updateData);
    } catch (e) {
      debugPrint('Error updating tracking session on stop: $e');
    }

    _currentBookingId = null;
    _isChauffeur = false;
    _bookedHours = 0;
    _startTime = null;
    _isPaused = false;
    notifyListeners();

    return extraHours;
  }

  void _updateLocationInFirebase(String bookingId, Position position) {
    _lastPosition = position;
    if (_isPaused) return;
    debugPrint(
      '📡 [TrackingService] Sending location update: ${position.latitude}, ${position.longitude}',
    );
    _database.ref('bookings/$bookingId/driver_location').set({
      'lat': position.latitude,
      'lng': position.longitude,
      'timestamp': ServerValue.timestamp,
    }).then((_) {
      debugPrint('📍 [TrackingService] Driver location successfully synced to Firebase');
    }).catchError((error) {
      debugPrint('❌ [TrackingService] Error updating location in Firebase: $error');
    });
  }
}
