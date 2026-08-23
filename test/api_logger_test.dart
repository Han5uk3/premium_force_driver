import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:premium_force_driver/api/api_logger.dart';

/// Guards on the logger that replaced Dio's [LogInterceptor].
///
/// The failure it exists to prevent is silent: a trip-detail body handed to the
/// platform log as one long line comes back cut off partway through, and the
/// rest of the booking is simply never printed.
void main() {
  group('DriverApiLogger', () {
    test('renders a long body in full, in short lines', () {
      final logger = DriverApiLogger();

      // Roughly the size of a real trip-detail payload, and far past the
      // ~1000-byte cap a single log message is subject to.
      final payload = {
        'success': true,
        'data': {
          'bookingNumber': 'PF-APT-2608-1420',
          'trips': [
            for (var i = 0; i < 60; i++)
              {'index': i, 'address': 'Prince Mohammad Bin Abdulaziz Airport'},
          ],
        },
      };

      final rendered = logger.renderForTest(jsonEncode(payload));

      expect(rendered.length, greaterThan(2000));
      // Nothing dropped: the last element is as present as the first.
      expect(rendered, contains('"index": 0'));
      expect(rendered, contains('"index": 59'));
      // Every line is short enough to survive the platform log intact.
      for (final line in rendered.split('\n')) {
        expect(line.length, lessThan(500));
      }
    });

    test('masks credentials wherever they are nested', () {
      final logger = DriverApiLogger();

      final rendered = logger.renderForTest({
        'fcm_token': 'abcdefghij',
        'data': {
          'accessToken': 'zyxwvutsrq',
          'passengerPhone': '+966501234567',
        },
      });

      expect(rendered, isNot(contains('abcdefghij')));
      expect(rendered, isNot(contains('zyxwvutsrq')));
      expect(rendered, contains('<redacted, 10 chars>'));
      // Not a credential, and the driver needs to see it.
      expect(rendered, contains('+966501234567'));
    });

    test('truncates only when a cap is set', () {
      final body = jsonEncode({'note': 'x' * 500});

      expect(
        DriverApiLogger().renderForTest(body),
        isNot(contains('truncated')),
      );
      expect(
        DriverApiLogger(maxBodyChars: 100).renderForTest(body),
        contains('truncated'),
      );
    });

    test('leaves a non-JSON body alone rather than failing', () {
      expect(
        DriverApiLogger().renderForTest('<html>gateway timeout</html>'),
        '<html>gateway timeout</html>',
      );
    });
  });
}
