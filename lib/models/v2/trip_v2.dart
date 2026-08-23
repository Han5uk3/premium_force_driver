import 'package:premium_force_driver/models/v2/trip_service_type.dart';
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
  /// Opens the moment the driver sets off — `driver_en_route` — and closes
  /// when the backend accepts `completed` or the ride is cancelled. The
  /// approach is the half of the journey the customer most wants to watch:
  /// waiting at the kerb, they need to see the car coming, not only where it is
  /// once they are already in it.
  ///
  /// `TrackingService` reconciles against this and nothing else, so this getter
  /// alone decides the sharing window — and, because
  /// [TripActions.advance] asks for location permission whenever the status it
  /// is about to send shares location, it also decides when the driver is
  /// prompted.
  bool get sharesLocation => isLive;

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
    this.airportNameAr,
    this.terminalName,
    this.terminalNameAr,
    this.cityFromName,
    this.cityFromNameAr,
    this.cityToName,
    this.cityToNameAr,
    this.flightNumber,
    this.pickupDate,
    this.pickupTime,
    this.pickupDateTime,
    this.pickupTimezone,
    this.pickupLocalTimeFormatted,
    this.durationHours,
    this.distanceKm,
  });

  final TripLocationV2? pickupLocation;
  final TripLocationV2? dropOffLocation;

  /// Airport, terminal and city names as the payload spells them —
  /// `airportName`/`airportNameAr` on a populated sub-document, not `name`.
  final String? airportName;
  final String? airportNameAr;
  final String? terminalName;
  final String? terminalNameAr;
  final String? cityFromName;
  final String? cityFromNameAr;
  final String? cityToName;
  final String? cityToNameAr;

  final String? flightNumber;

  /// Pickup as the customer entered it: `YYYY-MM-DD` and `HH:mm`, a wall clock
  /// in the pickup city's timezone rather than an instant.
  final String? pickupDate;
  final String? pickupTime;

  /// Authoritative pickup instant (UTC), sent as `pickupUTC` on the booking
  /// payloads and as `pickupDateTime` on the session ones.
  final DateTime? pickupDateTime;
  final String? pickupTimezone;

  /// Server-rendered display string, e.g. `"10 Aug 2026, 05:00 PM (AST)"`.
  final String? pickupLocalTimeFormatted;

  /// Booked hours on chauffeur hire; absent or zero on transfers.
  final int? durationHours;

  final double? distanceKm;

  factory TripRouteV2.fromJson(Map<String, dynamic> json) {
    final pickup = pickMap(json, const ['pickupLocation', 'pickup']);
    final dropOff = pickMap(json, const [
      'dropOffLocation',
      'dropoffLocation',
      'dropOff',
    ]);

    // Airport, terminal and cities arrive either as populated sub-documents
    // (`airport: { airportName, airportNameAr }`) or flattened onto the route
    // (`cityFromName`), depending on whether the endpoint populated them.
    final airport = pickMap(json, const ['airport', 'airportId']);
    final terminal = pickMap(json, const ['terminal', 'terminalId']);
    final cityFrom = pickMap(json, const ['cityFrom', 'city', 'cityId']);
    final cityTo = pickMap(json, const ['cityTo']);

    return TripRouteV2(
      pickupLocation: pickup.isEmpty ? null : TripLocationV2.fromJson(pickup),
      dropOffLocation: dropOff.isEmpty
          ? null
          : TripLocationV2.fromJson(dropOff),
      airportName:
          pickString(json, const ['airportName']) ??
          pickString(airport, const ['airportName', 'name']),
      airportNameAr:
          pickString(json, const ['airportNameAr']) ??
          pickString(airport, const ['airportNameAr', 'nameAr']),
      terminalName:
          pickString(json, const ['terminalName']) ??
          pickString(terminal, const ['terminalName', 'name']),
      terminalNameAr:
          pickString(json, const ['terminalNameAr']) ??
          pickString(terminal, const ['terminalNameAr', 'nameAr']),
      cityFromName:
          pickString(json, const ['cityFromName']) ??
          pickString(cityFrom, const ['cityName', 'name']),
      cityFromNameAr:
          pickString(json, const ['cityFromNameAr']) ??
          pickString(cityFrom, const ['cityNameAr', 'nameAr']),
      cityToName:
          pickString(json, const ['cityToName']) ??
          pickString(cityTo, const ['cityName', 'name']),
      cityToNameAr:
          pickString(json, const ['cityToNameAr']) ??
          pickString(cityTo, const ['cityNameAr', 'nameAr']),
      flightNumber: pickString(json, const ['flightNumber']),
      pickupDate: pickString(json, const ['pickupDate']),
      pickupTime: pickString(json, const ['pickupTime']),
      // `pickupUTC` is what the booking endpoints actually send; reading only
      // `pickupDateTime` is what left every card and detail row showing a dash.
      pickupDateTime: pickDateTime(json, const [
        'pickupUTC',
        'pickupDateTime',
        'pickupdatetime',
        'pickupAt',
      ]),
      pickupTimezone: pickString(json, const ['pickupTimezone']),
      pickupLocalTimeFormatted: pickString(json, const [
        'pickupLocalTimeFormatted',
      ]),
      durationHours: pickInt(json, const [
        'durationHours',
        'hours',
        'estimatedHours',
      ]),
      distanceKm: pickDouble(json, const ['distanceKm', 'distance']),
    );
  }

  /// The pickup as a wall clock, or null when the route holds no date/time
  /// strings.
  ///
  /// `pickupDate` and `pickupTime` name a time in the pickup city, not an
  /// instant, so they are parsed without a zone: the result carries exactly the
  /// digits the backend sent, which formatting then leaves alone. Preferred
  /// over [pickupDateTime], which would be shifted into the *device's* timezone
  /// — a driver whose phone is not on Riyadh time would otherwise be shown the
  /// wrong hour for the pickup.
  DateTime? get pickupWallClock {
    final date = pickupDate?.trim();
    final time = pickupTime?.trim();
    if (date == null || date.isEmpty || time == null || time.isEmpty) {
      return null;
    }
    return DateTime.tryParse('${date}T$time');
  }

  String? airportDisplay(bool isArabic) =>
      _localised(airportName, airportNameAr, isArabic);

  String? terminalDisplay(bool isArabic) =>
      _localised(terminalName, terminalNameAr, isArabic);

  String? cityFromDisplay(bool isArabic) =>
      _localised(cityFromName, cityFromNameAr, isArabic);

  String? cityToDisplay(bool isArabic) =>
      _localised(cityToName, cityToNameAr, isArabic);

  static String? _localised(String? en, String? ar, bool isArabic) {
    if (isArabic && (ar?.trim().isNotEmpty ?? false)) return ar;
    return (en?.trim().isNotEmpty ?? false) ? en : ar;
  }
}

