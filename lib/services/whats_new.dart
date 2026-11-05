import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One release's "What's new" notes.
class WhatsNewEntry {
  const WhatsNewEntry({
    required this.build,
    required this.version,
    required this.date,
    required this.en,
    required this.ar,
    this.popup = true,
  });

  /// The build number (pubspec `+N`) that first ships these notes.
  final int build;

  /// The version name shown beside it ("1.1.0").
  final String version;

  /// The day it was released, `yyyy-mm-dd`.
  final String date;
  final List<String> en;
  final List<String> ar;

  /// False for history-only entries (older releases listed in Settings'
  /// patch notes): they never pop up, whatever build a rider comes from.
  final bool popup;

  /// Every note, in the rider's language (the patch notes page).
  List<String> notesFor(String localeName) => localeName.startsWith('ar') ? ar : en;

  /// The first few, for the one-time popup, which stays short.
  List<String> popupNotesFor(String localeName) => notesFor(localeName).take(WhatsNew.popupMaxNotes).toList();
}

/// The popup a rider sees once after updating the app.
///
/// To announce a release, add an entry at the TOP of [entries] with the
/// build number `build_release.ps1` will give it. Riders who skipped
/// releases see only the newest entry. A fresh install sees nothing (it gets
/// the welcome tour), just remembers the build it started on.
class WhatsNew {
  static const String _seenKey = 'whats_new_seen_build';

  /// The popup shows at most this many notes; the patch notes page all.
  static const int popupMaxNotes = 5;

