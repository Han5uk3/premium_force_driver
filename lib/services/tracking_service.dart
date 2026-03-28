import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  void startTracking(String bookingId) async {
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

    // Configure location settings
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    // Stop existing stream if any
    stopTracking();

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _updateLocationInFirebase(bookingId, position);
    });
  }

  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  void _updateLocationInFirebase(String bookingId, Position position) {
    _database.ref('bookings/$bookingId/driver_location').set({
      'lat': position.latitude,
      'lng': position.longitude,
      'timestamp': ServerValue.timestamp,
    }).then((_) {
      debugPrint('Location updated for $bookingId: ${position.latitude}, ${position.longitude}');
    }).catchError((error) {
      debugPrint('Error updating location: $error');
    });
  }
}
