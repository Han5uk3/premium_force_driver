import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:premium_force_driver/api/apis.dart';

class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _positionStreamController = StreamController<Position>.broadcast();
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final ApiService _apiService = ApiService();

  Stream<Position> get positionStream => _positionStreamController.stream;

  // Store current session info for stop tracking
  String? _currentBookingId;
  bool _isChauffeur = false;
  int _bookedHours = 0; // booked hours for chauffeur trips
  DateTime? _startTime;

  bool get isTracking => _positionStreamSubscription != null;

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
    // Check permissions
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied');
      return;
    }

    // Stop any existing stream first
    stopTracking(saveToBackend: false);

    // Save session info
    _currentBookingId = bookingId;
    _isChauffeur = isChauffeur;
    _bookedHours = isChauffeur ? bookedHours : 0;
    _startTime = DateTime.now();

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
    await sessionRef.set(sessionData);
    debugPrint('📍 Tracking session started for booking $bookingId');

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

  /// Stop tracking. For chauffeur bookings, writes [stopTime] and [tripDuration]
  /// to RTDB and — if [saveToBackend] is true — also sends to the REST API.
  Future<int> stopTracking({bool saveToBackend = true}) async {
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

        // Persist times to the backend if requested
        if (saveToBackend) {
          _saveChauffeurTripTimes(
            bookingId: bookingId,
            startTime: _startTime!,
            stopTime: stopTime,
            durationSeconds: durationSeconds,
            extraHours: extraHours,
          );
        }
      }

      await sessionRef.update(updateData);
    } catch (e) {
      debugPrint('Error updating tracking session on stop: $e');
    }

    _currentBookingId = null;
    _isChauffeur = false;
    _bookedHours = 0;
    _startTime = null;

    return extraHours;
  }

  /// Save chauffeur trip timing data to backend.
  void _saveChauffeurTripTimes({
    required String bookingId,
    required DateTime startTime,
    required DateTime stopTime,
    required int durationSeconds,
    int extraHours = 0,
  }) {
    _apiService
        .saveChauffeurTripTimes(
          bookingId: bookingId,
          startTime: startTime.toIso8601String(),
          stopTime: stopTime.toIso8601String(),
          tripDurationSeconds: durationSeconds,
          extraHours: extraHours,
        )
        .then((_) {
          debugPrint('✅ Chauffeur trip times saved to backend');
        })
        .catchError((e) {
          debugPrint('❌ Failed to save chauffeur trip times: $e');
        });
  }

  void _updateLocationInFirebase(String bookingId, Position position) {
    _database.ref('bookings/$bookingId/driver_location').set({
      'lat': position.latitude,
      'lng': position.longitude,
      'timestamp': ServerValue.timestamp,
    }).then((_) {
      debugPrint(
        '📍 Location updated for $bookingId: ${position.latitude}, ${position.longitude}',
      );
    }).catchError((error) {
      debugPrint('Error updating location: $error');
    });
  }
}