/// The vehicle class the customer booked.
///
/// Distinct from [TripFleetV2], the physical car dispatch put on the ride: the
/// two used to be merged into one object, which let the fleet record's own
/// `name`/`model` silently overwrite the booked class — and, when the fleet
/// record carried neither, left the plate attached to a class that has none.
class TripVehicleV2 {
  const TripVehicleV2({
    this.name,
    this.model,
    this.image,
    this.brandName,
    this.categoryName,
    this.maxPassengers,
    this.maxLuggage,
  });

  final String? name;
  final String? model;
  final String? image;

  /// Make and class, when the payload populates them as sub-documents.
  final String? brandName;
  final String? categoryName;

  final int? maxPassengers;
  final int? maxLuggage;

  factory TripVehicleV2.fromJson(Map<String, dynamic> json) {
    final brand = pickMap(json, const ['brand', 'brandId']);
    final category = pickMap(json, const ['category', 'categoryId']);

    return TripVehicleV2(
      name: pickString(json, const ['name', 'vehicleName', 'carName']),
      model: pickString(json, const ['model', 'vehicleModel', 'modelName']),
      image: pickString(json, const ['image', 'imageUrl', 'carImage', 'photo']),
      brandName:
          pickString(json, const ['brandName']) ??
          pickString(brand, const ['name', 'brandName']),
      categoryName:
          pickString(json, const ['categoryName']) ??
          pickString(category, const ['name', 'categoryName']),
      maxPassengers: pickInt(json, const ['maxPassengers', 'passengers']),
      maxLuggage: pickInt(json, const ['maxLuggage', 'luggage']),
    );
  }

