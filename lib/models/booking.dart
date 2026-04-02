import 'package:premium_force_driver/models/user.dart';
import 'package:premium_force_driver/models/driver.dart';

/// Model representing a single booking/ride.
class BookingModel {
  final String id;
  final String customerId;
  final String? driverId;
  final String pickupLocation;
  final String dropoffLocation;
  final double pickupLatitude;
  final double pickupLongitude;
  final double dropoffLatitude;
  final double dropoffLongitude;
  final String
  status; // "P" = Pending, "AC" = Accepted, "OG" = Ongoing, "C" = Completed, "CA" = Cancelled
  final double fare;
  final double distance;
  final int estimatedDuration; // in seconds
  final int? actualDuration;
  final String rideType; // e.g., "Premium", "Economy", "Airport Arrival"
  final String vehicleType; // e.g., "Tesla Model S", "Honda Civic"
  final int passengerCount;
  final double? rating;
  final String? review;
  final String paymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isHourly;
  final String? arrival;
  final String? pickupdatetime;
  final double? discountPercentage;
  final String? orderID;
  final String? transactionID;
  final String? startedAt;
  final String? stoppedAt;
  final int? extraHours;
  final bool? extraPaymentCompleted;
  final double? extraDiscount;
  final double? extraPayment;
  final String? extraOrderID;
  final String? extraTransactionID;
  final String? specialRequestText;
  final String? specialRequestAudio;
  final List<String>? passengerNames;
  final String? passengerMobile;

  // Modern Nested Objects from rich backend response
  final CityDetails? city;
  final AirportDetails? airport;
  final TerminalDetails? terminal;
  final CarDetails? car;
  final UserModel? customer;
  final DriverModel? driver;
  final OriginalIds? originalIds;
  final Map<String, dynamic>? trackingTimeline;
  final String? paymentStatus;

  BookingModel({
    required this.id,
    required this.customerId,
    this.driverId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.dropoffLatitude,
    required this.dropoffLongitude,
    required this.status,
    required this.fare,
    required this.distance,
    required this.estimatedDuration,
    this.actualDuration,
    required this.rideType,
    required this.vehicleType,
    required this.passengerCount,
    this.rating,
    this.review,
    required this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
    this.city,
    this.airport,
    this.terminal,
    this.car,
    this.customer,
    this.driver,
    this.originalIds,
    this.trackingTimeline,
    this.paymentStatus,
    this.isHourly = false,
    this.arrival,
    this.pickupdatetime,
    this.discountPercentage,
    this.orderID,
    this.transactionID,
    this.startedAt,
    this.stoppedAt,
    this.extraHours,
    this.extraPaymentCompleted,
    this.extraDiscount,
    this.extraPayment,
    this.extraOrderID,
    this.extraTransactionID,
    this.specialRequestText,
    this.specialRequestAudio,
    this.passengerNames,
    this.passengerMobile,
  });

  /// Readable car name (e.g. "S-Class")
  String get displayName {
    if (car != null) return car!.displayName;
    return vehicleType;
  }

  /// Returns the car category name for display.
  String get displayRideType => rideType;

  /// Readable brand name (e.g. "Mercedes-Benz")
  String get displayBrand {
    if (car != null) return car!.carbrand ?? 'N/A';
    return 'N/A';
  }

