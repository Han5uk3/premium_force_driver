/// Driver model representing a registered driver in the Premium Force Driver app.
///
/// Fields match the AWS/MongoDB backend schema for drivers:
/// - Basic: [uid], [firstName], [lastName], [email], [countryCode], [phoneNumber]
/// - Profile: [profileImageUrl], [location], [lat], [long]
/// - Licensing: [licenseNumber], [licenseExpiry], [licenseImageUrl], [isLicenseVerified]
/// - Vehicle: [assignedCar] (car ID or full car object)
/// - Status: [isActive], [isVerified], [documentVerified]
/// - Metrics: [rating], [totalRides], [totalEarnings], [completedRides]
/// - Dates: [createdAt], [updatedAt]
class DriverModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String countryCode;
  final String phoneNumber;
  final String? location;
  final double? lat;
  final double? long;
  final String? profileImageUrl;

  // Driver-specific fields
  final String? licenseNumber;
  final DateTime? licenseExpiry;
  final String? licenseImageUrl;
  final bool isLicenseVerified;

  // Vehicle assignment
  final String? assignedCarId;

  // Account status
  final bool isActive;
  final bool isVerified;
  final bool documentVerified;

  // Performance metrics
  final double rating;
  final int completedRides;
  final double totalEarnings;

  // New fields for status & active vehicle
  final bool isBusy;
  final bool isWorkstarted;
  final bool hasActiveVehicle;
  final ActiveVehicleModel? activeVehicle;

  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DriverModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.countryCode,
    required this.phoneNumber,
    this.location,
    this.lat,
    this.long,
    this.profileImageUrl,
    this.licenseNumber,
    this.licenseExpiry,
    this.licenseImageUrl,
    this.isLicenseVerified = false,
    this.assignedCarId,
    this.isActive = true,
    this.isVerified = false,
    this.documentVerified = false,
    this.rating = 0.0,
    this.completedRides = 0,
    this.totalEarnings = 0.0,
    this.isBusy = false,
    this.isWorkstarted = false,
    this.hasActiveVehicle = false,
    this.activeVehicle,
    required this.createdAt,
    this.updatedAt,
  });

  /// Full name of the driver (firstName + lastName)
  String get fullName => '$firstName $lastName';

  // ---------------------------------------------------------------------------
  // JSON Serialization
  // ---------------------------------------------------------------------------

  /// Creates a [DriverModel] from a JSON map returned by the backend.
  ///
  /// Handles various backend response formats:
  /// - Name can be `username`, `firstName`/`lastName`, or `name`
  /// - Profile images can be nested objects or direct URLs
  /// - Location can be a string or nested object with lat/long
  factory DriverModel.fromJson(Map<String, dynamic> json) {
    // ── Name extraction ────────────────────────────────────
    String firstName = json['firstName']?.toString() ?? '';
    String lastName = json['lastName']?.toString() ?? '';

    if (firstName.isEmpty && lastName.isEmpty) {
      final name =
          (json['driverName'] ?? json['username'] ?? json['name'] ?? '').toString();
      final parts = name.trim().split(' ');
      firstName = parts.isNotEmpty ? parts[0] : '';
      lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    } else if (firstName.isEmpty) {
      final name =
          (json['driverName'] ?? json['username'] ?? json['name'] ?? '').toString();
      firstName = name;
    }

    // ── Profile image ──────────────────────────────────────
    String? profileImageUrl;
    final profileRaw = json['profileImage'];
    if (profileRaw is String) {
      profileImageUrl = profileRaw;
    } else if (profileRaw is Map<String, dynamic>) {
      profileImageUrl = profileRaw['url'] as String?;
    }

    // ── License image ──────────────────────────────────────
    String? licenseImageUrl;
    final licenseRaw = json['licenseImage'];
    if (licenseRaw is String) {
      licenseImageUrl = licenseRaw;
    } else if (licenseRaw is Map<String, dynamic>) {
      licenseImageUrl = licenseRaw['url'] as String?;
    }

    // ── Location ───────────────────────────────────────────
    String? locationStr;
    double? lat;
    double? lng;
    final locationRaw = json['location'];
    if (locationRaw is String) {
      locationStr = locationRaw;
      lat = (json['lat'] as num?)?.toDouble();
      lng = (json['long'] as num?)?.toDouble();
    } else if (locationRaw is Map<String, dynamic>) {
      lat = (locationRaw['lat'] as num?)?.toDouble();
      lng = (locationRaw['long'] as num?)?.toDouble();
    } else {
      lat = (json['lat'] as num?)?.toDouble();
      lng = (json['long'] as num?)?.toDouble();
    }

    // ── License expiry ─────────────────────────────────────
    DateTime? licenseExpiry;
    final expiryRaw = json['licenseExpiry'];
    if (expiryRaw is String) {
      licenseExpiry = DateTime.tryParse(expiryRaw);
    } else if (expiryRaw is int) {
      licenseExpiry = DateTime.fromMillisecondsSinceEpoch(expiryRaw);
    }

    // ── Assigned car ───────────────────────────────────────
    String? assignedCarId;
    final carRaw = json['assignedCar'];
    if (carRaw is String) {
      assignedCarId = carRaw;
    } else if (carRaw is Map<String, dynamic>) {
      assignedCarId = carRaw['_id'] ?? carRaw['id'];
    }

    // ── Active Vehicle Parsing ─────────────────────────────
    final isBusyVal = (json['isBusy'] as bool?) ?? false;
    final isWorkstartedVal = (json['isWorkstarted'] as bool?) ?? false;
    final hasActiveVehicleVal = (json['hasActiveVehicle'] as bool?) ?? false;
    ActiveVehicleModel? activeVehicleVal;
    if (json['activeVehicle'] is Map<String, dynamic>) {
      activeVehicleVal = ActiveVehicleModel.fromJson(json['activeVehicle']);
    }

    return DriverModel(
      uid: (json['_id'] ?? json['id'] ?? json['uid'] ?? '').toString(),
      firstName: firstName,
      lastName: lastName,
      email: json['email']?.toString() ?? '',
      countryCode: (json['countryCode'] ?? '+966').toString(),
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      location: locationStr,
      lat: lat,
      long: lng,
      profileImageUrl: profileImageUrl,
      licenseNumber: json['licenseNumber'] as String?,
      licenseExpiry: licenseExpiry,
      licenseImageUrl: licenseImageUrl,
      isLicenseVerified: (json['isLicenseVerified'] as bool?) ?? false,
      assignedCarId: assignedCarId,
      isActive: (json['isActive'] as bool?) ?? true,
      isVerified: (json['isVerified'] as bool?) ?? false,
      documentVerified: (json['documentVerified'] as bool?) ?? false,
      rating: ((json['rating'] as num?)?.toDouble()) ?? 0.0,
      completedRides: (json['completedRides'] as int?) ?? 0,
      totalEarnings: ((json['totalEarnings'] as num?)?.toDouble()) ?? 0.0,
      isBusy: isBusyVal,
      isWorkstarted: isWorkstartedVal,
      hasActiveVehicle: hasActiveVehicleVal,
      activeVehicle: activeVehicleVal,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is DateTime
                ? json['createdAt'] as DateTime
                : DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is DateTime
                ? json['updatedAt'] as DateTime
                : DateTime.tryParse(json['updatedAt'].toString()))
          : null,
    );
  }

  /// Converts this [DriverModel] to a JSON-compatible map for local storage.
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'countryCode': countryCode,
      'phoneNumber': phoneNumber,
      'location': location,
      'lat': lat,
      'long': long,
      'profileImageUrl': profileImageUrl,
      'licenseNumber': licenseNumber,
      'licenseExpiry': licenseExpiry?.toIso8601String(),
      'licenseImageUrl': licenseImageUrl,
      'isLicenseVerified': isLicenseVerified,
      'assignedCarId': assignedCarId,
      'isActive': isActive,
      'isVerified': isVerified,
      'documentVerified': documentVerified,
      'rating': rating,
      'completedRides': completedRides,
      'totalEarnings': totalEarnings,
      'isBusy': isBusy,
      'isWorkstarted': isWorkstarted,
      'hasActiveVehicle': hasActiveVehicle,
      'activeVehicle': activeVehicle?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // Copy With
  // ---------------------------------------------------------------------------

  DriverModel copyWith({
    String? uid,
    String? firstName,
    String? lastName,
    String? email,
    String? countryCode,
    String? phoneNumber,
    String? location,
    double? lat,
    double? long,
    String? profileImageUrl,
    String? licenseNumber,
    DateTime? licenseExpiry,
    String? licenseImageUrl,
    bool? isLicenseVerified,
    String? assignedCarId,
    bool? isActive,
    bool? isVerified,
    bool? documentVerified,
    double? rating,
    int? completedRides,
    double? totalEarnings,
    bool? isBusy,
    bool? isWorkstarted,
    bool? hasActiveVehicle,
    ActiveVehicleModel? activeVehicle,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DriverModel(
      uid: uid ?? this.uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      countryCode: countryCode ?? this.countryCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      location: location ?? this.location,
      lat: lat ?? this.lat,
      long: long ?? this.long,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseExpiry: licenseExpiry ?? this.licenseExpiry,
      licenseImageUrl: licenseImageUrl ?? this.licenseImageUrl,
      isLicenseVerified: isLicenseVerified ?? this.isLicenseVerified,
      assignedCarId: assignedCarId ?? this.assignedCarId,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      documentVerified: documentVerified ?? this.documentVerified,
      rating: rating ?? this.rating,
      completedRides: completedRides ?? this.completedRides,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      isBusy: isBusy ?? this.isBusy,
      isWorkstarted: isWorkstarted ?? this.isWorkstarted,
      hasActiveVehicle: hasActiveVehicle ?? this.hasActiveVehicle,
      activeVehicle: activeVehicle ?? this.activeVehicle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Equality & Hashing
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DriverModel &&
        other.uid == uid &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.email == email &&
        other.countryCode == countryCode &&
        other.phoneNumber == phoneNumber &&
        other.location == location &&
        other.lat == lat &&
        other.long == long &&
        other.profileImageUrl == profileImageUrl &&
        other.licenseNumber == licenseNumber &&
        other.licenseExpiry == licenseExpiry &&
        other.licenseImageUrl == licenseImageUrl &&
        other.isLicenseVerified == isLicenseVerified &&
        other.assignedCarId == assignedCarId &&
        other.isActive == isActive &&
        other.isVerified == isVerified &&
        other.documentVerified == documentVerified &&
        other.rating == rating &&
        other.completedRides == completedRides &&
        other.totalEarnings == totalEarnings &&
        other.isBusy == isBusy &&
        other.isWorkstarted == isWorkstarted &&
        other.hasActiveVehicle == hasActiveVehicle &&
        other.activeVehicle == activeVehicle &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      uid,
      firstName,
      lastName,
      email,
      countryCode,
      phoneNumber,
      location,
      lat,
      long,
      profileImageUrl,
      licenseNumber,
      licenseExpiry,
      licenseImageUrl,
      isLicenseVerified,
      assignedCarId,
      isActive,
      isVerified,
      documentVerified,
      rating,
      completedRides,
      totalEarnings,
      isBusy,
      isWorkstarted,
      hasActiveVehicle,
      activeVehicle,
      createdAt,
      updatedAt,
    ]);
  }

  @override
  String toString() {
    return 'DriverModel('
        'uid: $uid, '
        'fullName: $fullName, '
        'phoneNumber: $phoneNumber, '
        'isActive: $isActive, '
        'isWorkstarted: $isWorkstarted, '
        'hasActiveVehicle: $hasActiveVehicle, '
        'rating: $rating, '
        'completedRides: $completedRides'
        ')';
  }
}

