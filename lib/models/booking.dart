import 'package:premium_force_driver/models/user.dart';
import 'package:premium_force_driver/models/driver.dart';

/// Base Model representing a single booking/ride.
abstract class BookingModel {
  final String id;
  final String customerId;
  final String? driverId;
  final String pickupLocation;
  final double pickupLatitude;
  final double pickupLongitude;
  final double dropoffLatitude;
  final double dropoffLongitude;
  final String status; // Normalized: "P", "AC", "OG", "C", "CA", "starttracking", etc.
  final double fare;
  final String rideType;
  final String vehicleType;
  final int passengerCount;
  final double? rating;
  final String? review;
  final String paymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isHourly;
  final String? specialRequestText;
  final String? specialRequestAudio;
  final List<String>? passengerNames;
  final String? passengerMobile;
  final String? orderID;
  final String? transactionID;
  final String? paymentStatus;

  // Fields often used in UI (common across types or with fallbacks)
  final String? dropoffLocation;
  final double distance;
  final int estimatedDuration;
  final String? pickupdatetime;

  // Nested Objects
  final CityDetails? city;
  final AirportDetails? airport;
  final TerminalDetails? terminal;
  final CarDetails? car;
  final UserModel? customer;
  final DriverModel? driver;
  final OriginalIds? originalIds;
  final Map<String, dynamic>? trackingTimeline;

  BookingModel({
    required this.id,
    required this.customerId,
    this.driverId,
    required this.pickupLocation,
    required this.pickupLatitude,
    required this.pickupLongitude,
    this.dropoffLatitude = 0.0,
    this.dropoffLongitude = 0.0,
    required this.status,
    required this.fare,
    required this.rideType,
    required this.vehicleType,
    required this.passengerCount,
    this.rating,
    this.review,
    required this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
    required this.isHourly,
    this.specialRequestText,
    this.specialRequestAudio,
    this.passengerNames,
    this.passengerMobile,
    this.orderID,
    this.transactionID,
    this.paymentStatus,
    this.dropoffLocation,
    this.distance = 0.0,
    this.estimatedDuration = 0,
    this.pickupdatetime,
    this.city,
    this.airport,
    this.terminal,
    this.car,
    this.customer,
    this.driver,
    this.originalIds,
    this.trackingTimeline,
  });

  /// Readable car name (e.g. "S-Class")
  String get displayName => car?.displayName ?? vehicleType;

  /// Returns the car category name for display.
  String get displayRideType => rideType;

  /// Readable brand name (e.g. "Mercedes-Benz")
  String get displayBrand => car?.carbrand ?? 'N/A';

  /// Polymorphic factory to create either Standard or Chauffeur booking.
  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final bool isChauffeur =
        (json['category']?.toString().toLowerCase().contains('chauffeur') ?? false) ||
        (json['categoryID'] is Map &&
            json['categoryID']['name']?.toString().toLowerCase().contains('chauffeur') == true) ||
        (json['category']?.toString().toLowerCase().contains('bus') ?? false) ||
        (json['hours'] != null || json['estimatedHours'] != null) ||
        ((json['pickupDateTime'] != null || json['pickupdatetime'] != null) &&
            (json['dropOffLat'] == null || _toDouble(json['dropOffLat']) == 0) &&
            (json['dropoffLatitude'] == null || _toDouble(json['dropoffLatitude']) == 0) &&
            (json['arrival'] == null)); // Standard bookings usually have arrival date/time

    if (isChauffeur) {
      return ChauffeurBookingModel.fromJson(json);
    } else {
      return StandardBookingModel.fromJson(json);
    }
  }

  Map<String, dynamic> toJson();

  BookingModel copyWith({
    String? id,
    String? status,
    String? startedAt,
    String? stoppedAt,
    int? extraHours,
  });

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
      'Booking(id: $id, type: ${isHourly ? "Hourly" : "Standard"}, status: $status)';

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) {
      if (value.contains('.')) return double.tryParse(value)?.toInt() ?? 0;
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static String _normalizeStatus(dynamic status) {
    if (status == null) return 'P';
    final s = status.toString().toLowerCase().trim();
    if (s == 'p' || s == 'pending') return 'P';
    if (s == 'ac' || s == 'accepted' || s == 'assigned') return 'AC';
    if (s == 'og' || s == 'ongoing' || s == 'started') return 'OG';
    if (s == 'starttracking' || s == 'tracking') return 'starttracking';
    if (s == 'stoptracking' || s == 'stopped') return 'stoptracking';
    if (s == 'c' || s == 'completed' || s == 'reviewed') return 'C';
    if (s == 'ca' || s == 'cancelled' || s == 'x') return 'CA';
    if (s == 'paymentpending') return 'paymentpending';
    return s.toUpperCase();
  }
}