  /// Label such as `"S450 2023"`, falling back to the make and class when the
  /// payload named neither the vehicle nor its model.
  String get label {
    final named = [
      name,
      model,
    ].where((part) => part?.trim().isNotEmpty == true).join(' ').trim();
    if (named.isNotEmpty) return named;
    return [
      brandName,
      categoryName,
    ].where((part) => part?.trim().isNotEmpty == true).join(' ').trim();
  }

  bool get isEmpty => label.isEmpty && (image?.trim().isEmpty ?? true);
}

/// The physical car dispatch assigned to the trip.
///
/// This is what the driver is actually collecting the passenger in, so it is
/// read and shown on its own rather than folded into the booked class.
class TripFleetV2 {
  const TripFleetV2({
    this.id,
    this.licensePlate,
    this.name,
    this.model,
    this.colour,
    this.image,
  });

  final String? id;
  final String? licensePlate;
  final String? name;
  final String? model;
  final String? colour;
  final String? image;

  factory TripFleetV2.fromJson(Map<String, dynamic> json) {
    // The fleet record sometimes nests the vehicle class it belongs to, which
    // is where its make and model live when the record itself carries neither.
    final vehicle = pickMap(json, const ['vehicle', 'vehicleId', 'car']);

    return TripFleetV2(
      id: pickId(json, const ['_id', 'id', 'fleetId']),
      licensePlate: pickString(json, const [
        'licensePlate',
        'plateNumber',
        'plate',
        'carLicenseNumber',
        'licenseNumber',
      ]),
      name:
          pickString(json, const ['name', 'vehicleName', 'carName']) ??
          pickString(vehicle, const ['name', 'vehicleName']),
      model:
          pickString(json, const ['model', 'vehicleModel', 'carModel']) ??
          pickString(vehicle, const ['model', 'vehicleModel']),
      colour: pickString(json, const ['color', 'colour', 'carColor']),
      image:
          pickString(json, const ['image', 'imageUrl', 'carImage', 'photo']) ??
          pickString(vehicle, const ['image', 'imageUrl']),
    );
  }

  /// Label such as `"S450 2023"`, or empty when the record only carries a plate.
  String get label => [
    name,
    model,
  ].where((part) => part?.trim().isNotEmpty == true).join(' ').trim();

  bool get isEmpty =>
      label.isEmpty &&
      (licensePlate?.trim().isEmpty ?? true) &&
      (colour?.trim().isEmpty ?? true);
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
    this.fleet,
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

  /// The class the customer booked.
  final TripVehicleV2? vehicle;

  /// The car dispatch actually put on the ride, once one is assigned.
  final TripFleetV2? fleet;

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
      vehicle: vehicleJson.isEmpty ? null : TripVehicleV2.fromJson(vehicleJson),
      fleet: fleetJson.isEmpty ? null : TripFleetV2.fromJson(fleetJson),
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

  /// The product this trip is, resolved from [serviceType] and
  /// [transferSubType]. Null when the backend sent a spelling neither knows.
  TripServiceType? get resolvedServiceType =>
      TripServiceType.fromResponse(serviceType, transferSubType);

  /// Pickup instant, for the "today" check that gates starting a ride.
  ///
  /// Display goes through [pickupDisplayInstant] instead, which prefers the
  /// wall clock the customer actually picked.
  DateTime? get pickupDateTime => route?.pickupDateTime;

  /// When the ride itself began, as the backend recorded it.
  ///
  /// Distinct from when location sharing began: sharing now opens at
  /// `driver_en_route`, which is before the passenger is aboard. Chauffeur hire
  /// is billed from the moment the trip starts, so the two must not be
  /// conflated. Read off the timeline rather than the clock, so it survives the
  /// app being killed and relaunched mid-ride.
  DateTime? get rideStartedAt {
    for (final step in timeline) {
      if (step.key == TripStatusV2.tripStarted.wireValue) return step.timestamp;
    }
    return null;
  }

  /// The pickup as the cards and the detail screen should render it.
  ///
  /// `pickupDate`/`pickupTime` name a time in the pickup city and carry no
  /// zone, so they are shown exactly as sent; `pickupUTC` is an instant, and is
  /// converted to device time here. Preferring the former keeps a driver whose
  /// phone is on another timezone from being shown the wrong hour.
  DateTime? get pickupDisplayInstant =>
      route?.pickupWallClock ?? route?.pickupDateTime?.toLocal();

