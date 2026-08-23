import 'package:flutter_test/flutter_test.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/l10n/app_localizations_ar.dart';
import 'package:premium_force_driver/l10n/app_localizations_en.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';
import 'package:premium_force_driver/trips/trip_status_style.dart';

/// Guards on the wording of the four ride controls.
///
/// Each transition does something different and irreversible, so each has to
/// say so. The dialog used to ask "Do you want to continue?" for all four,
/// which told the driver nothing about what they were agreeing to.
void main() {
  /// The statuses the driver can actually act from.
  const actionable = [
    TripStatusV2.driverAssigned,
    TripStatusV2.driverEnRoute,
    TripStatusV2.driverArrived,
    TripStatusV2.tripStarted,
  ];

  for (final AppLocalizations loc in [
    AppLocalizationsEn(),
    AppLocalizationsAr(),
  ]) {
    group('confirmMessage (${loc.localeName})', () {
      test('gives every action its own wording', () {
        final messages = actionable
            .map((status) => status.confirmMessage(loc))
            .toList();

        expect(messages.toSet(), hasLength(actionable.length));
        // None of them falls through to the old generic line.
        expect(messages, isNot(contains(loc.confirmStatusUpdate)));
        for (final message in messages) {
          expect(message.trim(), isNotEmpty);
        }
      });

      test('warns before the transition with no way back', () {
        // Completing is the only irreversible one, and the one that closes the
        // location feed.
        expect(TripStatusV2.tripStarted.next, TripStatusV2.completed);
        expect(
          TripStatusV2.tripStarted.confirmMessage(loc),
          loc.confirmCompleteTrip,
        );
      });

      test('pairs each message with the action button beside it', () {
        expect(
          TripStatusV2.driverAssigned.actionLabel(loc),
          loc.actionStartDriving,
        );
        expect(
          TripStatusV2.driverAssigned.confirmMessage(loc),
          loc.confirmStartDriving,
        );

        expect(TripStatusV2.driverEnRoute.actionLabel(loc), loc.actionArrived);
        expect(
          TripStatusV2.driverEnRoute.confirmMessage(loc),
          loc.confirmArrived,
        );

        expect(
          TripStatusV2.driverArrived.actionLabel(loc),
          loc.actionStartTrip,
        );
        expect(
          TripStatusV2.driverArrived.confirmMessage(loc),
          loc.confirmStartTrip,
        );
      });

      test('offers nothing to confirm where there is nothing to do', () {
        for (final status in TripStatusV2.values) {
          if (actionable.contains(status)) continue;
          expect(status.actionLabel(loc), isNull, reason: '$status');
        }
      });
    });
  }
}
