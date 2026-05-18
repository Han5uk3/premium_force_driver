import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @manageProfile.
  ///
  /// In en, this message translates to:
  /// **'Manage Profile'**
  String get manageProfile;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAndConditions;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get off;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @bookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get bookings;

  /// No description provided for @newBooking.
  ///
  /// In en, this message translates to:
  /// **'New Booking'**
  String get newBooking;

  /// No description provided for @recentBookings.
  ///
  /// In en, this message translates to:
  /// **'Recent Bookings'**
  String get recentBookings;

  /// No description provided for @premiumFleet.
  ///
  /// In en, this message translates to:
  /// **'Premium Fleet'**
  String get premiumFleet;

  /// No description provided for @bookServices.
  ///
  /// In en, this message translates to:
  /// **'Book Services'**
  String get bookServices;

  /// No description provided for @airportArrival.
  ///
  /// In en, this message translates to:
  /// **'Airport Arrival'**
  String get airportArrival;

  /// No description provided for @airportDeparture.
  ///
  /// In en, this message translates to:
  /// **'Airport Departure'**
  String get airportDeparture;

  /// No description provided for @privateTransfer.
  ///
  /// In en, this message translates to:
  /// **'Private Transfer'**
  String get privateTransfer;

  /// No description provided for @chauffeurService.
  ///
  /// In en, this message translates to:
  /// **'Chauffeur Service'**
  String get chauffeurService;

  /// No description provided for @luxury.
  ///
  /// In en, this message translates to:
  /// **'Luxury'**
  String get luxury;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @airport.
  ///
  /// In en, this message translates to:
  /// **'Airport'**
  String get airport;

  /// No description provided for @terminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminal;

  /// No description provided for @riyadh.
  ///
  /// In en, this message translates to:
  /// **'Riyadh'**
  String get riyadh;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get hours;

  /// No description provided for @vehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Type'**
  String get vehicleType;

  /// No description provided for @jeddah.
  ///
  /// In en, this message translates to:
  /// **'Jeddah'**
  String get jeddah;

  /// No description provided for @hrs.
  ///
  /// In en, this message translates to:
  /// **'hrs'**
  String get hrs;

  /// No description provided for @dammam.
  ///
  /// In en, this message translates to:
  /// **'Dammam'**
  String get dammam;

  /// No description provided for @business.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get business;

  /// No description provided for @sedan.
  ///
  /// In en, this message translates to:
  /// **'Sedan'**
  String get sedan;

  /// No description provided for @suv.
  ///
  /// In en, this message translates to:
  /// **'SUV'**
  String get suv;

  /// No description provided for @convertible.
  ///
  /// In en, this message translates to:
  /// **'Convertible'**
  String get convertible;

  /// No description provided for @coupe.
  ///
  /// In en, this message translates to:
  /// **'Coupe'**
  String get coupe;

  /// No description provided for @sports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get sports;

  /// No description provided for @premium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premium;

  /// No description provided for @standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standard;

  /// No description provided for @economy.
  ///
  /// In en, this message translates to:
  /// **'Economy'**
  String get economy;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @luxuryAirportTransfers.
  ///
  /// In en, this message translates to:
  /// **'Luxury Airport Transfers'**
  String get luxuryAirportTransfers;

  /// No description provided for @inSaudiArabia.
  ///
  /// In en, this message translates to:
  /// **'In Saudi Arabia'**
  String get inSaudiArabia;

  /// No description provided for @bookNow.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get bookNow;

  /// No description provided for @passenger.
  ///
  /// In en, this message translates to:
  /// **'Passenger'**
  String get passenger;

  /// No description provided for @pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickup;

  /// No description provided for @dropoff.
  ///
  /// In en, this message translates to:
  /// **'Dropoff'**
  String get dropoff;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @ongoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get ongoing;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// No description provided for @chooseCity.
  ///
  /// In en, this message translates to:
  /// **'Choose City'**
  String get chooseCity;

  /// No description provided for @chooseProfilePicture.
  ///
  /// In en, this message translates to:
  /// **'Choose Profile Picture'**
  String get chooseProfilePicture;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @specialId.
  ///
  /// In en, this message translates to:
  /// **'Special ID'**
  String get specialId;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @tapToSelectYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Tap to select your location'**
  String get tapToSelectYourLocation;

  /// No description provided for @pleaseEnterYourName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get pleaseEnterYourName;

  /// No description provided for @pleaseAddAProfilePicture.
  ///
  /// In en, this message translates to:
  /// **'Please add a profile picture'**
  String get pleaseAddAProfilePicture;

  /// No description provided for @pleaseSelectYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Please select your location'**
  String get pleaseSelectYourLocation;

  /// No description provided for @completeYourProfileToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile To Get Started'**
  String get completeYourProfileToGetStarted;

  /// No description provided for @tapToAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to add photo'**
  String get tapToAddPhoto;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @enterYourFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get enterYourFullName;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @enterYourEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get enterYourEmailAddress;

  /// No description provided for @pleaseEnterYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterYourEmail;

  /// No description provided for @nameMustBeAtLeast2Characters.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get nameMustBeAtLeast2Characters;

  /// No description provided for @pleaseEnterAValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterAValidEmail;

  /// No description provided for @specialidoptional.
  ///
  /// In en, this message translates to:
  /// **'Special ID (Optional)'**
  String get specialidoptional;

  /// No description provided for @enterSpecialIdIFAvailable.
  ///
  /// In en, this message translates to:
  /// **'Enter Special ID if available'**
  String get enterSpecialIdIFAvailable;

  /// No description provided for @enterYourSpecialId.
  ///
  /// In en, this message translates to:
  /// **'Enter your special ID'**
  String get enterYourSpecialId;

  /// No description provided for @pleaseEnterYourSpecialId.
  ///
  /// In en, this message translates to:
  /// **'Please enter your special ID'**
  String get pleaseEnterYourSpecialId;

  /// No description provided for @iAmACorporateEmployee.
  ///
  /// In en, this message translates to:
  /// **'Are you a corporate employee?'**
  String get iAmACorporateEmployee;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// No description provided for @enterMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter mobile number'**
  String get enterMobileNumber;

  /// No description provided for @pleaseEnterYourMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter your mobile number'**
  String get pleaseEnterYourMobileNumber;

  /// No description provided for @pleaseEnterValidMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid mobile number'**
  String get pleaseEnterValidMobileNumber;

  /// No description provided for @byContinuingYouAgreeToOur.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our'**
  String get byContinuingYouAgreeToOur;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get and;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @selectLocation.
  ///
  /// In en, this message translates to:
  /// **'Select Location'**
  String get selectLocation;

  /// No description provided for @pleaseAgreeToTheTermsAndConditionsAndPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Please agree to the terms and conditions and privacy policy.'**
  String get pleaseAgreeToTheTermsAndConditionsAndPrivacyPolicy;

  /// No description provided for @tripInfo.
  ///
  /// In en, this message translates to:
  /// **'Trip Info'**
  String get tripInfo;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @serviceType.
  ///
  /// In en, this message translates to:
  /// **'Service Type'**
  String get serviceType;

  /// No description provided for @tellUsAboutYourJourney.
  ///
  /// In en, this message translates to:
  /// **'Tell Us About Your Journey'**
  String get tellUsAboutYourJourney;

  /// No description provided for @enterFlightNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter Flight Number'**
  String get enterFlightNumber;

  /// No description provided for @flightNumber.
  ///
  /// In en, this message translates to:
  /// **'Flight Number'**
  String get flightNumber;

  /// No description provided for @arrivalDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Arrival Date and Time'**
  String get arrivalDateAndTime;

  /// No description provided for @departureDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Departure Date and Time'**
  String get departureDateAndTime;

  /// No description provided for @pickupDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Pickup Date and Time'**
  String get pickupDateAndTime;

  /// No description provided for @pickupLocation.
  ///
  /// In en, this message translates to:
  /// **'Pickup Location'**
  String get pickupLocation;

  /// No description provided for @dropLocation.
  ///
  /// In en, this message translates to:
  /// **'Drop Location'**
  String get dropLocation;

  /// No description provided for @tapToSelectAPickupLocation.
  ///
  /// In en, this message translates to:
  /// **'Tap to select a pickup location'**
  String get tapToSelectAPickupLocation;

  /// No description provided for @tapToSelectADropLocation.
  ///
  /// In en, this message translates to:
  /// **'Tap to select a drop location'**
  String get tapToSelectADropLocation;

  /// No description provided for @terminal1.
  ///
  /// In en, this message translates to:
  /// **'Terminal 1'**
  String get terminal1;

  /// No description provided for @terminal2.
  ///
  /// In en, this message translates to:
  /// **'Terminal 2'**
  String get terminal2;

  /// No description provided for @terminal3.
  ///
  /// In en, this message translates to:
  /// **'Terminal 3'**
  String get terminal3;

  /// No description provided for @terminal4.
  ///
  /// In en, this message translates to:
  /// **'Terminal 4'**
  String get terminal4;

  /// No description provided for @terminal5.
  ///
  /// In en, this message translates to:
  /// **'Terminal 5'**
  String get terminal5;

  /// No description provided for @hajjTerminal.
  ///
  /// In en, this message translates to:
  /// **'Hajj Terminal'**
  String get hajjTerminal;

  /// No description provided for @northTerminal.
  ///
  /// In en, this message translates to:
  /// **'North Terminal'**
  String get northTerminal;

  /// No description provided for @southTerminal.
  ///
  /// In en, this message translates to:
  /// **'South Terminal'**
  String get southTerminal;

  /// No description provided for @passengerTerminal.
  ///
  /// In en, this message translates to:
  /// **'Passenger Terminal'**
  String get passengerTerminal;

  /// No description provided for @aramcoTerminal.
  ///
  /// In en, this message translates to:
  /// **'Aramco Terminal'**
  String get aramcoTerminal;

  /// No description provided for @royalTerminal.
  ///
  /// In en, this message translates to:
  /// **'Royal Terminal'**
  String get royalTerminal;

  /// No description provided for @flightNumberIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Flight number is required'**
  String get flightNumberIsRequired;

  /// No description provided for @pickupLocationIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Pickup location is required'**
  String get pickupLocationIsRequired;

  /// No description provided for @dropLocationIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Drop location is required'**
  String get dropLocationIsRequired;

  /// No description provided for @kingKhalidInternationalAirport.
  ///
  /// In en, this message translates to:
  /// **'King Khalid International Airport'**
  String get kingKhalidInternationalAirport;

  /// No description provided for @kingFahadInternationalAirport.
  ///
  /// In en, this message translates to:
  /// **'King Fahad International Airport'**
  String get kingFahadInternationalAirport;

  /// No description provided for @kingAbdulazizInternationalAirport.
  ///
  /// In en, this message translates to:
  /// **'King Abdulaziz International Airport'**
  String get kingAbdulazizInternationalAirport;

  /// No description provided for @pickupDateAndTimeIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Pickup date and time are required'**
  String get pickupDateAndTimeIsRequired;

  /// No description provided for @dateAndTimeIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Date and time are required'**
  String get dateAndTimeIsRequired;

  /// No description provided for @previouslySelectedTimeClearedAsItIsInThePast.
  ///
  /// In en, this message translates to:
  /// **'Previously selected time cleared as it is in the past'**
  String get previouslySelectedTimeClearedAsItIsInThePast;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @pleaseSelectADateFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a date first'**
  String get pleaseSelectADateFirst;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get selectTime;

  /// No description provided for @cannotSelectPastTimeForToday.
  ///
  /// In en, this message translates to:
  /// **'Cannot select past time for today'**
  String get cannotSelectPastTimeForToday;

  /// No description provided for @chooseYouPreferredVehicle.
  ///
  /// In en, this message translates to:
  /// **'Choose you preferred vehicle'**
  String get chooseYouPreferredVehicle;

  /// No description provided for @chauffeurredClass.
  ///
  /// In en, this message translates to:
  /// **'Chauffeurred Class'**
  String get chauffeurredClass;

  /// No description provided for @preferredModel.
  ///
  /// In en, this message translates to:
  /// **'Preferred Model'**
  String get preferredModel;

  /// No description provided for @choosePreferredBrand.
  ///
  /// In en, this message translates to:
  /// **'Choose Preferred Brand'**
  String get choosePreferredBrand;

  /// No description provided for @specialRequests.
  ///
  /// In en, this message translates to:
  /// **'Special Requests'**
  String get specialRequests;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @luxurySedan.
  ///
  /// In en, this message translates to:
  /// **'Luxury Sedan'**
  String get luxurySedan;

  /// No description provided for @luxurySuv.
  ///
  /// In en, this message translates to:
  /// **'Luxury SUV'**
  String get luxurySuv;

  /// No description provided for @luxuryCoupe.
  ///
  /// In en, this message translates to:
  /// **'Luxury Coupe'**
  String get luxuryCoupe;

  /// No description provided for @luxurySports.
  ///
  /// In en, this message translates to:
  /// **'Luxury Sports'**
  String get luxurySports;

  /// No description provided for @luxuryConvertible.
  ///
  /// In en, this message translates to:
  /// **'Luxury Convertible'**
  String get luxuryConvertible;

  /// No description provided for @model1.
  ///
  /// In en, this message translates to:
  /// **'Model 1'**
  String get model1;

  /// No description provided for @model2.
  ///
  /// In en, this message translates to:
  /// **'Model 2'**
  String get model2;

  /// No description provided for @model3.
  ///
  /// In en, this message translates to:
  /// **'Model 3'**
  String get model3;

  /// No description provided for @providePassengerInfo.
  ///
  /// In en, this message translates to:
  /// **'Provide Passenger Info'**
  String get providePassengerInfo;

  /// No description provided for @numberOfPassengers.
  ///
  /// In en, this message translates to:
  /// **'No. of Passengers'**
  String get numberOfPassengers;

  /// No description provided for @passengerNameAtleastOne.
  ///
  /// In en, this message translates to:
  /// **'Passenger Name (Atleast one separated by commas)'**
  String get passengerNameAtleastOne;

  /// No description provided for @passengerName.
  ///
  /// In en, this message translates to:
  /// **'Passenger Name'**
  String get passengerName;

  /// No description provided for @pleaseEnterAtleastOnepassengerName.
  ///
  /// In en, this message translates to:
  /// **'Please enter atleast one passenger name'**
  String get pleaseEnterAtleastOnepassengerName;

  /// No description provided for @pleaseEnterAMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a mobile number'**
  String get pleaseEnterAMobileNumber;

  /// No description provided for @pleaseEnterAPassengerName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a passenger name'**
  String get pleaseEnterAPassengerName;

  /// No description provided for @reviewAndConfirm.
  ///
  /// In en, this message translates to:
  /// **'Review and Confirm'**
  String get reviewAndConfirm;

  /// No description provided for @reviewAndConfirmYourRequest.
  ///
  /// In en, this message translates to:
  /// **'Review and Confirm Your Request'**
  String get reviewAndConfirmYourRequest;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @service.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get service;

  /// No description provided for @passengers.
  ///
  /// In en, this message translates to:
  /// **'Passengers'**
  String get passengers;

  /// No description provided for @notAssigned.
  ///
  /// In en, this message translates to:
  /// **'Not Assigned'**
  String get notAssigned;

  /// No description provided for @chauffeur.
  ///
  /// In en, this message translates to:
  /// **'Chauffeur'**
  String get chauffeur;

  /// No description provided for @totalDistance.
  ///
  /// In en, this message translates to:
  /// **'Total Distance'**
  String get totalDistance;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @vat.
  ///
  /// In en, this message translates to:
  /// **'VAT (15%)'**
  String get vat;

  /// No description provided for @paymentSummary.
  ///
  /// In en, this message translates to:
  /// **'Payment Summary'**
  String get paymentSummary;

  /// No description provided for @km.
  ///
  /// In en, this message translates to:
  /// **'KM'**
  String get km;

  /// No description provided for @charge.
  ///
  /// In en, this message translates to:
  /// **'Charge'**
  String get charge;

  /// No description provided for @bookService.
  ///
  /// In en, this message translates to:
  /// **'Book Service'**
  String get bookService;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logoutConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @loginAgainMessage.
  ///
  /// In en, this message translates to:
  /// **'You will have to login again next time you open the app.'**
  String get loginAgainMessage;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account?'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone and all your data will be cleared.'**
  String get deleteAccountMessage;

  /// No description provided for @pickupTimeCannotBeAfterDepartureTime.
  ///
  /// In en, this message translates to:
  /// **'Pickup time cannot be after departure time'**
  String get pickupTimeCannotBeAfterDepartureTime;

  /// No description provided for @pickupTimeAtLeast4HoursBeforeDeparture.
  ///
  /// In en, this message translates to:
  /// **'Pickup time must be at least 4 hours before departure time'**
  String get pickupTimeAtLeast4HoursBeforeDeparture;

  /// No description provided for @noRecentBookings.
  ///
  /// In en, this message translates to:
  /// **'No recent bookings'**
  String get noRecentBookings;

  /// No description provided for @noUpcomingBookings.
  ///
  /// In en, this message translates to:
  /// **'No upcoming bookings'**
  String get noUpcomingBookings;

  /// No description provided for @noOngoingBookings.
  ///
  /// In en, this message translates to:
  /// **'No ongoing bookings'**
  String get noOngoingBookings;

  /// No description provided for @noCompletedBookings.
  ///
  /// In en, this message translates to:
  /// **'No completed bookings'**
  String get noCompletedBookings;

  /// No description provided for @onceYouBookItWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Once you book a service, it will appear here.'**
  String get onceYouBookItWillAppearHere;

  /// No description provided for @termsIntro.
  ///
  /// In en, this message translates to:
  /// **'These terms and conditions outline the rules and regulations for the use of the Premium Force application, a luxury chauffeur booking service operating in the Kingdom of Saudi Arabia.\n\nBy accessing this app, we assume you accept these terms and conditions. Do not continue to use Premium Force if you do not agree to take all of the terms and conditions stated on this page.\n'**
  String get termsIntro;

  /// No description provided for @termsSection1Title.
  ///
  /// In en, this message translates to:
  /// **'1. App Services & Bookings'**
  String get termsSection1Title;

  /// No description provided for @termsSection1Content.
  ///
  /// In en, this message translates to:
  /// **'Premium Force connects users with luxury chauffeur services within Saudi Arabia. All bookings are subject to availability, and we reserve the right to decline or cancel bookings under specific circumstances outlined in our policies.'**
  String get termsSection1Content;

  /// No description provided for @termsSection2Title.
  ///
  /// In en, this message translates to:
  /// **'2. User Responsibilities'**
  String get termsSection2Title;

  /// No description provided for @termsSection2Content.
  ///
  /// In en, this message translates to:
  /// **'You are specifically restricted from all of the following:\n• using this app in any way that impacts user access or disrupts the chauffeur services;\n• using this app contrary to the applicable laws and regulations of the Kingdom of Saudi Arabia;\n• behaving inappropriately towards our chauffeurs or damaging the provided luxury vehicles.'**
  String get termsSection2Content;

  /// No description provided for @termsSection3Title.
  ///
  /// In en, this message translates to:
  /// **'3. Payments & Cancellations'**
  String get termsSection3Title;

  /// No description provided for @termsSection3Content.
  ///
  /// In en, this message translates to:
  /// **'All payments for chauffeur services must be made through the approved methods within the app. Cancellation policies apply to all bookings. Late cancellations or no-shows may incur charges as detailed during the booking process.'**
  String get termsSection3Content;

  /// No description provided for @termsSection4Title.
  ///
  /// In en, this message translates to:
  /// **'4. Privacy'**
  String get termsSection4Title;

  /// No description provided for @termsSection4Content.
  ///
  /// In en, this message translates to:
  /// **'Please read our Privacy Policy. Your use of the Application signifies your continuing consent to our Privacy Policy regarding the collection and use of your personal and location data necessary for the chauffeur service.'**
  String get termsSection4Content;

  /// No description provided for @termsSection5Title.
  ///
  /// In en, this message translates to:
  /// **'5. Disclaimer of Warranties'**
  String get termsSection5Title;

  /// No description provided for @termsSection5Content.
  ///
  /// In en, this message translates to:
  /// **'This app is provided \"as is,\" and Premium Force expresses no representations or warranties related to the continuous availability of the app or specific chauffeurs.'**
  String get termsSection5Content;

  /// No description provided for @termsSection6Title.
  ///
  /// In en, this message translates to:
  /// **'6. Governing Law & Jurisdiction'**
  String get termsSection6Title;

  /// No description provided for @termsSection6Content.
  ///
  /// In en, this message translates to:
  /// **'These Terms will be governed by and interpreted in accordance with the laws of the Kingdom of Saudi Arabia, and you submit to the exclusive jurisdiction of the courts located in Saudi Arabia for the resolution of any disputes.'**
  String get termsSection6Content;

  /// No description provided for @termsSection7Title.
  ///
  /// In en, this message translates to:
  /// **'7. Changes and Amendments'**
  String get termsSection7Title;

  /// No description provided for @termsSection7Content.
  ///
  /// In en, this message translates to:
  /// **'We reserve the right to modify these terms or policies relating to the app or services at any time. Continued use of the app after any such changes shall constitute your consent to such changes.'**
  String get termsSection7Content;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @startTracking.
  ///
  /// In en, this message translates to:
  /// **'Start Tracking'**
  String get startTracking;

  /// No description provided for @getDirections.
  ///
  /// In en, this message translates to:
  /// **'Get Directions'**
  String get getDirections;

  /// No description provided for @stopTracking.
  ///
  /// In en, this message translates to:
  /// **'Stop Tracking'**
  String get stopTracking;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @startRide.
  ///
  /// In en, this message translates to:
  /// **'Start Ride'**
  String get startRide;

  /// No description provided for @pauseRide.
  ///
  /// In en, this message translates to:
  /// **'Pause Ride'**
  String get pauseRide;

  /// No description provided for @endRide.
  ///
  /// In en, this message translates to:
  /// **'End Ride'**
  String get endRide;

  /// No description provided for @resumeRide.
  ///
  /// In en, this message translates to:
  /// **'Resume Ride'**
  String get resumeRide;

  /// No description provided for @directions.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get directions;

  /// No description provided for @couldNotLaunchMaps.
  ///
  /// In en, this message translates to:
  /// **'Could not launch maps'**
  String get couldNotLaunchMaps;

  /// No description provided for @locationServicesAreDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled.'**
  String get locationServicesAreDisabled;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied.'**
  String get locationPermissionDenied;

  /// No description provided for @errorGettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Error getting location: '**
  String get errorGettingLocation;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @driverNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'Driver Not Registered'**
  String get driverNotRegistered;

  /// No description provided for @noDriverRegistered.
  ///
  /// In en, this message translates to:
  /// **'No driver registered with this phone number in the app.\n\nPlease contact the admin to register your number.'**
  String get noDriverRegistered;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @errorLoadingBookings.
  ///
  /// In en, this message translates to:
  /// **'Error loading bookings'**
  String get errorLoadingBookings;

  /// No description provided for @pleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again'**
  String get pleaseTryAgain;

  /// No description provided for @noUpcomingBookingsMessage.
  ///
  /// In en, this message translates to:
  /// **'No upcoming bookings yet.\nWait for new ride requests!'**
  String get noUpcomingBookingsMessage;

  /// No description provided for @noOngoingRidesMessage.
  ///
  /// In en, this message translates to:
  /// **'No ongoing rides right now.\nStart a booking to begin!'**
  String get noOngoingRidesMessage;

  /// No description provided for @noCompletedRidesMessage.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t completed any rides yet.\nComplete bookings to see them here!'**
  String get noCompletedRidesMessage;

  /// No description provided for @noBookingsFound.
  ///
  /// In en, this message translates to:
  /// **'No bookings found.'**
  String get noBookingsFound;

  /// No description provided for @acceptBooking.
  ///
  /// In en, this message translates to:
  /// **'Accept Booking'**
  String get acceptBooking;

  /// No description provided for @acceptBookingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to accept this booking?'**
  String get acceptBookingConfirm;

  /// No description provided for @rejectBooking.
  ///
  /// In en, this message translates to:
  /// **'Reject Booking'**
  String get rejectBooking;

  /// No description provided for @rejectBookingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reject this booking?'**
  String get rejectBookingConfirm;

  /// No description provided for @completeBooking.
  ///
  /// In en, this message translates to:
  /// **'Complete Booking'**
  String get completeBooking;

  /// No description provided for @completeBookingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to complete this booking?'**
  String get completeBookingConfirm;

  /// No description provided for @startTrackingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you ready to start tracking for this booking?'**
  String get startTrackingConfirm;

  /// No description provided for @stopTrackingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to stop tracking?'**
  String get stopTrackingConfirm;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @bookingAccepted.
  ///
  /// In en, this message translates to:
  /// **'Booking accepted'**
  String get bookingAccepted;

  /// No description provided for @bookingRejected.
  ///
  /// In en, this message translates to:
  /// **'Booking rejected'**
  String get bookingRejected;

  /// No description provided for @bookingCompleted.
  ///
  /// In en, this message translates to:
  /// **'Booking completed'**
  String get bookingCompleted;

  /// No description provided for @trackingStarted.
  ///
  /// In en, this message translates to:
  /// **'Tracking started'**
  String get trackingStarted;

  /// No description provided for @tripEnded.
  ///
  /// In en, this message translates to:
  /// **'Trip ended'**
  String get tripEnded;

  /// No description provided for @extraHoursDetected.
  ///
  /// In en, this message translates to:
  /// **'Extra hours detected. Customer needs to pay.'**
  String get extraHoursDetected;

  /// No description provided for @syncPendingExtraHours.
  ///
  /// In en, this message translates to:
  /// **'Sync pending for extra hours.'**
  String get syncPendingExtraHours;

  /// No description provided for @trackingStoppedSyncPending.
  ///
  /// In en, this message translates to:
  /// **'Tracking stopped, sync pending'**
  String get trackingStoppedSyncPending;

  /// No description provided for @customerReview.
  ///
  /// In en, this message translates to:
  /// **'Customer Review'**
  String get customerReview;

  /// No description provided for @assigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get assigned;

  /// No description provided for @paymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment Pending'**
  String get paymentPending;

  /// No description provided for @reviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get reviewed;

  /// No description provided for @rideStoppedSyncPending.
  ///
  /// In en, this message translates to:
  /// **'Ride stopped, sync pending'**
  String get rideStoppedSyncPending;

  /// No description provided for @ridePaused.
  ///
  /// In en, this message translates to:
  /// **'Ride paused'**
  String get ridePaused;

  /// No description provided for @rideResumed.
  ///
  /// In en, this message translates to:
  /// **'Ride resumed'**
  String get rideResumed;

  /// No description provided for @endRideConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to end this ride?'**
  String get endRideConfirm;

  /// No description provided for @startRideConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to start this ride?'**
  String get startRideConfirm;

  /// No description provided for @rideStarted.
  ///
  /// In en, this message translates to:
  /// **'Ride started'**
  String get rideStarted;

  /// No description provided for @tracking.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get tracking;

  /// No description provided for @startRideAvailableOnDate.
  ///
  /// In en, this message translates to:
  /// **'Start Ride will be available on booking date'**
  String get startRideAvailableOnDate;

  /// No description provided for @startTrackingAvailableOnDate.
  ///
  /// In en, this message translates to:
  /// **'Start Tracking available on booking date'**
  String get startTrackingAvailableOnDate;

  /// No description provided for @locationPermissionsPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are permanently denied. Enable from settings.'**
  String get locationPermissionsPermanentlyDenied;

  /// No description provided for @searchForALocation.
  ///
  /// In en, this message translates to:
  /// **'Search for a location...'**
  String get searchForALocation;

  /// No description provided for @selectedLocation.
  ///
  /// In en, this message translates to:
  /// **'Selected Location'**
  String get selectedLocation;

  /// No description provided for @gettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting location...'**
  String get gettingLocation;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use Current Location'**
  String get useCurrentLocation;

  /// No description provided for @pleaseSelectALocationFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a location first'**
  String get pleaseSelectALocationFirst;

  /// No description provided for @confirmLocation.
  ///
  /// In en, this message translates to:
  /// **'Confirm Location'**
  String get confirmLocation;

  /// No description provided for @signupFailed.
  ///
  /// In en, this message translates to:
  /// **'Signup failed'**
  String get signupFailed;

  /// No description provided for @byClickingContinue.
  ///
  /// In en, this message translates to:
  /// **'By Clicking continue button you agree to our '**
  String get byClickingContinue;

  /// No description provided for @noDriverRegisteredError.
  ///
  /// In en, this message translates to:
  /// **'No driver registered with this phone number'**
  String get noDriverRegisteredError;

  /// No description provided for @voiceNote.
  ///
  /// In en, this message translates to:
  /// **'Voice Note'**
  String get voiceNote;

  /// No description provided for @recordVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'Record voice note'**
  String get recordVoiceNote;

  /// No description provided for @saveVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'Save Voice Note'**
  String get saveVoiceNote;

  /// No description provided for @bookingInfo.
  ///
  /// In en, this message translates to:
  /// **'Booking Information'**
  String get bookingInfo;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @customerInfo.
  ///
  /// In en, this message translates to:
  /// **'Customer Details'**
  String get customerInfo;

  /// No description provided for @fare.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get fare;

  /// No description provided for @riyal.
  ///
  /// In en, this message translates to:
  /// **'SAR'**
  String get riyal;

  /// No description provided for @extraHoursCharge.
  ///
  /// In en, this message translates to:
  /// **'Extra Hours Charge'**
  String get extraHoursCharge;

  /// No description provided for @locationBackgroundDisclosureTitle.
  ///
  /// In en, this message translates to:
  /// **'Background Location Access'**
  String get locationBackgroundDisclosureTitle;

  /// No description provided for @locationBackgroundDisclosureMessage.
  ///
  /// In en, this message translates to:
  /// **'Premium Force Driver collects location data to enable tracking your progress and sharing your real-time position with the customer, even when the app is closed or not in use. This ensures a smooth pickup and trip experience.'**
  String get locationBackgroundDisclosureMessage;

  /// No description provided for @allowAllTheTime.
  ///
  /// In en, this message translates to:
  /// **'Allow All The Time'**
  String get allowAllTheTime;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @enableLocationServices.
  ///
  /// In en, this message translates to:
  /// **'Enable Location Services'**
  String get enableLocationServices;

  /// No description provided for @locationServicesDisabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled. Please enable them to start tracking.'**
  String get locationServicesDisabledMessage;

  /// No description provided for @locationPermissionAlwaysRequired.
  ///
  /// In en, this message translates to:
  /// **'Background location permission is required for the driver app to update your position while you are on the move. Please select \'Allow all the time\' in settings.'**
  String get locationPermissionAlwaysRequired;

  /// No description provided for @pauseTracking.
  ///
  /// In en, this message translates to:
  /// **'Pause Tracking'**
  String get pauseTracking;

  /// No description provided for @resumeTracking.
  ///
  /// In en, this message translates to:
  /// **'Resume Tracking'**
  String get resumeTracking;

  /// No description provided for @trackingPaused.
  ///
  /// In en, this message translates to:
  /// **'Tracking Paused'**
  String get trackingPaused;

  /// No description provided for @trackingResumed.
  ///
  /// In en, this message translates to:
  /// **'Tracking Resumed'**
  String get trackingResumed;

  /// Greeting prefix.
  String get hello;

  /// Select vehicle to take out text.
  String get selectVehicle;

  /// No fleets available for takeout text.
  String get noVehiclesAvailable;

  /// License plate label.
  String get licensePlate;

  /// Pickup vehicle label.
  String get pickupVehicle;

  /// Confirm take out header.
  String get confirmTakeOut;

  /// Confirm take out message prefix.
  String get confirmTakeOutMessage;

  /// Return vehicle button label.
  String get returnVehicle;

  /// Confirm return header.
  String get confirmReturn;

  /// Confirm return message.
  String get confirmReturnMessage;

  /// Active & Online status switch.
  String get activeAndOnline;

  /// Offline status switch.
  String get offline;

  /// No vehicle taken out fallback.
  String get noVehicleTakenOut;

  /// Booking summary section title.
  String get bookingSummary;

  /// Active Ride tracker section title.
  String get activeRide;

  /// No active tracked ride label.
  String get noActiveRide;

  /// Tip for active ride tracker.
  String get activeRideTip;

  /// Vehicle pickup success snackbar.
  String get vehiclePickupSuccess;

  /// Vehicle return success snackbar.
  String get vehicleReturnSuccess;

  /// Active status snackbar.
  String get statusActive;

  /// Offline status snackbar.
  String get statusOffline;

  /// Failed to update status snackbar error.
  String get failedToUpdateStatus;

  /// Active vehicle label fallback.
  String get activeVehicle;

  /// Failed to pick up vehicle snackbar error.
  String get failedToPickUpVehicle;

  /// Failed to return vehicle snackbar error.
  String get failedToReturnVehicle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