// ── Standard Booking Model (Airport / Private Transfer) ────────────────────

class StandardBookingModel extends BookingModel {
  final String? flightNumber;

  StandardBookingModel({
    required super.id,
    required super.customerId,
    super.driverId,
    required super.pickupLocation,
    required super.pickupLatitude,
    required super.pickupLongitude,
    required super.dropoffLatitude,
    required super.dropoffLongitude,
    required super.dropoffLocation,
    required super.status,
    required super.fare,
    required super.distance,
    required super.rideType,
    required super.vehicleType,
    required super.passengerCount,
    super.rating,
    super.review,
    required super.paymentMethod,
    required super.createdAt,
    required super.updatedAt,
    super.pickupdatetime,
    this.flightNumber,
    required super.estimatedDuration,
    super.city,
    super.airport,
    super.terminal,
    super.car,
    super.customer,
    super.driver,
    super.originalIds,
    super.trackingTimeline,
    super.specialRequestText,
    super.specialRequestAudio,
    super.passengerNames,
    super.passengerMobile,
    super.orderID,
    super.transactionID,
    super.paymentStatus,
  }) : super(isHourly: false);

  factory StandardBookingModel.fromJson(Map<String, dynamic> json) {
    final customerObj = json['customer'] ?? json['customerID'];
    final customerData = customerObj is Map<String, dynamic> ? UserModel.fromJson(customerObj) : null;
    final driverObj = json['driver'] ?? json['driverID'];
    final driverData = driverObj is Map<String, dynamic> ? DriverModel.fromJson(driverObj) : null;
    final cityData = json['city'] != null ? CityDetails.fromJson(json['city']) : (json['cityID'] is Map<String, dynamic> ? CityDetails.fromJson(json['cityID']) : null);
    final airportData = json['airport'] != null ? AirportDetails.fromJson(json['airport']) : (json['airportID'] is Map<String, dynamic> ? AirportDetails.fromJson(json['airportID']) : null);
    final terminalData = json['terminal'] != null ? TerminalDetails.fromJson(json['terminal']) : (json['terminalID'] is Map<String, dynamic> ? TerminalDetails.fromJson(json['terminalID']) : null);
    final carData = json['car'] != null ? CarDetails.fromJson(json['car']) : (json['carID'] is Map<String, dynamic> ? CarDetails.fromJson(json['carID']) : null);

    return StandardBookingModel(
      id: (json['_id'] ?? json['id'] ?? json['bookingID'] ?? '').toString(),
      customerId: customerData?.uid ?? (json['customerID'] is String ? json['customerID'] : (json['customerId'] ?? json['customerID']?['_id']))?.toString() ?? '',
      driverId: driverData?.uid ?? (json['driverID'] is String ? json['driverID'] : (json['driverId'] ?? json['driverID']?['_id']))?.toString(),
      pickupLocation: json['pickupAddress']?.toString() ?? json['pickupLocation']?.toString() ?? json['pickupAdddress']?.toString() ?? terminalData?.terminalName ?? airportData?.airportName ?? '',
      pickupLatitude: BookingModel._toDouble(json['pickupLat'] ?? json['pickupLatitude']),
      pickupLongitude: BookingModel._toDouble(json['pickupLong'] ?? json['pickupLongitude']),
      dropoffLocation: json['dropOffAddress']?.toString() ?? json['dropoffLocation']?.toString() ?? '',
      dropoffLatitude: BookingModel._toDouble(json['dropOffLat'] ?? json['dropoffLatitude']),
      dropoffLongitude: BookingModel._toDouble(json['dropOffLong'] ?? json['dropoffLongitude']),
      distance: BookingModel._toDouble(json['distance'] ?? json['totalDistance']),
      status: BookingModel._normalizeStatus(json['bookingStatus'] ?? json['status']),
      fare: BookingModel._toDouble(json['charge'] ?? json['fare'] ?? json['totalAmount']),
      rideType: json['carClass']?.toString() ?? json['car']?['categoryDetails']?['name']?.toString() ?? json['categoryID']?['name']?.toString() ?? json['carmodel']?.toString() ?? 'Standard',
      vehicleType: json['carmodel']?.toString() ?? carData?.displayName ?? json['carName']?.toString() ?? 'Standard',
      passengerCount: BookingModel._toInt(json['passengerCount'] ?? json['passengersCount'] ?? json['numberOfPassengers'] ?? 1).clamp(1, 100),
      rating: json['rating'] is Map ? BookingModel._toDouble(json['rating']['rate']) : (json['rating'] != null ? BookingModel._toDouble(json['rating']) : null),
      review: json['rating'] is Map ? json['rating']['reviewText']?.toString() : json['review']?.toString(),
      paymentMethod: json['paymentMethod']?.toString() ?? 'Card',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      pickupdatetime: json['pickupdatetime']?.toString() ?? json['pickupDateTime']?.toString() ?? json['arrival']?.toString(),
      flightNumber: json['flightNumber']?.toString(),
      estimatedDuration: BookingModel._toInt(json['estimatedDuration']),
      city: cityData,
      airport: airportData,
      terminal: terminalData,
      car: carData,
      customer: customerData,
      driver: driverData,
      originalIds: OriginalIds.fromJson(json),
      trackingTimeline: (json['TrackingTimeLine'] is Map ? Map<String, dynamic>.from(json['TrackingTimeLine']) : (json['trackingTimeline'] is Map ? Map<String, dynamic>.from(json['trackingTimeline']) : null)),
      specialRequestText: json['specialRequestText']?.toString(),
      specialRequestAudio: json['specialRequestAudio'] is Map ? json['specialRequestAudio']['url']?.toString() : json['specialRequestAudio']?.toString(),
      passengerNames: json['passengerNames'] is List ? List<String>.from(json['passengerNames']) : null,
      passengerMobile: json['passengerMobile']?.toString(),
      orderID: json['orderID']?.toString(),
      transactionID: json['transactionID']?.toString(),
      paymentStatus: json['paymentStatus'] is bool ? (json['paymentStatus'] ? "Paid" : "Unpaid") : json['paymentStatus']?.toString(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'bookingStatus': status,
    'isHourly': false,
    'pickupAddress': pickupLocation,
    'dropOffAddress': dropoffLocation,
    'charge': fare,
    'distance': distance,
    'pickupDateTime': pickupdatetime,
    'pickupdatetime': pickupdatetime,
    'flightNumber': flightNumber,
  };

  @override
  StandardBookingModel copyWith({
    String? id,
    String? status,
    String? startedAt,
    String? stoppedAt,
    int? extraHours,
  }) => StandardBookingModel(
    id: id ?? this.id,
    status: status ?? this.status,
    customerId: customerId,
    pickupLocation: pickupLocation,
    pickupLatitude: pickupLatitude,
    pickupLongitude: pickupLongitude,
    dropoffLocation: dropoffLocation,
    dropoffLatitude: dropoffLatitude,
    dropoffLongitude: dropoffLongitude,
    fare: fare,
    distance: distance,
    rideType: rideType,
    vehicleType: vehicleType,
    passengerCount: passengerCount,
    paymentMethod: paymentMethod,
    createdAt: createdAt,
    updatedAt: updatedAt,
    pickupdatetime: pickupdatetime,
    flightNumber: flightNumber,
    estimatedDuration: estimatedDuration,
    city: city,
    airport: airport,
    terminal: terminal,
    car: car,
    customer: customer,
    driver: driver,
    originalIds: originalIds,
    trackingTimeline: trackingTimeline,
    specialRequestText: specialRequestText,
    specialRequestAudio: specialRequestAudio,
    passengerNames: passengerNames,
    passengerMobile: passengerMobile,
    orderID: orderID,
    transactionID: transactionID,
    paymentStatus: paymentStatus,
  );
}

// ── Chauffeur Booking Model (Hourly) ────────────────────────────────────────

class ChauffeurBookingModel extends BookingModel {
  final int hours;
  final int? extraHours;
  final double? extraPayment;
  final String? startedAt;
  final String? stoppedAt;
  final double? extraDiscount;
  final bool? extraPaymentCompleted;

  ChauffeurBookingModel({
    required super.id,
    required super.customerId,
    super.driverId,
    required super.pickupLocation,
    required super.pickupLatitude,
    required super.pickupLongitude,
    super.dropoffLatitude,
    super.dropoffLongitude,
    required this.hours,
    this.extraHours,
    this.extraPayment,
    this.startedAt,
    this.stoppedAt,
    this.extraDiscount,
    this.extraPaymentCompleted,
    required super.status,
    required super.fare,
    required super.rideType,
    required super.vehicleType,
    required super.passengerCount,
    super.rating,
    super.review,
    required super.paymentMethod,
    required super.createdAt,
    required super.updatedAt,
    super.pickupdatetime,
    super.city,
    super.car,
    super.customer,
    super.driver,
    super.originalIds,
    super.trackingTimeline,
    super.specialRequestText,
    super.specialRequestAudio,
    super.passengerNames,
    super.passengerMobile,
    super.orderID,
    super.transactionID,
    super.paymentStatus,
  }) : super(isHourly: true, estimatedDuration: hours);

  factory ChauffeurBookingModel.fromJson(Map<String, dynamic> json) {
    final customerObj = json['customer'] ?? json['customerID'];
    final customerData = customerObj is Map<String, dynamic> ? UserModel.fromJson(customerObj) : null;
    final driverObj = json['driver'] ?? json['driverID'];
    final driverData = driverObj is Map<String, dynamic> ? DriverModel.fromJson(driverObj) : null;
    final cityData = json['city'] != null ? CityDetails.fromJson(json['city']) : (json['cityID'] is Map<String, dynamic> ? CityDetails.fromJson(json['cityID']) : null);
    final carData = json['car'] != null ? CarDetails.fromJson(json['car']) : (json['carID'] is Map<String, dynamic> ? CarDetails.fromJson(json['carID']) : null);

    return ChauffeurBookingModel(
      id: (json['_id'] ?? json['id'] ?? json['bookingID'] ?? '').toString(),
      customerId: customerData?.uid ?? (json['customerID'] is String ? json['customerID'] : (json['customerID'] is Map ? json['customerID']['_id'] : null))?.toString() ?? '',
      driverId: driverData?.uid ?? (json['driverID'] is String ? json['driverID'] : (json['driverID'] is Map ? json['driverID']['_id'] : null))?.toString(),
      pickupLocation: json['pickupAdddress']?.toString() ?? json['pickupAddress']?.toString() ?? json['pickupLocation']?.toString() ?? '',
      pickupLatitude: BookingModel._toDouble(json['pickupLat'] ?? json['pickupLatitude']),
      pickupLongitude: BookingModel._toDouble(json['pickuplong'] ?? json['pickupLong'] ?? json['pickupLongitude']),
      hours: BookingModel._toInt(json['hours'] ?? json['estimatedHours']),
      extraHours: BookingModel._toInt(json['extraHours'] ?? json['extrahours']),
      extraPayment: BookingModel._toDouble(json['extraPayment']),
      startedAt: json['startedAt']?.toString(),
      stoppedAt: json['stoppedAt']?.toString(),
      pickupdatetime: json['pickupDateTime']?.toString() ?? json['pickupdatetime']?.toString(),
      extraDiscount: BookingModel._toDouble(json['extraDiscount']),
      extraPaymentCompleted: json['extraPaymentCompleted'] is bool ? json['extraPaymentCompleted'] : (json['extraPaymentCompleted']?.toString().toLowerCase() == 'true'),
      status: BookingModel._normalizeStatus(json['bookingStatus'] ?? json['status']),
      fare: BookingModel._toDouble(json['charge'] ?? json['fare'] ?? json['totalAmount']),
      rideType: json['carClass']?.toString() ?? (json['categoryID'] is Map ? json['categoryID']['name'] : json['category'])?.toString() ?? 'Chauffeur',
      vehicleType: json['model']?.toString() ?? carData?.displayName ?? json['carName']?.toString() ?? 'Chauffeur',
      passengerCount: BookingModel._toInt(json['passsenrgersCount'] ?? json['passengerCount'] ?? 1).clamp(1, 100),
      paymentMethod: json['paymentMethod']?.toString() ?? 'Card',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      city: cityData,
      car: carData,
      customer: customerData,
      driver: driverData,
      originalIds: OriginalIds.fromJson(json),
      trackingTimeline: (json['TrackingTimeLine'] is Map ? Map<String, dynamic>.from(json['TrackingTimeLine']) : (json['trackingTimeline'] is Map ? Map<String, dynamic>.from(json['trackingTimeline']) : null)),
      specialRequestText: json['specialRequestText']?.toString(),
      specialRequestAudio: json['specialRequestAudio'] is Map ? json['specialRequestAudio']['url']?.toString() : json['specialRequestAudio']?.toString(),
      passengerNames: json['passengerNames'] is List ? List<String>.from(json['passengerNames']) : null,
      passengerMobile: json['passengerMobile']?.toString(),
      orderID: json['orderID']?.toString(),
      transactionID: json['transactionID']?.toString(),
      paymentStatus: json['paymentStatus'] is bool ? (json['paymentStatus'] ? "Paid" : "Unpaid") : json['paymentStatus']?.toString(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'bookingStatus': status,
    'isHourly': true,
    'pickupAdddress': pickupLocation,
    'hours': hours,
    'charge': fare,
  };

  @override
  ChauffeurBookingModel copyWith({
    String? id,
    String? status,
    String? startedAt,
    String? stoppedAt,
    int? extraHours,
  }) => ChauffeurBookingModel(
    id: id ?? this.id,
    status: status ?? this.status,
    customerId: customerId,
    pickupLocation: pickupLocation,
    pickupLatitude: pickupLatitude,
    pickupLongitude: pickupLongitude,
    hours: hours,
    extraHours: extraHours ?? this.extraHours,
    startedAt: startedAt ?? this.startedAt,
    stoppedAt: stoppedAt ?? this.stoppedAt,
    fare: fare,
    rideType: rideType,
    vehicleType: vehicleType,
    passengerCount: passengerCount,
    paymentMethod: paymentMethod,
    createdAt: createdAt,
    updatedAt: updatedAt,
    pickupdatetime: pickupdatetime,
    city: city,
    car: car,
    customer: customer,
    driver: driver,
    originalIds: originalIds,
    trackingTimeline: trackingTimeline,
    specialRequestText: specialRequestText,
    specialRequestAudio: specialRequestAudio,
    passengerNames: passengerNames,
    passengerMobile: passengerMobile,
    orderID: orderID,
    transactionID: transactionID,
    paymentStatus: paymentStatus,
  );
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
    final brand = json['brandID'] ?? json['brandDetails'];
    if (brand is Map) {
      logo = (brand['brandIcon'] ?? brand['image']) is Map ? (brand['brandIcon'] ?? brand['image'])['url']?.toString() : null;
    }

    return CarDetails(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      carName: json['carName']?.toString() ?? '',
      carbrand: json['carbrand']?.toString() ?? (brand is Map ? brand['brandName']?.toString() : null),
      carmodel: json['carmodel']?.toString() ?? json['model']?.toString(),
      carImage: json['carImage'] is Map ? json['carImage']['url']?.toString() : (json['carImage'] ?? json['carimage'] is Map ? json['carimage']['url'] : null)?.toString(),
      brandLogo: logo,
    );
  }

  String get displayName => carName.isNotEmpty ? carName : '${carbrand ?? ''} ${carmodel ?? ''}'.trim();
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
    String? extractId(dynamic obj) {
      if (obj == null) return null;
      if (obj is String) return obj;
      if (obj is Map) return (obj['_id'] ?? obj['id'])?.toString();
      return null;
    }

    return OriginalIds(
      cityID: extractId(json['cityID'] ?? json['city']),
      airportID: extractId(json['airportID'] ?? json['airport']),
      terminalID: extractId(json['terminalID'] ?? json['terminal']),
      carID: extractId(json['carID'] ?? json['car']),
      customerID: extractId(json['customerID'] ?? json['customer']),
      driverID: extractId(json['driverID'] ?? json['driver']),
      brandID: extractId(json['brandID'] ?? (json['car'] is Map ? json['car']['brandID'] : null)),
    );
  }
}