class ActiveVehicleModel {
  final String id;
  final String carLicenseNumber;
  final bool isBusyCar;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? activeHistoryId;
  final String? driverId;
  final DateTime? lastTakenOutAt;
  final DateTime? lastReturnAt;
  final ActiveCarDetails? car;

  ActiveVehicleModel({
    required this.id,
    required this.carLicenseNumber,
    required this.isBusyCar,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.activeHistoryId,
    this.driverId,
    this.lastTakenOutAt,
    this.lastReturnAt,
    this.car,
  });

  factory ActiveVehicleModel.fromJson(Map<String, dynamic> json) {
    final carRaw = json['carID'] ?? json['car'];
    final carData = carRaw is Map<String, dynamic> ? ActiveCarDetails.fromJson(carRaw) : null;

    return ActiveVehicleModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      carLicenseNumber: json['carLicenseNumber']?.toString() ?? '',
      isBusyCar: (json['isBusyCar'] as bool?) ?? false,
      isActive: (json['isActive'] as bool?) ?? true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      activeHistoryId: (json['activeHistoryID'] ?? json['activeHistoryId'])?.toString(),
      driverId: (json['driverID'] ?? json['driverId'])?.toString(),
      lastTakenOutAt: json['lastTakenOutAt'] != null ? DateTime.tryParse(json['lastTakenOutAt'].toString()) : null,
      lastReturnAt: json['lastReturnAt'] != null ? DateTime.tryParse(json['lastReturnAt'].toString()) : null,
      car: carData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'carLicenseNumber': carLicenseNumber,
      'isBusyCar': isBusyCar,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'activeHistoryID': activeHistoryId,
      'driverID': driverId,
      'lastTakenOutAt': lastTakenOutAt?.toIso8601String(),
      'lastReturnAt': lastReturnAt?.toIso8601String(),
      'carID': car?.toJson(),
    };
  }
}

class ActiveCarDetails {
  final String id;
  final String carName;
  final String model;
  final int numberOfPassengers;
  final String? carImageUrl;

  ActiveCarDetails({
    required this.id,
    required this.carName,
    required this.model,
    required this.numberOfPassengers,
    this.carImageUrl,
  });

  factory ActiveCarDetails.fromJson(Map<String, dynamic> json) {
    String? imageUrl;
    final imageRaw = json['carImage'];
    if (imageRaw is String) {
      imageUrl = imageRaw;
    } else if (imageRaw is Map<String, dynamic>) {
      imageUrl = imageRaw['url'] as String?;
    }

    return ActiveCarDetails(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      carName: json['carName']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      numberOfPassengers: (json['numberOfPassengers'] as int?) ?? 0,
      carImageUrl: imageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'carName': carName,
      'model': model,
      'numberOfPassengers': numberOfPassengers,
      'carImage': carImageUrl,
    };
  }
}
