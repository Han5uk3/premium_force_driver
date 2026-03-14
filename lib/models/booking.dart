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
  });

  /// Create a BookingModel from JSON.
  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['_id'] ?? json['id'] ?? '',
      customerId: json['customerId'] ?? '',
      driverId: json['driverId'],
      pickupLocation: json['pickupLocation'] ?? '',
      dropoffLocation: json['dropoffLocation'] ?? '',
      pickupLatitude: (json['pickupLatitude'] as num?)?.toDouble() ?? 0.0,
      pickupLongitude: (json['pickupLongitude'] as num?)?.toDouble() ?? 0.0,
      dropoffLatitude: (json['dropoffLatitude'] as num?)?.toDouble() ?? 0.0,
      dropoffLongitude: (json['dropoffLongitude'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'P',
      fare: (json['fare'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      estimatedDuration: json['estimatedDuration'] ?? 0,
      actualDuration: json['actualDuration'],
      rideType: json['rideType'] ?? 'Economy',
      vehicleType: json['vehicleType'] ?? 'Standard',
      passengerCount: json['passengerCount'] ?? 1,
      rating: (json['rating'] as num?)?.toDouble(),
      review: json['review'],
      paymentMethod: json['paymentMethod'] ?? 'Card',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : DateTime.now(),
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
