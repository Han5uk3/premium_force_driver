/// The four bookable products, as the driver surface sees them.
///
/// The driver never *creates* a booking, so unlike the customer app's copy this
/// carries no session paths or `catcode` bridge — only what is needed to read a
/// `serviceType`/`transferSubType` pair back off a trip and name it.
enum TripServiceType {
  airportArrival,
  airportDeparture,
  chauffeur,
  privateTransfer;

  bool get isAirport => this == airportArrival || this == airportDeparture;
  bool get isChauffeur => this == chauffeur;

  /// Reconstruct from a trip payload, using [subType] to disambiguate the two
  /// airport directions.
  static TripServiceType? fromResponse(String? serviceType, String? subType) {
    final normalisedSub = subType?.toLowerCase().replaceAll('-', '_').trim();
    if (normalisedSub == 'airport_arrival') return airportArrival;
    if (normalisedSub == 'airport_departure') return airportDeparture;

    return switch (serviceType?.toLowerCase().replaceAll('-', '_').trim()) {
      'airport_transfer' => airportArrival,
      // A chauffeur booking reports its `chauffeurType` as the service type, so
      // both hourly hire and the fixed packages land here.
      'hourly' || 'chauffeur' || 'package' => chauffeur,
      'private_transfer' => privateTransfer,
      _ => null,
    };
  }
}
