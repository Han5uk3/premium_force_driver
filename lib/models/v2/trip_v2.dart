import 'package:premium_force_driver/utils/json_utils.dart';

/// Trip models for the v2 driver surface — `GET /driver/bookings/my-trips`,
/// `GET /driver/bookings/:id` and `PATCH /driver/bookings/:id/status`.
///
/// All three return the same booking shape, so one model covers the list, the
/// detail view and the reply to a status change.

/// Lifecycle of a trip as the driver sees it.
///
/// The driver may only ever advance one step at a time — the backend rejects a
/// skip — so [next] is the single action the UI should ever offer.
enum TripStatusV2 {
  pendingPayment('pending_payment'),
  confirmed('confirmed'),
  driverAssigned('driver_assigned'),
  driverEnRoute('driver_en_route'),
  driverArrived('driver_arrived'),
  tripStarted('trip_started'),
  completed('completed'),
  cancelled('cancelled'),
  unknown('unknown');

  const TripStatusV2(this.wireValue);

  /// The exact string the API uses.
  final String wireValue;

  static TripStatusV2 fromWire(String? value) {
    final normalised = value?.trim().toLowerCase().replaceAll('-', '_');
    if (normalised == null || normalised.isEmpty) return unknown;
    for (final status in values) {
      if (status.wireValue == normalised) return status;
    }
    // Tolerate spellings the backend uses interchangeably, plus the v1 codes
    // still present on older records.
    return switch (normalised) {
      'canceled' || 'ca' => cancelled,
      'in_trip' || 'ontrip' || 'on_trip' || 'started' || 'og' => tripStarted,
      'en_route' || 'enroute' => driverEnRoute,
      'arrived' => driverArrived,
      'assigned' || 'ac' || 'accepted' => driverAssigned,
      'awaiting_payment' || 'paymentpending' => pendingPayment,
      'c' => completed,
      _ => unknown,
    };
  }

  /// The one status the driver may move to from here, or null when there is
  /// nothing left to do (or nothing they are allowed to do yet).
  ///
  /// Mirrors the endpoint's own guard: `driver_assigned` → `driver_en_route` →
  /// `driver_arrived` → `trip_started` → `completed`. Anything before
  /// `driver_assigned` is the admin's or the customer's to move.
  TripStatusV2? get next => switch (this) {
    driverAssigned => driverEnRoute,
    driverEnRoute => driverArrived,
    driverArrived => tripStarted,
    tripStarted => completed,
    _ => null,
  };

  /// Whether the driver can act on the trip at all.
  bool get isActionable => next != null;

  /// Whether the ride is under way.
  bool get isLive =>
      this == driverEnRoute || this == driverArrived || this == tripStarted;

  /// Whether the driver's location is published to the customer.
  ///
  /// From the moment the ride starts until it ends — the window the backend
  /// opens by accepting `trip_started` and closes by accepting `completed`.
  /// `TrackingService` reconciles against this and nothing else, so widening it
  /// to [driverEnRoute] here is all it takes to let customers watch the car
  /// approach as well.
  bool get sharesLocation => this == tripStarted;

  /// Whether the trip is over, one way or the other.
  bool get isFinished => this == completed || this == cancelled;

  /// Whether completing from here needs the extra-charges prompt.
  bool get collectsExtrasOnNext => next == completed;
}

/// Which slice of the driver's trips to fetch.
///
/// The endpoint takes exactly these two values for `filter`; omitting it returns
/// everything assigned to the driver.
enum TripFilterV2 {
  active('active'),
  completed('completed');

  const TripFilterV2(this.wireValue);

  final String wireValue;
}

/// How the driver took payment for on-the-spot extras.
enum ExtraPaymentMethodV2 {
  pos('pos'),
  cash('cash');

  const ExtraPaymentMethodV2(this.wireValue);

  final String wireValue;

  static ExtraPaymentMethodV2 fromWire(String? value) {
    final normalised = value?.trim().toLowerCase();
    return normalised == 'cash' ? cash : pos;
  }
}

/// A step in the trip's progress timeline, rendered as a vertical stepper.
class TripTimelineStep {
  const TripTimelineStep({
    required this.key,
    required this.label,
    this.labelAr,
    this.isCompleted = false,
    this.isCurrent = false,
    this.isCancelled = false,
    this.timestamp,
  });

  final String key;
  final String label;
  final String? labelAr;
  final bool isCompleted;
  final bool isCurrent;
  final bool isCancelled;
  final DateTime? timestamp;