  /// Create a BookingModel from JSON.
  factory BookingModel.fromJson(Map<String, dynamic> json) {
    // Helper to extract double from various formats
    double toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Helper to extract int from various formats
    int toolToInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) {
        // Handle cases like "3.0" by parsing as double first if it has a decimal point
        if (value.contains('.')) {
          return double.tryParse(value)?.toInt() ?? 0;
        }
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    // Status normalization
    String normalizeStatus(dynamic status) {
      if (status == null) return 'P';
      final s = status.toString().toLowerCase().trim();
      if (s == 'p' || s == 'pending') return 'P';
      if (s == 'ac' || s == 'accepted' || s == 'assigned')
        return 'AC'; // Map 'assigned' to AC
      if (s == 'og' || s == 'ongoing') return 'OG';
      if (s == 'starttracking' || s == 'starttrack') return 'starttracking';
      if (s == 'stoptracking' || s == 'stoptrack') return 'stoptracking';
      if (s == 'c' || s == 'completed' || s == 'reviewed') return 'C';
      if (s == 'ca' || s == 'cancelled' || s == 'x') return 'CA';
      if (s == 'paymentpending') return 'paymentpending';
      return s.toUpperCase(); // Fallback to raw status in caps
    }

    // Parse nested objects if present
    final customerObj = json['customer'] ?? json['customerID'];
    final customerData = customerObj is Map<String, dynamic>
        ? UserModel.fromJson(customerObj)
        : null;

    final driverObj = json['driver'] ?? json['driverID'];
    final driverData = driverObj is Map<String, dynamic>
        ? DriverModel.fromJson(driverObj)
        : null;

    final cityData = json['city'] != null
        ? CityDetails.fromJson(json['city'])
        : (json['cityID'] is Map<String, dynamic>
              ? CityDetails.fromJson(json['cityID'])
              : null);
    final airportData = json['airport'] != null
        ? AirportDetails.fromJson(json['airport'])
        : (json['airportID'] is Map<String, dynamic>
              ? AirportDetails.fromJson(json['airportID'])
              : null);
    final terminalData = json['terminal'] != null
        ? TerminalDetails.fromJson(json['terminal'])
        : (json['terminalID'] is Map<String, dynamic>
              ? TerminalDetails.fromJson(json['terminalID'])
              : null);
    var carData = json['car'] != null
        ? CarDetails.fromJson(json['car'])
        : (json['carID'] is Map<String, dynamic>
              ? CarDetails.fromJson(json['carID'])
              : null);
    if (carData != null && json['carImage'] != null) {
      carData = CarDetails(
        id: carData.id,
        carName: carData.carName,
        carbrand: carData.carbrand,
        carmodel: carData.carmodel,
        carImage: json['carImage'] is Map
            ? json['carImage']['url']?.toString()
            : json['carImage'].toString(),
        brandLogo: carData.brandLogo,
      );
    }

    final ids = json['originalIds'] != null
        ? OriginalIds.fromJson(json['originalIds'])
        : OriginalIds(
            cityID:
                (json['cityID'] is Map ? json['cityID']['_id'] : json['cityID'])
                    ?.toString(),
            airportID:
                (json['airportID'] is Map
                        ? json['airportID']['_id']
                        : json['airportID'])
                    ?.toString(),
            terminalID:
                (json['terminalID'] is Map
                        ? json['terminalID']['_id']
                        : json['terminalID'])
                    ?.toString(),
            carID: (json['carID'] is Map ? json['carID']['_id'] : json['carID'])
                ?.toString(),
            customerID:
                customerData?.uid ??
                (json['customerID'] is String
                    ? json['customerID']
                    : (json['customerID'] is Map
                          ? json['customerID']['_id']
                          : null)),
            driverID:
                driverData?.uid ??
                (json['driverID'] is String
                    ? json['driverID']
                    : (json['driverID'] is Map
                          ? json['driverID']['_id']
                          : null)),
            brandID:
                (json['brandID'] is Map
                        ? json['brandID']['_id']
                        : json['brandID'])
                    ?.toString(),
          );

    return BookingModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      customerId:
          customerData?.uid ??
          json['customerID']?.toString() ??
          json['customerId']?.toString() ??
          ids.customerID ??
          '',
      driverId:
          driverData?.uid ??
          json['driverID']?.toString() ??
          json['driverId']?.toString() ??
          ids.driverID ??
          '',
      pickupLocation:
          json['pickupAddress']?.toString() ??
          json['pickupLocation']?.toString() ??
          json['pickupAdddress']?.toString() ??
          terminalData?.terminalName ??
          airportData?.airportName ??
          '',
      dropoffLocation:
          json['dropOffAddress']?.toString() ??
          json['dropoffLocation']?.toString() ??
          '',
      pickupLatitude: toDouble(json['pickupLat'] ?? json['pickupLatitude']),
      pickupLongitude: toDouble(
        json['pickupLong'] ?? json['pickuplong'] ?? json['pickupLongitude'],
      ),
      dropoffLatitude: toDouble(json['dropOffLat'] ?? json['dropoffLatitude']),
      dropoffLongitude: toDouble(
        json['dropOffLong'] ?? json['dropoffLongitude'],
      ),
      status: normalizeStatus(json['bookingStatus'] ?? json['status']),
      fare: toDouble(json['charge'] ?? json['fare'] ?? json['totalAmount']),
      distance: toDouble(json['distance'] ?? json['totalDistance']),
      estimatedDuration: toolToInt(json['estimatedDuration'] ?? json['hours']),
      actualDuration: json['actualDuration'] != null
          ? toolToInt(json['actualDuration'])
          : null,
      rideType: json['categoryID'] is Map
          ? (json['categoryID']['name']?.toString() ?? 'Standard')
          : (json['category']?.toString() ??
                json['rideType']?.toString() ??
                'Standard'),
      vehicleType:
          carData?.displayName ??
          json['carName']?.toString() ??
          json['vehicleType']?.toString() ??
          json['carClass']?.toString() ??
          'Standard',
      passengerCount: (toolToInt(
        json['passengerCount'] ??
            json['passsenrgersCount'] ??
            json['passengersCount'] ??
            json['passengers'] ??
            json['passenger'] ??
            json['numberOfPassengers'] ??
            json['noOfPassengers'] ??
            json['passCount'],
      )).clamp(1, 100),
      rating: (json['rating'] is Map)
          ? toDouble(json['rating']['rate'] ?? json['rating']['rating'])
          : (json['rating'] != null ? toDouble(json['rating']) : null),
      review: (json['rating'] is Map)
          ? json['rating']['reviewText']?.toString()
          : json['review']?.toString(),
      paymentMethod: json['paymentMethod']?.toString() ?? 'Card',
      createdAt: (json['createdAt'] != null)
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      arrival: json['arrival']?.toString(),
      pickupdatetime:
          json['pickupdatetime']?.toString() ??
          json['pickupDateTime']?.toString(),
      city: cityData,
      airport: airportData,
      terminal: terminalData,
      car: carData,
      customer: customerData,
      driver: driverData,
      originalIds: ids,
      trackingTimeline: json['trackingTimeline'] as Map<String, dynamic>?,
      paymentStatus: json['paymentStatus'] is bool
          ? (json['paymentStatus'] ? "Paid" : "Unpaid")
          : json['paymentStatus']?.toString() ?? "Unpaid",
      isHourly:
          (json['category']?.toString().toLowerCase().contains('chauffeur') ??
              false) ||
          (json['categoryID'] is Map &&
              json['categoryID']['name']?.toString().toLowerCase().contains(
                    'chauffeur',
                  ) ==
                  true) ||
          (toDouble(
                    json['dropOffLat'] ??
                        json['dropoffLatitude'] ??
                        json['dropoffLatitude'],
                  ) ==
                  0 &&
              toDouble(json['dropOffLong'] ?? json['dropoffLongitude']) == 0) ||
          (json['estimatedHours'] != null ||
              json['hours'] != null ||
              json['pickupdatetime'] != null),
      discountPercentage: json['discountPercentage'] != null
          ? double.tryParse(json['discountPercentage'].toString())
          : null,
      orderID: json['orderID']?.toString(),
      transactionID: json['transactionID']?.toString(),
      startedAt: json['startedAt']?.toString(),
      stoppedAt: json['stoppedAt']?.toString(),
      extraHours: json['extraHours'] != null
          ? toolToInt(json['extraHours'])
          : (json['extrahours'] != null ? toolToInt(json['extrahours']) : null),
      extraPaymentCompleted: json['extraPaymentCompleted'] is bool
          ? json['extraPaymentCompleted']
          : (json['extraPaymentCompleted']?.toString().toLowerCase() == 'true'),
      extraDiscount: toDouble(json['extraDiscount']),
      extraPayment: toDouble(json['extraPayment']),
      extraOrderID: json['extraOrderID']?.toString(),
      extraTransactionID: json['extraTransactionID']?.toString(),
      specialRequestText: json['specialRequestText']?.toString(),
      specialRequestAudio: json['specialRequestAudio']?.toString(),
      passengerNames: json['passengerNames'] != null
          ? List<String>.from(json['passengerNames'])
          : null,
      passengerMobile: json['passengerMobile']?.toString(),
    );
  }

  /// Convert BookingModel to JSON.
  Map<String, dynamic> toJson() => {
    '_id': id,
    'customerId': customerId,
    'driverId': driverId,
    'pickupLocation': pickupLocation,
    'dropoffLocation': dropoffLocation,
    'pickupLatitude': pickupLatitude,
    'pickupLongitude': pickupLongitude,
    'dropoffLatitude': dropoffLatitude,
    'dropoffLongitude': dropoffLongitude,
    'status': status,
    'isHourly': isHourly,
    'fare': fare,
    'distance': distance,
    'estimatedDuration': estimatedDuration,
    'actualDuration': actualDuration,
    'rideType': rideType,
    'vehicleType': vehicleType,
    'passengerCount': passengerCount,
    'rating': rating,
    'review': review,
    'paymentMethod': paymentMethod,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'paymentStatus': paymentStatus,
    'arrival': arrival,
    'pickupdatetime': pickupdatetime,
    'discountPercentage': discountPercentage,
    'orderID': orderID,
    'transactionID': transactionID,
    'startedAt': startedAt,
    'stoppedAt': stoppedAt,
    'extraHours': extraHours,
    'extraPaymentCompleted': extraPaymentCompleted,
    'extraDiscount': extraDiscount,
    'extraPayment': extraPayment,
    'extraOrderID': extraOrderID,
    'extraTransactionID': extraTransactionID,
    'specialRequestText': specialRequestText,
    'specialRequestAudio': specialRequestAudio,
    'passengerNames': passengerNames,
    'passengerMobile': passengerMobile,
    if (originalIds != null)
      'originalIds': {
        'cityID': originalIds!.cityID,
        'airportID': originalIds!.airportID,
        'terminalID': originalIds!.terminalID,
        'carID': originalIds!.carID,
        'customerID': originalIds!.customerID,
        'driverID': originalIds!.driverID,
        'brandID': originalIds!.brandID,
      },
  };

  /// Create a copy with modified fields.
  BookingModel copyWith({
    String? id,
    String? customerId,
    String? driverId,
    String? pickupLocation,
    String? dropoffLocation,
    double? pickupLatitude,
    double? pickupLongitude,
    double? dropoffLatitude,
    double? dropoffLongitude,
    String? status,
    double? fare,
    double? distance,
    int? estimatedDuration,
    int? actualDuration,
    String? rideType,
    String? vehicleType,
    int? passengerCount,
    double? rating,
    String? review,
    String? paymentMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isHourly,
    CityDetails? city,
    AirportDetails? airport,
    TerminalDetails? terminal,
    CarDetails? car,
    UserModel? customer,
    DriverModel? driver,
    OriginalIds? originalIds,
    Map<String, dynamic>? trackingTimeline,
    String? paymentStatus,
    String? startedAt,
    String? stoppedAt,
    int? extraHours,
    String? specialRequestText,
    String? specialRequestAudio,
    List<String>? passengerNames,
    String? passengerMobile,
  }) => BookingModel(
    id: id ?? this.id,
    customerId: customerId ?? this.customerId,
    driverId: driverId ?? this.driverId,
    pickupLocation: pickupLocation ?? this.pickupLocation,
    dropoffLocation: dropoffLocation ?? this.dropoffLocation,
    pickupLatitude: pickupLatitude ?? this.pickupLatitude,
    pickupLongitude: pickupLongitude ?? this.pickupLongitude,
    dropoffLatitude: dropoffLatitude ?? this.dropoffLatitude,
    dropoffLongitude: dropoffLongitude ?? this.dropoffLongitude,
    status: status ?? this.status,
    fare: fare ?? this.fare,
    distance: distance ?? this.distance,
    estimatedDuration: estimatedDuration ?? this.estimatedDuration,
    actualDuration: actualDuration ?? this.actualDuration,
    rideType: rideType ?? this.rideType,
    vehicleType: vehicleType ?? this.vehicleType,
    passengerCount: passengerCount ?? this.passengerCount,
    rating: rating ?? this.rating,
    review: review ?? this.review,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    city: city ?? this.city,
    airport: airport ?? this.airport,
    terminal: terminal ?? this.terminal,
    car: car ?? this.car,
    customer: customer ?? this.customer,
    driver: driver ?? this.driver,
    originalIds: originalIds ?? this.originalIds,
    trackingTimeline: trackingTimeline ?? this.trackingTimeline,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    isHourly: isHourly ?? this.isHourly,
    arrival: arrival ?? this.arrival,
    pickupdatetime: pickupdatetime ?? this.pickupdatetime,
    discountPercentage: discountPercentage ?? this.discountPercentage,
    orderID: orderID ?? this.orderID,
    transactionID: transactionID ?? this.transactionID,
    startedAt: startedAt ?? this.startedAt,
    stoppedAt: stoppedAt ?? this.stoppedAt,
    extraHours: extraHours ?? this.extraHours,
    extraPaymentCompleted: extraPaymentCompleted ?? this.extraPaymentCompleted,
    extraDiscount: extraDiscount ?? this.extraDiscount,
    extraPayment: extraPayment ?? this.extraPayment,
    extraOrderID: extraOrderID ?? this.extraOrderID,
    extraTransactionID: extraTransactionID ?? this.extraTransactionID,
    specialRequestText: specialRequestText ?? this.specialRequestText,
    specialRequestAudio: specialRequestAudio ?? this.specialRequestAudio,
    passengerNames: passengerNames ?? this.passengerNames,
    passengerMobile: passengerMobile ?? this.passengerMobile,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'BookingModel(id: $id, status: $status, '
      'pickup: $pickupLocation, dropoff: $dropoffLocation)';
}

