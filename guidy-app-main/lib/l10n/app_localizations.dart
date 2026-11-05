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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Navigate Egypt with intelligence'**
  String get appTagline;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get goodMorning;

  /// No description provided for @goodMorningUser.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String goodMorningUser(String name);

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodAfternoonUser.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}'**
  String goodAfternoonUser(String name);

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get goodEvening;

  /// No description provided for @goodEveningUser.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String goodEveningUser(String name);

  /// No description provided for @goodNight.
  ///
  /// In en, this message translates to:
  /// **'Good Night'**
  String get goodNight;

  /// No description provided for @goodNightUser.
  ///
  /// In en, this message translates to:
  /// **'Good night, {name}'**
  String goodNightUser(String name);

  /// No description provided for @whereTo.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get whereTo;

  /// No description provided for @quickAccessHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get quickAccessHome;

  /// No description provided for @quickAccessWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get quickAccessWork;

  /// No description provided for @quickAccessSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get quickAccessSaved;

  /// No description provided for @routingTo.
  ///
  /// In en, this message translates to:
  /// **'Routing to {name}...'**
  String routingTo(String name);

  /// No description provided for @gpsRequiredToRoute.
  ///
  /// In en, this message translates to:
  /// **'Ensure GPS is enabled to route.'**
  String get gpsRequiredToRoute;

  /// No description provided for @resettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Resetting {key} location...'**
  String resettingLocation(String key);

  /// No description provided for @setLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Set {key}'**
  String setLocationTitle(String key);

  /// No description provided for @locationSavedAs.
  ///
  /// In en, this message translates to:
  /// **'{key} saved as {name}'**
  String locationSavedAs(String key, String name);

  /// No description provided for @searchOrTapMap.
  ///
  /// In en, this message translates to:
  /// **'Search or tap map...'**
  String get searchOrTapMap;

  /// No description provided for @saveAsKey.
  ///
  /// In en, this message translates to:
  /// **'Save as {key}'**
  String saveAsKey(String key);

  /// No description provided for @pickupLocation.
  ///
  /// In en, this message translates to:
  /// **'Pickup Location'**
  String get pickupLocation;

  /// No description provided for @gpsFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to get GPS location.'**
  String get gpsFetchFailed;

  /// No description provided for @findRoutes.
  ///
  /// In en, this message translates to:
  /// **'Find Routes'**
  String get findRoutes;

  /// No description provided for @routeOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Route Options'**
  String get routeOptionsTitle;

  /// No description provided for @routeCalculationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not calculate route.'**
  String get routeCalculationFailed;

  /// No description provided for @availableRoutes.
  ///
  /// In en, this message translates to:
  /// **'Available Routes'**
  String get availableRoutes;

  /// Route Options view switch: the list of route cards.
  ///
  /// In en, this message translates to:
  /// **'Route list'**
  String get routeListTab;

  /// Route Options view switch: a table comparing every route side by side.
  ///
  /// In en, this message translates to:
  /// **'Quick compare'**
  String get quickCompareTab;

  /// No description provided for @statDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get statDuration;

  /// No description provided for @statFare.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get statFare;

  /// No description provided for @statDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get statDistance;

  /// No description provided for @routeTimeBreakdown.
  ///
  /// In en, this message translates to:
  /// **'{riding} travelling, about {wait} waiting'**
  String routeTimeBreakdown(String riding, String wait);

  /// No description provided for @stepWaitHint.
  ///
  /// In en, this message translates to:
  /// **'Wait about {wait}'**
  String stepWaitHint(String wait);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}'**
  String durationMinutes(String minutes);

  /// No description provided for @distanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distanceKm(String km);

  /// No description provided for @fareEgp.
  ///
  /// In en, this message translates to:
  /// **'{amount} EGP'**
  String fareEgp(String amount);

  /// No description provided for @alsoWorksLabel.
  ///
  /// In en, this message translates to:
  /// **'Also works: {routes}'**
  String alsoWorksLabel(String routes);

  /// No description provided for @routeEveryMinutes.
  ///
  /// In en, this message translates to:
  /// **'{route} (about every {minutes})'**
  String routeEveryMinutes(String route, String minutes);

  /// No description provided for @listSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get listSeparator;

  /// No description provided for @navNowLabel.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get navNowLabel;

  /// No description provided for @navAlsoServing.
  ///
  /// In en, this message translates to:
  /// **'Also serving this leg'**
  String get navAlsoServing;

  /// No description provided for @navYourRoute.
  ///
  /// In en, this message translates to:
  /// **'Your route'**
  String get navYourRoute;

  /// No description provided for @navMinutesAway.
  ///
  /// In en, this message translates to:
  /// **'about {minutes} away'**
  String navMinutesAway(String minutes);

  /// No description provided for @navArrivingNow.
  ///
  /// In en, this message translates to:
  /// **'Arriving now'**
  String get navArrivingNow;

  /// No description provided for @navEveryMinutes.
  ///
  /// In en, this message translates to:
  /// **'about every {minutes}'**
  String navEveryMinutes(String minutes);

  /// No description provided for @navWalkToStop.
  ///
  /// In en, this message translates to:
  /// **'{meters} m walk to {stop}'**
  String navWalkToStop(String meters, String stop);

  /// No description provided for @navWalkToStopFirst.
  ///
  /// In en, this message translates to:
  /// **'Walk {meters} m to {stop} first'**
  String navWalkToStopFirst(String meters, String stop);

  /// No description provided for @navGetOffThenWalk.
  ///
  /// In en, this message translates to:
  /// **'Get off at {stop}, then walk {meters} m'**
  String navGetOffThenWalk(String stop, String meters);

  /// No description provided for @legalAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get legalAgreePrefix;

  /// No description provided for @legalTermsLink.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get legalTermsLink;

  /// No description provided for @legalAgreeSep1.
  ///
  /// In en, this message translates to:
  /// **', the '**
  String get legalAgreeSep1;

  /// No description provided for @legalPrivacyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get legalPrivacyLink;

  /// No description provided for @legalAgreeSep2.
  ///
  /// In en, this message translates to:
  /// **' and the '**
  String get legalAgreeSep2;

  /// No description provided for @legalDeletionLink.
  ///
  /// In en, this message translates to:
  /// **'Data Deletion Policy'**
  String get legalDeletionLink;

  /// No description provided for @legalAgreeEnd.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get legalAgreeEnd;

  /// No description provided for @legalConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you continue'**
  String get legalConsentTitle;

  /// No description provided for @legalConsentBody.
  ///
  /// In en, this message translates to:
  /// **'Please read Guidy\'s terms and policies and agree to them to use the app. Tap a name to read it.'**
  String get legalConsentBody;

  /// No description provided for @legalConsentContinue.
  ///
  /// In en, this message translates to:
  /// **'Agree and continue'**
  String get legalConsentContinue;

  /// No description provided for @navNoLiveData.
  ///
  /// In en, this message translates to:
  /// **'No live data yet'**
  String get navNoLiveData;

  /// No description provided for @navLocationOff.
  ///
  /// In en, this message translates to:
  /// **'Location is off, so the map won\'t follow you.'**
  String get navLocationOff;

  /// No description provided for @navLocationBlocked.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked for Guidy. Turn it on in Settings to follow the route live.'**
  String get navLocationBlocked;

  /// No description provided for @navLocationLost.
  ///
  /// In en, this message translates to:
  /// **'Lost GPS signal. Your route is still below.'**
  String get navLocationLost;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get nameLabel;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get nameHint;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @passwordCreateHint.
  ///
  /// In en, this message translates to:
  /// **'Create a password'**
  String get passwordCreateHint;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get confirmPasswordHint;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @noAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get noAccountPrompt;

  /// No description provided for @hasAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get hasAccountPrompt;

  /// No description provided for @fillBothFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in both fields'**
  String get fillBothFields;

  /// No description provided for @fillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields'**
  String get fillAllFields;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get invalidEmail;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed'**
  String get signInFailed;

  /// No description provided for @signUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed'**
  String get signUpFailed;

  /// No description provided for @incorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get incorrectCredentials;

  /// No description provided for @checkInternet.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection.'**
  String get checkInternet;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDontMatch;

  /// No description provided for @emailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered.'**
  String get emailAlreadyRegistered;

  /// No description provided for @languageSwitcherTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSwitcherTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @youHaveArrived.
  ///
  /// In en, this message translates to:
  /// **'You have arrived!'**
  String get youHaveArrived;

  /// No description provided for @arrivingAt.
  ///
  /// In en, this message translates to:
  /// **'Arriving at {station}...'**
  String arrivingAt(String station);

  /// No description provided for @distanceKmTo.
  ///
  /// In en, this message translates to:
  /// **'{distance} km to {station}'**
  String distanceKmTo(String distance, String station);

  /// No description provided for @distanceMTo.
  ///
  /// In en, this message translates to:
  /// **'{distance} m to {station}'**
  String distanceMTo(String distance, String station);

  /// No description provided for @myCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'My Current Location'**
  String get myCurrentLocation;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @darkModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkModeLabel;

  /// No description provided for @darkModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Overrides your device\'s system setting'**
  String get darkModeSubtitle;

  /// No description provided for @accountSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSectionLabel;

  /// No description provided for @preferencesSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferencesSectionLabel;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @quickDestinationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick Destinations'**
  String get quickDestinationsLabel;

  /// No description provided for @adPlaceholderLabel.
  ///
  /// In en, this message translates to:
  /// **'Advertisement'**
  String get adPlaceholderLabel;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @contactUsLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUsLabel;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// No description provided for @socialSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in. Please try again.'**
  String get socialSignInFailed;

  /// No description provided for @savedPlacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved Places'**
  String get savedPlacesTitle;

  /// No description provided for @addPlaceButton.
  ///
  /// In en, this message translates to:
  /// **'Add a place'**
  String get addPlaceButton;

  /// No description provided for @noSavedPlacesYet.
  ///
  /// In en, this message translates to:
  /// **'No saved places yet. Tap below to add one.'**
  String get noSavedPlacesYet;

  /// No description provided for @deletePlaceConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this place?'**
  String get deletePlaceConfirmTitle;

  /// No description provided for @deletePlaceConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You can always add it again later.'**
  String get deletePlaceConfirmBody;

  /// No description provided for @placeNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name (e.g. Gym, Mosque)'**
  String get placeNameHint;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @removeButton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeButton;

  /// No description provided for @noSearchResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No places found. Try a different search.'**
  String get noSearchResultsFound;

  /// No description provided for @placeSearchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Place search isn\'t available in this version of the app. You can still pick a spot on the map.'**
  String get placeSearchUnavailable;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get continueAsGuest;

  /// No description provided for @guestLabel.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guestLabel;

  /// No description provided for @deleteAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountButton;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and can\'t be undone.'**
  String get deleteAccountConfirmBody;

  /// No description provided for @deleteGuestDataButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Guest Data'**
  String get deleteGuestDataButton;

  /// No description provided for @deleteGuestDataConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your guest data?'**
  String get deleteGuestDataConfirmTitle;

  /// No description provided for @deleteGuestDataConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This ends your guest session and deletes the data linked to it, like your agreement to our terms. Route reports you sent are kept. This can\'t be undone.'**
  String get deleteGuestDataConfirmBody;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @reauthRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again'**
  String get reauthRequiredTitle;

  /// No description provided for @reauthRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'For your security, confirm it\'s you before we delete your account.'**
  String get reauthRequiredBody;

  /// No description provided for @confirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmButton;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete your account. Please try again.'**
  String get deleteAccountFailed;

  /// No description provided for @recentSearchesLabel.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recentSearchesLabel;

  /// No description provided for @clearHistoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearHistoryLabel;

  /// No description provided for @shareRouteText.
  ///
  /// In en, this message translates to:
  /// **'How to get from {start} to {end} by public transport, on Guidy:\n{link}'**
  String shareRouteText(String start, String end, String link);

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @somethingWentWrongTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrongTitle;

  /// No description provided for @rateGuidyLabel.
  ///
  /// In en, this message translates to:
  /// **'Rate Guidy'**
  String get rateGuidyLabel;

  /// No description provided for @privacyPolicyLabel.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyLabel;

  /// No description provided for @supportSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supportSectionLabel;

  /// No description provided for @useCurrentLocationTooltip.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get useCurrentLocationTooltip;

  /// No description provided for @showPasswordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPasswordTooltip;

  /// No description provided for @hidePasswordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePasswordTooltip;

  /// No description provided for @closeMapTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeMapTooltip;

  /// No description provided for @centerOnMyLocationTooltip.
  ///
  /// In en, this message translates to:
  /// **'Center on my location'**
  String get centerOnMyLocationTooltip;

  /// No description provided for @removePlaceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove this place'**
  String get removePlaceTooltip;

  /// No description provided for @vehicleBus.
  ///
  /// In en, this message translates to:
  /// **'Bus'**
  String get vehicleBus;

  /// No description provided for @vehicleMinibus.
  ///
  /// In en, this message translates to:
  /// **'Minibus'**
  String get vehicleMinibus;

  /// No description provided for @vehicleMicrobus.
  ///
  /// In en, this message translates to:
  /// **'Microbus'**
  String get vehicleMicrobus;

  /// No description provided for @vehicleMetro.
  ///
  /// In en, this message translates to:
  /// **'Metro'**
  String get vehicleMetro;

  /// No description provided for @vehicleMonorail.
  ///
  /// In en, this message translates to:
  /// **'Monorail'**
  String get vehicleMonorail;

  /// No description provided for @vehicleLrt.
  ///
  /// In en, this message translates to:
  /// **'LRT'**
  String get vehicleLrt;

  /// No description provided for @vehicleTram.
  ///
  /// In en, this message translates to:
  /// **'Tram'**
  String get vehicleTram;

  /// No description provided for @vehicleAirportShuttle.
  ///
  /// In en, this message translates to:
  /// **'Airport Shuttle'**
  String get vehicleAirportShuttle;

  /// Cairo Ring Road bus rapid transit
  ///
  /// In en, this message translates to:
  /// **'BRT'**
  String get vehicleBrt;

  /// No description provided for @vehicleWalk.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get vehicleWalk;

  /// No description provided for @routeTierRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get routeTierRecommended;

  /// No description provided for @routeTierFastest.
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get routeTierFastest;

  /// No description provided for @routeTierRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get routeTierRegular;

  /// No description provided for @routeTierCheapest.
  ///
  /// In en, this message translates to:
  /// **'Cheapest'**
  String get routeTierCheapest;

  /// No description provided for @routeTierAlternative.
  ///
  /// In en, this message translates to:
  /// **'Alternative'**
  String get routeTierAlternative;

  /// No description provided for @routeTierWalk.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get routeTierWalk;

  /// No description provided for @crowdLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get crowdLow;

  /// No description provided for @crowdMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get crowdMedium;

  /// No description provided for @crowdHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get crowdHigh;

  /// No description provided for @instrWalkToStationTitle.
  ///
  /// In en, this message translates to:
  /// **'Walk to Station'**
  String get instrWalkToStationTitle;

  /// No description provided for @instrWalkToStationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Walk {distance}m to {station}'**
  String instrWalkToStationSubtitle(String distance, String station);

  /// No description provided for @instrWalkToTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Walk to Transfer'**
  String get instrWalkToTransferTitle;

  /// No description provided for @instrWalkToTransferSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Walk to the next stop near {station}'**
  String instrWalkToTransferSubtitle(String station);

  /// No description provided for @instrContinueWalkTitle.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get instrContinueWalkTitle;

  /// No description provided for @instrContinueWalkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Continue on foot'**
  String get instrContinueWalkSubtitle;

  /// No description provided for @instrBoardTitleWithVehicle.
  ///
  /// In en, this message translates to:
  /// **'Board {vehicleType}'**
  String instrBoardTitleWithVehicle(String vehicleType);

  /// No description provided for @instrBoardWithNumber.
  ///
  /// In en, this message translates to:
  /// **'{vehicleType} {routeNumber}'**
  String instrBoardWithNumber(String vehicleType, String routeNumber);

  /// No description provided for @instrBoardGeneral.
  ///
  /// In en, this message translates to:
  /// **'{vehicleType} towards {routeDescription}'**
  String instrBoardGeneral(String vehicleType, String routeDescription);

  /// No description provided for @instrTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get instrTransferTitle;

  /// No description provided for @instrArriveTitle.
  ///
  /// In en, this message translates to:
  /// **'Arrive & Disembark'**
  String get instrArriveTitle;

  /// No description provided for @instrArriveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get off at {station}'**
  String instrArriveSubtitle(String station);

  /// No description provided for @instrWalkToDestinationTitle.
  ///
  /// In en, this message translates to:
  /// **'Walk to Destination'**
  String get instrWalkToDestinationTitle;

  /// No description provided for @instrWalkToDestinationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Walk {distance}m to your destination'**
  String instrWalkToDestinationSubtitle(String distance);

  /// No description provided for @fareEstimateNote.
  ///
  /// In en, this message translates to:
  /// **'Fares are estimates and may vary'**
  String get fareEstimateNote;

  /// No description provided for @tripRecapTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip Overview'**
  String get tripRecapTitle;

  /// No description provided for @tripStepsLabel.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get tripStepsLabel;

  /// No description provided for @fareTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Fare'**
  String get fareTotalLabel;

  /// No description provided for @startNavigationButton.
  ///
  /// In en, this message translates to:
  /// **'Start Navigation'**
  String get startNavigationButton;

  /// No description provided for @navLines.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get navLines;

  /// No description provided for @navMetro.
  ///
  /// In en, this message translates to:
  /// **'Metro'**
  String get navMetro;

  /// Title of the Lines list for one transport mode, e.g. "Minibus Lines".
  ///
  /// In en, this message translates to:
  /// **'{mode} Lines'**
  String linesOfMode(String mode);

  /// Line detail: label of the card with the time of the first trip of the day.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get lineFirstTrip;

  /// Line detail: label of the card with the time of the last trip of the day.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get lineLastTrip;

  /// Line detail: label of the card with the line's operating hours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get lineServiceHours;

  /// Line detail: the line is running at the moment.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get lineOpenNow;

  /// Line detail: the line is not running at the moment.
  ///
  /// In en, this message translates to:
  /// **'Closed now'**
  String get lineClosedNow;

  /// Trip recap: a line on the trip is not running now, and when it starts again.
  ///
  /// In en, this message translates to:
  /// **'Closed now, opens at {time}'**
  String lineClosedOpensAt(String time);

  /// Live navigation: menu button that opens the tool rail on the map.
  ///
  /// In en, this message translates to:
  /// **'Show trip tools'**
  String get navToolsShow;

  /// Live navigation: menu button that folds the tool rail away.
  ///
  /// In en, this message translates to:
  /// **'Hide trip tools'**
  String get navToolsHide;

  /// Live navigation tool rail: zoom the map out to show the whole route.
  ///
  /// In en, this message translates to:
  /// **'Route overview'**
  String get navToolsOverview;

  /// No description provided for @linesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Line number, or where it goes'**
  String get linesSearchHint;

  /// No description provided for @linesSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Search a line number like 65, or a place like Maadi.'**
  String get linesSearchPrompt;

  /// No description provided for @linesNoResults.
  ///
  /// In en, this message translates to:
  /// **'No lines match that search.'**
  String get linesNoResults;

  /// No description provided for @linesTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a line to see every stop it makes.'**
  String get linesTapHint;

  /// Title of the Lines screen while the Alexandria-only view is on.
  ///
  /// In en, this message translates to:
  /// **'Alexandria Lines'**
  String get linesAlexandriaTitle;

  /// Title of the Alexandria-only Lines list for one transport mode, e.g. "Alexandria Microbus Lines".
  ///
  /// In en, this message translates to:
  /// **'Alexandria {mode} Lines'**
  String linesAlexandriaOfMode(String mode);

  /// Subtitle of the Alexandria-only Lines view.
  ///
  /// In en, this message translates to:
  /// **'Only lines that run in Alexandria, including the Cairo to Alexandria microbuses.'**
  String get linesAlexandriaHint;

  /// Alexandria-only Lines view: the data has no Alexandria lines.
  ///
  /// In en, this message translates to:
  /// **'No Alexandria lines are available right now.'**
  String get linesAlexandriaEmpty;

  /// No description provided for @linesStopCount.
  ///
  /// In en, this message translates to:
  /// **'{count} stops'**
  String linesStopCount(int count);

  /// No description provided for @linesEveryMinutes.
  ///
  /// In en, this message translates to:
  /// **'About every {minutes}'**
  String linesEveryMinutes(String minutes);

  /// No description provided for @linesDirectionTowards.
  ///
  /// In en, this message translates to:
  /// **'Towards {terminus}'**
  String linesDirectionTowards(String terminus);

  /// No description provided for @linesStopsInOrder.
  ///
  /// In en, this message translates to:
  /// **'Stops in order'**
  String get linesStopsInOrder;

  /// No description provided for @linesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load lines right now.'**
  String get linesLoadFailed;

  /// No description provided for @linesViewList.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get linesViewList;

  /// No description provided for @linesViewMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get linesViewMap;

  /// No description provided for @linesFitRoute.
  ///
  /// In en, this message translates to:
  /// **'Fit Route'**
  String get linesFitRoute;

  /// No description provided for @metroTitle.
  ///
  /// In en, this message translates to:
  /// **'Metro Planner'**
  String get metroTitle;

  /// No description provided for @metroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Metro only. No buses, no walking legs.'**
  String get metroSubtitle;

  /// No description provided for @metroFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get metroFromLabel;

  /// No description provided for @metroToLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get metroToLabel;

  /// No description provided for @metroPickStation.
  ///
  /// In en, this message translates to:
  /// **'Choose a station'**
  String get metroPickStation;

  /// No description provided for @metroPlanButton.
  ///
  /// In en, this message translates to:
  /// **'Show metro route'**
  String get metroPlanButton;

  /// No description provided for @metroSameStationError.
  ///
  /// In en, this message translates to:
  /// **'Pick two different stations.'**
  String get metroSameStationError;

  /// No description provided for @metroNoPathError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find a metro-only route between those two.'**
  String get metroNoPathError;

  /// No description provided for @metroSearchStationHint.
  ///
  /// In en, this message translates to:
  /// **'Search stations'**
  String get metroSearchStationHint;

  /// No description provided for @metroChangeAt.
  ///
  /// In en, this message translates to:
  /// **'Change at {station}'**
  String metroChangeAt(String station);

  /// No description provided for @metroChangeTo.
  ///
  /// In en, this message translates to:
  /// **'Change to {line}'**
  String metroChangeTo(String line);

  /// No description provided for @metroChangesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change} other{{count} changes}}'**
  String metroChangesCount(int count);

  /// No description provided for @metroNoChanges.
  ///
  /// In en, this message translates to:
  /// **'Direct, no changes'**
  String get metroNoChanges;

  /// No description provided for @metroInterchangeBadge.
  ///
  /// In en, this message translates to:
  /// **'Interchange'**
  String get metroInterchangeBadge;

  /// No description provided for @metroRideStops.
  ///
  /// In en, this message translates to:
  /// **'Ride {count} stops'**
  String metroRideStops(int count);

  /// No description provided for @metroSwapTooltip.
  ///
  /// In en, this message translates to:
  /// **'Swap start and destination'**
  String get metroSwapTooltip;

  /// No description provided for @metroLinesServing.
  ///
  /// In en, this message translates to:
  /// **'Lines: {lines}'**
  String metroLinesServing(String lines);

  /// No description provided for @metroStationsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the station list.'**
  String get metroStationsLoadFailed;

  /// No description provided for @navRecenterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Re-center on me'**
  String get navRecenterTooltip;

  /// No description provided for @fareFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get fareFree;

  /// No description provided for @pinnedLocation.
  ///
  /// In en, this message translates to:
  /// **'Pinned location'**
  String get pinnedLocation;

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the Guidy server. Check your connection and try again.'**
  String get serverUnreachable;

  /// No description provided for @errorOutsideCoverage.
  ///
  /// In en, this message translates to:
  /// **'That place is outside the area Guidy covers.'**
  String get errorOutsideCoverage;

  /// No description provided for @errorNoRouteFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find a way to get there. It may be outside our coverage.'**
  String get errorNoRouteFound;

  /// No description provided for @errorNoServiceThisHour.
  ///
  /// In en, this message translates to:
  /// **'Nothing is running at this hour. Most routes here run about 06:00 to 23:00. Try again during service hours.'**
  String get errorNoServiceThisHour;

  /// No description provided for @errorTitleNotCovered.
  ///
  /// In en, this message translates to:
  /// **'We don\'t cover this trip yet'**
  String get errorTitleNotCovered;

  /// No description provided for @errorTitleNoService.
  ///
  /// In en, this message translates to:
  /// **'Nothing is running right now'**
  String get errorTitleNoService;

  /// No description provided for @linesDirectionTowardsFrom.
  ///
  /// In en, this message translates to:
  /// **'Towards {terminus}, from {origin}'**
  String linesDirectionTowardsFrom(String terminus, String origin);

  /// No description provided for @reportEntryPoint.
  ///
  /// In en, this message translates to:
  /// **'Something wrong with this route?'**
  String get reportEntryPoint;

  /// No description provided for @reportCommentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please tell us a bit more so we can act on it.'**
  String get reportCommentRequired;

  /// No description provided for @reportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get reportSubmit;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Thanks, your report was sent.'**
  String get reportSent;

  /// No description provided for @reportQueued.
  ///
  /// In en, this message translates to:
  /// **'Saved. We\'ll send it as soon as you\'re back online.'**
  String get reportQueued;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send that report. Please try again.'**
  String get reportFailed;

  /// No description provided for @reportSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to send a report.'**
  String get reportSignInRequired;

  /// No description provided for @routeTierPartial.
  ///
  /// In en, this message translates to:
  /// **'Gets you close'**
  String get routeTierPartial;

  /// No description provided for @partialUncoveredNotice.
  ///
  /// In en, this message translates to:
  /// **'This doesn\'t reach your destination. The last {distance} isn\'t covered by any route we know yet.'**
  String partialUncoveredNotice(String distance);

  /// No description provided for @partialLastCoveredStop.
  ///
  /// In en, this message translates to:
  /// **'Last stop we cover: {stop}'**
  String partialLastCoveredStop(String stop);

  /// No description provided for @nearestHubsHint.
  ///
  /// In en, this message translates to:
  /// **'The closest places we do cover are {origin} near your start, and {destination} near your destination.'**
  String nearestHubsHint(String origin, String destination);

  /// No description provided for @reportMissingRouteButton.
  ///
  /// In en, this message translates to:
  /// **'Tell us what\'s missing'**
  String get reportMissingRouteButton;

  /// No description provided for @reportMissingRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Which route should be here?'**
  String get reportMissingRouteTitle;

  /// No description provided for @reportMissingRouteIntro.
  ///
  /// In en, this message translates to:
  /// **'Our data is incomplete for this trip. If you know a bus, minibus or microbus that makes it, tell us and we\'ll add it for everyone.'**
  String get reportMissingRouteIntro;

  /// No description provided for @reportMissingRouteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. minibus 37 from Kilo 4 & Half to Kafr Tohormos'**
  String get reportMissingRouteHint;

  /// No description provided for @betterRouteButton.
  ///
  /// In en, this message translates to:
  /// **'Know a better route?'**
  String get betterRouteButton;

  /// No description provided for @betterRouteSheetIntro.
  ///
  /// In en, this message translates to:
  /// **'Tell us about it and we\'ll check it and add it for everyone.'**
  String get betterRouteSheetIntro;

  /// No description provided for @betterRouteWriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Write it to us'**
  String get betterRouteWriteTitle;

  /// No description provided for @betterRouteWriteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Describe it in your own words'**
  String get betterRouteWriteSubtitle;

  /// No description provided for @betterRouteWriteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. walk to Abbas El Akkad, minibus 66 to Ramses, then the metro'**
  String get betterRouteWriteHint;

  /// No description provided for @betterRouteBuildTitle.
  ///
  /// In en, this message translates to:
  /// **'Build it from the transport network'**
  String get betterRouteBuildTitle;

  /// No description provided for @betterRouteBuildSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick each line and walk in order'**
  String get betterRouteBuildSubtitle;

  /// No description provided for @betterRouteBuilderTitle.
  ///
  /// In en, this message translates to:
  /// **'Build your route'**
  String get betterRouteBuilderTitle;

  /// No description provided for @betterRouteBuilderIntro.
  ///
  /// In en, this message translates to:
  /// **'Add each part of the trip in order, from your start to your destination.'**
  String get betterRouteBuilderIntro;

  /// No description provided for @betterRouteAddWalk.
  ///
  /// In en, this message translates to:
  /// **'Add a walk'**
  String get betterRouteAddWalk;

  /// No description provided for @betterRouteAddRide.
  ///
  /// In en, this message translates to:
  /// **'Add a ride'**
  String get betterRouteAddRide;

  /// No description provided for @betterRouteWalkMeters.
  ///
  /// In en, this message translates to:
  /// **'Metres (optional)'**
  String get betterRouteWalkMeters;

  /// No description provided for @betterRouteBoardAt.
  ///
  /// In en, this message translates to:
  /// **'Board at (optional)'**
  String get betterRouteBoardAt;

  /// No description provided for @betterRouteGetOffAt.
  ///
  /// In en, this message translates to:
  /// **'Get off at (optional)'**
  String get betterRouteGetOffAt;

  /// No description provided for @betterRouteFare.
  ///
  /// In en, this message translates to:
  /// **'Fare in EGP (optional)'**
  String get betterRouteFare;

  /// No description provided for @betterRouteNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Anything else we should know? (optional)'**
  String get betterRouteNoteHint;

  /// No description provided for @betterRouteRemoveLeg.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get betterRouteRemoveLeg;

  /// No description provided for @betterRouteReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get betterRouteReorderHint;

  /// No description provided for @betterRouteMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get betterRouteMoveUp;

  /// No description provided for @betterRouteMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get betterRouteMoveDown;

  /// No description provided for @betterRouteChangeLine.
  ///
  /// In en, this message translates to:
  /// **'Change line'**
  String get betterRouteChangeLine;

  /// No description provided for @betterRoutePickLineTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick the line'**
  String get betterRoutePickLineTitle;

  /// No description provided for @betterRouteNotInApp.
  ///
  /// In en, this message translates to:
  /// **'Not in the app? Type it yourself'**
  String get betterRouteNotInApp;

  /// No description provided for @betterRouteTypedMode.
  ///
  /// In en, this message translates to:
  /// **'Type of ride'**
  String get betterRouteTypedMode;

  /// No description provided for @betterRouteTypedName.
  ///
  /// In en, this message translates to:
  /// **'Line number or name'**
  String get betterRouteTypedName;

  /// No description provided for @betterRouteTypedAdd.
  ///
  /// In en, this message translates to:
  /// **'Add this line'**
  String get betterRouteTypedAdd;

  /// No description provided for @betterRouteTypedBadge.
  ///
  /// In en, this message translates to:
  /// **'Not in the app'**
  String get betterRouteTypedBadge;

  /// No description provided for @betterRouteNeedRide.
  ///
  /// In en, this message translates to:
  /// **'Add at least one ride to send the route.'**
  String get betterRouteNeedRide;

  /// No description provided for @betterRouteSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send the route'**
  String get betterRouteSubmit;

  /// No description provided for @betterRouteDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave without sending?'**
  String get betterRouteDiscardTitle;

  /// No description provided for @betterRouteDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The route you built will be lost.'**
  String get betterRouteDiscardBody;

  /// No description provided for @betterRouteDiscardLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get betterRouteDiscardLeave;

  /// No description provided for @betterRouteDiscardStay.
  ///
  /// In en, this message translates to:
  /// **'Keep building'**
  String get betterRouteDiscardStay;

  /// No description provided for @excludeMetro.
  ///
  /// In en, this message translates to:
  /// **'Exclude Metro'**
  String get excludeMetro;

  /// No description provided for @filterMinWalk.
  ///
  /// In en, this message translates to:
  /// **'Minimum Walk'**
  String get filterMinWalk;

  /// No description provided for @filterMinTransfers.
  ///
  /// In en, this message translates to:
  /// **'Fewest Transfers'**
  String get filterMinTransfers;

  /// No description provided for @shareTripTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share Trip'**
  String get shareTripTooltip;

  /// No description provided for @navStopAlarmOn.
  ///
  /// In en, this message translates to:
  /// **'Stop alert active'**
  String get navStopAlarmOn;

  /// No description provided for @navStopAlarmOff.
  ///
  /// In en, this message translates to:
  /// **'Stop alert disabled'**
  String get navStopAlarmOff;

  /// No description provided for @navStopAlarmAlert.
  ///
  /// In en, this message translates to:
  /// **'Prepare to get off! Next stop: {station}'**
  String navStopAlarmAlert(String station);

  /// No description provided for @metroTicketTitle.
  ///
  /// In en, this message translates to:
  /// **'Metro Ticket Counter'**
  String get metroTicketTitle;

  /// No description provided for @navStopAlarmActiveToast.
  ///
  /// In en, this message translates to:
  /// **'Stop alert: Active (vibrates 400m before your stop)'**
  String get navStopAlarmActiveToast;

  /// No description provided for @navStopAlarmDisabledToast.
  ///
  /// In en, this message translates to:
  /// **'Stop alert: Disabled'**
  String get navStopAlarmDisabledToast;

  /// No description provided for @navRecenterFinding.
  ///
  /// In en, this message translates to:
  /// **'Finding your location...'**
  String get navRecenterFinding;

  /// No description provided for @navRecenterSuccess.
  ///
  /// In en, this message translates to:
  /// **'Centered on your location'**
  String get navRecenterSuccess;

  /// No description provided for @navRecenterFallback.
  ///
  /// In en, this message translates to:
  /// **'GPS unavailable, centered on trip start'**
  String get navRecenterFallback;

  /// No description provided for @navOverviewToast.
  ///
  /// In en, this message translates to:
  /// **'Full route overview'**
  String get navOverviewToast;

  /// No description provided for @directRouteNoTransfers.
  ///
  /// In en, this message translates to:
  /// **'Direct transit'**
  String get directRouteNoTransfers;

  /// No description provided for @transfersCountBadge.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transfer} other{{count} transfers}}'**
  String transfersCountBadge(int count);

  /// No description provided for @walkMetersBadge.
  ///
  /// In en, this message translates to:
  /// **'{meters} m walk'**
  String walkMetersBadge(String meters);

  /// No description provided for @quickReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Commute Conditions'**
  String get quickReportTitle;

  /// No description provided for @quickReportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help fellow commuters know live transit status'**
  String get quickReportSubtitle;

  /// No description provided for @reportCategoryTraffic.
  ///
  /// In en, this message translates to:
  /// **'Traffic standstill / Severe jam'**
  String get reportCategoryTraffic;

  /// No description provided for @reportCategoryMissing.
  ///
  /// In en, this message translates to:
  /// **'Bus delayed or missing'**
  String get reportCategoryMissing;

  /// No description provided for @reportCategoryCrowd.
  ///
  /// In en, this message translates to:
  /// **'Severe vehicle or stop crowding'**
  String get reportCategoryCrowd;

  /// No description provided for @reportCategoryFare.
  ///
  /// In en, this message translates to:
  /// **'Microbus driver / collector increased fare'**
  String get reportCategoryFare;

  /// No description provided for @reportCategoryDiversion.
  ///
  /// In en, this message translates to:
  /// **'Route diverted / Roadblock'**
  String get reportCategoryDiversion;

  /// No description provided for @reportThanksToast.
  ///
  /// In en, this message translates to:
  /// **'Thank you, your report helps fellow commuters!'**
  String get reportThanksToast;

  /// No description provided for @reportNotePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Any extra details? (Optional)'**
  String get reportNotePlaceholder;

  /// No description provided for @walkManeuverRight.
  ///
  /// In en, this message translates to:
  /// **'Turn right'**
  String get walkManeuverRight;

  /// No description provided for @walkManeuverLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn left'**
  String get walkManeuverLeft;

  /// No description provided for @walkManeuverUTurn.
  ///
  /// In en, this message translates to:
  /// **'Make a U-turn'**
  String get walkManeuverUTurn;

  /// No description provided for @walkInDistance.
  ///
  /// In en, this message translates to:
  /// **'In {distance} {action}'**
  String walkInDistance(String distance, String action);

  /// No description provided for @metroNetworkMapButton.
  ///
  /// In en, this message translates to:
  /// **'Network Map'**
  String get metroNetworkMapButton;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get navHistory;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Trips & Savings'**
  String get historyTitle;

  /// No description provided for @totalMoneySaved.
  ///
  /// In en, this message translates to:
  /// **'Money Saved'**
  String get totalMoneySaved;

  /// No description provided for @totalTimeSaved.
  ///
  /// In en, this message translates to:
  /// **'Time Saved'**
  String get totalTimeSaved;

  /// No description provided for @emptyHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'No Trips Logged Yet'**
  String get emptyHistoryTitle;

  /// No description provided for @emptyHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start navigating or plan a trip with Guidy to see your cumulative money, time, and carbon savings!'**
  String get emptyHistorySubtitle;

  /// No description provided for @planTripButton.
  ///
  /// In en, this message translates to:
  /// **'Plan a Trip'**
  String get planTripButton;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear all trip history?'**
  String get clearHistoryConfirm;

  /// No description provided for @clearHistoryAction.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistoryAction;

  /// No description provided for @clearHistorySuccess.
  ///
  /// In en, this message translates to:
  /// **'Trip history cleared'**
  String get clearHistorySuccess;

  /// No description provided for @tripDeletedToast.
  ///
  /// In en, this message translates to:
  /// **'Trip removed from history'**
  String get tripDeletedToast;

  /// No description provided for @savingsCalculationInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'How Savings are Calculated'**
  String get savingsCalculationInfoTitle;

  /// No description provided for @savingsCalculationInfo.
  ///
  /// In en, this message translates to:
  /// **'Savings are calculated based on your personal route choice: when you choose the Fastest route, we calculate the minutes you saved compared to slower alternatives, and when you choose the Cheapest route, we calculate the money you saved compared to more expensive alternatives.'**
  String get savingsCalculationInfo;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get filterThisWeek;

  /// No description provided for @filterThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get filterThisMonth;

  /// No description provided for @filterMetro.
  ///
  /// In en, this message translates to:
  /// **'Metro'**
  String get filterMetro;

  /// No description provided for @filterBus.
  ///
  /// In en, this message translates to:
  /// **'Bus'**
  String get filterBus;

  /// No description provided for @filterMicrobus.
  ///
  /// In en, this message translates to:
  /// **'Microbus'**
  String get filterMicrobus;

  /// No description provided for @minsSavedShort.
  ///
  /// In en, this message translates to:
  /// **'{mins} saved'**
  String minsSavedShort(String mins);

  /// No description provided for @hoursMinsSavedShort.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {mins}m saved'**
  String hoursMinsSavedShort(String hours, String mins);

  /// No description provided for @reportLineTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Line Issue'**
  String get reportLineTitle;

  /// No description provided for @reportMetroTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Metro Issue'**
  String get reportMetroTitle;

  /// No description provided for @reportReasonLineDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'Line does not exist or discontinued'**
  String get reportReasonLineDoesNotExist;

  /// No description provided for @reportReasonLineWrongPath.
  ///
  /// In en, this message translates to:
  /// **'Route diversion or different streets'**
  String get reportReasonLineWrongPath;

  /// No description provided for @reportReasonLineWrongStop.
  ///
  /// In en, this message translates to:
  /// **'Wrong stop sequence or missing stop'**
  String get reportReasonLineWrongStop;

  /// No description provided for @reportReasonLineWrongFare.
  ///
  /// In en, this message translates to:
  /// **'Incorrect fare'**
  String get reportReasonLineWrongFare;

  /// No description provided for @reportReasonLineBadTiming.
  ///
  /// In en, this message translates to:
  /// **'Inaccurate schedule or frequency'**
  String get reportReasonLineBadTiming;

  /// No description provided for @reportReasonMetroStationClosed.
  ///
  /// In en, this message translates to:
  /// **'Station closed or out of service'**
  String get reportReasonMetroStationClosed;

  /// No description provided for @reportReasonMetroWrongTransfer.
  ///
  /// In en, this message translates to:
  /// **'Incorrect transfer instruction'**
  String get reportReasonMetroWrongTransfer;

  /// No description provided for @reportReasonMetroWrongFare.
  ///
  /// In en, this message translates to:
  /// **'Incorrect ticket fare'**
  String get reportReasonMetroWrongFare;

  /// No description provided for @reportReasonMetroDelay.
  ///
  /// In en, this message translates to:
  /// **'Significant delay or disruption'**
  String get reportReasonMetroDelay;

  /// No description provided for @reportPickStopOptional.
  ///
  /// In en, this message translates to:
  /// **'Select affected stop (optional)'**
  String get reportPickStopOptional;

  /// No description provided for @reportAllStopsOption.
  ///
  /// In en, this message translates to:
  /// **'General line issue (entire route)'**
  String get reportAllStopsOption;

  /// No description provided for @reportActionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get reportActionSubmit;

  /// No description provided for @reportLineSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your report has been submitted to improve the network.'**
  String get reportLineSuccessToast;

  /// No description provided for @reportCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Add details (e.g. actual fare, detour street, etc.)'**
  String get reportCommentHint;

  /// No description provided for @reportAnIssueWithThisLine.
  ///
  /// In en, this message translates to:
  /// **'Report an issue with this line'**
  String get reportAnIssueWithThisLine;

  /// No description provided for @reportAnIssueWithMetro.
  ///
  /// In en, this message translates to:
  /// **'Report an issue with this metro route'**
  String get reportAnIssueWithMetro;

  /// No description provided for @reportCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other issue'**
  String get reportCategoryOther;

  /// No description provided for @reportReasonPrompt.
  ///
  /// In en, this message translates to:
  /// **'What is the problem?'**
  String get reportReasonPrompt;

  /// No description provided for @recentTripsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Trips'**
  String get recentTripsTitle;

  /// No description provided for @recentTripsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trips you\'ve taken, their cost and duration'**
  String get recentTripsSubtitle;

  /// No description provided for @noRecentTripsYet.
  ///
  /// In en, this message translates to:
  /// **'No trips taken yet. Take a ride and it will appear here!'**
  String get noRecentTripsYet;

  /// No description provided for @moneySavedPill.
  ///
  /// In en, this message translates to:
  /// **'Saved {amount} EGP'**
  String moneySavedPill(String amount);

  /// No description provided for @tripDetailFarePaid.
  ///
  /// In en, this message translates to:
  /// **'Fare Paid'**
  String get tripDetailFarePaid;

  /// No description provided for @tripDetailOpenRecap.
  ///
  /// In en, this message translates to:
  /// **'View Trip Details'**
  String get tripDetailOpenRecap;

  /// A number of minutes, pluralised. Arabic needs its own forms: 1 دقيقة, 2 دقيقتين, 3-10 دقائق, 11+ دقيقة.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min} other{{count} min}}'**
  String minutesCount(int count);

  /// Whole hours of a trip over an hour: 1 h, 2 h. Arabic needs its own forms: ساعة, ساعتين, 3-10 ساعات, 11+ ساعة.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} h}}'**
  String durationHours(int count);

  /// The minutes after the hours of a long trip: 1 h 18 min. Arabic joins them with و (ساعة و18 دقيقة).
  ///
  /// In en, this message translates to:
  /// **'{minutes}'**
  String durationAndMinutes(String minutes);

  /// A walk on a route card, beside the walking icon.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String routeWalkMeters(String meters);

  /// A ride's line on a route card: Minibus 66, Green Bus G1.
  ///
  /// In en, this message translates to:
  /// **'{mode} {number}'**
  String routeCardLine(String mode, String number);

  /// No description provided for @plannerHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a line on the map or a route below to choose it'**
  String get plannerHint;

  /// No description provided for @plannerWalkTo.
  ///
  /// In en, this message translates to:
  /// **'Walk {distance} to {station}'**
  String plannerWalkTo(String distance, String station);

  /// No description provided for @plannerWalkToDestination.
  ///
  /// In en, this message translates to:
  /// **'Walk {distance} to your destination'**
  String plannerWalkToDestination(String distance);

  /// No description provided for @lineRecommended.
  ///
  /// In en, this message translates to:
  /// **'recommended'**
  String get lineRecommended;

  /// No description provided for @lineRecommendedLegend.
  ///
  /// In en, this message translates to:
  /// **'Just as good: covers the whole ride, no extra walk, a similar fare'**
  String get lineRecommendedLegend;

  /// No description provided for @plannerAnyOfTheseLines.
  ///
  /// In en, this message translates to:
  /// **'{mode}, take any of these'**
  String plannerAnyOfTheseLines(String mode);

  /// No description provided for @plannerMoreLines.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String plannerMoreLines(int count);

  /// No description provided for @plannerFewerLines.
  ///
  /// In en, this message translates to:
  /// **'Show fewer'**
  String get plannerFewerLines;

  /// No description provided for @plannerHailAt.
  ///
  /// In en, this message translates to:
  /// **'Wave one down at {station}'**
  String plannerHailAt(String station);

  /// No description provided for @plannerAskToStopAt.
  ///
  /// In en, this message translates to:
  /// **'Ask the driver to stop at {station}'**
  String plannerAskToStopAt(String station);

  /// No description provided for @plannerWalkToStreet.
  ///
  /// In en, this message translates to:
  /// **'Walk {distance} to the street'**
  String plannerWalkToStreet(String distance);

  /// No description provided for @stepWalkToStreet.
  ///
  /// In en, this message translates to:
  /// **'Walk to the street'**
  String get stepWalkToStreet;

  /// No description provided for @plannerTakeFrom.
  ///
  /// In en, this message translates to:
  /// **'Get on at {station}'**
  String plannerTakeFrom(String station);

  /// No description provided for @plannerTowards.
  ///
  /// In en, this message translates to:
  /// **'towards {station}'**
  String plannerTowards(String station);

  /// No description provided for @plannerGetOffAt.
  ///
  /// In en, this message translates to:
  /// **'Get off at {station}'**
  String plannerGetOffAt(String station);

  /// No description provided for @plannerStart.
  ///
  /// In en, this message translates to:
  /// **'Start trip'**
  String get plannerStart;

  /// No description provided for @plannerClosedNow.
  ///
  /// In en, this message translates to:
  /// **'Some lines on this route aren\'t running right now'**
  String get plannerClosedNow;

  /// No description provided for @plannerMeters.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String plannerMeters(String meters);

  /// No description provided for @plannerSteps.
  ///
  /// In en, this message translates to:
  /// **'Your trip'**
  String get plannerSteps;

  /// No description provided for @navRideTo.
  ///
  /// In en, this message translates to:
  /// **'Stay on until {station}'**
  String navRideTo(String station);

  /// No description provided for @navRiding.
  ///
  /// In en, this message translates to:
  /// **'On {line}'**
  String navRiding(String line);

  /// No description provided for @navWalkThenBoard.
  ///
  /// In en, this message translates to:
  /// **'Then {action}'**
  String navWalkThenBoard(String action);

  /// No description provided for @navGetReadyOff.
  ///
  /// In en, this message translates to:
  /// **'Get ready to get off at {station}'**
  String navGetReadyOff(String station);

  /// No description provided for @navNearBoarding.
  ///
  /// In en, this message translates to:
  /// **'Almost at {station}'**
  String navNearBoarding(String station);

  /// No description provided for @navGetOffHere.
  ///
  /// In en, this message translates to:
  /// **'Get off here'**
  String get navGetOffHere;

  /// No description provided for @navWalkToDestinationFrom.
  ///
  /// In en, this message translates to:
  /// **'Walk from {station} to your destination'**
  String navWalkToDestinationFrom(String station);

  /// No description provided for @navYouArrived.
  ///
  /// In en, this message translates to:
  /// **'You have arrived'**
  String get navYouArrived;

  /// No description provided for @navSwitchRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to this route?'**
  String get navSwitchRouteTitle;

  /// No description provided for @navSwitchRouteBody.
  ///
  /// In en, this message translates to:
  /// **'{minutes}, {fare}'**
  String navSwitchRouteBody(String minutes, String fare);

  /// No description provided for @navSwitchRouteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Switch route'**
  String get navSwitchRouteConfirm;

  /// No description provided for @navCompassTooltip.
  ///
  /// In en, this message translates to:
  /// **'North up'**
  String get navCompassTooltip;

  /// No description provided for @simpleModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Simple mode'**
  String get simpleModeLabel;

  /// No description provided for @simpleModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Big text and buttons, fewer choices, one step at a time'**
  String get simpleModeSubtitle;

  /// No description provided for @simpleShowMoreRoutes.
  ///
  /// In en, this message translates to:
  /// **'Show other routes'**
  String get simpleShowMoreRoutes;

  /// No description provided for @simpleShowFewerRoutes.
  ///
  /// In en, this message translates to:
  /// **'Show only the best route'**
  String get simpleShowFewerRoutes;

  /// No description provided for @shareRouteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share this route'**
  String get shareRouteTooltip;

  /// No description provided for @shareLiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share my trip live'**
  String get shareLiveTooltip;

  /// No description provided for @shareLiveText.
  ///
  /// In en, this message translates to:
  /// **'Follow my trip to {dest} live on Guidy:\n{link}'**
  String shareLiveText(String dest, String link);

  /// No description provided for @shareLiveActive.
  ///
  /// In en, this message translates to:
  /// **'Your trip is being shared live'**
  String get shareLiveActive;

  /// No description provided for @shareLiveStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get shareLiveStop;

  /// No description provided for @shareLiveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start sharing. Check your internet connection.'**
  String get shareLiveFailed;

  /// No description provided for @liveViewerTitle.
  ///
  /// In en, this message translates to:
  /// **'Live trip'**
  String get liveViewerTitle;

  /// No description provided for @liveViewerHeading.
  ///
  /// In en, this message translates to:
  /// **'{name} is on the way to {dest}'**
  String liveViewerHeading(String name, String dest);

  /// No description provided for @liveViewerHeadingNoName.
  ///
  /// In en, this message translates to:
  /// **'On the way to {dest}'**
  String liveViewerHeadingNoName(String dest);

  /// No description provided for @liveViewerOnVehicle.
  ///
  /// In en, this message translates to:
  /// **'Now on {vehicle}'**
  String liveViewerOnVehicle(String vehicle);

  /// No description provided for @liveViewerWalking.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get liveViewerWalking;

  /// No description provided for @liveViewerEta.
  ///
  /// In en, this message translates to:
  /// **'Arrives around {time} (in {minutes})'**
  String liveViewerEta(String time, String minutes);

  /// No description provided for @liveViewerArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived at {dest}'**
  String liveViewerArrived(String dest);

  /// No description provided for @liveViewerEnded.
  ///
  /// In en, this message translates to:
  /// **'This trip is no longer being shared.'**
  String get liveViewerEnded;

  /// No description provided for @liveViewerUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last update {time}'**
  String liveViewerUpdated(String time);

  /// No description provided for @liveViewerWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for their first location…'**
  String get liveViewerWaiting;

  /// No description provided for @liveViewerOffline.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh. Retrying…'**
  String get liveViewerOffline;

  /// No description provided for @routeTierAvailableNow.
  ///
  /// In en, this message translates to:
  /// **'Running now'**
  String get routeTierAvailableNow;

  /// No description provided for @nightNothingRunningTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing\'s running for this trip right now'**
  String get nightNothingRunningTitle;

  /// No description provided for @nightNothingRunningBody.
  ///
  /// In en, this message translates to:
  /// **'None of the lines this trip needs run at this hour. Your usual route below starts running again at {time} (in {wait}).'**
  String nightNothingRunningBody(String time, String wait);

  /// No description provided for @nightCanWalk.
  ///
  /// In en, this message translates to:
  /// **'It\'s close enough to walk. See the walking option.'**
  String get nightCanWalk;

  /// No description provided for @nightAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Late night: your usual lines have stopped'**
  String get nightAvailableTitle;

  /// No description provided for @nightAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'The first option uses lines that are still running. Your usual route starts running again at {time} (in {wait}).'**
  String nightAvailableBody(String time, String wait);

  /// No description provided for @nightUsualRoute.
  ///
  /// In en, this message translates to:
  /// **'Usual route, runs again at {time}'**
  String nightUsualRoute(String time);

  /// No description provided for @pwRuleMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get pwRuleMinLength;

  /// No description provided for @pwRuleUpper.
  ///
  /// In en, this message translates to:
  /// **'An uppercase letter (A-Z)'**
  String get pwRuleUpper;

  /// No description provided for @pwRuleLower.
  ///
  /// In en, this message translates to:
  /// **'A lowercase letter (a-z)'**
  String get pwRuleLower;

  /// No description provided for @pwRuleDigit.
  ///
  /// In en, this message translates to:
  /// **'A number (0-9)'**
  String get pwRuleDigit;

  /// No description provided for @pwRuleSymbol.
  ///
  /// In en, this message translates to:
  /// **'A symbol, like ! @ # ?'**
  String get pwRuleSymbol;

  /// No description provided for @pwRuleNoEdgeSpaces.
  ///
  /// In en, this message translates to:
  /// **'No spaces at the start or end'**
  String get pwRuleNoEdgeSpaces;

  /// No description provided for @pwRuleNotCommon.
  ///
  /// In en, this message translates to:
  /// **'Not a commonly used password'**
  String get pwRuleNotCommon;

  /// No description provided for @pwStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get pwStrengthWeak;

  /// No description provided for @pwStrengthFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get pwStrengthFair;

  /// No description provided for @pwStrengthGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get pwStrengthGood;

  /// No description provided for @pwStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get pwStrengthStrong;

  /// No description provided for @pwStrengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Password strength'**
  String get pwStrengthLabel;

  /// No description provided for @passwordRulesNotMet.
  ///
  /// In en, this message translates to:
  /// **'Your password doesn\'t meet all the rules yet.'**
  String get passwordRulesNotMet;

  /// No description provided for @tooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment and try again.'**
  String get tooManyRequests;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to {email}. Open it, then come back and tap \"I\'ve verified\". Check your spam folder if you can\'t find it.'**
  String verifyEmailBody(String email);

  /// No description provided for @verifyEmailResend.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get verifyEmailResend;

  /// No description provided for @verifyEmailResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String verifyEmailResendIn(int seconds);

  /// No description provided for @verifyEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent.'**
  String get verifyEmailSent;

  /// No description provided for @verifyEmailCheck.
  ///
  /// In en, this message translates to:
  /// **'I\'ve verified'**
  String get verifyEmailCheck;

  /// No description provided for @verifyEmailNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not verified yet. Open the link in the email first.'**
  String get verifyEmailNotYet;

  /// No description provided for @verifyEmailUseOther.
  ///
  /// In en, this message translates to:
  /// **'Use a different account'**
  String get verifyEmailUseOther;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordLink;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email and we\'ll send you a link to set a new password.'**
  String get forgotPasswordBody;

  /// No description provided for @forgotPasswordSend.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get forgotPasswordSend;

  /// No description provided for @forgotPasswordSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for that email, a reset link is on its way. Check your inbox and spam folder.'**
  String get forgotPasswordSent;

  /// No description provided for @changePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordButton;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPasswordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @confirmNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPasswordLabel;

  /// No description provided for @changePasswordSave.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get changePasswordSave;

  /// No description provided for @changePasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password updated.'**
  String get changePasswordSuccess;

  /// No description provided for @currentPasswordWrong.
  ///
  /// In en, this message translates to:
  /// **'Your current password is incorrect.'**
  String get currentPasswordWrong;

  /// No description provided for @changePasswordFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update your password. Please try again.'**
  String get changePasswordFailed;

  /// No description provided for @newPasswordSameAsOld.
  ///
  /// In en, this message translates to:
  /// **'Your new password must be different from the current one.'**
  String get newPasswordSameAsOld;

  /// No description provided for @authEmailFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the email. Please try again.'**
  String get authEmailFailed;

  /// No description provided for @stepWalkTo.
  ///
  /// In en, this message translates to:
  /// **'Walk to {place}'**
  String stepWalkTo(String place);

  /// No description provided for @stepWalkToDestination.
  ///
  /// In en, this message translates to:
  /// **'Walk to your destination'**
  String get stepWalkToDestination;

  /// No description provided for @stepWalkMeta.
  ///
  /// In en, this message translates to:
  /// **'{meters} m, about {minutes}'**
  String stepWalkMeta(String meters, String minutes);

  /// No description provided for @rideTakeThing.
  ///
  /// In en, this message translates to:
  /// **'Take {thing}'**
  String rideTakeThing(String thing);

  /// No description provided for @rideRideThing.
  ///
  /// In en, this message translates to:
  /// **'Ride {thing}'**
  String rideRideThing(String thing);

  /// No description provided for @stepBoardAt.
  ///
  /// In en, this message translates to:
  /// **'Board at {station}'**
  String stepBoardAt(String station);

  /// No description provided for @stepToward.
  ///
  /// In en, this message translates to:
  /// **'toward {place}'**
  String stepToward(String place);

  /// No description provided for @stepRideTo.
  ///
  /// In en, this message translates to:
  /// **'Ride to {station}'**
  String stepRideTo(String station);

  /// No description provided for @stepStops.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stop} other{{count} stops}}'**
  String stepStops(int count);

  /// No description provided for @stepGetOffAt.
  ///
  /// In en, this message translates to:
  /// **'Get off at {station}'**
  String stepGetOffAt(String station);

  /// No description provided for @stepThenWalkTo.
  ///
  /// In en, this message translates to:
  /// **'then walk {meters} m to {place}, about {minutes}'**
  String stepThenWalkTo(String meters, String place, String minutes);

  /// No description provided for @stepThenWalkToDestination.
  ///
  /// In en, this message translates to:
  /// **'then walk {meters} m to your destination, about {minutes}'**
  String stepThenWalkToDestination(String meters, String minutes);

  /// No description provided for @liveGetOffIn.
  ///
  /// In en, this message translates to:
  /// **'Get off at {station} in about {minutes}'**
  String liveGetOffIn(String station, String minutes);

  /// No description provided for @liveWalkMetersLeft.
  ///
  /// In en, this message translates to:
  /// **'{meters} m left, about {minutes}'**
  String liveWalkMetersLeft(String meters, String minutes);

  /// No description provided for @liveWalkLeft.
  ///
  /// In en, this message translates to:
  /// **'{meters} m to {place}, about {minutes}'**
  String liveWalkLeft(String meters, String place, String minutes);

  /// No description provided for @routeShortRide.
  ///
  /// In en, this message translates to:
  /// **'{minutes} faster for {fare} EGP more'**
  String routeShortRide(String minutes, String fare);

  /// No description provided for @routeLongWalk.
  ///
  /// In en, this message translates to:
  /// **'Long walk: {minutes}'**
  String routeLongWalk(String minutes);

  /// No description provided for @rideReportButton.
  ///
  /// In en, this message translates to:
  /// **'I took a vehicle'**
  String get rideReportButton;

  /// No description provided for @rideReportTitle.
  ///
  /// In en, this message translates to:
  /// **'What did you take?'**
  String get rideReportTitle;

  /// No description provided for @rideReportFare.
  ///
  /// In en, this message translates to:
  /// **'Fare (EGP)'**
  String get rideReportFare;

  /// No description provided for @rideReportStart.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get rideReportStart;

  /// No description provided for @rideReportRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording your ride: {distance} in {minutes}'**
  String rideReportRecording(String distance, String minutes);

  /// No description provided for @rideReportStop.
  ///
  /// In en, this message translates to:
  /// **'I got off'**
  String get rideReportStop;

  /// No description provided for @rideReportThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks! We\'ll review this ride.'**
  String get rideReportThanks;

  /// No description provided for @rideVehicleTuktuk.
  ///
  /// In en, this message translates to:
  /// **'Tuk-tuk'**
  String get rideVehicleTuktuk;

  /// No description provided for @rideVehicleTaxi.
  ///
  /// In en, this message translates to:
  /// **'Taxi'**
  String get rideVehicleTaxi;

  /// No description provided for @rideVehicleOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get rideVehicleOther;

  /// No description provided for @tourSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tourSkip;

  /// No description provided for @tourNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tourNext;

  /// No description provided for @tourDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tourDone;

  /// No description provided for @tourStepOf.
  ///
  /// In en, this message translates to:
  /// **'{step} of {total}'**
  String tourStepOf(int step, int total);

  /// No description provided for @tourWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Guidy'**
  String get tourWelcomeTitle;

  /// No description provided for @tourWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'A quick look at what Guidy can do. It takes a minute, and you can skip it any time.'**
  String get tourWelcomeBody;

  /// No description provided for @tourSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan a trip'**
  String get tourSearchTitle;

  /// No description provided for @tourSearchBody.
  ///
  /// In en, this message translates to:
  /// **'Tap here, type where you\'re going, and Guidy compares buses, microbuses, minibuses and the metro by time, fare and walking.'**
  String get tourSearchBody;

  /// No description provided for @tourQuickTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick destinations'**
  String get tourQuickTitle;

  /// No description provided for @tourQuickBody.
  ///
  /// In en, this message translates to:
  /// **'Home, Work and your saved places in one tap. Hold Home or Work to change it. They\'re in the search screen too, for the start or the destination.'**
  String get tourQuickBody;

  /// No description provided for @tourRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent trips'**
  String get tourRecentTitle;

  /// No description provided for @tourRecentBody.
  ///
  /// In en, this message translates to:
  /// **'Your last trips, with what you saved. Tap one to see it again or start it again.'**
  String get tourRecentBody;

  /// No description provided for @tourLinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get tourLinesTitle;

  /// No description provided for @tourLinesBody.
  ///
  /// In en, this message translates to:
  /// **'Every bus, microbus and minibus line: where it goes and where it stops.'**
  String get tourLinesBody;

  /// No description provided for @tourMetroTitle.
  ///
  /// In en, this message translates to:
  /// **'Metro & rail'**
  String get tourMetroTitle;

  /// No description provided for @tourMetroBody.
  ///
  /// In en, this message translates to:
  /// **'The metro and rail map, stations and fares.'**
  String get tourMetroBody;

  /// No description provided for @tourTripsTitle.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get tourTripsTitle;

  /// No description provided for @tourTripsBody.
  ///
  /// In en, this message translates to:
  /// **'All your trips and how much time and money Guidy saved you.'**
  String get tourTripsBody;

  /// No description provided for @tourSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tourSettingsTitle;

  /// No description provided for @tourSettingsBody.
  ///
  /// In en, this message translates to:
  /// **'Language, dark mode, Simple mode, your account, and this tutorial if you want it again.'**
  String get tourSettingsBody;

  /// No description provided for @tourTripNowTitle.
  ///
  /// In en, this message translates to:
  /// **'What to do now'**
  String get tourTripNowTitle;

  /// No description provided for @tourTripNowBody.
  ///
  /// In en, this message translates to:
  /// **'The step you\'re on: where to walk, which vehicle to take and where to get off. It moves on by itself as you go.'**
  String get tourTripNowBody;

  /// No description provided for @tourTripLeftTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s left of this step'**
  String get tourTripLeftTitle;

  /// No description provided for @tourTripLeftBody.
  ///
  /// In en, this message translates to:
  /// **'How far and how long until the end of this step, updated as you move. A ride shows its fare next to the line. Drag this card up for every step.'**
  String get tourTripLeftBody;

  /// No description provided for @tourTripToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip tools'**
  String get tourTripToolsTitle;

  /// No description provided for @tourTripToolsBody.
  ///
  /// In en, this message translates to:
  /// **'See the whole route, share your trip live with family, or report a problem with a line.'**
  String get tourTripToolsBody;

  /// No description provided for @tourTripButtonsTitle.
  ///
  /// In en, this message translates to:
  /// **'Map buttons'**
  String get tourTripButtonsTitle;

  /// No description provided for @tourTripButtonsBody.
  ///
  /// In en, this message translates to:
  /// **'Turn the map north, bring the map back to you, and turn the alert before your stop on or off.'**
  String get tourTripButtonsBody;

  /// No description provided for @tourTripPipTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave the app any time'**
  String get tourTripPipTitle;

  /// No description provided for @tourTripPipBody.
  ///
  /// In en, this message translates to:
  /// **'On Android the trip keeps going in a small window over your other apps. Drag it to the bottom of the screen to close it.'**
  String get tourTripPipBody;

  /// No description provided for @settingsReplayTutorial.
  ///
  /// In en, this message translates to:
  /// **'Replay tutorial'**
  String get settingsReplayTutorial;

  /// No description provided for @settingsReplayTutorialSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A quick tour of Guidy\'s main features'**
  String get settingsReplayTutorialSubtitle;

  /// Pill on a Lines-screen card for a line in Alexandria (Cairo/Giza lines get none)
  ///
  /// In en, this message translates to:
  /// **'Alexandria'**
  String get lineCityAlexandria;

  /// Pill on a Lines-screen card for an intercity microbus between Cairo/Giza and Alexandria
  ///
  /// In en, this message translates to:
  /// **'Cairo ⇄ Alexandria'**
  String get lineCityIntercity;

  /// No description provided for @commuteNotifsLabel.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get commuteNotifsLabel;

  /// No description provided for @commuteNotifsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Best times to leave, last-ride warnings'**
  String get commuteNotifsSubtitle;

  /// No description provided for @commuteNotifsEasier.
  ///
  /// In en, this message translates to:
  /// **'Easier times to travel'**
  String get commuteNotifsEasier;

  /// No description provided for @commuteNotifsLastService.
  ///
  /// In en, this message translates to:
  /// **'Last-service warnings'**
  String get commuteNotifsLastService;

  /// No description provided for @commuteNotifsNeedHomeWork.
  ///
  /// In en, this message translates to:
  /// **'Save Home and Work, then plan the trip once, to get these.'**
  String get commuteNotifsNeedHomeWork;

  /// No description provided for @commuteNotifsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for Guidy on this phone, so these can\'t reach you.'**
  String get commuteNotifsBlocked;

  /// No description provided for @commuteNotifsOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Turn on in phone settings'**
  String get commuteNotifsOpenSettings;

  /// No description provided for @commuteChannelName.
  ///
  /// In en, this message translates to:
  /// **'Commute'**
  String get commuteChannelName;

  /// No description provided for @commuteChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Easier times for your trips between Home and Work, and your lines\' last service.'**
  String get commuteChannelDescription;

  /// No description provided for @commuteLastServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'{line} stops at {time}'**
  String commuteLastServiceTitle(String line, String time);

  /// No description provided for @commuteLastServiceBody.
  ///
  /// In en, this message translates to:
  /// **'Still out? This is the last service today for a line on your way home.'**
  String get commuteLastServiceBody;

  /// No description provided for @commuteEasierTitleMorning.
  ///
  /// In en, this message translates to:
  /// **'A good time to head to work'**
  String get commuteEasierTitleMorning;

  /// No description provided for @commuteEasierTitleEvening.
  ///
  /// In en, this message translates to:
  /// **'A good time to head home'**
  String get commuteEasierTitleEvening;

  /// No description provided for @commuteEasierBody.
  ///
  /// In en, this message translates to:
  /// **'{line} runs every {every} until {until}. Other times it\'s every {slow}.'**
  String commuteEasierBody(
    String line,
    String every,
    String until,
    String slow,
  );

  /// No description provided for @commuteRushTitleMorning.
  ///
  /// In en, this message translates to:
  /// **'Beat the morning rush'**
  String get commuteRushTitleMorning;

  /// No description provided for @commuteRushBodyMorning.
  ///
  /// In en, this message translates to:
  /// **'Leave before {time} for an easier ride to work.'**
  String commuteRushBodyMorning(String time);

  /// No description provided for @commuteRushTitleEvening.
  ///
  /// In en, this message translates to:
  /// **'A quieter time to head home'**
  String get commuteRushTitleEvening;

  /// No description provided for @commuteRushBodyEvening.
  ///
  /// In en, this message translates to:
  /// **'Traffic eases now, before the evening rush at {time}.'**
  String commuteRushBodyEvening(String time);

  /// No description provided for @actWalkTo.
  ///
  /// In en, this message translates to:
  /// **'Walk {minutes} to'**
  String actWalkTo(String minutes);

  /// No description provided for @actWaveDownAny.
  ///
  /// In en, this message translates to:
  /// **'Wave down any of these'**
  String get actWaveDownAny;

  /// No description provided for @actWaveDown.
  ///
  /// In en, this message translates to:
  /// **'Wave down {line} on'**
  String actWaveDown(String line);

  /// No description provided for @actWaitForAny.
  ///
  /// In en, this message translates to:
  /// **'Wait for one of these'**
  String get actWaitForAny;

  /// No description provided for @actTakeAt.
  ///
  /// In en, this message translates to:
  /// **'{action} at'**
  String actTakeAt(String action);

  /// No description provided for @actAskDriverStopAt.
  ///
  /// In en, this message translates to:
  /// **'Ask the driver to stop at'**
  String get actAskDriverStopAt;

  /// No description provided for @actWaveDownRide.
  ///
  /// In en, this message translates to:
  /// **'Wave down a ride'**
  String get actWaveDownRide;

  /// No description provided for @actWaitForRide.
  ///
  /// In en, this message translates to:
  /// **'Wait for a ride'**
  String get actWaitForRide;

  /// No description provided for @stepAskDriver.
  ///
  /// In en, this message translates to:
  /// **'Ask the driver: going to {place}?'**
  String stepAskDriver(String place);

  /// No description provided for @stepWhichMicrobuses.
  ///
  /// In en, this message translates to:
  /// **'Which microbuses?'**
  String get stepWhichMicrobuses;

  /// No description provided for @stepWhichBuses.
  ///
  /// In en, this message translates to:
  /// **'Which buses?'**
  String get stepWhichBuses;

  /// No description provided for @actGetOffAt.
  ///
  /// In en, this message translates to:
  /// **'Get off at'**
  String get actGetOffAt;

  /// No description provided for @actGetOffWalkTo.
  ///
  /// In en, this message translates to:
  /// **'Get off, then walk {minutes} to'**
  String actGetOffWalkTo(String minutes);

  /// No description provided for @actYourDestination.
  ///
  /// In en, this message translates to:
  /// **'your destination'**
  String get actYourDestination;

  /// No description provided for @navStepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get navStepDone;

  /// No description provided for @navStepLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get navStepLater;

  /// No description provided for @navBackToNow.
  ///
  /// In en, this message translates to:
  /// **'Back to now'**
  String get navBackToNow;

  /// No description provided for @navPrevStep.
  ///
  /// In en, this message translates to:
  /// **'Previous step'**
  String get navPrevStep;

  /// No description provided for @navNextStep.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get navNextStep;

  /// No description provided for @routeDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Route details'**
  String get routeDetailsTitle;

  /// No description provided for @routeLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get routeLeave;

  /// No description provided for @routeGetOff.
  ///
  /// In en, this message translates to:
  /// **'Get off'**
  String get routeGetOff;

  /// No description provided for @routeAskDriverStop.
  ///
  /// In en, this message translates to:
  /// **'Ask the driver to stop'**
  String get routeAskDriverStop;

  /// No description provided for @routeArrive.
  ///
  /// In en, this message translates to:
  /// **'Arrive'**
  String get routeArrive;

  /// No description provided for @routeRideFold.
  ///
  /// In en, this message translates to:
  /// **'Ride {stops}'**
  String routeRideFold(String stops);

  /// No description provided for @routeWalkLeg.
  ///
  /// In en, this message translates to:
  /// **'Walk {minutes}, {distance}'**
  String routeWalkLeg(String minutes, String distance);

  /// No description provided for @simpleWhereToGo.
  ///
  /// In en, this message translates to:
  /// **'Where do you want to go?'**
  String get simpleWhereToGo;

  /// No description provided for @simpleGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get simpleGoHome;

  /// No description provided for @simpleGoWork.
  ///
  /// In en, this message translates to:
  /// **'Go to work'**
  String get simpleGoWork;

  /// No description provided for @simpleSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'My saved places'**
  String get simpleSavedPlaces;

  /// No description provided for @simpleMyTrips.
  ///
  /// In en, this message translates to:
  /// **'My trips'**
  String get simpleMyTrips;

  /// No description provided for @simpleTapToChoose.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose the place'**
  String get simpleTapToChoose;

  /// No description provided for @simpleChangePlace.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get simpleChangePlace;

  /// No description provided for @simpleGoAgain.
  ///
  /// In en, this message translates to:
  /// **'Go again'**
  String get simpleGoAgain;

  /// No description provided for @simpleFrom.
  ///
  /// In en, this message translates to:
  /// **'From: {place}'**
  String simpleFrom(String place);

  /// No description provided for @simpleChangeStart.
  ///
  /// In en, this message translates to:
  /// **'Change starting point'**
  String get simpleChangeStart;

  /// No description provided for @simpleUseMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get simpleUseMyLocation;

  /// No description provided for @simpleBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get simpleBack;

  /// No description provided for @simpleBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get simpleBackHome;

  /// No description provided for @simpleRoutesTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how to go'**
  String get simpleRoutesTitle;

  /// No description provided for @simpleRoutesHint.
  ///
  /// In en, this message translates to:
  /// **'The easiest ways, fewest changes first'**
  String get simpleRoutesHint;

  /// No description provided for @simpleOption.
  ///
  /// In en, this message translates to:
  /// **'Option {n}'**
  String simpleOption(int n);

  /// No description provided for @simpleEasiest.
  ///
  /// In en, this message translates to:
  /// **'Easiest'**
  String get simpleEasiest;

  /// No description provided for @simpleChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No changes} =1{1 change} other{{count} changes}}'**
  String simpleChanges(int count);

  /// No description provided for @simpleWalkFor.
  ///
  /// In en, this message translates to:
  /// **'Walk {minutes}'**
  String simpleWalkFor(String minutes);

  /// No description provided for @simpleTripTotal.
  ///
  /// In en, this message translates to:
  /// **'{minutes}, {fare}'**
  String simpleTripTotal(String minutes, String fare);

  /// No description provided for @simpleStartTrip.
  ///
  /// In en, this message translates to:
  /// **'Start this trip'**
  String get simpleStartTrip;

  /// No description provided for @simpleNoRoutes.
  ///
  /// In en, this message translates to:
  /// **'We could not find a way to go. Please try another place.'**
  String get simpleNoRoutes;

  /// No description provided for @simpleStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {n} of {total}'**
  String simpleStepOf(int n, int total);

  /// No description provided for @simpleWalkTo.
  ///
  /// In en, this message translates to:
  /// **'Walk to {place}'**
  String simpleWalkTo(String place);

  /// No description provided for @simpleRideTo.
  ///
  /// In en, this message translates to:
  /// **'{action} to {place}'**
  String simpleRideTo(String action, String place);

  /// No description provided for @simpleGetOffAt.
  ///
  /// In en, this message translates to:
  /// **'Get off at {place}'**
  String simpleGetOffAt(String place);

  /// No description provided for @simpleWalkOn.
  ///
  /// In en, this message translates to:
  /// **'Walk to your destination'**
  String get simpleWalkOn;

  /// No description provided for @simpleTellDriver.
  ///
  /// In en, this message translates to:
  /// **'Tell the driver: “{place}”'**
  String simpleTellDriver(String place);

  /// No description provided for @simpleNextStep.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get simpleNextStep;

  /// No description provided for @simpleEndTrip.
  ///
  /// In en, this message translates to:
  /// **'End trip'**
  String get simpleEndTrip;

  /// No description provided for @simpleEndTripTitle.
  ///
  /// In en, this message translates to:
  /// **'End this trip?'**
  String get simpleEndTripTitle;

  /// No description provided for @simpleEndTripBody.
  ///
  /// In en, this message translates to:
  /// **'The directions will stop. You can start the trip again from the list of ways to go.'**
  String get simpleEndTripBody;

  /// No description provided for @simpleEndTripYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, end trip'**
  String get simpleEndTripYes;

  /// No description provided for @simpleKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'No, keep going'**
  String get simpleKeepGoing;

  /// No description provided for @simpleClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear your recent searches?'**
  String get simpleClearTitle;

  /// No description provided for @simpleClearBody.
  ///
  /// In en, this message translates to:
  /// **'This only removes the list. Your saved places stay.'**
  String get simpleClearBody;

  /// No description provided for @simpleClearYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, clear'**
  String get simpleClearYes;

  /// No description provided for @simpleSettingsOn.
  ///
  /// In en, this message translates to:
  /// **'Simple Mode is on'**
  String get simpleSettingsOn;

  /// No description provided for @simpleSettingsOnHint.
  ///
  /// In en, this message translates to:
  /// **'Turn it off to see every feature again.'**
  String get simpleSettingsOnHint;

  /// No description provided for @simpleLogOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out of Guidy?'**
  String get simpleLogOutTitle;

  /// No description provided for @simpleLogOutBody.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to use your saved places and trips.'**
  String get simpleLogOutBody;

  /// No description provided for @simpleLogOutYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, log out'**
  String get simpleLogOutYes;

  /// No description provided for @simpleTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off Simple Mode'**
  String get simpleTurnOff;

  /// No description provided for @walkReportButton.
  ///
  /// In en, this message translates to:
  /// **'This walk is wrong'**
  String get walkReportButton;

  /// No description provided for @walkReportedLabel.
  ///
  /// In en, this message translates to:
  /// **'Walk reported'**
  String get walkReportedLabel;

  /// No description provided for @walkReportTitle.
  ///
  /// In en, this message translates to:
  /// **'What is wrong with this walk?'**
  String get walkReportTitle;

  /// No description provided for @walkReasonBuildings.
  ///
  /// In en, this message translates to:
  /// **'It goes through buildings'**
  String get walkReasonBuildings;

  /// No description provided for @walkReasonTooLong.
  ///
  /// In en, this message translates to:
  /// **'It is too long'**
  String get walkReasonTooLong;

  /// No description provided for @walkReasonNoPath.
  ///
  /// In en, this message translates to:
  /// **'The path does not exist'**
  String get walkReasonNoPath;

  /// No description provided for @walkReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get walkReasonOther;

  /// No description provided for @walkReportNote.
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get walkReportNote;

  /// No description provided for @walkReportSend.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get walkReportSend;

  /// No description provided for @walkReportThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks! We will check this walk.'**
  String get walkReportThanks;

  /// No description provided for @tripSharingLabel.
  ///
  /// In en, this message translates to:
  /// **'Share my trips'**
  String get tripSharingLabel;

  /// No description provided for @tripSharingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Helps fix bus routes and missing footpaths.'**
  String get tripSharingSubtitle;

  /// No description provided for @tripSharingInfoTooltip.
  ///
  /// In en, this message translates to:
  /// **'What this shares'**
  String get tripSharingInfoTooltip;

  /// No description provided for @tripSharingInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'What \"Share my trips\" does'**
  String get tripSharingInfoTitle;

  /// No description provided for @tripSharingInfoBody.
  ///
  /// In en, this message translates to:
  /// **'Only while you follow a trip in Guidy, it records:\n\n• The route you rode: the lines and stops, when you reached each step, and your phone\'s GPS along the way. This is how Guidy learns that a bus or microbus now takes a different street, and fixes the line for everyone.\n\n• The paths you walk on the trip\'s walking steps. Before anything is sent, the first and last 50 metres of each walk are cut off, so your home, work and other doors stay out of it. This finds footpaths and crossings missing from the map.\n\nNothing is recorded when you\'re not following a trip. What\'s sent is kept with the trip it came from, without your name, and deleted after 180 days. Deleting your account removes what ties it to you.\n\nThis is on by default, as our Terms and Privacy Policy say. You can turn it off here at any time: nothing more is recorded, and anything not sent yet is deleted.'**
  String get tripSharingInfoBody;

  /// No description provided for @tripSharingInfoOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get tripSharingInfoOk;

  /// No description provided for @tripShareAskTitle.
  ///
  /// In en, this message translates to:
  /// **'Help improve Guidy'**
  String get tripShareAskTitle;

  /// No description provided for @tripShareAskBody.
  ///
  /// In en, this message translates to:
  /// **'Share this trip\'s path to help fix bus routes and missing footpaths?'**
  String get tripShareAskBody;

  /// No description provided for @tripShareAskYes.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get tripShareAskYes;

  /// No description provided for @tripShareAskNo.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get tripShareAskNo;

  /// No description provided for @whatsNewTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s new in Guidy'**
  String get whatsNewTitle;

  /// No description provided for @whatsNewOk.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get whatsNewOk;

  /// No description provided for @commuteInfoTooltip.
  ///
  /// In en, this message translates to:
  /// **'About commute notifications'**
  String get commuteInfoTooltip;

  /// No description provided for @commuteInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Commute notifications'**
  String get commuteInfoTitle;

  /// No description provided for @commuteInfoBody.
  ///
  /// In en, this message translates to:
  /// **'Guidy watches the trip between your saved Home and Work, both ways. Save Home and Work, then plan that trip once: Guidy remembers its lines and looks them up again every two weeks.\n\nIt can send two kinds of alert, each with its own switch:\n• Easier times to travel: when one of your lines runs much more often than usual (mornings 5-11, afternoons 1-9). If your lines have no timetable, it warns you before the morning (7:00) and evening (4:30) rush hours.\n• Last-service warning: 45 minutes before the first of your lines stops for the day.\n\nAt most 3 a day, at least an hour apart, and none on Fridays.\n\nIt is planned on your phone from the lines\' timetables, with no account needed, and nothing about you is sent to make it. The alerts arrive even when Guidy is closed.\n\nTo turn them off, use the switches under \"Notifications\": one for each kind, or the top one for all of them.'**
  String get commuteInfoBody;

  /// No description provided for @patchNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Patch notes'**
  String get patchNotesTitle;

  /// No description provided for @patchNotesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What changed in every version'**
  String get patchNotesSubtitle;

  /// No description provided for @patchNotesCurrent.
  ///
  /// In en, this message translates to:
  /// **'You are here'**
  String get patchNotesCurrent;

  /// No description provided for @removeBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide the banner for 24 hours'**
  String get removeBannerTitle;

  /// No description provided for @removeBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Watch a short ad. Other ads stay.'**
  String get removeBannerSubtitle;

  /// No description provided for @removeBannerActive.
  ///
  /// In en, this message translates to:
  /// **'Banner hidden until {time}'**
  String removeBannerActive(String time);

  /// No description provided for @removeBannerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No ad is available right now. Please try again later.'**
  String get removeBannerUnavailable;

  /// No description provided for @removeBannerDone.
  ///
  /// In en, this message translates to:
  /// **'Done. The banner is hidden for 24 hours.'**
  String get removeBannerDone;

  /// No description provided for @removeBannerNotWatched.
  ///
  /// In en, this message translates to:
  /// **'The banner stays: the ad has to be watched to the end.'**
  String get removeBannerNotWatched;

  /// No description provided for @currentTripLabel.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get currentTripLabel;

  /// No description provided for @currentTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Your trip to {place}'**
  String currentTripTitle(String place);

  /// No description provided for @tripGoingTo.
  ///
  /// In en, this message translates to:
  /// **'Going to {place}'**
  String tripGoingTo(String place);

  /// No description provided for @currentTripLeft.
  ///
  /// In en, this message translates to:
  /// **'About {minutes} left'**
  String currentTripLeft(String minutes);

  /// No description provided for @currentTripTap.
  ///
  /// In en, this message translates to:
  /// **'Tap to continue'**
  String get currentTripTap;

  /// No description provided for @tripChannelName.
  ///
  /// In en, this message translates to:
  /// **'Trip in progress'**
  String get tripChannelName;

  /// No description provided for @tripChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Your current step while a trip is running.'**
  String get tripChannelDescription;

  /// No description provided for @tripAlertChannelName.
  ///
  /// In en, this message translates to:
  /// **'Stop alerts'**
  String get tripAlertChannelName;

  /// No description provided for @tripAlertChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'A heads-up when your stop is coming.'**
  String get tripAlertChannelDescription;

  /// No description provided for @tripNearTitle.
  ///
  /// In en, this message translates to:
  /// **'Get ready'**
  String get tripNearTitle;

  /// No description provided for @tripNearBody.
  ///
  /// In en, this message translates to:
  /// **'{place} is coming up. Time to get off or change.'**
  String tripNearBody(String place);
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
