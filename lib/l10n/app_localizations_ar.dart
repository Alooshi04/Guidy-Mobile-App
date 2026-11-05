// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTagline => 'رفيقك في مواصلات مصر';

  @override
  String get goodMorning => 'صباح الخير';

  @override
  String goodMorningUser(String name) {
    return 'صباح الخير يا $name';
  }

  @override
  String get goodAfternoon => 'نهارك سعيد';

  @override
  String goodAfternoonUser(String name) {
    return 'نهارك سعيد يا $name';
  }

  @override
  String get goodEvening => 'مساء الخير';

  @override
  String goodEveningUser(String name) {
    return 'مساء الخير يا $name';
  }

  @override
  String get goodNight => 'مساء الخير';

  @override
  String goodNightUser(String name) {
    return 'مساء الخير يا $name';
  }

  @override
  String get whereTo => 'رايح فين؟';

  @override
  String get quickAccessHome => 'البيت';

  @override
  String get quickAccessWork => 'الشغل';

  @override
  String get quickAccessSaved => 'محفوظ';

  @override
  String routingTo(String name) {
    return 'بنوصلك لـ $name...';
  }

  @override
  String get gpsRequiredToRoute => 'لازم تشغل الـ GPS عشان نقدر نوصلك.';

  @override
  String resettingLocation(String key) {
    return 'بنغيّر مكان $key...';
  }

  @override
  String setLocationTitle(String key) {
    return 'حدّد مكان $key';
  }

  @override
  String locationSavedAs(String key, String name) {
    return 'اتحفظ $key باسم $name';
  }

  @override
  String get searchOrTapMap => 'دوّر أو دوس على الخريطة...';

  @override
  String saveAsKey(String key) {
    return 'احفظ كـ $key';
  }

  @override
  String get pickupLocation => 'منين؟';

  @override
  String get gpsFetchFailed => 'معرفناش نجيب موقعك بالـ GPS.';

  @override
  String get findRoutes => 'دوّر على مواصلة';

  @override
  String get routeOptionsTitle => 'خيارات الرحلة';

  @override
  String get routeCalculationFailed => 'معرفناش نحسب الطريق.';

  @override
  String get availableRoutes => 'الطرق اللي ممكن تروح بيها';

  @override
  String get routeListTab => 'قايمة السكك';

  @override
  String get quickCompareTab => 'مقارنة سريعة';

  @override
  String get statDuration => 'المدة';

  @override
  String get statFare => 'السعر';

  @override
  String get statDistance => 'المسافة';

  @override
  String routeTimeBreakdown(String riding, String wait) {
    return '$riding ركوب وحوالي $wait انتظار';
  }

  @override
  String stepWaitHint(String wait) {
    return 'استنى حوالي $wait';
  }

  @override
  String durationMinutes(String minutes) {
    return '$minutes';
  }

  @override
  String distanceKm(String km) {
    return '$km كم';
  }

  @override
  String fareEgp(String amount) {
    return '$amount جنيه';
  }

  @override
  String alsoWorksLabel(String routes) {
    return 'كمان ينفع: $routes';
  }

  @override
  String routeEveryMinutes(String route, String minutes) {
    return '$route كل $minutes تقريبًا';
  }

  @override
  String get listSeparator => '، ';

  @override
  String get navNowLabel => 'دلوقتي';

  @override
  String get navAlsoServing => 'مواصلات تانية على نفس الخط';

  @override
  String get navYourRoute => 'خطك';

  @override
  String navMinutesAway(String minutes) {
    return 'جاي بعد $minutes تقريبًا';
  }

  @override
  String get navArrivingNow => 'جاي دلوقتي';

  @override
  String navEveryMinutes(String minutes) {
    return 'كل $minutes تقريبًا';
  }

  @override
  String navWalkToStop(String meters, String stop) {
    return '$meters م مشي لـ$stop';
  }

  @override
  String navWalkToStopFirst(String meters, String stop) {
    return 'امشي $meters م لـ$stop الأول';
  }

  @override
  String navGetOffThenWalk(String stop, String meters) {
    return 'انزل عند $stop وامشي $meters م';
  }

  @override
  String get legalAgreePrefix => 'أوافق على ';

  @override
  String get legalTermsLink => 'الشروط والأحكام';

  @override
  String get legalAgreeSep1 => '، و';

  @override
  String get legalPrivacyLink => 'سياسة الخصوصية';

  @override
  String get legalAgreeSep2 => ' و';

  @override
  String get legalDeletionLink => 'سياسة حذف البيانات';

  @override
  String get legalAgreeEnd => '.';

  @override
  String get legalConsentTitle => 'قبل ما تكمل';

  @override
  String get legalConsentBody =>
      'من فضلك اقرا شروط Guidy وسياساته ووافق عليها عشان تستخدم التطبيق. دوس على أي اسم عشان تقراه.';

  @override
  String get legalConsentContinue => 'موافق، كمّل';

  @override
  String get navNoLiveData => 'مفيش بيانات مباشرة لسه';

  @override
  String get navLocationOff => 'الموقع مقفول، الخريطة مش هتتحرك معاك.';

  @override
  String get navLocationBlocked =>
      'الموقع محجوب لجايدي. افتحه من الإعدادات عشان تتابع الخط مباشرة.';

  @override
  String get navLocationLost => 'الإشارة ضاعت. خطواتك لسه تحت.';

  @override
  String get createAccount => 'اعمل حساب';

  @override
  String get nameLabel => 'الاسم بالكامل';

  @override
  String get nameHint => 'اكتب اسمك';

  @override
  String get emailLabel => 'الإيميل';

  @override
  String get emailHint => 'اكتب إيميلك';

  @override
  String get passwordLabel => 'الباسورد';

  @override
  String get passwordHint => 'اكتب الباسورد';

  @override
  String get passwordCreateHint => 'اعمل باسورد';

  @override
  String get confirmPasswordLabel => 'تأكيد الباسورد';

  @override
  String get confirmPasswordHint => 'أكد الباسورد';

  @override
  String get signIn => 'دخول';

  @override
  String get signUp => 'تسجيل';

  @override
  String get noAccountPrompt => 'مش عندك حساب؟ ';

  @override
  String get hasAccountPrompt => 'عندك حساب بالفعل؟ ';

  @override
  String get fillBothFields => 'لازم تملى الخانتين';

  @override
  String get fillAllFields => 'لازم تملى كل الخانات';

  @override
  String get invalidEmail => 'اكتب إيميل صحيح';

  @override
  String get signInFailed => 'الدخول فشل';

  @override
  String get signUpFailed => 'التسجيل فشل';

  @override
  String get incorrectCredentials => 'الإيميل أو الباسورد غلط.';

  @override
  String get checkInternet => 'اتأكد من النت عندك.';

  @override
  String get passwordsDontMatch => 'الباسوردين مش زي بعض';

  @override
  String get emailAlreadyRegistered => 'الإيميل ده متسجل قبل كده.';

  @override
  String get languageSwitcherTitle => 'اللغة';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get youHaveArrived => 'وصلت!';

  @override
  String arrivingAt(String station) {
    return 'هتوصل $station...';
  }

  @override
  String distanceKmTo(String distance, String station) {
    return '$distance كم لحد $station';
  }

  @override
  String distanceMTo(String distance, String station) {
    return '$distance متر لحد $station';
  }

  @override
  String get myCurrentLocation => 'موقعي الحالي';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get darkModeLabel => 'الوضع الليلي';

  @override
  String get darkModeSubtitle => 'بيغيّر وضع التطبيق مهما كان إعداد موبايلك';

  @override
  String get accountSectionLabel => 'الحساب';

  @override
  String get preferencesSectionLabel => 'التفضيلات';

  @override
  String get logOut => 'تسجيل الخروج';

  @override
  String get quickDestinationsLabel => 'وجهات سريعة';

  @override
  String get adPlaceholderLabel => 'إعلان';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get contactUsLabel => 'تواصل معانا';

  @override
  String get continueWithGoogle => 'الدخول بحساب Google';

  @override
  String get orDivider => 'أو';

  @override
  String get socialSignInFailed => 'معرفناش نسجل دخولك. جرب تاني.';

  @override
  String get savedPlacesTitle => 'الأماكن المحفوظة';

  @override
  String get addPlaceButton => 'ضيف مكان';

  @override
  String get noSavedPlacesYet =>
      'لسه مفيش أماكن محفوظة. دوس تحت عشان تضيف واحد.';

  @override
  String get deletePlaceConfirmTitle => 'تشيل المكان ده؟';

  @override
  String get deletePlaceConfirmBody => 'تقدر تضيفه تاني في أي وقت.';

  @override
  String get placeNameHint => 'الاسم (زي: الجيم، المسجد)';

  @override
  String get cancelButton => 'إلغاء';

  @override
  String get removeButton => 'شيل';

  @override
  String get noSearchResultsFound =>
      'ملقيناش حاجة بالاسم ده. جرب تدور بطريقة تانية.';

  @override
  String get placeSearchUnavailable =>
      'البحث عن الأماكن مش شغال في النسخة دي. تقدر تختار مكان من الخريطة.';

  @override
  String get continueAsGuest => 'كمل كضيف';

  @override
  String get guestLabel => 'ضيف';

  @override
  String get deleteAccountButton => 'احذف الحساب';

  @override
  String get deleteAccountConfirmTitle => 'متأكد إنك عايز تحذف حسابك؟';

  @override
  String get deleteAccountConfirmBody => 'الخطوة دي نهائية ومش هينفع ترجعها.';

  @override
  String get deleteGuestDataButton => 'احذف بيانات الضيف';

  @override
  String get deleteGuestDataConfirmTitle => 'متأكد إنك عايز تحذف بيانات الضيف؟';

  @override
  String get deleteGuestDataConfirmBody =>
      'ده هينهي جلسة الضيف ويحذف البيانات المرتبطة بيها، زي موافقتك على الشروط. البلاغات اللي بعتها عن الطرق هتفضل موجودة. الخطوة دي نهائية ومش هينفع ترجعها.';

  @override
  String get deleteButton => 'احذف';

  @override
  String get reauthRequiredTitle => 'سجل دخولك تاني';

  @override
  String get reauthRequiredBody =>
      'علشان أمانك، أكد إنك إنت قبل ما نحذف حسابك.';

  @override
  String get confirmButton => 'تأكيد';

  @override
  String get deleteAccountFailed => 'معرفناش نحذف حسابك. جرب تاني.';

  @override
  String get recentSearchesLabel => 'الأخيرة';

  @override
  String get clearHistoryLabel => 'امسح';

  @override
  String shareRouteText(String start, String end, String link) {
    return 'إزاي تروح من $start لـ$end بالمواصلات، على Guidy:\n$link';
  }

  @override
  String get retryButton => 'حاول تاني';

  @override
  String get somethingWentWrongTitle => 'حصلت مشكلة';

  @override
  String get rateGuidyLabel => 'قيّم جايدي';

  @override
  String get privacyPolicyLabel => 'سياسة الخصوصية';

  @override
  String get supportSectionLabel => 'الدعم';

  @override
  String get useCurrentLocationTooltip => 'استخدم موقعي الحالي';

  @override
  String get showPasswordTooltip => 'اظهر الباسورد';

  @override
  String get hidePasswordTooltip => 'اخفي الباسورد';

  @override
  String get closeMapTooltip => 'قفل';

  @override
  String get centerOnMyLocationTooltip => 'روح لموقعي';

  @override
  String get removePlaceTooltip => 'شيل المكان ده';

  @override
  String get vehicleBus => 'أتوبيس';

  @override
  String get vehicleMinibus => 'ميني باص';

  @override
  String get vehicleMicrobus => 'ميكروباص';

  @override
  String get vehicleMetro => 'المترو';

  @override
  String get vehicleMonorail => 'المونوريل';

  @override
  String get vehicleLrt => 'القطار الكهربائي الخفيف';

  @override
  String get vehicleTram => 'الترام';

  @override
  String get vehicleAirportShuttle => 'مكوك المطار';

  @override
  String get vehicleBrt => 'الأتوبيس الترددي';

  @override
  String get vehicleWalk => 'مشي';

  @override
  String get routeTierRecommended => 'الموصى به';

  @override
  String get routeTierFastest => 'الأسرع';

  @override
  String get routeTierRegular => 'عادي';

  @override
  String get routeTierCheapest => 'الأرخص';

  @override
  String get routeTierAlternative => 'سكة تانية';

  @override
  String get routeTierWalk => 'مشي';

  @override
  String get crowdLow => 'قليلة';

  @override
  String get crowdMedium => 'متوسطة';

  @override
  String get crowdHigh => 'كتير';

  @override
  String get instrWalkToStationTitle => 'امشي للمحطة';

  @override
  String instrWalkToStationSubtitle(String distance, String station) {
    return 'امشي $distance متر لحد $station';
  }

  @override
  String get instrWalkToTransferTitle => 'امشي لمحطة التغيير';

  @override
  String instrWalkToTransferSubtitle(String station) {
    return 'امشي للمحطة اللي جاية قرب $station';
  }

  @override
  String get instrContinueWalkTitle => 'بتمشي';

  @override
  String get instrContinueWalkSubtitle => 'كمل مشي';

  @override
  String instrBoardTitleWithVehicle(String vehicleType) {
    return 'اركب $vehicleType';
  }

  @override
  String instrBoardWithNumber(String vehicleType, String routeNumber) {
    return '$vehicleType رقم $routeNumber';
  }

  @override
  String instrBoardGeneral(String vehicleType, String routeDescription) {
    return '$vehicleType رايح $routeDescription';
  }

  @override
  String get instrTransferTitle => 'غيّر مواصلة';

  @override
  String get instrArriveTitle => 'وصلت، انزل';

  @override
  String instrArriveSubtitle(String station) {
    return 'انزل عند $station';
  }

  @override
  String get instrWalkToDestinationTitle => 'امشي لوجهتك';

  @override
  String instrWalkToDestinationSubtitle(String distance) {
    return 'امشي $distance متر لحد وجهتك';
  }

  @override
  String get fareEstimateNote => 'الأسعار تقريبية وممكن تختلف';

  @override
  String get tripRecapTitle => 'نظرة على الرحلة';

  @override
  String get tripStepsLabel => 'الخطوات';

  @override
  String get fareTotalLabel => 'إجمالي السعر';

  @override
  String get startNavigationButton => 'ابدأ الرحلة';

  @override
  String get navLines => 'الخطوط';

  @override
  String get navMetro => 'المترو';

  @override
  String linesOfMode(String mode) {
    return 'خطوط $mode';
  }

  @override
  String get lineFirstTrip => 'أول رحلة';

  @override
  String get lineLastTrip => 'آخر رحلة';

  @override
  String get lineServiceHours => 'المواعيد';

  @override
  String get lineOpenNow => 'شغال دلوقتي';

  @override
  String get lineClosedNow => 'مش شغال دلوقتي';

  @override
  String lineClosedOpensAt(String time) {
    return 'مش شغال دلوقتي، هيفتح الساعة $time';
  }

  @override
  String get navToolsShow => 'اظهر أدوات الرحلة';

  @override
  String get navToolsHide => 'اخفي أدوات الرحلة';

  @override
  String get navToolsOverview => 'شوف المشوار كله';

  @override
  String get linesSearchHint => 'رقم الخط، أو المنطقة اللي بيعدي منها';

  @override
  String get linesSearchPrompt =>
      'دوّر برقم الخط زي 65، أو باسم مكان زي المعادي.';

  @override
  String get linesNoResults => 'مفيش خطوط مطابقة للبحث.';

  @override
  String get linesTapHint => 'دوس على أي خط تشوف كل محطاته.';

  @override
  String get linesAlexandriaTitle => 'خطوط الإسكندرية';

  @override
  String linesAlexandriaOfMode(String mode) {
    return 'خطوط $mode الإسكندرية';
  }

  @override
  String get linesAlexandriaHint =>
      'الخطوط اللي شغالة في إسكندرية بس، ومعاها ميكروباصات القاهرة إسكندرية.';

  @override
  String get linesAlexandriaEmpty => 'مفيش خطوط إسكندرية متاحة دلوقتي.';

  @override
  String linesStopCount(int count) {
    return '$count محطة';
  }

  @override
  String linesEveryMinutes(String minutes) {
    return 'كل $minutes تقريبًا';
  }

  @override
  String linesDirectionTowards(String terminus) {
    return 'باتجاه $terminus';
  }

  @override
  String get linesStopsInOrder => 'المحطات بالترتيب';

  @override
  String get linesLoadFailed => 'مش قادرين نحمّل الخطوط دلوقتي.';

  @override
  String get linesViewList => 'المحطات';

  @override
  String get linesViewMap => 'الخريطة';

  @override
  String get linesFitRoute => 'ضبط المسار';

  @override
  String get metroTitle => 'مخطط المترو';

  @override
  String get metroSubtitle => 'مترو بس، من غير أتوبيسات ولا مشي.';

  @override
  String get metroFromLabel => 'من';

  @override
  String get metroToLabel => 'إلى';

  @override
  String get metroPickStation => 'اختار محطة';

  @override
  String get metroPlanButton => 'اعرض خط المترو';

  @override
  String get metroSameStationError => 'اختار محطتين مختلفين.';

  @override
  String get metroNoPathError => 'مفيش طريق بالمترو لوحده بين المحطتين دول.';

  @override
  String get metroSearchStationHint => 'ابحث عن محطة';

  @override
  String metroChangeAt(String station) {
    return 'غيّر عند $station';
  }

  @override
  String metroChangeTo(String line) {
    return 'غيّر لخط $line';
  }

  @override
  String metroChangesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغيير',
      many: '$count تغييرًا',
      few: '$count تغييرات',
      two: 'تغييران',
      one: 'تغيير واحد',
    );
    return '$_temp0';
  }

  @override
  String get metroNoChanges => 'مباشر، من غير تغيير';

  @override
  String get metroInterchangeBadge => 'محطة تبديل';

  @override
  String metroRideStops(int count) {
    return 'اركب $count محطة';
  }

  @override
  String get metroSwapTooltip => 'بدّل البداية والوجهة';

  @override
  String metroLinesServing(String lines) {
    return 'الخطوط: $lines';
  }

  @override
  String get metroStationsLoadFailed => 'مش قادرين نحمّل قائمة المحطات.';

  @override
  String get navRecenterTooltip => 'رجّعني لمكاني';

  @override
  String get fareFree => 'ببلاش';

  @override
  String get pinnedLocation => 'موقع محدد على الخريطة';

  @override
  String get serverUnreachable =>
      'مش قادرين نوصل لسيرفر جايدي. اطمن على الإنترنت وجرب تاني.';

  @override
  String get errorOutsideCoverage =>
      'المكان ده بره المنطقة اللي جايدي بيغطيها.';

  @override
  String get errorNoRouteFound =>
      'مش لاقيين طريق للمكان ده. ممكن يكون بره المناطق اللي بنغطيها.';

  @override
  String get errorNoServiceThisHour =>
      'مفيش مواصلات شغالة في الوقت ده. أغلب الخطوط بتشتغل من حوالي ٦ الصبح لـ١١ بالليل. جرب تاني في المواعيد دي.';

  @override
  String get errorTitleNotCovered => 'لسه مش بنغطي المشوار ده';

  @override
  String get errorTitleNoService => 'مفيش مواصلات شغالة دلوقتي';

  @override
  String linesDirectionTowardsFrom(String terminus, String origin) {
    return 'باتجاه $terminus، من $origin';
  }

  @override
  String get reportEntryPoint => 'في حاجة غلط في الطريق ده؟';

  @override
  String get reportCommentRequired => 'اكتبلنا شوية تفاصيل عشان نقدر نتصرف.';

  @override
  String get reportSubmit => 'ابعت البلاغ';

  @override
  String get reportSent => 'شكراً، بلاغك وصلنا.';

  @override
  String get reportQueued => 'حفظناه. هنبعته أول ما النت يرجع.';

  @override
  String get reportFailed => 'مش قادرين نبعت البلاغ. جرب تاني.';

  @override
  String get reportSignInRequired => 'سجّل دخولك عشان تبعت بلاغ.';

  @override
  String get routeTierPartial => 'يقرّبك من وجهتك';

  @override
  String partialUncoveredNotice(String distance) {
    return 'ده مش بيوصل لوجهتك. آخر $distance مفيش خط نعرفه بيغطّيها لحد دلوقتي.';
  }

  @override
  String partialLastCoveredStop(String stop) {
    return 'آخر محطة بنغطّيها: $stop';
  }

  @override
  String nearestHubsHint(String origin, String destination) {
    return 'أقرب الأماكن اللي بنغطّيها: $origin جنب نقطة البداية، و$destination جنب وجهتك.';
  }

  @override
  String get reportMissingRouteButton => 'قوللنا الناقص إيه';

  @override
  String get reportMissingRouteTitle => 'أنهي خط المفروض يكون هنا؟';

  @override
  String get reportMissingRouteIntro =>
      'بياناتنا ناقصة في الرحلة دي. لو تعرف أتوبيس أو ميني باص أو ميكروباص بيوصل، اكتبه وهنضيفه للكل.';

  @override
  String get reportMissingRouteHint =>
      'مثلاً: ميني باص ٣٧ من الكيلو أربعة و نص لكفر طهرمس';

  @override
  String get betterRouteButton => 'تعرف طريق أحسن؟';

  @override
  String get betterRouteSheetIntro => 'قولّنا عليه وهنراجعه ونضيفه للكل.';

  @override
  String get betterRouteWriteTitle => 'اكتبلنا الطريق';

  @override
  String get betterRouteWriteSubtitle => 'اوصفه بكلامك';

  @override
  String get betterRouteWriteHint =>
      'مثلاً: امشي لعباس العقاد، وخد ميني باص 66 لرمسيس، وبعدين المترو';

  @override
  String get betterRouteBuildTitle => 'ابنيه بنفسك من شبكة المواصلات';

  @override
  String get betterRouteBuildSubtitle => 'اختار كل خط وكل مشية بالترتيب';

  @override
  String get betterRouteBuilderTitle => 'ابني طريقك';

  @override
  String get betterRouteBuilderIntro =>
      'ضيف كل جزء من المشوار بالترتيب، من مكانك لحد وجهتك.';

  @override
  String get betterRouteAddWalk => 'ضيف مشي';

  @override
  String get betterRouteAddRide => 'ضيف مواصلة';

  @override
  String get betterRouteWalkMeters => 'كام متر (اختياري)';

  @override
  String get betterRouteBoardAt => 'هتركب منين (اختياري)';

  @override
  String get betterRouteGetOffAt => 'هتنزل فين (اختياري)';

  @override
  String get betterRouteFare => 'الأجرة بالجنيه (اختياري)';

  @override
  String get betterRouteNoteHint => 'عايز تقولنا حاجة تانية؟ (اختياري)';

  @override
  String get betterRouteRemoveLeg => 'شيل';

  @override
  String get betterRouteReorderHint => 'اسحب عشان ترتّب';

  @override
  String get betterRouteMoveUp => 'طلّعه لفوق';

  @override
  String get betterRouteMoveDown => 'نزّله لتحت';

  @override
  String get betterRouteChangeLine => 'غيّر الخط';

  @override
  String get betterRoutePickLineTitle => 'اختار الخط';

  @override
  String get betterRouteNotInApp => 'مش لاقيه؟ اكتبه بنفسك';

  @override
  String get betterRouteTypedMode => 'نوع المواصلة';

  @override
  String get betterRouteTypedName => 'رقم الخط أو اسمه';

  @override
  String get betterRouteTypedAdd => 'ضيف الخط ده';

  @override
  String get betterRouteTypedBadge => 'مش في التطبيق';

  @override
  String get betterRouteNeedRide =>
      'ضيف مواصلة واحدة على الأقل عشان تبعت الطريق.';

  @override
  String get betterRouteSubmit => 'ابعت الطريق';

  @override
  String get betterRouteDiscardTitle => 'تخرج من غير ما تبعت؟';

  @override
  String get betterRouteDiscardBody => 'الطريق اللي بنيته هيضيع.';

  @override
  String get betterRouteDiscardLeave => 'اخرج';

  @override
  String get betterRouteDiscardStay => 'كمّل';

  @override
  String get excludeMetro => 'من غير مترو';

  @override
  String get filterMinWalk => 'أقل مشي';

  @override
  String get filterMinTransfers => 'أقل تحويلات';

  @override
  String get shareTripTooltip => 'مشاركة المشوار';

  @override
  String get navStopAlarmOn => 'تنبيه النزول شغال';

  @override
  String get navStopAlarmOff => 'تنبيه النزول مطفي';

  @override
  String navStopAlarmAlert(String station) {
    return 'استعد للنزول! محطتك القادمة: $station';
  }

  @override
  String get metroTicketTitle => 'شباك تذاكر المترو';

  @override
  String get navStopAlarmActiveToast =>
      'تنبيه النزول: شغال (الموبايل هيهتز قبل محطتك بـ 400م)';

  @override
  String get navStopAlarmDisabledToast => 'تنبيه النزول: مقفول';

  @override
  String get navRecenterFinding => 'بندوّر على مكانك...';

  @override
  String get navRecenterSuccess => 'رجعناك لمكانك';

  @override
  String get navRecenterFallback => 'معرفناش نحدد موقعك، رجعناك لبداية الرحلة';

  @override
  String get navOverviewToast => 'نظرة عامة على خط السير';

  @override
  String get directRouteNoTransfers => 'مباشر بدون تحويل';

  @override
  String transfersCountBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تحويلة',
      few: '$count تحويلات',
      two: 'تحويلتين',
      one: 'تحويلة واحدة',
    );
    return '$_temp0';
  }

  @override
  String walkMetersBadge(String meters) {
    return '$meters متر مشي';
  }

  @override
  String get quickReportTitle => 'إبلاغ عن حالة الطريق';

  @override
  String get quickReportSubtitle =>
      'ساعد ركاب تانيين يعرفوا ظروف المشوار دلوقتي';

  @override
  String get reportCategoryTraffic => 'الطريق واقف / زحمة مش طبيعية';

  @override
  String get reportCategoryMissing => 'الأتوبيس ما جاش / اتأخر كتير';

  @override
  String get reportCategoryCrowd => 'المحطة أو العربية زحمة جداً';

  @override
  String get reportCategoryFare => 'سواق الميكروباص / المحصل زوّد الأجرة';

  @override
  String get reportCategoryDiversion => 'المسار اتغير أو في تحويلة';

  @override
  String get reportThanksToast => 'شكراً، بلاغك اتسجل وهينبه باقي الركاب!';

  @override
  String get reportNotePlaceholder => 'أي تفاصيل زيادة تحب تضيفها؟ (اختياري)';

  @override
  String get walkManeuverRight => 'ادخل يمين';

  @override
  String get walkManeuverLeft => 'ادخل شمال';

  @override
  String get walkManeuverUTurn => 'لف وارجع';

  @override
  String walkInDistance(String distance, String action) {
    return 'بعد $distance $action';
  }

  @override
  String get metroNetworkMapButton => 'خريطة الشبكة';

  @override
  String get navHistory => 'رحلاتي';

  @override
  String get historyTitle => 'رحلاتي والتوفير';

  @override
  String get totalMoneySaved => 'إجمالي التوفير';

  @override
  String get totalTimeSaved => 'الوقت الموفَّر';

  @override
  String get emptyHistoryTitle => 'لسة ما عملتش مشاوير';

  @override
  String get emptyHistorySubtitle =>
      'ابدأ مشوارك أو خطط لسكة جديدة مع جايدي، وأول ما تتحرك هتلاقي مشاويرك وفلوسك اللي وفرتها متسجلة هنا!';

  @override
  String get planTripButton => 'خطط لمشوارك';

  @override
  String get clearHistoryConfirm => 'عايز تمسح كل مشاويرك اللي فاتت؟';

  @override
  String get clearHistoryAction => 'امسح السجل';

  @override
  String get clearHistorySuccess => 'مسحنا سجل المشاوير خلاص';

  @override
  String get tripDeletedToast => 'شيلنا المشوار من السجل';

  @override
  String get savingsCalculationInfoTitle => 'بنحسب التوفير إزاي؟';

  @override
  String get savingsCalculationInfo =>
      'بنحسب التوفير على أساس اختيارك انت بين السكك المتاحة: لما تختار السكة الأسرع بنحسب كام دقيقة وفّرتها مقارنة بباقي الخيارات، ولما تختار السكة الأوفر بنحسب كام جنيه وفّرته مقارنة بالخيارات التانية الأغلى.';

  @override
  String get filterAll => 'الكل';

  @override
  String get filterThisWeek => 'الأسبوع ده';

  @override
  String get filterThisMonth => 'الشهر ده';

  @override
  String get filterMetro => 'مترو';

  @override
  String get filterBus => 'أتوبيس';

  @override
  String get filterMicrobus => 'ميكروباص';

  @override
  String minsSavedShort(String mins) {
    return 'وفّرت $mins';
  }

  @override
  String hoursMinsSavedShort(String hours, String mins) {
    return 'وفّرت $hours ساعة و $mins د';
  }

  @override
  String get reportLineTitle => 'بلّغ عن مشكلة في الخط';

  @override
  String get reportMetroTitle => 'بلّغ عن مشكلة في المترو';

  @override
  String get reportReasonLineDoesNotExist => 'الخط مش موجود أو اتلغى';

  @override
  String get reportReasonLineWrongPath =>
      'مسار الخط اتغير أو بيعدي من شوارع تانية';

  @override
  String get reportReasonLineWrongStop => 'فيه محطة ناقصة أو ترتيب المحطات غلط';

  @override
  String get reportReasonLineWrongFare => 'الأجرة غلط';

  @override
  String get reportReasonLineBadTiming => 'المواعيد أو عدد الرحلات مش مظبوط';

  @override
  String get reportReasonMetroStationClosed => 'المحطة مقفولة أو مش شغالة';

  @override
  String get reportReasonMetroWrongTransfer => 'تعليمات التغيير بين الخطوط غلط';

  @override
  String get reportReasonMetroWrongFare => 'سعر التذكرة غلط';

  @override
  String get reportReasonMetroDelay => 'فيه تأخير كبير أو عطل في الخدمة';

  @override
  String get reportPickStopOptional =>
      'اختار المحطة اللي فيها المشكلة (اختياري)';

  @override
  String get reportAllStopsOption => 'مشكلة عامة في الخط كله';

  @override
  String get reportActionSubmit => 'ابعت البلاغ';

  @override
  String get reportLineSuccessToast =>
      'شكراً! بلاغك وصلنا وهيساعدنا نظبط الشبكة للكل.';

  @override
  String get reportCommentHint =>
      'زوّدنا بتفاصيل زي الأجرة الفعلية أو اسم الشارع البديل';

  @override
  String get reportAnIssueWithThisLine => 'بلّغ عن مشكلة في الخط ده';

  @override
  String get reportAnIssueWithMetro => 'بلّغ عن مشكلة في رحلة المترو';

  @override
  String get reportCategoryOther => 'مشكلة تانية';

  @override
  String get reportReasonPrompt => 'المشكلة إيه؟';

  @override
  String get recentTripsTitle => 'مشاويرك الأخيرة';

  @override
  String get recentTripsSubtitle =>
      'مشاويرك اللي عملتها، تكلفتها والوقت اللي أخدته';

  @override
  String get noRecentTripsYet =>
      'لسة ما عملتش مشاوير.. أول ما تتحرك هتلاقي مشاويرك متسجلة هنا!';

  @override
  String moneySavedPill(String amount) {
    return 'وفّرت $amount ج.م';
  }

  @override
  String get tripDetailFarePaid => 'الأجرة المدفوعة';

  @override
  String get tripDetailOpenRecap => 'تفاصيل المشوار';

  @override
  String minutesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دقيقة',
      few: '$count دقائق',
      two: 'دقيقتين',
      one: 'دقيقة',
      zero: 'أقل من دقيقة',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ساعة',
      few: '$count ساعات',
      two: 'ساعتين',
      one: 'ساعة',
    );
    return '$_temp0';
  }

  @override
  String durationAndMinutes(String minutes) {
    return 'و$minutes';
  }

  @override
  String routeWalkMeters(String meters) {
    return '$meters م';
  }

  @override
  String routeCardLine(String mode, String number) {
    return '$mode $number';
  }

  @override
  String get plannerHint =>
      'دوس على أي خط في الخريطة أو في القايمة عشان تختاره';

  @override
  String plannerWalkTo(String distance, String station) {
    return 'امشي $distance لحد $station';
  }

  @override
  String plannerWalkToDestination(String distance) {
    return 'امشي $distance لحد مكانك';
  }

  @override
  String get lineRecommended => 'مقترح';

  @override
  String get lineRecommendedLegend =>
      'زيه بالظبط: بيوصّلك نفس المشوار، من غير مشي زيادة، وبأجرة قريبة';

  @override
  String plannerAnyOfTheseLines(String mode) {
    return '$mode، اركب أي واحد منهم';
  }

  @override
  String plannerMoreLines(int count) {
    return '+$count كمان';
  }

  @override
  String get plannerFewerLines => 'عرض أقل';

  @override
  String plannerHailAt(String station) {
    return 'شاور لواحد عند $station';
  }

  @override
  String plannerAskToStopAt(String station) {
    return 'قول للسواق يقف عند $station';
  }

  @override
  String plannerWalkToStreet(String distance) {
    return 'امشي $distance لحد الشارع';
  }

  @override
  String get stepWalkToStreet => 'امشي لحد الشارع';

  @override
  String plannerTakeFrom(String station) {
    return 'اركب من $station';
  }

  @override
  String plannerTowards(String station) {
    return 'اتجاه $station';
  }

  @override
  String plannerGetOffAt(String station) {
    return 'انزل عند $station';
  }

  @override
  String get plannerStart => 'يلا نبدأ';

  @override
  String get plannerClosedNow => 'في خطوط في الطريق ده مش شغالة دلوقتي';

  @override
  String plannerMeters(String meters) {
    return '$meters متر';
  }

  @override
  String get plannerSteps => 'خطوات المشوار';

  @override
  String navRideTo(String station) {
    return 'خليك راكب لحد $station';
  }

  @override
  String navRiding(String line) {
    return 'راكب $line';
  }

  @override
  String navWalkThenBoard(String action) {
    return 'وبعدين $action';
  }

  @override
  String navGetReadyOff(String station) {
    return 'جهّز نفسك، هتنزل في $station';
  }

  @override
  String navNearBoarding(String station) {
    return 'قربت توصل $station';
  }

  @override
  String get navGetOffHere => 'انزل هنا';

  @override
  String navWalkToDestinationFrom(String station) {
    return 'امشي من $station لحد مكانك';
  }

  @override
  String get navYouArrived => 'وصلت';

  @override
  String get navSwitchRouteTitle => 'تغيّر للطريق ده؟';

  @override
  String navSwitchRouteBody(String minutes, String fare) {
    return '$minutes، $fare';
  }

  @override
  String get navSwitchRouteConfirm => 'غيّر الطريق';

  @override
  String get navCompassTooltip => 'اتجاه الشمال';

  @override
  String get simpleModeLabel => 'الوضع البسيط';

  @override
  String get simpleModeSubtitle => 'كلام وزراير أكبر، إختيارات أقل، وخطوة خطوة';

  @override
  String get simpleShowMoreRoutes => 'اعرض طرق تانية';

  @override
  String get simpleShowFewerRoutes => 'اعرض أحسن طريق بس';

  @override
  String get shareRouteTooltip => 'شارك الطريق ده';

  @override
  String get shareLiveTooltip => 'شارك رحلتي لايف';

  @override
  String shareLiveText(String dest, String link) {
    return 'تابع رحلتي لـ$dest لايف على Guidy:\n$link';
  }

  @override
  String get shareLiveActive => 'رحلتك متشاركة لايف';

  @override
  String get shareLiveStop => 'وقّف';

  @override
  String get shareLiveFailed => 'معرفناش نبدأ المشاركة. اتأكد من النت.';

  @override
  String get liveViewerTitle => 'رحلة لايف';

  @override
  String liveViewerHeading(String name, String dest) {
    return '$name في الطريق لـ$dest';
  }

  @override
  String liveViewerHeadingNoName(String dest) {
    return 'في الطريق لـ$dest';
  }

  @override
  String liveViewerOnVehicle(String vehicle) {
    return 'دلوقتي في $vehicle';
  }

  @override
  String get liveViewerWalking => 'ماشي على رجله';

  @override
  String liveViewerEta(String time, String minutes) {
    return 'هيوصل حوالي $time (كمان $minutes)';
  }

  @override
  String liveViewerArrived(String dest) {
    return 'وصل $dest';
  }

  @override
  String get liveViewerEnded => 'الرحلة دي مبقتش متشاركة.';

  @override
  String liveViewerUpdated(String time) {
    return 'آخر تحديث $time';
  }

  @override
  String get liveViewerWaiting => 'مستنيين أول مكان يوصلنا…';

  @override
  String get liveViewerOffline => 'معرفناش نحدّث. بنحاول تاني…';

  @override
  String get routeTierAvailableNow => 'شغّال دلوقتي';

  @override
  String get nightNothingRunningTitle => 'مفيش مواصلات شغالة للمشوار ده دلوقتي';

  @override
  String nightNothingRunningBody(String time, String wait) {
    return 'ولا خط من الخطوط اللي المشوار ده محتاجها شغال في الوقت ده. طريقك المعتاد اللي تحت بيرجع يشتغل الساعة $time (بعد $wait).';
  }

  @override
  String get nightCanWalk => 'المسافة تتمشي. شوف اختيار المشي.';

  @override
  String get nightAvailableTitle => 'بالليل: خطوطك المعتادة وقفت';

  @override
  String nightAvailableBody(String time, String wait) {
    return 'أول اختيار بيستخدم خطوط لسه شغالة. طريقك المعتاد بيرجع يشتغل الساعة $time (بعد $wait).';
  }

  @override
  String nightUsualRoute(String time) {
    return 'الطريق المعتاد، بيرجع يشتغل الساعة $time';
  }

  @override
  String get pwRuleMinLength => '8 حروف على الأقل';

  @override
  String get pwRuleUpper => 'حرف إنجليزي كابيتال (A-Z)';

  @override
  String get pwRuleLower => 'حرف إنجليزي سمول (a-z)';

  @override
  String get pwRuleDigit => 'رقم (0-9)';

  @override
  String get pwRuleSymbol => 'رمز، زي ! @ # ?';

  @override
  String get pwRuleNoEdgeSpaces => 'من غير مسافات في الأول أو الآخر';

  @override
  String get pwRuleNotCommon => 'مش باسورد مشهور ومستخدم كتير';

  @override
  String get pwStrengthWeak => 'ضعيف';

  @override
  String get pwStrengthFair => 'مقبول';

  @override
  String get pwStrengthGood => 'كويس';

  @override
  String get pwStrengthStrong => 'قوي';

  @override
  String get pwStrengthLabel => 'قوة الباسورد';

  @override
  String get passwordRulesNotMet => 'الباسورد لسه مش مطابق لكل الشروط.';

  @override
  String get tooManyRequests => 'محاولات كتير. استنى شوية وجرب تاني.';

  @override
  String get verifyEmailTitle => 'أكد إيميلك';

  @override
  String verifyEmailBody(String email) {
    return 'بعتنا لينك تأكيد على $email. افتحه، وبعدين ارجع هنا ودوس \"أكدت\". لو مش لاقيه بص في الـSpam.';
  }

  @override
  String get verifyEmailResend => 'ابعت الإيميل تاني';

  @override
  String verifyEmailResendIn(int seconds) {
    return 'ابعت تاني بعد $seconds ثانية';
  }

  @override
  String get verifyEmailSent => 'بعتنالك إيميل التأكيد.';

  @override
  String get verifyEmailCheck => 'أكدت';

  @override
  String get verifyEmailNotYet =>
      'لسه متأكدش. افتح اللينك اللي في الإيميل الأول.';

  @override
  String get verifyEmailUseOther => 'استخدم حساب تاني';

  @override
  String get forgotPasswordLink => 'نسيت الباسورد؟';

  @override
  String get forgotPasswordTitle => 'غيّر الباسورد';

  @override
  String get forgotPasswordBody =>
      'اكتب إيميل حسابك وهنبعتلك لينك تعمل بيه باسورد جديد.';

  @override
  String get forgotPasswordSend => 'ابعت اللينك';

  @override
  String get forgotPasswordSent =>
      'لو فيه حساب بالإيميل ده، لينك تغيير الباسورد في الطريق. بص في الـInbox والـSpam.';

  @override
  String get changePasswordButton => 'تغيير الباسورد';

  @override
  String get currentPasswordLabel => 'الباسورد الحالي';

  @override
  String get newPasswordLabel => 'الباسورد الجديد';

  @override
  String get confirmNewPasswordLabel => 'تأكيد الباسورد الجديد';

  @override
  String get changePasswordSave => 'حدّث الباسورد';

  @override
  String get changePasswordSuccess => 'الباسورد اتغير.';

  @override
  String get currentPasswordWrong => 'الباسورد الحالي غلط.';

  @override
  String get changePasswordFailed => 'معرفناش نغير الباسورد. جرب تاني.';

  @override
  String get newPasswordSameAsOld =>
      'الباسورد الجديد لازم يكون مختلف عن الحالي.';

  @override
  String get authEmailFailed => 'معرفناش نبعت الإيميل. جرب تاني.';

  @override
  String stepWalkTo(String place) {
    return 'امشي لحد $place';
  }

  @override
  String get stepWalkToDestination => 'امشي لحد المكان اللي رايحه';

  @override
  String stepWalkMeta(String meters, String minutes) {
    return '$meters متر، حوالي $minutes';
  }

  @override
  String rideTakeThing(String thing) {
    return 'اركب $thing';
  }

  @override
  String rideRideThing(String thing) {
    return 'اركب $thing';
  }

  @override
  String stepBoardAt(String station) {
    return 'اركب من $station';
  }

  @override
  String stepToward(String place) {
    return 'اتجاه $place';
  }

  @override
  String stepRideTo(String station) {
    return 'خليك راكب لحد $station';
  }

  @override
  String stepStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محطة',
      few: '$count محطات',
      two: 'محطتين',
      one: 'محطة واحدة',
    );
    return '$_temp0';
  }

  @override
  String stepGetOffAt(String station) {
    return 'انزل في $station';
  }

  @override
  String stepThenWalkTo(String meters, String place, String minutes) {
    return 'وبعدين امشي $meters متر لحد $place، حوالي $minutes';
  }

  @override
  String stepThenWalkToDestination(String meters, String minutes) {
    return 'وبعدين امشي $meters متر لحد المكان اللي رايحه، حوالي $minutes';
  }

  @override
  String liveGetOffIn(String station, String minutes) {
    return 'هتنزل في $station بعد حوالي $minutes';
  }

  @override
  String liveWalkMetersLeft(String meters, String minutes) {
    return 'فاضل $meters متر، حوالي $minutes';
  }

  @override
  String liveWalkLeft(String meters, String place, String minutes) {
    return 'فاضل $meters متر لحد $place، حوالي $minutes';
  }

  @override
  String routeShortRide(String minutes, String fare) {
    return 'أسرع بـ$minutes وأغلى بـ$fare ج.م';
  }

  @override
  String routeLongWalk(String minutes) {
    return 'مشي كتير: $minutes';
  }

  @override
  String get rideReportButton => 'ركبت مواصلة';

  @override
  String get rideReportTitle => 'ركبت إيه؟';

  @override
  String get rideReportFare => 'الأجرة (ج.م)';

  @override
  String get rideReportStart => 'ابدأ التسجيل';

  @override
  String rideReportRecording(String distance, String minutes) {
    return 'بنسجّل المشوار: $distance في $minutes';
  }

  @override
  String get rideReportStop => 'نزلت';

  @override
  String get rideReportThanks => 'شكرًا! هنراجع المشوار ده.';

  @override
  String get rideVehicleTuktuk => 'توكتوك';

  @override
  String get rideVehicleTaxi => 'تاكسي';

  @override
  String get rideVehicleOther => 'حاجة تانية';

  @override
  String get tourSkip => 'تخطّي';

  @override
  String get tourNext => 'التالي';

  @override
  String get tourDone => 'تمام';

  @override
  String tourStepOf(int step, int total) {
    return '$step من $total';
  }

  @override
  String get tourWelcomeTitle => 'أهلاً بيك في جايدي';

  @override
  String get tourWelcomeBody =>
      'لفّة سريعة على اللي جايدي يقدر يعمله. مش هتاخد دقيقة، وتقدر تتخطاها في أي وقت.';

  @override
  String get tourSearchTitle => 'خطّط مشوارك';

  @override
  String get tourSearchBody =>
      'دوس هنا واكتب رايح فين، وجايدي يقارنلك الأتوبيسات والميكروباصات والميني باصات والمترو بالوقت والأجرة والمشي.';

  @override
  String get tourQuickTitle => 'أماكن سريعة';

  @override
  String get tourQuickBody =>
      'البيت والشغل والأماكن اللي حفظتها بدوسة واحدة. دوس كتير على البيت أو الشغل عشان تغيّره. وموجودين كمان في شاشة البحث، لنقطة البداية أو الوصول.';

  @override
  String get tourRecentTitle => 'آخر مشاويرك';

  @override
  String get tourRecentBody =>
      'آخر مشاويرك واللي وفّرته فيها. دوس على أي واحد تشوفه تاني أو تبدأه من جديد.';

  @override
  String get tourLinesTitle => 'الخطوط';

  @override
  String get tourLinesBody =>
      'كل خطوط الأتوبيس والميكروباص والميني باص: رايحة فين وبتقف فين.';

  @override
  String get tourMetroTitle => 'المترو والقطر';

  @override
  String get tourMetroBody => 'خريطة المترو والقطر، والمحطات والأسعار.';

  @override
  String get tourTripsTitle => 'المشاوير';

  @override
  String get tourTripsBody => 'كل مشاويرك، وجايدي وفّرلك قد إيه وقت وفلوس.';

  @override
  String get tourSettingsTitle => 'الإعدادات';

  @override
  String get tourSettingsBody =>
      'اللغة، والوضع الليلي، والوضع البسيط، وحسابك، والشرح ده لو حبيت تشوفه تاني.';

  @override
  String get tourTripNowTitle => 'تعمل إيه دلوقتي';

  @override
  String get tourTripNowBody =>
      'الخطوة اللي انت فيها: تمشي لفين، تركب إيه، وتنزل فين. بتتغير لوحدها وانت ماشي.';

  @override
  String get tourTripLeftTitle => 'الباقي من الخطوة دي';

  @override
  String get tourTripLeftBody =>
      'فاضل قد إيه لحد آخر الخطوة دي وهتاخد قد إيه، وبتتحدّث وانت ماشي. ولو هتركب، الأجرة مكتوبة جنب رقم الخط. اسحب الكارت ده لفوق تشوف كل الخطوات.';

  @override
  String get tourTripToolsTitle => 'أدوات المشوار';

  @override
  String get tourTripToolsBody =>
      'شوف الطريق كله، شارك مشوارك لايف مع أهلك، أو بلّغ عن مشكلة في خط.';

  @override
  String get tourTripButtonsTitle => 'زراير الخريطة';

  @override
  String get tourTripButtonsBody =>
      'رجّع الخريطة للشمال، رجّع الخريطة عندك، وشغّل أو اقفل التنبيه قبل محطتك.';

  @override
  String get tourTripPipTitle => 'اطلع من التطبيق براحتك';

  @override
  String get tourTripPipBody =>
      'على أندرويد المشوار بيكمل في شباك صغير فوق باقي التطبيقات. اسحبه لتحت الشاشة عشان تقفله.';

  @override
  String get settingsReplayTutorial => 'شوف الشرح تاني';

  @override
  String get settingsReplayTutorialSubtitle =>
      'لفّة سريعة على أهم حاجات في جايدي';

  @override
  String get lineCityAlexandria => 'الإسكندرية';

  @override
  String get lineCityIntercity => 'القاهرة ⇄ الإسكندرية';

  @override
  String get commuteNotifsLabel => 'الإشعارات';

  @override
  String get commuteNotifsSubtitle => 'أحسن وقت تمشي فيه، وتنبيه آخر ميعاد';

  @override
  String get commuteNotifsEasier => 'أسهل وقت للمواصلات';

  @override
  String get commuteNotifsLastService => 'تنبيه آخر ميعاد';

  @override
  String get commuteNotifsNeedHomeWork =>
      'احفظ البيت والشغل، وخطط المشوار مرة، عشان توصلك.';

  @override
  String get commuteNotifsBlocked =>
      'الإشعارات مقفولة لـ جايدي على الموبايل ده، فمش هتوصلك.';

  @override
  String get commuteNotifsOpenSettings => 'شغّلها من إعدادات الموبايل';

  @override
  String get commuteChannelName => 'المشوار اليومي';

  @override
  String get commuteChannelDescription =>
      'أسهل وقت لمشوارك من البيت للشغل، وآخر ميعاد لخطوطك.';

  @override
  String commuteLastServiceTitle(String line, String time) {
    return '$line بيقف الساعة $time';
  }

  @override
  String get commuteLastServiceBody =>
      'لسه برة؟ ده آخر ميعاد النهارده لخط في طريق رجوعك للبيت.';

  @override
  String get commuteEasierTitleMorning => 'وقت كويس تنزل الشغل';

  @override
  String get commuteEasierTitleEvening => 'وقت كويس تروّح';

  @override
  String commuteEasierBody(
    String line,
    String every,
    String until,
    String slow,
  ) {
    return '$line بييجي كل $every لحد $until. في باقي الأوقات كل $slow.';
  }

  @override
  String get commuteRushTitleMorning => 'اسبق زحمة الصبح';

  @override
  String commuteRushBodyMorning(String time) {
    return 'انزل قبل $time عشان مشوارك للشغل يبقى أسهل.';
  }

  @override
  String get commuteRushTitleEvening => 'وقت أهدى للرجوع';

  @override
  String commuteRushBodyEvening(String time) {
    return 'الزحمة بتخف دلوقتي، قبل زحمة بالليل الساعة $time.';
  }

  @override
  String actWalkTo(String minutes) {
    return 'امشي $minutes لحد';
  }

  @override
  String get actWaveDownAny => 'شاور لأي واحدة من دول';

  @override
  String actWaveDown(String line) {
    return 'شاور لـ$line في';
  }

  @override
  String get actWaitForAny => 'استنى أي واحدة من دول';

  @override
  String actTakeAt(String action) {
    return '$action من';
  }

  @override
  String get actAskDriverStopAt => 'قول للسواق ينزّلك عند';

  @override
  String get actWaveDownRide => 'شاور لأي عربية';

  @override
  String get actWaitForRide => 'استنى أي عربية';

  @override
  String stepAskDriver(String place) {
    return 'اسأل السواق: رايح $place؟';
  }

  @override
  String get stepWhichMicrobuses => 'أنهي ميكروباصات؟';

  @override
  String get stepWhichBuses => 'أنهي أتوبيسات؟';

  @override
  String get actGetOffAt => 'انزل عند';

  @override
  String actGetOffWalkTo(String minutes) {
    return 'انزل وامشي $minutes لحد';
  }

  @override
  String get actYourDestination => 'المكان اللي رايحه';

  @override
  String get navStepDone => 'خلصت';

  @override
  String get navStepLater => 'بعدين';

  @override
  String get navBackToNow => 'ارجع للخطوة الحالية';

  @override
  String get navPrevStep => 'الخطوة اللي فاتت';

  @override
  String get navNextStep => 'الخطوة الجاية';

  @override
  String get routeDetailsTitle => 'تفاصيل الطريق';

  @override
  String get routeLeave => 'اتحرك';

  @override
  String get routeGetOff => 'انزل';

  @override
  String get routeAskDriverStop => 'قول للسواق يوقف';

  @override
  String get routeArrive => 'توصل';

  @override
  String routeRideFold(String stops) {
    return 'اركب $stops';
  }

  @override
  String routeWalkLeg(String minutes, String distance) {
    return 'مشي $minutes، $distance';
  }

  @override
  String get simpleWhereToGo => 'عايز تروح فين؟';

  @override
  String get simpleGoHome => 'روح البيت';

  @override
  String get simpleGoWork => 'روح الشغل';

  @override
  String get simpleSavedPlaces => 'أماكني المحفوظة';

  @override
  String get simpleMyTrips => 'رحلاتي';

  @override
  String get simpleTapToChoose => 'دوس عشان تختار المكان';

  @override
  String get simpleChangePlace => 'غيّر';

  @override
  String get simpleGoAgain => 'روح تاني';

  @override
  String simpleFrom(String place) {
    return 'من: $place';
  }

  @override
  String get simpleChangeStart => 'غيّر مكان البداية';

  @override
  String get simpleUseMyLocation => 'استخدم مكاني';

  @override
  String get simpleBack => 'رجوع';

  @override
  String get simpleBackHome => 'ارجع للرئيسية';

  @override
  String get simpleRoutesTitle => 'اختار تروح إزاي';

  @override
  String get simpleRoutesHint => 'أسهل الطرق، الأقل تغيير الأول';

  @override
  String simpleOption(int n) {
    return 'اختيار $n';
  }

  @override
  String get simpleEasiest => 'الأسهل';

  @override
  String simpleChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغييرات',
      one: 'تغيير واحد',
      zero: 'من غير تغيير',
    );
    return '$_temp0';
  }

  @override
  String simpleWalkFor(String minutes) {
    return 'امشي $minutes';
  }

  @override
  String simpleTripTotal(String minutes, String fare) {
    return '$minutes، $fare';
  }

  @override
  String get simpleStartTrip => 'ابدأ الرحلة دي';

  @override
  String get simpleNoRoutes => 'ملقيناش طريق. جرّب مكان تاني.';

  @override
  String simpleStepOf(int n, int total) {
    return 'خطوة $n من $total';
  }

  @override
  String simpleWalkTo(String place) {
    return 'امشي لحد $place';
  }

  @override
  String simpleRideTo(String action, String place) {
    return '$action لحد $place';
  }

  @override
  String simpleGetOffAt(String place) {
    return 'انزل في $place';
  }

  @override
  String get simpleWalkOn => 'امشي لحد المكان اللي رايحه';

  @override
  String simpleTellDriver(String place) {
    return 'قول للسواق: “$place”';
  }

  @override
  String get simpleNextStep => 'الخطوة اللي بعدها';

  @override
  String get simpleEndTrip => 'أنهي الرحلة';

  @override
  String get simpleEndTripTitle => 'تنهي الرحلة دي؟';

  @override
  String get simpleEndTripBody =>
      'الإرشادات هتقف. تقدر تبدأ الرحلة تاني من قايمة الطرق.';

  @override
  String get simpleEndTripYes => 'أيوه، أنهي الرحلة';

  @override
  String get simpleKeepGoing => 'لأ، كمّل';

  @override
  String get simpleClearTitle => 'تمسح آخر عمليات البحث؟';

  @override
  String get simpleClearBody =>
      'ده بيمسح القايمة بس. أماكنك المحفوظة هتفضل زي ما هي.';

  @override
  String get simpleClearYes => 'أيوه، امسح';

  @override
  String get simpleSettingsOn => 'الوضع البسيط شغال';

  @override
  String get simpleSettingsOnHint => 'اقفله عشان تشوف كل المميزات تاني.';

  @override
  String get simpleLogOutTitle => 'تسجّل خروج من جايدي؟';

  @override
  String get simpleLogOutBody =>
      'هتحتاج تسجّل دخول تاني عشان تشوف أماكنك ورحلاتك المحفوظة.';

  @override
  String get simpleLogOutYes => 'أيوه، سجّل خروج';

  @override
  String get simpleTurnOff => 'اقفل الوضع البسيط';

  @override
  String get walkReportButton => 'المشي ده غلط';

  @override
  String get walkReportedLabel => 'اتبلّغ عن المشي ده';

  @override
  String get walkReportTitle => 'إيه الغلط في المشي ده؟';

  @override
  String get walkReasonBuildings => 'بيعدّي من جوه مباني';

  @override
  String get walkReasonTooLong => 'طويل أوي';

  @override
  String get walkReasonNoPath => 'الطريق ده مش موجود';

  @override
  String get walkReasonOther => 'حاجة تانية';

  @override
  String get walkReportNote => 'ضيف ملاحظة (اختياري)';

  @override
  String get walkReportSend => 'ابعت البلاغ';

  @override
  String get walkReportThanks => 'شكراً! هنراجع المشي ده.';

  @override
  String get tripSharingLabel => 'شارك مشاويري';

  @override
  String get tripSharingSubtitle =>
      'بيساعد في تصليح الخطوط والطرق المشي الناقصة.';

  @override
  String get tripSharingInfoTooltip => 'بيشارك إيه';

  @override
  String get tripSharingInfoTitle => '«شارك مشاويري» بيعمل إيه';

  @override
  String get tripSharingInfoBody =>
      'وانت ماشي في مشوار على Guidy بس، بيسجّل:\n\n• الطريق اللي ركبته: الخطوط والمحطات، وإمتى وصلت كل خطوة، والـ GPS بتاع موبايلك على الطريق. كده Guidy بيعرف إن أتوبيس أو ميكروباص بقى ماشي في شارع تاني، ويصلّح الخط للكل.\n\n• الطرق اللي بتمشيها في خطوات المشي في المشوار. قبل ما أي حاجة تتبعت، أول وآخر ٥٠ متر من كل مشية بيتشالوا، عشان بيتك وشغلك وأي باب يفضلوا برّه. ده بيلاقي الطرق المشي والعدّايات اللي مش موجودة على الخريطة.\n\nمفيش حاجة بتتسجّل وانت مش ماشي في مشوار. اللي بيتبعت بيتحفظ مع المشوار اللي جه منه، من غير اسمك، وبيتمسح بعد ١٨٠ يوم. لو مسحت حسابك، بيتشال أي حاجة بتربطه بيك.\n\nده شغّال من الأول، زي ما الشروط وسياسة الخصوصية بتقول. تقدر تقفله من هنا في أي وقت: مفيش حاجة تانية هتتسجّل، وأي حاجة لسه ماتبعتتش هتتمسح.';

  @override
  String get tripSharingInfoOk => 'تمام';

  @override
  String get tripShareAskTitle => 'ساعدنا نحسّن جايدي';

  @override
  String get tripShareAskBody =>
      'تشارك مسار الرحلة دي عشان نصلّح خطوط الأتوبيس والطرق الناقصة؟';

  @override
  String get tripShareAskYes => 'أشارك';

  @override
  String get tripShareAskNo => 'مش دلوقتي';

  @override
  String get whatsNewTitle => 'الجديد في جايدي';

  @override
  String get whatsNewOk => 'تمام';

  @override
  String get commuteInfoTooltip => 'عن إشعارات المشوار اليومي';

  @override
  String get commuteInfoTitle => 'إشعارات المشوار اليومي';

  @override
  String get commuteInfoBody =>
      'جايدي بيتابع المشوار بين البيت والشغل اللي حفظتهم، رايح وجاي. احفظ البيت والشغل وخطط المشوار مرة، وجايدي بيفتكر خطوطه وبيدوّر عليها تاني كل أسبوعين.\n\nفيه نوعين تنبيهات، ولكل نوع مفتاحه:\n• أسهل وقت للمواصلات: لما خط من خطوطك يبقى ماشي أكتر من العادة بكتير (الصبح من ٥ لـ ١١، وبعد الضهر من ١ لـ ٩). ولو خطوطك ملهاش مواعيد، بينبهك قبل زحمة الصبح (٧:٠٠) وزحمة المسا (٤:٣٠).\n• تنبيه آخر ميعاد: قبل ما أول خط من خطوطك يخلّص اليوم بـ ٤٥ دقيقة.\n\n٣ تنبيهات في اليوم بالكتير، بينهم ساعة على الأقل، ومفيش يوم الجمعة.\n\nالتنبيهات بتتحسب على موبايلك من مواعيد الخطوط، من غير حساب، ومفيش حاجة عنك بتتبعت عشانها. وبتوصلك حتى لو جايدي مقفول.\n\nعشان توقفها، استخدم المفاتيح تحت \"الإشعارات\": مفتاح لكل نوع، أو المفتاح اللي فوق لكلهم.';

  @override
  String get patchNotesTitle => 'ملاحظات التحديثات';

  @override
  String get patchNotesSubtitle => 'إيه اللي اتغيّر في كل نسخة';

  @override
  String get patchNotesCurrent => 'نسختك';

  @override
  String get removeBannerTitle => 'اخفي البانر لمدة 24 ساعة';

  @override
  String get removeBannerSubtitle =>
      'شوف إعلان قصير. باقي الإعلانات هتفضل ظاهرة.';

  @override
  String removeBannerActive(String time) {
    return 'البانر مخفي لحد $time';
  }

  @override
  String get removeBannerUnavailable =>
      'مفيش إعلان متاح دلوقتي. جرّب تاني بعدين.';

  @override
  String get removeBannerDone => 'تمام. البانر مخفي لمدة 24 ساعة.';

  @override
  String get removeBannerNotWatched =>
      'البانر هيفضل ظاهر: لازم تشوف الإعلان للآخر.';

  @override
  String get currentTripLabel => 'شغالة دلوقتي';

  @override
  String currentTripTitle(String place) {
    return 'رحلتك لحد $place';
  }

  @override
  String tripGoingTo(String place) {
    return 'رايح $place';
  }

  @override
  String currentTripLeft(String minutes) {
    return 'فاضل حوالي $minutes';
  }

  @override
  String get currentTripTap => 'اضغط وكمّل';

  @override
  String get tripChannelName => 'الرحلة الشغالة';

  @override
  String get tripChannelDescription =>
      'الخطوة اللي انت فيها وانت ماشي في رحلتك.';

  @override
  String get tripAlertChannelName => 'تنبيهات المحطة';

  @override
  String get tripAlertChannelDescription => 'تنبيه لما محطتك تقرّب.';

  @override
  String get tripNearTitle => 'جهّز نفسك';

  @override
  String tripNearBody(String place) {
    return 'قرّبت على $place. وقت النزول أو التغيير.';
  }
}