// ── Helper Sub-Classes for Nested Data ──────────────────────────────────────

class CityDetails {
  final String id;
  final String cityName;
  final String? cityNameAr;
  final String? imageUrl;
  final bool isActive;

  CityDetails({
    required this.id,
    required this.cityName,
    this.cityNameAr,
    this.imageUrl,
    this.isActive = true,
  });

  factory CityDetails.fromJson(Map<String, dynamic> json) {
    return CityDetails(
      id: json['_id']?.toString() ?? '',
      cityName: json['cityName']?.toString() ?? '',
      cityNameAr: json['cityNameAr']?.toString(),
      imageUrl: json['image'] is Map ? json['image']['url']?.toString() : null,
      isActive: json['isActive'] ?? true,
    );
  }
}

class AirportDetails {
  final String id;
  final String airportName;
  final String? cityID;

  AirportDetails({required this.id, required this.airportName, this.cityID});

  factory AirportDetails.fromJson(Map<String, dynamic> json) {
    return AirportDetails(
      id: json['_id']?.toString() ?? '',
      airportName: json['airportName']?.toString() ?? '',
      cityID: json['cityID']?.toString(),
    );
  }
}

class TerminalDetails {
  final String id;
  final String terminalName;
  final String? airportID;

  TerminalDetails({
    required this.id,
    required this.terminalName,
    this.airportID,
  });

