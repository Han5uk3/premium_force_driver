import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:premium_force_driver/models/v2/trip_service_type.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';
import 'package:premium_force_driver/services/tracking_service.dart';

/// Parsing guards for the shapes `GET /driver/bookings/:id` actually sends.
///
/// Every field checked here was previously read under a key the backend does
/// not use — the populated sub-documents spell their names `airportName` and
/// `cityName`, and the pickup instant arrives as `pickupUTC` — which is why the
/// cards showed a dash where the pickup should have been.
void main() {
  group('TripV2.fromJson', () {
    test('reads an airport arrival off the populated detail payload', () {
      final trip = TripV2.fromJson(
        jsonDecode(_airportArrivalDetail) as Map<String, dynamic>,
      );

      expect(trip.bookingNumber, 'PF-APT-2608-1420');
      expect(trip.status, TripStatusV2.driverAssigned);
      expect(trip.resolvedServiceType, TripServiceType.airportArrival);
      expect(trip.isChauffeur, isFalse);

      // Populated sub-documents, under their own key spellings.
      expect(
        trip.route?.airportName,
        'Prince Mohammad Bin Abdulaziz International Airport',
      );
      expect(trip.route?.terminalName, 'Madinah Airport');
      expect(trip.route?.cityFromName, 'Madinah');
      expect(trip.route?.cityToName, 'Madinah');
      expect(trip.route?.cityFromDisplay(true), 'المدينة المنورة');

      // The pickup, as the card renders it: the wall clock wins over the
      // instant, so it is shown in the pickup city's time and not the device's.
      expect(trip.pickupDisplayInstant, DateTime(2026, 8, 26, 18, 30));
      expect(trip.pickupDateTime?.isUtc, isTrue);
    });

    test('keeps the assigned car separate from the booked class', () {
      final trip = TripV2.fromJson(
        jsonDecode(_airportArrivalDetail) as Map<String, dynamic>,
      );

      expect(trip.vehicle?.label, 'GMC Yukon XL 2025');
      expect(trip.fleet?.licensePlate, '5432-RSA');
      expect(trip.fleet?.label, 'GMC Yukon XL 2024');
      expect(trip.fleet?.colour, 'Black');
    });

    test('falls back to pickupUTC when no wall clock was sent', () {
      final trip = TripV2.fromJson({
        '_id': 'a',
        'bookingNumber': 'PF-1',
        'bookingStatus': 'confirmed',
        'route': {'pickupUTC': '2026-08-10T14:00:00.000Z'},
      });

      expect(
        trip.pickupDisplayInstant,
        DateTime.utc(2026, 8, 10, 14).toLocal(),
      );
    });

    test('recognises hourly hire as chauffeur and keeps its booked hours', () {
      final trip = TripV2.fromJson({
        '_id': 'b',
        'bookingNumber': 'PF-2',
        'bookingStatus': 'driver_assigned',
        'serviceType': 'hourly',
        'route': {'durationHours': 6, 'pickupDate': '2026-08-26'},
      });

      expect(trip.resolvedServiceType, TripServiceType.chauffeur);
      expect(trip.isChauffeur, isTrue);
      expect(trip.durationHours, 6);
      // Hourly hire has no destination, so the card shows the hours instead.
      expect(trip.dropOffAddress, isNull);
    });

    test('leaves durationHours null on a transfer', () {
      final trip = TripV2.fromJson({
        '_id': 'c',
        'bookingNumber': 'PF-3',
        'bookingStatus': 'confirmed',
        'serviceType': 'private_transfer',
        'route': {'durationHours': 0},
      });

      expect(trip.resolvedServiceType, TripServiceType.privateTransfer);
      expect(trip.isChauffeur, isFalse);
      expect(trip.durationHours, isNull);
    });
  });

  group('TripStatusV2.sharesLocation', () {
    test('opens when the driver sets off and closes when the ride ends', () {
      // The approach is the half of the journey the customer waits through, so
      // the feed has to be open before the passenger is aboard.
      expect(TripStatusV2.driverEnRoute.sharesLocation, isTrue);
      expect(TripStatusV2.driverArrived.sharesLocation, isTrue);
      expect(TripStatusV2.tripStarted.sharesLocation, isTrue);

      expect(TripStatusV2.driverAssigned.sharesLocation, isFalse);
      expect(TripStatusV2.confirmed.sharesLocation, isFalse);
      expect(TripStatusV2.completed.sharesLocation, isFalse);
      expect(TripStatusV2.cancelled.sharesLocation, isFalse);
    });

    test('makes going en route the transition that prompts for location', () {
      // TripActions asks for permission whenever the status it is about to send
      // shares location, so this is what puts the prompt before the API call.
      expect(TripStatusV2.driverAssigned.next, TripStatusV2.driverEnRoute);
      expect(TripStatusV2.driverAssigned.next!.sharesLocation, isTrue);
    });
  });

  group('TrackingPhase.of', () {
    TripV2 tripAt(TripStatusV2 status, {bool withDropOff = true}) {
      return TripV2.fromJson({
        '_id': 'p',
        'bookingNumber': 'PF-P',
        'bookingStatus': status.wireValue,
        if (!withDropOff) 'serviceType': 'hourly',
        'route': {
          'pickupLocation': {'lat': 24.71, 'lng': 46.67},
          if (withDropOff)
            'dropOffLocation': {'lat': 24.66, 'lng': 46.62}
          else
            'durationHours': 6,
        },
      });
    }

    test('is the approach until the trip starts', () {
      expect(
        TrackingPhase.of(tripAt(TripStatusV2.driverEnRoute)),
        TrackingPhase.toPickup,
      );
      // Arriving does not move the map: the car is at the pickup either way.
      expect(
        TrackingPhase.of(tripAt(TripStatusV2.driverArrived)),
        TrackingPhase.toPickup,
      );
    });

    test('switches to the drop-off when the trip starts', () {
      expect(
        TrackingPhase.of(tripAt(TripStatusV2.tripStarted)),
        TrackingPhase.toDropOff,
      );
    });

    test('has no second leg for hourly hire', () {
      final trip = tripAt(TripStatusV2.tripStarted, withDropOff: false);

      expect(trip.isChauffeur, isTrue);
      expect(trip.hasDropOffPoint, isFalse);
      // Still sharing — the car is live on the map — but with nowhere to route.
      expect(trip.status.sharesLocation, isTrue);
      expect(TrackingPhase.of(trip), TrackingPhase.inProgress);
    });

    test('treats a 0,0 drop-off as no drop-off', () {
      final trip = TripV2.fromJson({
        '_id': 'z',
        'bookingNumber': 'PF-Z',
        'bookingStatus': 'trip_started',
        'route': {
          'pickupLocation': {'lat': 24.71, 'lng': 46.67},
          'dropOffLocation': {'lat': 0, 'lng': 0},
        },
      });

      expect(trip.hasDropOffPoint, isFalse);
      expect(TrackingPhase.of(trip), TrackingPhase.inProgress);
    });
  });

  group('TripV2.rideStartedAt', () {
    test('reads the hire clock off the timeline, not the sharing start', () {
      final trip = TripV2.fromJson({
        '_id': 'd',
        'bookingNumber': 'PF-4',
        'bookingStatus': 'trip_started',
        'serviceType': 'hourly',
        'timeline': [
          {
            'key': 'driver_en_route',
            'label': 'Driver En-Route',
            'isCompleted': true,
            'timestamp': '2026-08-26T15:00:00.000Z',
          },
          {
            'key': 'trip_started',
            'label': 'Trip Started',
            'isCompleted': true,
            'isCurrent': true,
            'timestamp': '2026-08-26T15:40:00.000Z',
          },
        ],
      });

      // Forty minutes of approach that the customer must not be billed for.
      expect(trip.rideStartedAt, DateTime.utc(2026, 8, 26, 15, 40));
    });

    test('is null while the driver is still on the way', () {
      final trip = TripV2.fromJson({
        '_id': 'e',
        'bookingNumber': 'PF-5',
        'bookingStatus': 'driver_en_route',
        'timeline': [
          {
            'key': 'trip_started',
            'label': 'Trip Started',
            'isCompleted': false,
            'timestamp': null,
          },
        ],
      });

      expect(trip.status.sharesLocation, isTrue);
      expect(trip.rideStartedAt, isNull);
    });
  });
}