  /// Newest first. History-only entries (`popup: false`) are older
  /// releases, listed in Settings' patch notes and never shown as a popup.
  static const List<WhatsNewEntry> entries = [
    WhatsNewEntry(
      build: 30,
      version: '1.2.1',
      date: '2026-11-03',
      en: [
        'Route cards show how far you walk and which line to take, like "Minibus 66".',
        'Less text on the trip screen, so you see more of the map.',
        'Know a better route? Tell us, or build it yourself from the transport network.',
        'Stop alerts come only while you ride, never while you walk.',
        'A bigger, steadier arrow on the map, and the map no longer spins as you walk.',
        'Long trips show hours and minutes, like "1 h 18 min".',
        'Each ride shows its fare next to the line number.',
        'A walk step moves on as soon as you reach the stop.',
      ],
      ar: [
        'كروت الطرق بقت بتقولك هتمشي قد إيه وتركب أنهي خط، زي «ميني باص 66».',
        'كلام أقل في شاشة المشوار، عشان تشوف الخريطة أكتر.',
        'تعرف طريق أحسن؟ قولنا عليه، أو ابنيه بنفسك من شبكة المواصلات.',
        'تنبيه النزول بييجي وإنت راكب بس، مش وإنت ماشي.',
        'سهم أكبر وأثبت على الخريطة، والخريطة مبقتش بتلف وإنت ماشي.',
        'المشاوير الطويلة بتتكتب بالساعات والدقايق، زي «ساعة و18 دقيقة».',
        'أجرة كل ركوبة جنب رقم الخط.',
        'خطوة المشي بتخلص أول ما توصل المحطة.',
      ],
    ),
    WhatsNewEntry(
      build: 29,
      version: '1.2.0',
      date: '2026-10-31',
      en: [
        'Your current trip now stays on Home and comes back after you close the app.',
        'Phone notifications for your current step and just before your stop.',
        'New "End trip" button at the bottom of the trip sheet.',
        'More accurate routes and fares.',
        'Guidy asks about notifications once, the first time you open it. You can change it any time from Settings > Notifications.',
        'Simple Mode now lives only in Settings.',
        'Prefer no banner? Watch a short ad to hide it for 24 hours.',
        'Smoother Arabic and a more polished dark mode.',
        'Fixes: the tour highlight sits in the right place, the status bar is readable in light mode, the Trips title, and colours that were off.',
        'Alexandria bus names no longer start with "APTA".',
        'Privacy: analytics follows your choice, and Guidy asks before sharing a trip.',
      ],
      ar: [
        'مشوارك الحالي بقى فاضل في الرئيسية وبيرجعلك حتى بعد ما تقفل التطبيق.',
        'إشعارات على موبايلك بالخطوة اللي إنت فيها وقبل محطتك بشوية.',
        'زرار جديد «إنهاء المشوار» تحت ورقة المشوار.',
        'طرق وأجرة أدق.',
        'جايدي بيسألك عن الإشعارات مرة واحدة أول ما تفتحه، وتقدر تغيّرها في أي وقت من الإعدادات > الإشعارات.',
        'الوضع البسيط بقى في الإعدادات بس.',
        'مش عايز البانر؟ شوف إعلان قصير واخفيه ٢٤ ساعة.',
        'عربي أنعم ووضع داكن أحلى.',
        'إصلاحات: تظبيط مكان تمييز الجولة، وشريط الحالة بقى واضح في الوضع الفاتح، وعنوان «رحلاتي»، وألوان كانت مش مظبوطة.',
        'أسماء أتوبيسات إسكندرية مبقتش بتبدأ بـ«APTA».',
        'الخصوصية: التحليلات بتمشي على اختيارك، وجايدي بيسألك قبل ما تشارك مشوارك.',
      ],
    ),
    WhatsNewEntry(
      build: 28,
      version: '1.1.0',
      date: '2026-10-27',
      en: [
        'Nothing hides behind your phone\'s back and home buttons any more.',
        'The trip fare now stands out next to the time on every route.',
        'Simple Mode marks the Fastest, Cheapest and Recommended routes, with a big time and fare.',
        'New "Previous step" button while you follow a trip.',
        'A bigger "Where to?" button on Home.',
        'Clearer wording: "Take a microbus", "Ride the metro".',
        'Commute alerts: shorter text, an info button, and tested to arrive even when Guidy is closed.',
        'Patch notes in Settings: see what changed in every version.',
        'Home and Work shortcuts offer to open your phone settings when location is blocked for Guidy.',
        'The metro station sheet is easier to read in dark mode, and spacing in Arabic is smoother.',
      ],
      ar: [
        'مفيش حاجة بقت بتستخبى ورا زراير الرجوع والهوم في موبايلك.',
        'أجرة المشوار بقت باينة جنب الوقت في كل طريق.',
        'الوضع البسيط بقى بيعلّم الأسرع والأرخص والمُوصى بيه، وبيعرض الوقت والأجرة بخط كبير.',
        'زرار جديد «الخطوة اللي فاتت» وإنت ماشي في المشوار.',
        'زرار «رايح فين؟» بقى أكبر في الرئيسية.',
        'صياغة أوضح: «اركب ميكروباص»، «اركب المترو».',
        'تنبيهات المشوار اليومي: كلام أقصر وزرار معلومات، واتجربت إنها توصلك حتى لو جايدي مقفول.',
        'ملاحظات التحديثات في الإعدادات: شوف إيه اللي اتغيّر في كل نسخة.',
        'اختصارات البيت والشغل بتفتحلك إعدادات الموبايل لو اللوكيشن مقفول على جايدي.',
        'شاشة محطة المترو أوضح في الوضع الداكن، والمسافات في العربي أظبط.',
      ],
    ),
    WhatsNewEntry(
      build: 27,
      version: '1.1.0',
      date: '2026-10-27',
      popup: false,
      en: [
        'Dark mode: the white strip at the bottom of the screen is gone; the navigation bar now matches the app.',
        'Stability and performance improvements.',
      ],
      ar: [
        'الوضع الداكن: الشريط الأبيض اللي كان تحت الشاشة اختفى، وشريط التنقل بقى بنفس لون التطبيق.',
        'تحسينات في الثبات والأداء.',
      ],
    ),
    WhatsNewEntry(
      build: 26,
      version: '1.1.0',
      date: '2026-10-24',
      en: [
        'Metro steps name the line the way you say it: "Line 2", "Line 3".',
        'The direction arrow keeps following your phone after you minimise a trip.',
        'After each update you\'ll see what\'s new here.',
      ],
      ar: [
        'خطوات المترو بقت بتقول "الخط التاني" و"الخط التالت" زي ما بنقولها.',
        'سهم الاتجاه بقى بيفضل ماشي مع الموبايل بعد ما تصغّر الرحلة.',
        'بعد كل تحديث هتلاقي الجديد هنا.',
      ],
    ),
    WhatsNewEntry(
      build: 25,
      version: '1.1.0',
      date: '2026-10-22',
      popup: false,
      en: [
        'Every line keeps its colour everywhere: metro Line 3 is green on the card, the map and during your trip.',
        'Search shows places in your city first, named in your language.',
        'Bus chips say AC or double-decker.',
        'Routes with a long walk say so.',
        'Walking times between stops are more accurate.',
        '"We don\'t cover this trip yet" instead of an error.',
        'Delete your data from Simple Mode too.',
      ],
      ar: [
        'كل خط بقى ليه لون واحد في كل حتة: الخط التالت للمترو أخضر في الكارت والخريطة وإنت ماشي.',
        'البحث بيوريك أماكن مدينتك الأول وبلغتك.',
        'الأتوبيسات بتقول مكيف أو دبل ديكر.',
        'الطرق اللي فيها مشي كتير بتقولك.',
        'أوقات المشي بين المحطات بقت أدق.',
        '«لسه مش بنغطي المشوار ده» بدل رسالة الخطأ.',
        'تقدر تمسح بياناتك من الوضع البسيط كمان.',
      ],
    ),
    WhatsNewEntry(
      build: 24,
      version: '1.1.0',
      date: '2026-10-22',
      popup: false,
      en: [
        'Simple Mode, rebuilt for seniors: one clear path, big buttons, one step at a time.',
        'The banner ad moved to the top, away from your phone\'s buttons.',
        'Alexandria-only Lines view.',
        'No more long walking loops for short walks.',
        'Commute alerts now ask for permission, and tell you if notifications are off.',
        'One "Share my trips" setting, with an info button.',
        'Tell us when a walk is wrong.',
      ],
      ar: [
        'الوضع البسيط اتعمل من جديد لكبار السن: طريق واحد واضح، زراير كبيرة، وخطوة خطوة.',
        'الإعلان بقى فوق، بعيد عن زراير الموبايل.',
        'صفحة خطوط إسكندرية لوحدها.',
        'مفيش لفّ طويل في المشي للمسافات القصيرة.',
        'تنبيهات المشوار بتطلب الإذن، وبتقولك لو الإشعارات مقفولة.',
        'إعداد واحد «شارك مشاويري» وجنبه زرار معلومات.',
        'قولّنا لو المشي غلط.',
      ],
    ),
    WhatsNewEntry(
      build: 22,
      version: '1.1.0',
      date: '2026-10-21',
      popup: false,
      en: [
        'Route Options redesigned: compact cards, and a detail page with every line and every stop.',
        'Commute alerts tell you when your usual trip is easiest and when the last ride leaves.',
        'Microbuses tell you what to ask the driver.',
        'The familiar trip screen is back, and every vehicle you can take is always shown.',
        'Alexandria picks microbuses first, since buses wait until full.',
        'Bigger search bar, exact fares and Arabic fixes.',
      ],
      ar: [
        'شكل جديد لاختيار المسار: كروت مختصرة وصفحة تفاصيل فيها كل الخطوط وكل المحطات.',
        'تنبيهات المشوار بتقولك إمتى أسهل وقت لمشوارك وإمتى آخر عربية.',
        'الميكروباص بيقولك تسأل السواق على إيه.',
        'شاشة الرحلة القديمة رجعت، وكل العربيات اللي تنفعك ظاهرة دايماً.',
        'إسكندرية بترشح الميكروباص الأول، لأن الأتوبيس بيستنى لما يتملي.',
        'شريط بحث أكبر، وأجرة مظبوطة، وتصليحات في العربي.',
      ],
    ),
    WhatsNewEntry(
      build: 18,
      version: '1.0.11',
      date: '2026-10-14',
      popup: false,
      en: [
        'Board a microbus, minibus or bus wherever it passes, not just at stops, and get off where you ask (not on bridges or highways).',
        'Each step lists every line you can take, most frequent first, best ones highlighted.',
        'Change vehicles where two routes cross instead of walking between stops.',
        'No more 4+ vehicle trips that barely save time.',
        'Better Alexandria routes, with fewer waits for full buses.',
        'New icon that fits every phone.',
      ],
      ar: [
        'اركب الميكروباص أو الميني باص أو الأتوبيس في أي حتة بيعدي منها، مش بس عند المواقف، وانزل في المكان اللي تطلبه (مش على الكباري أو الطرق السريعة).',
        'كل خطوة بتعرض كل الخطوط اللي تنفعك، الأكتر مرور الأول، والأحسن متعلّم.',
        'غيّر العربية في المكان اللي بيتقاطع فيه خطين بدل ما تمشي بين المواقف.',
        'مفيش رحلات بـ٤ عربيات أو أكتر وفرقها في الوقت بسيط.',
        'مسارات إسكندرية أحسن، واستنى أقل لحد ما الأتوبيس يتملي.',
        'أيقونة جديدة بتناسب كل الموبايلات.',
      ],
    ),
    WhatsNewEntry(
      build: 12,
      version: '1.0.11',
      date: '2026-10-08',
      popup: false,
      en: [
        '14 more Alexandria microbus lines, including Borg El-Arab, Abu Qir and Abu Talat.',
        'New Alexandria filter in the Lines tab.',
        'Alexandria buses show APTA\'s official prices; microbus fares follow distance (for example 5 to 22 EGP).',
        'Trip tools now sit in one row, and the step card stays visible above the ad.',
        'Walking routes and recommendations now follow real sidewalks and roads around gated compounds and neighborhood perimeters.',
        'Fixes: the Location Accuracy prompt no longer repeats, the Metro title overlap, "1 change", and a faster Trips tab.',
      ],
      ar: [
        '14 خط ميكروباص جديد في إسكندرية، منهم برج العرب وأبو قير وأبو تلات.',
        'فلتر جديد لخطوط إسكندرية في شاشة الخطوط.',
        'أتوبيسات إسكندرية بأسعار هيئة النقل العام الرسمية، وأجرة الميكروباص على حسب المسافة (زي 5 لـ 22 ج.م).',
        'أدوات الرحلة بقت في صف واحد، وكارت الخطوة بيفضل ظاهر فوق الإعلان.',
        'مسارات المشي والترشيحات بتتبع الشوارع والأرصفة الحقيقية حوالين الكمبوندات والمناطق المقفولة.',
        'إصلاحات: رسالة دقة الموقع مبقتش تتكرر، وتداخل عنوان المترو، وكلمة "1 تغيير"، وشاشة الرحلات أسرع.',
      ],
    ),
    WhatsNewEntry(
      build: 11,
      version: '1.0.10',
      date: '2026-10-07',
      popup: false,
      en: [
        'Plan trips inside Alexandria: APTA buses, microbuses, minibuses and tomnaya.',
        'Travel between Cairo/Giza and Alexandria by intercity microbus (from Aboud, Ramses and Moneeb).',
        'Place search finds places near you, in either city.',
        'Lines screen marks Alexandria and intercity lines, and shows their real fares.',
      ],
      ar: [
        'خطط مشاويرك جوه إسكندرية: أتوبيسات هيئة النقل العام، ميكروباصات، ميني باصات وتمناية.',
        'سافر بين القاهرة/الجيزة وإسكندرية بالميكروباص من عبود ورمسيس والمنيب.',
        'البحث عن الأماكن بيلاقي الأماكن اللي جنبك في أي مدينة.',
        'شاشة الخطوط بتميّز خطوط إسكندرية والسفر، وبتعرض أجرتها الحقيقية.',
      ],
    ),
  ];

  /// The entry to show, or null. [seenBuild]: the build this rider last
  /// opened (null before this feature existed, or on a fresh install).
  static WhatsNewEntry? pick({required int? seenBuild, required int currentBuild, required bool freshInstall}) {
    if (seenBuild == null && freshInstall) return null;
    for (final e in entries) {
      if (!e.popup) continue;
      if (e.build <= currentBuild && (seenBuild == null || e.build > seenBuild)) return e;
    }
    return null;
  }

  /// Decides, and records the current build as seen so it shows only once.
  /// Never throws: a popup is not worth holding up the tour or the app.
  static Future<WhatsNewEntry?> takeForLaunch({required bool freshInstall}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber);
      if (current == null) return null;
      final seen = prefs.getInt(_seenKey);
      if (seen != null && seen >= current) return null;
      await prefs.setInt(_seenKey, current);
      return pick(seenBuild: seen, currentBuild: current, freshInstall: freshInstall);
    } catch (_) {
      return null;
    }
  }
}
