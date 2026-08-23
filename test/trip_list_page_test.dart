import 'package:flutter_test/flutter_test.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';

/// Guards on paging `GET /driver/bookings/my-trips`.
///
/// Both tabs page through the same code, and both used to be able to stop dead
/// at the first ten trips: the endpoint does not always return pagination
/// metadata, and a missing `page` used to parse as 1 — which made the provider
/// record page 1 as the page it held, so every "load more" asked for page 2
/// again.
void main() {
  Map<String, dynamic> payload(int count, {Map<String, dynamic>? meta}) {
    return {
      'trips': [
        for (var i = 0; i < count; i++)
          {
            '_id': 'trip-$i',
            'bookingNumber': 'PF-$i',
            'bookingStatus': 'driver_assigned',
          },
      ],
      ...?meta,
    };
  }

  group('TripListPage pagination', () {
    test('believes the metadata when the endpoint sends it', () {
      final page = TripListPage.fromJson(
        payload(
          10,
          meta: {
            'meta': {'page': 2, 'limit': 10, 'total': 34, 'totalPages': 4},
          },
        ),
        requestedPage: 2,
      );

      expect(page.page, 2);
      expect(page.totalPages, 4);
      expect(page.hasMore, isTrue);
    });

    test('knows the last page from the metadata', () {
      final page = TripListPage.fromJson(
        payload(
          4,
          meta: {
            'meta': {'page': 4, 'limit': 10, 'total': 34, 'totalPages': 4},
          },
        ),
        requestedPage: 4,
      );

      expect(page.hasMore, isFalse);
    });

    test('derives the page count from a bare total', () {
      final page = TripListPage.fromJson(
        payload(10, meta: {'total': 25, 'limit': 10}),
        requestedPage: 1,
      );

      expect(page.totalPages, 3);
      expect(page.hasMore, isTrue);
    });

    test('keeps paging on a full page with no metadata at all', () {
      // The shape the driver endpoint has been seen to send: just the trips.
      final page = TripListPage.fromJson(payload(10), requestedPage: 1);

      expect(page.totalPages, isNull);
      expect(page.hasMore, isTrue, reason: 'a full page implies another');
    });

    test('stops on a short page with no metadata', () {
      final page = TripListPage.fromJson(payload(6), requestedPage: 1);

      expect(page.hasMore, isFalse);
    });

    test('reports the page it was asked for when the response does not', () {
      // The bug that made paging loop: without this the provider records page 1
      // however deep the driver has scrolled, and re-requests page 2 forever.
      final page = TripListPage.fromJson(payload(10), requestedPage: 3);

      expect(page.page, 3);
    });

    test('lets the response override the requested page', () {
      final page = TripListPage.fromJson(
        payload(10, meta: {'page': 2}),
        requestedPage: 5,
      );

      expect(page.page, 2);
    });

    test('takes the requested limit when the response omits it', () {
      final page = TripListPage.fromJson(payload(20), requestedLimit: 20);

      expect(page.limit, 20);
      expect(page.hasMore, isTrue);
    });
  });
}