/// Trimmed from the driver app's own log of
/// `GET /api/v2/driver/bookings/6a8acd45085028dbc9ebbd16`.
const String _airportArrivalDetail = '''
{
  "_id": "6a8acd45085028dbc9ebbd16",
  "bookingNumber": "PF-APT-2608-1420",
  "bookingStatus": "driver_assigned",
  "serviceType": "airport_transfer",
  "transferSubType": "airport_arrival",
  "route": {
    "cityFrom": {
      "_id": "69ce2ee0e51a0e460209eea0",
      "cityName": "Madinah",
      "cityNameAr": "المدينة المنورة"
    },
    "cityTo": {
      "_id": "69ce2ee0e51a0e460209eea0",
      "cityName": "Madinah",
      "cityNameAr": "المدينة المنورة"
    },
    "airport": {
      "_id": "69cfcdfe16a318f7ae666b13",
      "airportName": "Prince Mohammad Bin Abdulaziz International Airport",
      "airportNameAr": "مطار الأمير محمد بن عبد العزيز الدولي"
    },
    "terminal": {
      "_id": "6a4e1b44bc91d891949cbf62",
      "terminalName": "Madinah Airport",
      "terminalNameAr": "صالة رقم 1"
    },
    "pickupLocation": {
      "lat": 0,
      "lng": 0,
      "address": "Prince Mohammad Bin Abdulaziz International Airport"
    },
    "dropOffLocation": {
      "lat": 24.39632203859852,
      "lng": 39.54050939530134,
      "address": "Abu Kabir, Madinah, Al Madinah"
    },
    "flightNumber": "SV-1024",
    "pickupDate": "2026-08-26",
    "pickupTime": "18:30",
    "pickupUTC": "2026-08-26T15:30:00.000Z",
    "pickupLocalTimeFormatted": "26 Aug 2026, 06:30 PM (AST)"
  },
  "vehicle": {
    "vehicleId": "65e2b1f8a9d1c234567890ab",
    "name": "GMC Yukon XL",
    "model": "2025",
    "maxPassengers": 6
  },
  "fleet": {
    "_id": "68b2c3d4e5f6789012345678",
    "licensePlate": "5432-RSA",
    "name": "GMC Yukon XL",
    "model": "2024",
    "color": "Black"
  },
  "passengerDetails": {
    "passengersCount": 3,
    "passengerNames": "Tariq Al-Mansoor",
    "passengerPhone": "+966501234567"
  },
  "pricing": {"currency": "SAR", "totalAmount": 460},
  "timeline": []
}
''';