  /// The server's own rendering of the pickup, used only when neither the wall
  /// clock nor the instant came back.
  String? get pickupLocalTimeFormatted => route?.pickupLocalTimeFormatted;

  /// Pickup address, falling back to the terminal or airport on an arrival where
  /// the pickup point is a gate rather than a street address.
  String? get pickupAddress =>
      route?.pickupLocation?.address ??
      _joinNonEmpty([route?.terminalName, route?.airportName]) ??
      route?.cityFromName;

  /// Drop-off address. Null for chauffeur hire, which has no destination.
  String? get dropOffAddress =>
      route?.dropOffLocation?.address ??
      (isChauffeur ? null : route?.cityToName);

  /// Whether the trip has a destination to navigate to.
  ///
  /// Hourly chauffeur hire has none — the customer books the car by the hour
  /// and directs it themselves — and the backend sends `0,0` rather than
  /// omitting the field, so a null check alone would not catch it.
  bool get hasDropOffPoint => (dropOffLat ?? 0) != 0 && (dropOffLng ?? 0) != 0;

  double? get pickupLat => route?.pickupLocation?.lat;
  double? get pickupLng => route?.pickupLocation?.lng;
  double? get dropOffLat => route?.dropOffLocation?.lat;
  double? get dropOffLng => route?.dropOffLocation?.lng;

  /// Whether this is hourly chauffeur hire rather than a point-to-point
  /// transfer.
  ///
  /// A chauffeur booking reports its `chauffeurType` â `hourly`, or one of the
  /// fixed packages â as its `serviceType`, so matching on the word
  /// "chauffeur" alone missed every hourly hire. [TripServiceType.fromResponse]
  /// knows all the spellings; the booked hours remain a fallback.
  bool get isChauffeur =>
      resolvedServiceType?.isChauffeur ?? (route?.durationHours ?? 0) > 0;

  /// Booked hours on chauffeur hire, or null on anything that is not hourly.
  int? get durationHours {
    final hours = route?.durationHours ?? 0;
    return hours > 0 ? hours : null;
  }

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
    this.totalPages,
  });

  final List<TripV2> trips;

  /// The page these trips are from — as the response echoed it, or as it was
  /// asked for when the response said nothing.
  ///
  /// Defaulting a missing value to 1 is what would break paging outright: the
  /// provider records it as the page it now holds, so every `loadMore` would
  /// ask for page 2 again, forever.
  final int page;

  final int limit;
  final int total;

  /// Null when the response carried no pagination metadata at all.
  final int? totalPages;

  /// [requestedPage] and [requestedLimit] are what was asked for, and stand in
  /// wherever the response does not say.
  factory TripListPage.fromJson(
    Map<String, dynamic> json, {
    int requestedPage = 1,
    int requestedLimit = 10,
  }) {
    // Pagination arrives either nested under `meta`/`pagination` or flattened
    // onto the payload; reading the wrong one would pin every filter to a
    // single page, so both are tried.
    final meta = pickMap(json, const ['meta', 'pagination']);
    final source = meta.isNotEmpty ? meta : json;

    final limit =
        pickInt(source, const ['limit', 'pageSize', 'perPage']) ??
        requestedLimit;
    final total =
        pickInt(source, const ['totalItems', 'total', 'totalCount']) ?? 0;

    return TripListPage(
      trips: pickMapList(json, const [
        'bookings',
        'trips',
        'data',
        'items',
      ]).map(TripV2.fromJson).toList(),
      page: pickInt(source, const ['page', 'currentPage']) ?? requestedPage,
      limit: limit,
      total: total,
      totalPages:
          pickInt(source, const ['totalPages', 'pages']) ??
          (total > 0 && limit > 0 ? (total + limit - 1) ~/ limit : null),
    );
  }

  /// Whether asking for another page is worth it.
  ///
  /// The metadata is believed when it is there. When it is not — and the
  /// driver endpoint has been known to send a bare `{trips: [...]}` — a full
  /// page is taken to mean there may be another, and a short one to mean the
  /// end. Without that fallback the list would stop dead at ten trips.
  bool get hasMore {
    final pages = totalPages;
    if (pages != null) return page < pages;
    return limit > 0 && trips.length >= limit;
  }
}
