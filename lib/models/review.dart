class ReviewModel {
  final String id;
  final ReviewDriverInfo? driverID;
  final ReviewBookingInfo? bookingID;
  final String reviewText;
  final double rate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReviewModel({
    required this.id,
    this.driverID,
    this.bookingID,
    required this.reviewText,
    required this.rate,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['_id'] ?? '',
      driverID: json['driverID'] != null && json['driverID'] is Map<String, dynamic>
          ? ReviewDriverInfo.fromJson(json['driverID'])
          : null,
      bookingID: json['bookingID'] != null && json['bookingID'] is Map<String, dynamic>
          ? ReviewBookingInfo.fromJson(json['bookingID'])
          : null,
      reviewText: json['reviewText'] ?? '',
      rate: (json['rate'] ?? 0).toDouble(),
      isActive: json['isActive'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ReviewDriverInfo {
  final String id;
  final String driverName;
  final String phoneNumber;

  ReviewDriverInfo({
    required this.id,
    required this.driverName,
    required this.phoneNumber,
  });

  factory ReviewDriverInfo.fromJson(Map<String, dynamic> json) {
    return ReviewDriverInfo(
      id: json['_id'] ?? '',
      driverName: json['driverName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
    );
  }
}

class ReviewBookingInfo {
  final String id;
  final String pickupAddress;
  final String dropOffAddress;
  final String carmodel;
  final double charge;
  final DateTime createdAt;

  ReviewBookingInfo({
    required this.id,
    required this.pickupAddress,
    required this.dropOffAddress,
    required this.carmodel,
    required this.charge,
    required this.createdAt,
  });

  factory ReviewBookingInfo.fromJson(Map<String, dynamic> json) {
    return ReviewBookingInfo(
      id: json['_id'] ?? '',
      pickupAddress: json['pickupAddress'] ?? '',
      dropOffAddress: json['dropOffAddress'] ?? '',
      carmodel: json['carmodel'] ?? '',
      charge: (json['charge'] ?? 0).toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