  factory TerminalDetails.fromJson(Map<String, dynamic> json) {
    return TerminalDetails(
      id: json['_id']?.toString() ?? '',
      terminalName: json['terminalName']?.toString() ?? '',
      airportID: json['airportID']?.toString(),
    );
  }
}

class CarDetails {
  final String id;
  final String carName;
  final String? carbrand;
  final String? carmodel;
  final String? carImage;
  final String? brandLogo;

  CarDetails({
    required this.id,
    required this.carName,
    this.carbrand,
    this.carmodel,
    this.carImage,
    this.brandLogo,
  });

  factory CarDetails.fromJson(Map<String, dynamic> json) {
    String? logo;
    final brand = json['brandID'];
    if (brand is Map) {
      final icon = brand['brandIcon'] ?? brand['image'];
      if (icon is Map) logo = icon['url']?.toString();
    }

    return CarDetails(
      id: json['_id']?.toString() ?? '',
      carName: json['carName']?.toString() ?? '',
      carbrand:
          json['carbrand']?.toString() ??
          (brand is Map ? brand['brandName']?.toString() : null),
      carmodel:
          json['carmodel']?.toString() ??
          (json['carID'] is Map ? json['carID']['model']?.toString() : null),
      carImage: json['carImage'] is Map
          ? json['carImage']['url']?.toString()
          : (json['carImage']?.toString()),
      brandLogo: logo,
    );
  }