  factory TripTimelineStep.fromJson(Map<String, dynamic> json) {
    return TripTimelineStep(
      key: pickString(json, const ['key']) ?? '',
      label: pickString(json, const ['label']) ?? '',
      labelAr: pickString(json, const ['labelAr']),
      isCompleted: pickBool(json, const ['isCompleted']) ?? false,
      isCurrent: pickBool(json, const ['isCurrent']) ?? false,
      isCancelled: pickBool(json, const ['isCancelled']) ?? false,
      timestamp: pickDateTime(json, const ['timestamp']),
    );
  }

  String displayLabel(bool isArabic) => isArabic
      ? (labelAr?.trim().isNotEmpty == true ? labelAr! : label)
      : label;
}

/// Charges the driver collected during the ride — waiting time, parking, tolls.
///
/// Recorded when the trip is completed; the backend adds [amount] to the
/// booking's grand total.
class ExtraChargesV2 {
  const ExtraChargesV2({
    this.hasExtraCharges = false,
    this.amount = 0,
    this.paymentMethod,
    this.notes,
    this.collectedAt,
  });

  final bool hasExtraCharges;
  final double amount;
  final ExtraPaymentMethodV2? paymentMethod;
  final String? notes;
  final DateTime? collectedAt;

  factory ExtraChargesV2.fromJson(Map<String, dynamic> json) {
    final amount = pickDouble(json, const ['amount']) ?? 0;
    return ExtraChargesV2(
      hasExtraCharges:
          pickBool(json, const ['hasExtraCharges']) ?? (amount > 0),
      amount: amount,
      paymentMethod: json['paymentMethod'] == null
          ? null
          : ExtraPaymentMethodV2.fromWire(
              pickString(json, const ['paymentMethod']),
            ),
      notes: pickString(json, const ['notes']),
      collectedAt: pickDateTime(json, const ['collectedAt']),
    );
  }

  bool get isEmpty => !hasExtraCharges && amount <= 0;
}

/// A point on the trip — pickup or drop-off.
class TripLocationV2 {
  const TripLocationV2({this.address, this.lat, this.lng});

  final String? address;
  final double? lat;
  final double? lng;

  factory TripLocationV2.fromJson(Map<String, dynamic> json) {
    return TripLocationV2(
      address: pickString(json, const ['address', 'name', 'formattedAddress']),
      lat: pickDouble(json, const ['lat', 'latitude']),
      lng: pickDouble(json, const ['lng', 'lon', 'longitude']),
    );
  }

  bool get hasCoordinates => lat != null && lng != null;
}

/// The route the trip follows, including its scheduled pickup.
class TripRouteV2 {
  const TripRouteV2({
    this.pickupLocation,
    this.dropOffLocation,
    this.airportName,
    this.terminalName,
    this.cityName,
    this.flightNumber,
    this.pickupDateTime,
    this.durationHours,
  });

  final TripLocationV2? pickupLocation;
  final TripLocationV2? dropOffLocation;
  final String? airportName;
  final String? terminalName;
  final String? cityName;
  final String? flightNumber;
  final DateTime? pickupDateTime;

  /// Booked hours on chauffeur hire; absent or zero on transfers.
  final int? durationHours;

  factory TripRouteV2.fromJson(Map<String, dynamic> json) {
    final pickup = pickMap(json, const ['pickupLocation', 'pickup']);
    final dropOff = pickMap(json, const [
      'dropOffLocation',
      'dropoffLocation',
      'dropOff',
    ]);

    // Airport, terminal and city arrive either as ids or as populated
    // sub-documents, depending on the endpoint.
    final airport = pickMap(json, const ['airport', 'airportId']);
    final terminal = pickMap(json, const ['terminal', 'terminalId']);
    final city = pickMap(json, const ['city', 'cityId']);

    return TripRouteV2(
      pickupLocation: pickup.isEmpty ? null : TripLocationV2.fromJson(pickup),
      dropOffLocation: dropOff.isEmpty
          ? null
          : TripLocationV2.fromJson(dropOff),
      airportName: pickString(airport, const ['name']),
      terminalName: pickString(terminal, const ['name']),
      cityName: pickString(city, const ['name', 'nameEn']),
      flightNumber: pickString(json, const ['flightNumber']),
      pickupDateTime: pickDateTime(json, const [
        'pickupDateTime',
        'pickupdatetime',
        'pickupAt',
      ]),
      durationHours: pickInt(json, const [
        'durationHours',
        'hours',
        'estimatedHours',
      ]),
    );
  }
}

/// The vehicle class the customer booked.
class TripVehicleV2 {
  const TripVehicleV2({this.name, this.model, this.image, this.licensePlate});

  final String? name;
  final String? model;
  final String? image;

  /// Plate of the physical car assigned to the trip, when the payload nests the
  /// fleet record.
  final String? licensePlate;

