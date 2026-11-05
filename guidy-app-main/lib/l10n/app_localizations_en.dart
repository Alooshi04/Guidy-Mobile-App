// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'Navigate Egypt with intelligence';

  @override
  String get goodMorning => 'Good Morning';

  @override
  String goodMorningUser(String name) {
    return 'Good morning, $name';
  }

  @override
  String get goodAfternoon => 'Good Afternoon';

  @override
  String goodAfternoonUser(String name) {
    return 'Good afternoon, $name';
  }

  @override
  String get goodEvening => 'Good Evening';

  @override
  String goodEveningUser(String name) {
    return 'Good evening, $name';
  }

  @override
  String get goodNight => 'Good Night';

  @override
  String goodNightUser(String name) {
    return 'Good night, $name';
  }

  @override
  String get whereTo => 'Where to?';

  @override
  String get quickAccessHome => 'Home';

  @override
  String get quickAccessWork => 'Work';

  @override
  String get quickAccessSaved => 'Saved';

  @override
  String routingTo(String name) {
    return 'Routing to $name...';
  }

  @override
  String get gpsRequiredToRoute => 'Ensure GPS is enabled to route.';

  @override
  String resettingLocation(String key) {
    return 'Resetting $key location...';
  }

  @override
  String setLocationTitle(String key) {
    return 'Set $key';
  }

  @override
  String locationSavedAs(String key, String name) {
    return '$key saved as $name';
  }

  @override
  String get searchOrTapMap => 'Search or tap map...';

  @override
  String saveAsKey(String key) {
    return 'Save as $key';
  }

  @override
  String get pickupLocation => 'Pickup Location';

  @override
  String get gpsFetchFailed => 'Failed to get GPS location.';

  @override
  String get findRoutes => 'Find Routes';

  @override
  String get routeOptionsTitle => 'Route Options';

  @override
  String get routeCalculationFailed => 'Could not calculate route.';

  @override
  String get availableRoutes => 'Available Routes';

  @override
  String get routeListTab => 'Route list';

  @override
  String get quickCompareTab => 'Quick compare';

  @override
  String get statDuration => 'Duration';

  @override
  String get statFare => 'Fare';

  @override
  String get statDistance => 'Distance';

  @override
  String routeTimeBreakdown(String riding, String wait) {
    return '$riding travelling, about $wait waiting';
  }

  @override
  String stepWaitHint(String wait) {
    return 'Wait about $wait';
  }

  @override
  String durationMinutes(String minutes) {
    return '$minutes';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String fareEgp(String amount) {
    return '$amount EGP';
  }

  @override
  String alsoWorksLabel(String routes) {
    return 'Also works: $routes';
  }

  @override
  String routeEveryMinutes(String route, String minutes) {
    return '$route (about every $minutes)';
  }

  @override
  String get listSeparator => ', ';

  @override
  String get navNowLabel => 'Now';

  @override
  String get navAlsoServing => 'Also serving this leg';

  @override
  String get navYourRoute => 'Your route';

  @override
  String navMinutesAway(String minutes) {
    return 'about $minutes away';
  }

  @override
  String get navArrivingNow => 'Arriving now';

  @override
  String navEveryMinutes(String minutes) {
    return 'about every $minutes';
  }

  @override
  String navWalkToStop(String meters, String stop) {
    return '$meters m walk to $stop';
  }

  @override
  String navWalkToStopFirst(String meters, String stop) {
    return 'Walk $meters m to $stop first';
  }

  @override
  String navGetOffThenWalk(String stop, String meters) {
    return 'Get off at $stop, then walk $meters m';
  }

  @override
  String get legalAgreePrefix => 'I agree to the ';

  @override
  String get legalTermsLink => 'Terms and Conditions';

  @override
  String get legalAgreeSep1 => ', the ';

  @override
  String get legalPrivacyLink => 'Privacy Policy';

  @override
  String get legalAgreeSep2 => ' and the ';

  @override
  String get legalDeletionLink => 'Data Deletion Policy';

  @override
  String get legalAgreeEnd => '.';

  @override
  String get legalConsentTitle => 'Before you continue';

  @override
  String get legalConsentBody =>
      'Please read Guidy\'s terms and policies and agree to them to use the app. Tap a name to read it.';

  @override
  String get legalConsentContinue => 'Agree and continue';

  @override
  String get navNoLiveData => 'No live data yet';

  @override
  String get navLocationOff => 'Location is off, so the map won\'t follow you.';

  @override
  String get navLocationBlocked =>
      'Location is blocked for Guidy. Turn it on in Settings to follow the route live.';

  @override
  String get navLocationLost => 'Lost GPS signal. Your route is still below.';

  @override
  String get createAccount => 'Create Account';

  @override
  String get nameLabel => 'Full Name';

  @override
  String get nameHint => 'Enter your name';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'Enter your email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get passwordCreateHint => 'Create a password';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get confirmPasswordHint => 'Confirm your password';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get noAccountPrompt => 'Don\'t have an account? ';

  @override
  String get hasAccountPrompt => 'Already have an account? ';

  @override
  String get fillBothFields => 'Please fill in both fields';

  @override
  String get fillAllFields => 'Please fill in all fields';

  @override
  String get invalidEmail => 'Please enter a valid email address';

  @override
  String get signInFailed => 'Sign in failed';

  @override
  String get signUpFailed => 'Sign up failed';

  @override
  String get incorrectCredentials => 'Incorrect email or password.';

  @override
  String get checkInternet => 'Check your internet connection.';

  @override
  String get passwordsDontMatch => 'Passwords do not match';

  @override
  String get emailAlreadyRegistered => 'This email is already registered.';

  @override
  String get languageSwitcherTitle => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get youHaveArrived => 'You have arrived!';

  @override
  String arrivingAt(String station) {
    return 'Arriving at $station...';
  }

  @override
  String distanceKmTo(String distance, String station) {
    return '$distance km to $station';
  }

  @override
  String distanceMTo(String distance, String station) {
    return '$distance m to $station';
  }

  @override
  String get myCurrentLocation => 'My Current Location';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get darkModeLabel => 'Dark Mode';

  @override
  String get darkModeSubtitle => 'Overrides your device\'s system setting';

  @override
  String get accountSectionLabel => 'Account';

  @override
  String get preferencesSectionLabel => 'Preferences';

  @override
  String get logOut => 'Log Out';

  @override
  String get quickDestinationsLabel => 'Quick Destinations';

  @override
  String get adPlaceholderLabel => 'Advertisement';

  @override
  String get navHome => 'Home';

  @override
  String get navSettings => 'Settings';

  @override
  String get contactUsLabel => 'Contact Us';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get orDivider => 'or';

  @override
  String get socialSignInFailed => 'Couldn\'t sign in. Please try again.';

  @override
  String get savedPlacesTitle => 'Saved Places';

  @override
  String get addPlaceButton => 'Add a place';

  @override
  String get noSavedPlacesYet => 'No saved places yet. Tap below to add one.';

  @override
  String get deletePlaceConfirmTitle => 'Remove this place?';

  @override
  String get deletePlaceConfirmBody => 'You can always add it again later.';

  @override
  String get placeNameHint => 'Name (e.g. Gym, Mosque)';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get removeButton => 'Remove';

  @override
  String get noSearchResultsFound => 'No places found. Try a different search.';

  @override
  String get placeSearchUnavailable =>
      'Place search isn\'t available in this version of the app. You can still pick a spot on the map.';

  @override
  String get continueAsGuest => 'Continue as Guest';

  @override
  String get guestLabel => 'Guest';

  @override
  String get deleteAccountButton => 'Delete Account';

  @override
  String get deleteAccountConfirmTitle => 'Delete your account?';

  @override
  String get deleteAccountConfirmBody =>
      'This permanently deletes your account and can\'t be undone.';

  @override
  String get deleteGuestDataButton => 'Delete Guest Data';

  @override
  String get deleteGuestDataConfirmTitle => 'Delete your guest data?';

  @override
  String get deleteGuestDataConfirmBody =>
      'This ends your guest session and deletes the data linked to it, like your agreement to our terms. Route reports you sent are kept. This can\'t be undone.';

  @override
  String get deleteButton => 'Delete';

  @override
  String get reauthRequiredTitle => 'Please sign in again';

  @override
  String get reauthRequiredBody =>
      'For your security, confirm it\'s you before we delete your account.';

  @override
  String get confirmButton => 'Confirm';

  @override
  String get deleteAccountFailed =>
      'Couldn\'t delete your account. Please try again.';

  @override
  String get recentSearchesLabel => 'Recent';

  @override
  String get clearHistoryLabel => 'Clear';

  @override
  String shareRouteText(String start, String end, String link) {
    return 'How to get from $start to $end by public transport, on Guidy:\n$link';
  }

  @override
  String get retryButton => 'Retry';

  @override
  String get somethingWentWrongTitle => 'Something went wrong';

  @override
  String get rateGuidyLabel => 'Rate Guidy';

  @override
  String get privacyPolicyLabel => 'Privacy Policy';

  @override
  String get supportSectionLabel => 'Support';

  @override
  String get useCurrentLocationTooltip => 'Use my current location';

  @override
  String get showPasswordTooltip => 'Show password';

  @override
  String get hidePasswordTooltip => 'Hide password';

  @override
  String get closeMapTooltip => 'Close';

  @override
  String get centerOnMyLocationTooltip => 'Center on my location';

  @override
  String get removePlaceTooltip => 'Remove this place';

  @override
  String get vehicleBus => 'Bus';

  @override
  String get vehicleMinibus => 'Minibus';

  @override
  String get vehicleMicrobus => 'Microbus';

  @override
  String get vehicleMetro => 'Metro';

  @override
  String get vehicleMonorail => 'Monorail';

  @override
  String get vehicleLrt => 'LRT';

  @override
  String get vehicleTram => 'Tram';

  @override
  String get vehicleAirportShuttle => 'Airport Shuttle';

  @override
  String get vehicleBrt => 'BRT';

  @override
  String get vehicleWalk => 'Walk';

  @override
  String get routeTierRecommended => 'Recommended';

  @override
  String get routeTierFastest => 'Fastest';

  @override
  String get routeTierRegular => 'Regular';

  @override
  String get routeTierCheapest => 'Cheapest';

  @override
  String get routeTierAlternative => 'Alternative';

  @override
  String get routeTierWalk => 'Walk';

  @override
  String get crowdLow => 'Low';

  @override
  String get crowdMedium => 'Medium';

  @override
  String get crowdHigh => 'High';

  @override
  String get instrWalkToStationTitle => 'Walk to Station';

  @override
  String instrWalkToStationSubtitle(String distance, String station) {
    return 'Walk ${distance}m to $station';
  }

  @override
  String get instrWalkToTransferTitle => 'Walk to Transfer';

  @override
  String instrWalkToTransferSubtitle(String station) {
    return 'Walk to the next stop near $station';
  }

  @override
  String get instrContinueWalkTitle => 'Walking';

  @override
  String get instrContinueWalkSubtitle => 'Continue on foot';

  @override
  String instrBoardTitleWithVehicle(String vehicleType) {
    return 'Board $vehicleType';
  }

  @override
  String instrBoardWithNumber(String vehicleType, String routeNumber) {
    return '$vehicleType $routeNumber';
  }

  @override
  String instrBoardGeneral(String vehicleType, String routeDescription) {
    return '$vehicleType towards $routeDescription';
  }

  @override
  String get instrTransferTitle => 'Transfer';

  @override
  String get instrArriveTitle => 'Arrive & Disembark';

  @override
  String instrArriveSubtitle(String station) {
    return 'Get off at $station';
  }

  @override
  String get instrWalkToDestinationTitle => 'Walk to Destination';

  @override
  String instrWalkToDestinationSubtitle(String distance) {
    return 'Walk ${distance}m to your destination';
  }

  @override
  String get fareEstimateNote => 'Fares are estimates and may vary';

  @override
  String get tripRecapTitle => 'Trip Overview';

  @override
  String get tripStepsLabel => 'Steps';

  @override
  String get fareTotalLabel => 'Total Fare';

  @override
  String get startNavigationButton => 'Start Navigation';

  @override
  String get navLines => 'Lines';

  @override
  String get navMetro => 'Metro';

  @override
  String linesOfMode(String mode) {
    return '$mode Lines';
  }

  @override
  String get lineFirstTrip => 'Start';

  @override
  String get lineLastTrip => 'End';

  @override
  String get lineServiceHours => 'Hours';

  @override
  String get lineOpenNow => 'Open now';

  @override
  String get lineClosedNow => 'Closed now';

  @override
  String lineClosedOpensAt(String time) {
    return 'Closed now, opens at $time';
  }

  @override
  String get navToolsShow => 'Show trip tools';

  @override
  String get navToolsHide => 'Hide trip tools';

  @override
  String get navToolsOverview => 'Route overview';

  @override
  String get linesSearchHint => 'Line number, or where it goes';

  @override
  String get linesSearchPrompt =>
      'Search a line number like 65, or a place like Maadi.';

  @override
  String get linesNoResults => 'No lines match that search.';

  @override
  String get linesTapHint => 'Tap a line to see every stop it makes.';

  @override
  String get linesAlexandriaTitle => 'Alexandria Lines';

  @override
  String linesAlexandriaOfMode(String mode) {
    return 'Alexandria $mode Lines';
  }

  @override
  String get linesAlexandriaHint =>
      'Only lines that run in Alexandria, including the Cairo to Alexandria microbuses.';

  @override
  String get linesAlexandriaEmpty =>
      'No Alexandria lines are available right now.';

  @override
  String linesStopCount(int count) {
    return '$count stops';
  }

  @override
  String linesEveryMinutes(String minutes) {
    return 'About every $minutes';
  }

  @override
  String linesDirectionTowards(String terminus) {
    return 'Towards $terminus';
  }

  @override
  String get linesStopsInOrder => 'Stops in order';

  @override
  String get linesLoadFailed => 'Couldn\'t load lines right now.';

  @override
  String get linesViewList => 'Stops';

  @override
  String get linesViewMap => 'Map';

  @override
  String get linesFitRoute => 'Fit Route';

  @override
  String get metroTitle => 'Metro Planner';

  @override
  String get metroSubtitle => 'Metro only. No buses, no walking legs.';

  @override
  String get metroFromLabel => 'From';

  @override
  String get metroToLabel => 'To';

  @override
  String get metroPickStation => 'Choose a station';

  @override
  String get metroPlanButton => 'Show metro route';

  @override
  String get metroSameStationError => 'Pick two different stations.';

  @override
  String get metroNoPathError =>
      'We couldn\'t find a metro-only route between those two.';

  @override
  String get metroSearchStationHint => 'Search stations';

  @override
  String metroChangeAt(String station) {
    return 'Change at $station';
  }

  @override
  String metroChangeTo(String line) {
    return 'Change to $line';
  }

  @override
  String metroChangesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
    );
    return '$_temp0';
  }

  @override
  String get metroNoChanges => 'Direct, no changes';

  @override
  String get metroInterchangeBadge => 'Interchange';

  @override
  String metroRideStops(int count) {
    return 'Ride $count stops';
  }

  @override
  String get metroSwapTooltip => 'Swap start and destination';

  @override
  String metroLinesServing(String lines) {
    return 'Lines: $lines';
  }

  @override
  String get metroStationsLoadFailed => 'Couldn\'t load the station list.';

  @override
  String get navRecenterTooltip => 'Re-center on me';

  @override
  String get fareFree => 'Free';

  @override
  String get pinnedLocation => 'Pinned location';

  @override
  String get serverUnreachable =>
      'Could not reach the Guidy server. Check your connection and try again.';

  @override
  String get errorOutsideCoverage =>
      'That place is outside the area Guidy covers.';

  @override
  String get errorNoRouteFound =>
      'We couldn\'t find a way to get there. It may be outside our coverage.';

  @override
  String get errorNoServiceThisHour =>
      'Nothing is running at this hour. Most routes here run about 06:00 to 23:00. Try again during service hours.';

  @override
  String get errorTitleNotCovered => 'We don\'t cover this trip yet';

  @override
  String get errorTitleNoService => 'Nothing is running right now';

  @override
  String linesDirectionTowardsFrom(String terminus, String origin) {
    return 'Towards $terminus, from $origin';
  }

  @override
  String get reportEntryPoint => 'Something wrong with this route?';

  @override
  String get reportCommentRequired =>
      'Please tell us a bit more so we can act on it.';

  @override
  String get reportSubmit => 'Send report';

  @override
  String get reportSent => 'Thanks, your report was sent.';

  @override
  String get reportQueued =>
      'Saved. We\'ll send it as soon as you\'re back online.';

  @override
  String get reportFailed => 'Couldn\'t send that report. Please try again.';

  @override
  String get reportSignInRequired => 'Sign in to send a report.';

  @override
  String get routeTierPartial => 'Gets you close';

  @override
  String partialUncoveredNotice(String distance) {
    return 'This doesn\'t reach your destination. The last $distance isn\'t covered by any route we know yet.';
  }

  @override
  String partialLastCoveredStop(String stop) {
    return 'Last stop we cover: $stop';
  }

  @override
  String nearestHubsHint(String origin, String destination) {
    return 'The closest places we do cover are $origin near your start, and $destination near your destination.';
  }

  @override
  String get reportMissingRouteButton => 'Tell us what\'s missing';

  @override
  String get reportMissingRouteTitle => 'Which route should be here?';

  @override
  String get reportMissingRouteIntro =>
      'Our data is incomplete for this trip. If you know a bus, minibus or microbus that makes it, tell us and we\'ll add it for everyone.';

  @override
  String get reportMissingRouteHint =>
      'e.g. minibus 37 from Kilo 4 & Half to Kafr Tohormos';

  @override
  String get betterRouteButton => 'Know a better route?';

  @override
  String get betterRouteSheetIntro =>
      'Tell us about it and we\'ll check it and add it for everyone.';

  @override
  String get betterRouteWriteTitle => 'Write it to us';

  @override
  String get betterRouteWriteSubtitle => 'Describe it in your own words';

  @override
  String get betterRouteWriteHint =>
      'e.g. walk to Abbas El Akkad, minibus 66 to Ramses, then the metro';

  @override
  String get betterRouteBuildTitle => 'Build it from the transport network';

  @override
  String get betterRouteBuildSubtitle => 'Pick each line and walk in order';

  @override
  String get betterRouteBuilderTitle => 'Build your route';

  @override
  String get betterRouteBuilderIntro =>
      'Add each part of the trip in order, from your start to your destination.';

  @override
  String get betterRouteAddWalk => 'Add a walk';

  @override
  String get betterRouteAddRide => 'Add a ride';

  @override
  String get betterRouteWalkMeters => 'Metres (optional)';

  @override
  String get betterRouteBoardAt => 'Board at (optional)';

  @override
  String get betterRouteGetOffAt => 'Get off at (optional)';

  @override
  String get betterRouteFare => 'Fare in EGP (optional)';

  @override
  String get betterRouteNoteHint => 'Anything else we should know? (optional)';

  @override
  String get betterRouteRemoveLeg => 'Remove';

  @override
  String get betterRouteReorderHint => 'Drag to reorder';

  @override
  String get betterRouteMoveUp => 'Move up';

  @override
  String get betterRouteMoveDown => 'Move down';

  @override
  String get betterRouteChangeLine => 'Change line';

  @override
  String get betterRoutePickLineTitle => 'Pick the line';

  @override
  String get betterRouteNotInApp => 'Not in the app? Type it yourself';

  @override
  String get betterRouteTypedMode => 'Type of ride';

  @override
  String get betterRouteTypedName => 'Line number or name';

  @override
  String get betterRouteTypedAdd => 'Add this line';

  @override
  String get betterRouteTypedBadge => 'Not in the app';

  @override
  String get betterRouteNeedRide => 'Add at least one ride to send the route.';

  @override
  String get betterRouteSubmit => 'Send the route';

  @override
  String get betterRouteDiscardTitle => 'Leave without sending?';

  @override
  String get betterRouteDiscardBody => 'The route you built will be lost.';

  @override
  String get betterRouteDiscardLeave => 'Leave';

  @override
  String get betterRouteDiscardStay => 'Keep building';

  @override
  String get excludeMetro => 'Exclude Metro';

  @override
  String get filterMinWalk => 'Minimum Walk';

  @override
  String get filterMinTransfers => 'Fewest Transfers';

  @override
  String get shareTripTooltip => 'Share Trip';

  @override
  String get navStopAlarmOn => 'Stop alert active';

  @override
  String get navStopAlarmOff => 'Stop alert disabled';

  @override
  String navStopAlarmAlert(String station) {
    return 'Prepare to get off! Next stop: $station';
  }

  @override
  String get metroTicketTitle => 'Metro Ticket Counter';

  @override
  String get navStopAlarmActiveToast =>
      'Stop alert: Active (vibrates 400m before your stop)';

  @override
  String get navStopAlarmDisabledToast => 'Stop alert: Disabled';

  @override
  String get navRecenterFinding => 'Finding your location...';

  @override
  String get navRecenterSuccess => 'Centered on your location';

  @override
  String get navRecenterFallback => 'GPS unavailable, centered on trip start';

  @override
  String get navOverviewToast => 'Full route overview';

  @override
  String get directRouteNoTransfers => 'Direct transit';

  @override
  String transfersCountBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transfers',
      one: '1 transfer',
    );
    return '$_temp0';
  }

  @override
  String walkMetersBadge(String meters) {
    return '$meters m walk';
  }

  @override
  String get quickReportTitle => 'Report Commute Conditions';

  @override
  String get quickReportSubtitle =>
      'Help fellow commuters know live transit status';

  @override
  String get reportCategoryTraffic => 'Traffic standstill / Severe jam';

  @override
  String get reportCategoryMissing => 'Bus delayed or missing';

  @override
  String get reportCategoryCrowd => 'Severe vehicle or stop crowding';

  @override
  String get reportCategoryFare => 'Microbus driver / collector increased fare';

  @override
  String get reportCategoryDiversion => 'Route diverted / Roadblock';

  @override
  String get reportThanksToast =>
      'Thank you, your report helps fellow commuters!';

  @override
  String get reportNotePlaceholder => 'Any extra details? (Optional)';

  @override
  String get walkManeuverRight => 'Turn right';

  @override
  String get walkManeuverLeft => 'Turn left';

  @override
  String get walkManeuverUTurn => 'Make a U-turn';

  @override
  String walkInDistance(String distance, String action) {
    return 'In $distance $action';
  }

  @override
  String get metroNetworkMapButton => 'Network Map';

  @override
  String get navHistory => 'Trips';

  @override
  String get historyTitle => 'Trips & Savings';

  @override
  String get totalMoneySaved => 'Money Saved';

  @override
  String get totalTimeSaved => 'Time Saved';

  @override
  String get emptyHistoryTitle => 'No Trips Logged Yet';

  @override
  String get emptyHistorySubtitle =>
      'Start navigating or plan a trip with Guidy to see your cumulative money, time, and carbon savings!';

  @override
  String get planTripButton => 'Plan a Trip';

  @override
  String get clearHistoryConfirm => 'Clear all trip history?';

  @override
  String get clearHistoryAction => 'Clear History';

  @override
  String get clearHistorySuccess => 'Trip history cleared';

  @override
  String get tripDeletedToast => 'Trip removed from history';

  @override
  String get savingsCalculationInfoTitle => 'How Savings are Calculated';

  @override
  String get savingsCalculationInfo =>
      'Savings are calculated based on your personal route choice: when you choose the Fastest route, we calculate the minutes you saved compared to slower alternatives, and when you choose the Cheapest route, we calculate the money you saved compared to more expensive alternatives.';

  @override
  String get filterAll => 'All';

  @override
  String get filterThisWeek => 'This Week';

  @override
  String get filterThisMonth => 'This Month';

  @override
  String get filterMetro => 'Metro';

  @override
  String get filterBus => 'Bus';

  @override
  String get filterMicrobus => 'Microbus';

  @override
  String minsSavedShort(String mins) {
    return '$mins saved';
  }

  @override
  String hoursMinsSavedShort(String hours, String mins) {
    return '${hours}h ${mins}m saved';
  }

  @override
  String get reportLineTitle => 'Report Line Issue';

  @override
  String get reportMetroTitle => 'Report Metro Issue';

  @override
  String get reportReasonLineDoesNotExist =>
      'Line does not exist or discontinued';

  @override
  String get reportReasonLineWrongPath =>
      'Route diversion or different streets';

  @override
  String get reportReasonLineWrongStop => 'Wrong stop sequence or missing stop';

  @override
  String get reportReasonLineWrongFare => 'Incorrect fare';

  @override
  String get reportReasonLineBadTiming => 'Inaccurate schedule or frequency';

  @override
  String get reportReasonMetroStationClosed =>
      'Station closed or out of service';

  @override
  String get reportReasonMetroWrongTransfer => 'Incorrect transfer instruction';

  @override
  String get reportReasonMetroWrongFare => 'Incorrect ticket fare';

  @override
  String get reportReasonMetroDelay => 'Significant delay or disruption';

  @override
  String get reportPickStopOptional => 'Select affected stop (optional)';

  @override
  String get reportAllStopsOption => 'General line issue (entire route)';

  @override
  String get reportActionSubmit => 'Submit Report';

  @override
  String get reportLineSuccessToast =>
      'Thank you! Your report has been submitted to improve the network.';

  @override
  String get reportCommentHint =>
      'Add details (e.g. actual fare, detour street, etc.)';

  @override
  String get reportAnIssueWithThisLine => 'Report an issue with this line';

  @override
  String get reportAnIssueWithMetro => 'Report an issue with this metro route';

  @override
  String get reportCategoryOther => 'Other issue';

  @override
  String get reportReasonPrompt => 'What is the problem?';

  @override
  String get recentTripsTitle => 'Recent Trips';

  @override
  String get recentTripsSubtitle =>
      'Trips you\'ve taken, their cost and duration';

  @override
  String get noRecentTripsYet =>
      'No trips taken yet. Take a ride and it will appear here!';

  @override
  String moneySavedPill(String amount) {
    return 'Saved $amount EGP';
  }

  @override
  String get tripDetailFarePaid => 'Fare Paid';

  @override
  String get tripDetailOpenRecap => 'View Trip Details';

  @override
  String minutesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h',
    );
    return '$_temp0';
  }

  @override
  String durationAndMinutes(String minutes) {
    return '$minutes';
  }

  @override
  String routeWalkMeters(String meters) {
    return '$meters m';
  }

  @override
  String routeCardLine(String mode, String number) {
    return '$mode $number';
  }

  @override
  String get plannerHint =>
      'Tap a line on the map or a route below to choose it';

  @override
  String plannerWalkTo(String distance, String station) {
    return 'Walk $distance to $station';
  }

  @override
  String plannerWalkToDestination(String distance) {
    return 'Walk $distance to your destination';
  }

  @override
  String get lineRecommended => 'recommended';

  @override
  String get lineRecommendedLegend =>
      'Just as good: covers the whole ride, no extra walk, a similar fare';

  @override
  String plannerAnyOfTheseLines(String mode) {
    return '$mode, take any of these';
  }

  @override
  String plannerMoreLines(int count) {
    return '+$count more';
  }

  @override
  String get plannerFewerLines => 'Show fewer';

  @override
  String plannerHailAt(String station) {
    return 'Wave one down at $station';
  }

  @override
  String plannerAskToStopAt(String station) {
    return 'Ask the driver to stop at $station';
  }

  @override
  String plannerWalkToStreet(String distance) {
    return 'Walk $distance to the street';
  }

  @override
  String get stepWalkToStreet => 'Walk to the street';

  @override
  String plannerTakeFrom(String station) {
    return 'Get on at $station';
  }

  @override
  String plannerTowards(String station) {
    return 'towards $station';
  }

  @override
  String plannerGetOffAt(String station) {
    return 'Get off at $station';
  }

  @override
  String get plannerStart => 'Start trip';

  @override
  String get plannerClosedNow =>
      'Some lines on this route aren\'t running right now';

  @override
  String plannerMeters(String meters) {
    return '$meters m';
  }

  @override
  String get plannerSteps => 'Your trip';

  @override
  String navRideTo(String station) {
    return 'Stay on until $station';
  }

  @override
  String navRiding(String line) {
    return 'On $line';
  }

  @override
  String navWalkThenBoard(String action) {
    return 'Then $action';
  }

  @override
  String navGetReadyOff(String station) {
    return 'Get ready to get off at $station';
  }

  @override
  String navNearBoarding(String station) {
    return 'Almost at $station';
  }

  @override
  String get navGetOffHere => 'Get off here';

  @override
  String navWalkToDestinationFrom(String station) {
    return 'Walk from $station to your destination';
  }

  @override
  String get navYouArrived => 'You have arrived';

  @override
  String get navSwitchRouteTitle => 'Switch to this route?';

  @override
  String navSwitchRouteBody(String minutes, String fare) {
    return '$minutes, $fare';
  }

  @override
  String get navSwitchRouteConfirm => 'Switch route';

  @override
  String get navCompassTooltip => 'North up';

  @override
  String get simpleModeLabel => 'Simple mode';

  @override
  String get simpleModeSubtitle =>
      'Big text and buttons, fewer choices, one step at a time';

  @override
  String get simpleShowMoreRoutes => 'Show other routes';

  @override
  String get simpleShowFewerRoutes => 'Show only the best route';

  @override
  String get shareRouteTooltip => 'Share this route';

  @override
  String get shareLiveTooltip => 'Share my trip live';

  @override
  String shareLiveText(String dest, String link) {
    return 'Follow my trip to $dest live on Guidy:\n$link';
  }

  @override
  String get shareLiveActive => 'Your trip is being shared live';

  @override
  String get shareLiveStop => 'Stop';

  @override
  String get shareLiveFailed =>
      'Couldn\'t start sharing. Check your internet connection.';

  @override
  String get liveViewerTitle => 'Live trip';

  @override
  String liveViewerHeading(String name, String dest) {
    return '$name is on the way to $dest';
  }

  @override
  String liveViewerHeadingNoName(String dest) {
    return 'On the way to $dest';
  }

  @override
  String liveViewerOnVehicle(String vehicle) {
    return 'Now on $vehicle';
  }

  @override
  String get liveViewerWalking => 'Walking';

  @override
  String liveViewerEta(String time, String minutes) {
    return 'Arrives around $time (in $minutes)';
  }

  @override
  String liveViewerArrived(String dest) {
    return 'Arrived at $dest';
  }

  @override
  String get liveViewerEnded => 'This trip is no longer being shared.';

  @override
  String liveViewerUpdated(String time) {
    return 'Last update $time';
  }

  @override
  String get liveViewerWaiting => 'Waiting for their first location…';

  @override
  String get liveViewerOffline => 'Couldn\'t refresh. Retrying…';

  @override
  String get routeTierAvailableNow => 'Running now';

  @override
  String get nightNothingRunningTitle =>
      'Nothing\'s running for this trip right now';

  @override
  String nightNothingRunningBody(String time, String wait) {
    return 'None of the lines this trip needs run at this hour. Your usual route below starts running again at $time (in $wait).';
  }

  @override
  String get nightCanWalk =>
      'It\'s close enough to walk. See the walking option.';

  @override
  String get nightAvailableTitle => 'Late night: your usual lines have stopped';

  @override
  String nightAvailableBody(String time, String wait) {
    return 'The first option uses lines that are still running. Your usual route starts running again at $time (in $wait).';
  }

  @override
  String nightUsualRoute(String time) {
    return 'Usual route, runs again at $time';
  }

  @override
  String get pwRuleMinLength => 'At least 8 characters';

  @override
  String get pwRuleUpper => 'An uppercase letter (A-Z)';

  @override
  String get pwRuleLower => 'A lowercase letter (a-z)';

  @override
  String get pwRuleDigit => 'A number (0-9)';

  @override
  String get pwRuleSymbol => 'A symbol, like ! @ # ?';

  @override
  String get pwRuleNoEdgeSpaces => 'No spaces at the start or end';

  @override
  String get pwRuleNotCommon => 'Not a commonly used password';

  @override
  String get pwStrengthWeak => 'Weak';

  @override
  String get pwStrengthFair => 'Fair';

  @override
  String get pwStrengthGood => 'Good';

  @override
  String get pwStrengthStrong => 'Strong';

  @override
  String get pwStrengthLabel => 'Password strength';

  @override
  String get passwordRulesNotMet =>
      'Your password doesn\'t meet all the rules yet.';

  @override
  String get tooManyRequests =>
      'Too many attempts. Please wait a moment and try again.';

  @override
  String get verifyEmailTitle => 'Verify your email';

  @override
  String verifyEmailBody(String email) {
    return 'We sent a verification link to $email. Open it, then come back and tap \"I\'ve verified\". Check your spam folder if you can\'t find it.';
  }

  @override
  String get verifyEmailResend => 'Resend email';

  @override
  String verifyEmailResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get verifyEmailSent => 'Verification email sent.';

  @override
  String get verifyEmailCheck => 'I\'ve verified';

  @override
  String get verifyEmailNotYet =>
      'Not verified yet. Open the link in the email first.';

  @override
  String get verifyEmailUseOther => 'Use a different account';

  @override
  String get forgotPasswordLink => 'Forgot password?';

  @override
  String get forgotPasswordTitle => 'Reset your password';

  @override
  String get forgotPasswordBody =>
      'Enter your account email and we\'ll send you a link to set a new password.';

  @override
  String get forgotPasswordSend => 'Send link';

  @override
  String get forgotPasswordSent =>
      'If an account exists for that email, a reset link is on its way. Check your inbox and spam folder.';

  @override
  String get changePasswordButton => 'Change Password';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmNewPasswordLabel => 'Confirm new password';

  @override
  String get changePasswordSave => 'Update password';

  @override
  String get changePasswordSuccess => 'Password updated.';

  @override
  String get currentPasswordWrong => 'Your current password is incorrect.';

  @override
  String get changePasswordFailed =>
      'Couldn\'t update your password. Please try again.';

  @override
  String get newPasswordSameAsOld =>
      'Your new password must be different from the current one.';

  @override
  String get authEmailFailed => 'Couldn\'t send the email. Please try again.';

  @override
  String stepWalkTo(String place) {
    return 'Walk to $place';
  }

  @override
  String get stepWalkToDestination => 'Walk to your destination';

  @override
  String stepWalkMeta(String meters, String minutes) {
    return '$meters m, about $minutes';
  }

  @override
  String rideTakeThing(String thing) {
    return 'Take $thing';
  }

  @override
  String rideRideThing(String thing) {
    return 'Ride $thing';
  }

  @override
  String stepBoardAt(String station) {
    return 'Board at $station';
  }

  @override
  String stepToward(String place) {
    return 'toward $place';
  }

  @override
  String stepRideTo(String station) {
    return 'Ride to $station';
  }

  @override
  String stepStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops',
      one: '1 stop',
    );
    return '$_temp0';
  }

  @override
  String stepGetOffAt(String station) {
    return 'Get off at $station';
  }

  @override
  String stepThenWalkTo(String meters, String place, String minutes) {
    return 'then walk $meters m to $place, about $minutes';
  }

  @override
  String stepThenWalkToDestination(String meters, String minutes) {
    return 'then walk $meters m to your destination, about $minutes';
  }

  @override
  String liveGetOffIn(String station, String minutes) {
    return 'Get off at $station in about $minutes';
  }

  @override
  String liveWalkMetersLeft(String meters, String minutes) {
    return '$meters m left, about $minutes';
  }

  @override
  String liveWalkLeft(String meters, String place, String minutes) {
    return '$meters m to $place, about $minutes';
  }

  @override
  String routeShortRide(String minutes, String fare) {
    return '$minutes faster for $fare EGP more';
  }

  @override
  String routeLongWalk(String minutes) {
    return 'Long walk: $minutes';
  }

  @override
  String get rideReportButton => 'I took a vehicle';

  @override
  String get rideReportTitle => 'What did you take?';

  @override
  String get rideReportFare => 'Fare (EGP)';

  @override
  String get rideReportStart => 'Start recording';

  @override
  String rideReportRecording(String distance, String minutes) {
    return 'Recording your ride: $distance in $minutes';
  }

  @override
  String get rideReportStop => 'I got off';

  @override
  String get rideReportThanks => 'Thanks! We\'ll review this ride.';

  @override
  String get rideVehicleTuktuk => 'Tuk-tuk';

  @override
  String get rideVehicleTaxi => 'Taxi';

  @override
  String get rideVehicleOther => 'Other';

  @override
  String get tourSkip => 'Skip';

  @override
  String get tourNext => 'Next';

  @override
  String get tourDone => 'Done';

  @override
  String tourStepOf(int step, int total) {
    return '$step of $total';
  }

  @override
  String get tourWelcomeTitle => 'Welcome to Guidy';

  @override
  String get tourWelcomeBody =>
      'A quick look at what Guidy can do. It takes a minute, and you can skip it any time.';

  @override
  String get tourSearchTitle => 'Plan a trip';

  @override
  String get tourSearchBody =>
      'Tap here, type where you\'re going, and Guidy compares buses, microbuses, minibuses and the metro by time, fare and walking.';

  @override
  String get tourQuickTitle => 'Quick destinations';

  @override
  String get tourQuickBody =>
      'Home, Work and your saved places in one tap. Hold Home or Work to change it. They\'re in the search screen too, for the start or the destination.';

  @override
  String get tourRecentTitle => 'Recent trips';

  @override
  String get tourRecentBody =>
      'Your last trips, with what you saved. Tap one to see it again or start it again.';

  @override
  String get tourLinesTitle => 'Lines';

  @override
  String get tourLinesBody =>
      'Every bus, microbus and minibus line: where it goes and where it stops.';

  @override
  String get tourMetroTitle => 'Metro & rail';

  @override
  String get tourMetroBody => 'The metro and rail map, stations and fares.';

  @override
  String get tourTripsTitle => 'Trips';

  @override
  String get tourTripsBody =>
      'All your trips and how much time and money Guidy saved you.';

  @override
  String get tourSettingsTitle => 'Settings';

  @override
  String get tourSettingsBody =>
      'Language, dark mode, Simple mode, your account, and this tutorial if you want it again.';

  @override
  String get tourTripNowTitle => 'What to do now';

  @override
  String get tourTripNowBody =>
      'The step you\'re on: where to walk, which vehicle to take and where to get off. It moves on by itself as you go.';

  @override
  String get tourTripLeftTitle => 'What\'s left of this step';

  @override
  String get tourTripLeftBody =>
      'How far and how long until the end of this step, updated as you move. A ride shows its fare next to the line. Drag this card up for every step.';

  @override
  String get tourTripToolsTitle => 'Trip tools';

  @override
  String get tourTripToolsBody =>
      'See the whole route, share your trip live with family, or report a problem with a line.';

  @override
  String get tourTripButtonsTitle => 'Map buttons';

  @override
  String get tourTripButtonsBody =>
      'Turn the map north, bring the map back to you, and turn the alert before your stop on or off.';

  @override
  String get tourTripPipTitle => 'Leave the app any time';

  @override
  String get tourTripPipBody =>
      'On Android the trip keeps going in a small window over your other apps. Drag it to the bottom of the screen to close it.';

  @override
  String get settingsReplayTutorial => 'Replay tutorial';

  @override
  String get settingsReplayTutorialSubtitle =>
      'A quick tour of Guidy\'s main features';

  @override
  String get lineCityAlexandria => 'Alexandria';

  @override
  String get lineCityIntercity => 'Cairo ⇄ Alexandria';

  @override
  String get commuteNotifsLabel => 'Notifications';

  @override
  String get commuteNotifsSubtitle => 'Best times to leave, last-ride warnings';

  @override
  String get commuteNotifsEasier => 'Easier times to travel';

  @override
  String get commuteNotifsLastService => 'Last-service warnings';

  @override
  String get commuteNotifsNeedHomeWork =>
      'Save Home and Work, then plan the trip once, to get these.';

  @override
  String get commuteNotifsBlocked =>
      'Notifications are turned off for Guidy on this phone, so these can\'t reach you.';

  @override
  String get commuteNotifsOpenSettings => 'Turn on in phone settings';

  @override
  String get commuteChannelName => 'Commute';

  @override
  String get commuteChannelDescription =>
      'Easier times for your trips between Home and Work, and your lines\' last service.';

  @override
  String commuteLastServiceTitle(String line, String time) {
    return '$line stops at $time';
  }

  @override
  String get commuteLastServiceBody =>
      'Still out? This is the last service today for a line on your way home.';

  @override
  String get commuteEasierTitleMorning => 'A good time to head to work';

  @override
  String get commuteEasierTitleEvening => 'A good time to head home';

  @override
  String commuteEasierBody(
    String line,
    String every,
    String until,
    String slow,
  ) {
    return '$line runs every $every until $until. Other times it\'s every $slow.';
  }

  @override
  String get commuteRushTitleMorning => 'Beat the morning rush';

  @override
  String commuteRushBodyMorning(String time) {
    return 'Leave before $time for an easier ride to work.';
  }

  @override
  String get commuteRushTitleEvening => 'A quieter time to head home';

  @override
  String commuteRushBodyEvening(String time) {
    return 'Traffic eases now, before the evening rush at $time.';
  }

  @override
  String actWalkTo(String minutes) {
    return 'Walk $minutes to';
  }

  @override
  String get actWaveDownAny => 'Wave down any of these';

  @override
  String actWaveDown(String line) {
    return 'Wave down $line on';
  }

  @override
  String get actWaitForAny => 'Wait for one of these';

  @override
  String actTakeAt(String action) {
    return '$action at';
  }

  @override
  String get actAskDriverStopAt => 'Ask the driver to stop at';

  @override
  String get actWaveDownRide => 'Wave down a ride';

  @override
  String get actWaitForRide => 'Wait for a ride';

  @override
  String stepAskDriver(String place) {
    return 'Ask the driver: going to $place?';
  }

  @override
  String get stepWhichMicrobuses => 'Which microbuses?';

  @override
  String get stepWhichBuses => 'Which buses?';

  @override
  String get actGetOffAt => 'Get off at';

  @override
  String actGetOffWalkTo(String minutes) {
    return 'Get off, then walk $minutes to';
  }

  @override
  String get actYourDestination => 'your destination';

  @override
  String get navStepDone => 'Done';

  @override
  String get navStepLater => 'Later';

  @override
  String get navBackToNow => 'Back to now';

  @override
  String get navPrevStep => 'Previous step';

  @override
  String get navNextStep => 'Next step';

  @override
  String get routeDetailsTitle => 'Route details';

  @override
  String get routeLeave => 'Leave';

  @override
  String get routeGetOff => 'Get off';

  @override
  String get routeAskDriverStop => 'Ask the driver to stop';

  @override
  String get routeArrive => 'Arrive';

  @override
  String routeRideFold(String stops) {
    return 'Ride $stops';
  }

  @override
  String routeWalkLeg(String minutes, String distance) {
    return 'Walk $minutes, $distance';
  }

  @override
  String get simpleWhereToGo => 'Where do you want to go?';

  @override
  String get simpleGoHome => 'Go home';

  @override
  String get simpleGoWork => 'Go to work';

  @override
  String get simpleSavedPlaces => 'My saved places';

  @override
  String get simpleMyTrips => 'My trips';

  @override
  String get simpleTapToChoose => 'Tap to choose the place';

  @override
  String get simpleChangePlace => 'Change';

  @override
  String get simpleGoAgain => 'Go again';

  @override
  String simpleFrom(String place) {
    return 'From: $place';
  }

  @override
  String get simpleChangeStart => 'Change starting point';

  @override
  String get simpleUseMyLocation => 'Use my location';

  @override
  String get simpleBack => 'Back';

  @override
  String get simpleBackHome => 'Back to Home';

  @override
  String get simpleRoutesTitle => 'Choose how to go';

  @override
  String get simpleRoutesHint => 'The easiest ways, fewest changes first';

  @override
  String simpleOption(int n) {
    return 'Option $n';
  }

  @override
  String get simpleEasiest => 'Easiest';

  @override
  String simpleChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
      zero: 'No changes',
    );
    return '$_temp0';
  }

  @override
  String simpleWalkFor(String minutes) {
    return 'Walk $minutes';
  }

  @override
  String simpleTripTotal(String minutes, String fare) {
    return '$minutes, $fare';
  }

  @override
  String get simpleStartTrip => 'Start this trip';

  @override
  String get simpleNoRoutes =>
      'We could not find a way to go. Please try another place.';

  @override
  String simpleStepOf(int n, int total) {
    return 'Step $n of $total';
  }

  @override
  String simpleWalkTo(String place) {
    return 'Walk to $place';
  }

  @override
  String simpleRideTo(String action, String place) {
    return '$action to $place';
  }

  @override
  String simpleGetOffAt(String place) {
    return 'Get off at $place';
  }

  @override
  String get simpleWalkOn => 'Walk to your destination';

  @override
  String simpleTellDriver(String place) {
    return 'Tell the driver: “$place”';
  }

  @override
  String get simpleNextStep => 'Next step';

  @override
  String get simpleEndTrip => 'End trip';

  @override
  String get simpleEndTripTitle => 'End this trip?';

  @override
  String get simpleEndTripBody =>
      'The directions will stop. You can start the trip again from the list of ways to go.';

  @override
  String get simpleEndTripYes => 'Yes, end trip';

  @override
  String get simpleKeepGoing => 'No, keep going';

  @override
  String get simpleClearTitle => 'Clear your recent searches?';

  @override
  String get simpleClearBody =>
      'This only removes the list. Your saved places stay.';

  @override
  String get simpleClearYes => 'Yes, clear';

  @override
  String get simpleSettingsOn => 'Simple Mode is on';

  @override
  String get simpleSettingsOnHint => 'Turn it off to see every feature again.';

  @override
  String get simpleLogOutTitle => 'Log out of Guidy?';

  @override
  String get simpleLogOutBody =>
      'You will need to sign in again to use your saved places and trips.';

  @override
  String get simpleLogOutYes => 'Yes, log out';

  @override
  String get simpleTurnOff => 'Turn off Simple Mode';

  @override
  String get walkReportButton => 'This walk is wrong';

  @override
  String get walkReportedLabel => 'Walk reported';

  @override
  String get walkReportTitle => 'What is wrong with this walk?';

  @override
  String get walkReasonBuildings => 'It goes through buildings';

  @override
  String get walkReasonTooLong => 'It is too long';

  @override
  String get walkReasonNoPath => 'The path does not exist';

  @override
  String get walkReasonOther => 'Something else';

  @override
  String get walkReportNote => 'Add a note (optional)';

  @override
  String get walkReportSend => 'Send report';

  @override
  String get walkReportThanks => 'Thanks! We will check this walk.';

  @override
  String get tripSharingLabel => 'Share my trips';

  @override
  String get tripSharingSubtitle =>
      'Helps fix bus routes and missing footpaths.';

  @override
  String get tripSharingInfoTooltip => 'What this shares';

  @override
  String get tripSharingInfoTitle => 'What \"Share my trips\" does';

  @override
  String get tripSharingInfoBody =>
      'Only while you follow a trip in Guidy, it records:\n\n• The route you rode: the lines and stops, when you reached each step, and your phone\'s GPS along the way. This is how Guidy learns that a bus or microbus now takes a different street, and fixes the line for everyone.\n\n• The paths you walk on the trip\'s walking steps. Before anything is sent, the first and last 50 metres of each walk are cut off, so your home, work and other doors stay out of it. This finds footpaths and crossings missing from the map.\n\nNothing is recorded when you\'re not following a trip. What\'s sent is kept with the trip it came from, without your name, and deleted after 180 days. Deleting your account removes what ties it to you.\n\nThis is on by default, as our Terms and Privacy Policy say. You can turn it off here at any time: nothing more is recorded, and anything not sent yet is deleted.';

  @override
  String get tripSharingInfoOk => 'OK';

  @override
  String get tripShareAskTitle => 'Help improve Guidy';

  @override
  String get tripShareAskBody =>
      'Share this trip\'s path to help fix bus routes and missing footpaths?';

  @override
  String get tripShareAskYes => 'Share';

  @override
  String get tripShareAskNo => 'Not now';

  @override
  String get whatsNewTitle => 'What\'s new in Guidy';

  @override
  String get whatsNewOk => 'Got it';

  @override
  String get commuteInfoTooltip => 'About commute notifications';

  @override
  String get commuteInfoTitle => 'Commute notifications';

  @override
  String get commuteInfoBody =>
      'Guidy watches the trip between your saved Home and Work, both ways. Save Home and Work, then plan that trip once: Guidy remembers its lines and looks them up again every two weeks.\n\nIt can send two kinds of alert, each with its own switch:\n• Easier times to travel: when one of your lines runs much more often than usual (mornings 5-11, afternoons 1-9). If your lines have no timetable, it warns you before the morning (7:00) and evening (4:30) rush hours.\n• Last-service warning: 45 minutes before the first of your lines stops for the day.\n\nAt most 3 a day, at least an hour apart, and none on Fridays.\n\nIt is planned on your phone from the lines\' timetables, with no account needed, and nothing about you is sent to make it. The alerts arrive even when Guidy is closed.\n\nTo turn them off, use the switches under \"Notifications\": one for each kind, or the top one for all of them.';

  @override
  String get patchNotesTitle => 'Patch notes';

  @override
  String get patchNotesSubtitle => 'What changed in every version';

  @override
  String get patchNotesCurrent => 'You are here';

  @override
  String get removeBannerTitle => 'Hide the banner for 24 hours';

  @override
  String get removeBannerSubtitle => 'Watch a short ad. Other ads stay.';

  @override
  String removeBannerActive(String time) {
    return 'Banner hidden until $time';
  }

  @override
  String get removeBannerUnavailable =>
      'No ad is available right now. Please try again later.';

  @override
  String get removeBannerDone => 'Done. The banner is hidden for 24 hours.';

  @override
  String get removeBannerNotWatched =>
      'The banner stays: the ad has to be watched to the end.';

  @override
  String get currentTripLabel => 'In progress';

  @override
  String currentTripTitle(String place) {
    return 'Your trip to $place';
  }

  @override
  String tripGoingTo(String place) {
    return 'Going to $place';
  }

  @override
  String currentTripLeft(String minutes) {
    return 'About $minutes left';
  }

  @override
  String get currentTripTap => 'Tap to continue';

  @override
  String get tripChannelName => 'Trip in progress';

  @override
  String get tripChannelDescription =>
      'Your current step while a trip is running.';

  @override
  String get tripAlertChannelName => 'Stop alerts';

  @override
  String get tripAlertChannelDescription =>
      'A heads-up when your stop is coming.';

  @override
  String get tripNearTitle => 'Get ready';

  @override
  String tripNearBody(String place) {
    return '$place is coming up. Time to get off or change.';
  }
}