  String get displayName => carName.isNotEmpty
      ? carName
      : '${carbrand ?? ''} ${carmodel ?? ''}'.trim();
}

class OriginalIds {
  final String? cityID;
  final String? airportID;
  final String? terminalID;
  final String? carID;
  final String? customerID;
  final String? driverID;
  final String? brandID;

  OriginalIds({
    this.cityID,
    this.airportID,
    this.terminalID,
    this.carID,
    this.customerID,
    this.driverID,
    this.brandID,
  });

  factory OriginalIds.fromJson(Map<String, dynamic> json) {
    return OriginalIds(
      cityID:
          (json['cityID'] is Map
                  ? (json['cityID']['_id'] ?? json['cityID']['id'])
                  : json['cityID'])
              ?.toString(),
      airportID:
          (json['airportID'] is Map
                  ? (json['airportID']['_id'] ?? json['airportID']['id'])
                  : json['airportID'])
              ?.toString(),
      terminalID:
          (json['terminalID'] is Map
                  ? (json['terminalID']['_id'] ?? json['terminalID']['id'])
                  : json['terminalID'])
              ?.toString(),
      carID:
          (json['carID'] is Map
                  ? (json['carID']['_id'] ?? json['carID']['id'])
                  : json['carID'])
              ?.toString(),
      customerID:
          (json['customerID'] is Map
                  ? (json['customerID']['_id'] ?? json['customerID']['id'])
                  : json['customerID'])
              ?.toString(),
      driverID:
          (json['driverID'] is Map
                  ? (json['driverID']['_id'] ?? json['driverID']['id'])
                  : json['driverID'])
              ?.toString(),
      brandID:
          (json['brandID'] is Map
                  ? (json['brandID']['_id'] ?? json['brandID']['id'])
                  : json['brandID'])
              ?.toString(),
    );
  }
}