  factory TripVehicleV2.fromJson(Map<String, dynamic> json) {
    return TripVehicleV2(
      name: pickString(json, const ['name', 'vehicleName', 'brand']),
      model: pickString(json, const ['model', 'vehicleModel']),
      image: pickString(json, const ['image', 'imageUrl', 'photo']),
      licensePlate: pickString(json, const [
        'licensePlate',
        'plateNumber',
        'plate',
      ]),
    );
  }

  /// Label such as `"S450 2023"`.
  String get label => [
    name,
    model,
  ].where((part) => part?.trim().isNotEmpty == true).join(' ').trim();
}

/// The passenger the driver is collecting.
class TripCustomerV2 {
  const TripCustomerV2({
    this.name,
    this.phone,
    this.passengersCount = 1,
    this.luggageCount,
    this.notes,
  });

  final String? name;
  final String? phone;
  final int passengersCount;
  final int? luggageCount;

  /// Anything the customer asked for when booking.
  final String? notes;

  factory TripCustomerV2.fromJson(Map<String, dynamic> json) {
    return TripCustomerV2(
      name: pickString(json, const [
        'name',
        'passengerName',
        'fullName',
        'username',
      ]),
      phone: pickString(json, const [
        'phone',
        'phoneNumber',
        'mobile',
        'passengerPhone',
      ]),
      passengersCount:
          pickInt(json, const ['passengersCount', 'passengers']) ?? 1,
      luggageCount: pickInt(json, const ['luggageCount', 'luggage']),
      notes: pickString(json, const ['notes', 'specialRequests']),
    );
  }
}

/// What the trip is worth, as the backend calculated it.
class TripPricingV2 {
  const TripPricingV2({
    this.currency = 'SAR',
    this.baseFare,
    this.subtotal,
    this.vatAmount,
    this.totalAmount,
    this.grandTotal,
  });

  final String currency;
  final double? baseFare;
  final double? subtotal;
  final double? vatAmount;
  final double? totalAmount;

  /// [totalAmount] plus any extras collected on the spot.
  final double? grandTotal;

  factory TripPricingV2.fromJson(Map<String, dynamic> json) {
    return TripPricingV2(
      currency: pickString(json, const ['currency']) ?? 'SAR',
      baseFare: pickDouble(json, const ['baseFare']),
      subtotal: pickDouble(json, const ['subtotal']),
      vatAmount: pickDouble(json, const ['vatAmount']),
      totalAmount: pickDouble(json, const ['totalAmount']),
      grandTotal: pickDouble(json, const ['grandTotal']),
    );
  }

  /// What the driver should quote — the grand total once extras are in.
  double get payable => grandTotal ?? totalAmount ?? 0;
}

/// A trip assigned to the signed-in driver.
class TripV2 {
  const TripV2({
    required this.id,
    required this.bookingNumber,
    required this.status,
    this.customerId,
    this.serviceType,
    this.transferSubType,
    this.route,
    this.vehicle,
    this.customer,
    this.pricing,
    this.extraCharges,
    this.rideNotes,
    this.voiceNoteUrl,
    this.rating,
    this.reviewText,
    this.timeline = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String bookingNumber;
  final TripStatusV2 status;

  /// The customer this ride belongs to, written into the tracking session so the
  /// customer app can confirm it is watching its own ride.
  final String? customerId;

  final String? serviceType;
  final String? transferSubType;
  final TripRouteV2? route;
  final TripVehicleV2? vehicle;
  final TripCustomerV2? customer;
  final TripPricingV2? pricing;
  final ExtraChargesV2? extraCharges;
  final String? rideNotes;
  final String? voiceNoteUrl;

  /// The customer's rating, once they have left one.
  final double? rating;
  final String? reviewText;

  /// Empty on list payloads; populated on detail and on a status change.
  final List<TripTimelineStep> timeline;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TripV2.fromJson(Map<String, dynamic> json) {
    final routeJson = pickMap(json, const ['route']);
    final vehicleJson = pickMap(json, const ['vehicle']);
    final fleetJson = pickMap(json, const ['fleet']);
    final pricingJson = pickMap(json, const ['pricing']);
    final extrasJson = pickMap(json, const ['extraCharges']);
    final reviewJson = pickMap(json, const ['review']);

    // Passenger details live under `passengerDetails` on the booking and under
    // `customer` when the customer document itself is populated.
    final passengerJson = pickMap(json, const ['passengerDetails']);
    final customerJson = pickMap(json, const ['customer', 'customerID']);

    return TripV2(
      id: pickId(json, const ['_id', 'id', 'bookingId']) ?? '',
      bookingNumber: pickString(json, const ['bookingNumber']) ?? '',
      status: TripStatusV2.fromWire(
        pickString(json, const ['bookingStatus', 'status']),
      ),
      customerId: pickId(json, const ['customerID', 'customerId', 'customer']),
      serviceType: pickString(json, const ['serviceType']),
      transferSubType: pickString(json, const ['transferSubType']),
      route: routeJson.isEmpty ? null : TripRouteV2.fromJson(routeJson),
      vehicle: (vehicleJson.isEmpty && fleetJson.isEmpty)
          ? null
          : TripVehicleV2.fromJson({...vehicleJson, ...fleetJson}),
      customer: (passengerJson.isEmpty && customerJson.isEmpty)
          ? null
          : TripCustomerV2.fromJson({...customerJson, ...passengerJson}),
      pricing: pricingJson.isEmpty ? null : TripPricingV2.fromJson(pricingJson),
      extraCharges: extrasJson.isEmpty
          ? null
          : ExtraChargesV2.fromJson(extrasJson),
      rideNotes: pickString(json, const ['rideNotes', 'notes']),
      voiceNoteUrl: pickString(json, const ['voiceNote', 'voiceNoteUrl']),
      rating:
          pickDouble(json, const ['rating', 'rate']) ??
          pickDouble(reviewJson, const ['rate', 'rating']),
      reviewText:
          pickString(json, const ['review', 'reviewText']) ??
          pickString(reviewJson, const ['reviewText']),
      timeline: pickMapList(json, const [
        'timeline',
      ]).map(TripTimelineStep.fromJson).toList(),
      createdAt: pickDateTime(json, const ['createdAt']),
      updatedAt: pickDateTime(json, const ['updatedAt']),
    );
  }

  /// Pickup instant, for date/time display and for the "today" check that gates
  /// starting a ride.
  DateTime? get pickupDateTime => route?.pickupDateTime;

  /// Pickup address, falling back to the terminal or airport on an arrival where
  /// the pickup point is a gate rather than a street address.
  String? get pickupAddress =>
      route?.pickupLocation?.address ??
      _joinNonEmpty([route?.terminalName, route?.airportName]);

  /// Drop-off address. Null for chauffeur hire, which has no destination.
  String? get dropOffAddress => route?.dropOffLocation?.address;

  double? get pickupLat => route?.pickupLocation?.lat;
  double? get pickupLng => route?.pickupLocation?.lng;
  double? get dropOffLat => route?.dropOffLocation?.lat;
  double? get dropOffLng => route?.dropOffLocation?.lng;

  /// Whether this is hourly chauffeur hire rather than a point-to-point transfer.
  bool get isChauffeur =>
      (serviceType?.toLowerCase().contains('chauffeur') ?? false) ||
      (route?.durationHours ?? 0) > 0;

  int get passengersCount => customer?.passengersCount ?? 1;

  String get currency => pricing?.currency ?? 'SAR';

  /// Whether the customer has rated the ride.
  bool get isRated => (rating ?? 0) > 0;

  /// Whether extras were collected during the ride.
  bool get hasExtraCharges => !(extraCharges?.isEmpty ?? true);

  static String? _joinNonEmpty(List<String?> parts) {
    final joined = parts
        .where((part) => part?.trim().isNotEmpty == true)
        .join(', ');
    return joined.isEmpty ? null : joined;
  }
}

/// One page of `GET /driver/bookings/my-trips`.
class TripListPage {
  const TripListPage({
    required this.trips,
    this.page = 1,
    this.limit = 10,
    this.total = 0,
    this.totalPages = 1,
  });

  final List<TripV2> trips;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory TripListPage.fromJson(Map<String, dynamic> json) {
    // Pagination arrives either nested under `meta`/`pagination` or flattened
    // onto the payload; reading the wrong one would pin every filter to a single
    // page, so both are tried.
    final meta = pickMap(json, const ['meta', 'pagination']);
    final source = meta.isNotEmpty ? meta : json;

    final page = pickInt(source, const ['page', 'currentPage']) ?? 1;
    final limit = pickInt(source, const ['limit', 'pageSize', 'perPage']) ?? 10;
    final total =
        pickInt(source, const ['totalItems', 'total', 'totalCount']) ?? 0;

    return TripListPage(
      trips: pickMapList(json, const [
        'bookings',
        'trips',
        'data',
        'items',
      ]).map(TripV2.fromJson).toList(),
      page: page,
      limit: limit,
      total: total,
      totalPages:
          pickInt(source, const ['totalPages', 'pages']) ??
          (total > 0 && limit > 0 ? (total + limit - 1) ~/ limit : 1),
    );
  }

  bool get hasMore => page < totalPages;
}
