/// Centralized service for bidirectional English <-> Arabic translation and
/// localization of transit stations, Cairo landmarks, neighborhoods, and sentinels.
class LocationLocalizer {
  // Common sentinels
  static const Map<String, String> _sentinelsEnToAr = {
    'my current location': 'موقعي الحالي',
    'current location': 'موقعي الحالي',
    'origin': 'نقطة الانطلاق',
    'destination': 'الوجهة',
    'home': 'المنزل',
    'work': 'العمل',
    'dropped pin': 'موقع محدد',
  };

  static const Map<String, String> _sentinelsArToEn = {
    'موقعي الحالي': 'My Current Location',
    'الموقع الحالي': 'My Current Location',
    'نقطة الانطلاق': 'Origin',
    'نقطة البداية': 'Origin',
    'الوجهة': 'Destination',
    'نقطة الوصول': 'Destination',
    'المنزل': 'Home',
    'العمل': 'Work',
    'موقع محدد': 'Dropped Pin',
  };

  // Comprehensive Cairo Metro, LRT, and Monorail stations
  static const Map<String, String> _stationsEnToAr = {
    // Line 1
    'helwan': 'حلوان',
    'ain helwan': 'عين حلوان',
    'helwan university': 'جامعة حلوان',
    'wadi hof': 'وادي حوف',
    'hadayek helwan': 'حدائق حلوان',
    'el-maasara': 'المعصرة',
    'el maasara': 'المعصرة',
    'tora el-asmant': 'طرة الأسمنت',
    'tora el asmant': 'طرة الأسمنت',
    'kozzika': 'كوتسيكا',
    'tora el-balad': 'طرة البلد',
    'tora el balad': 'طرة البلد',
    'sakanat el-maadi': 'ثكنات المعادي',
    'sakanat el maadi': 'ثكنات المعادي',
    'maadi': 'المعادي',
    'hadayek el-maadi': 'حدائق المعادي',
    'hadayek el maadi': 'حدائق المعادي',
    'dar el-salam': 'دار السلام',
    'dar el salam': 'دار السلام',
    'el-zahraa': 'الزهراء',
    'el zahraa': 'الزهراء',
    'mar girgis': 'مار جرجس',
    'el-malek el-saleh': 'الملك الصالح',
    'el malek el saleh': 'الملك الصالح',
    'al-sayeda zeinab': 'السيدة زينب',
    'sayeda zeinab': 'السيدة زينب',
    'saad zaghloul': 'سعد زغلول',
    'sadat': 'السادات',
    'gamal abd el-nasser': 'جمال عبد الناصر',
    'gamal abdel nasser': 'جمال عبد الناصر',
    'nasser': 'ناصر',
    'orabi': 'عرابي',
    'al-shohadaa': 'الشهداء',
    'ramses': 'رمسيس',
    'ramses railway': 'رمسيس',
    'ramses central': 'رمسيس',
    'ramses station': 'رمسيس',
    'ghamra': 'غمرة',
    'el-demerdash': 'الدمرداش',
    'el demerdash': 'الدمرداش',
    'manshiet el-sadr': 'منشية الصدر',
    'manshiet el sadr': 'منشية الصدر',
    'kobri el-qobba': 'كوبري القبة',
    'kobri el qobba': 'كوبري القبة',
    'hammamat el-qobba': 'حمامات القبة',
    'hammamat el qobba': 'حمامات القبة',
    'saray el-qobba': 'سراي القبة',
    'saray el qobba': 'سراي القبة',
    'hadayeq el-zaitoun': 'حدائق الزيتون',
    'hadayeq el zaitoun': 'حدائق الزيتون',
    'helmeyat el-zaitoun': 'حلمية الزيتون',
    'helmeyat el zaitoun': 'حلمية الزيتون',
    'matareyya': 'المطرية',
    'ain shams': 'عين شمس',
    'ezbet el-nakhl': 'عزبة النخل',
    'ezbet el nakhl': 'عزبة النخل',
    'el-marg': 'المرج',
    'el marg': 'المرج',
    'new el-marg': 'المرج الجديدة',
    'new el marg': 'المرج الجديدة',

    // Line 2
    'el-mounib': 'المنيب',
    'el mounib': 'المنيب',
    'sakiat mekky': 'ساقية مكي',
    'omm el-masryeen': 'أم المصريين',
    'omm el masryeen': 'أم المصريين',
    'giza': 'الجيزة',
    'faisal': 'فيصل',
    'cairo university': 'جامعة القاهرة',
    'el-bohoth': 'البحوث',
    'el bohoth': 'البحوث',
    'dokki': 'الدقي',
    'opera': 'الأوبرا',
    'mohamed naguib': 'محمد نجيب',
    'attaba': 'العتبة',
    'masarra': 'مسرة',
    'road el-farag': 'روض الفرج',
    'road el farag': 'روض الفرج',
    'st. teresa': 'سانت تريزا',
    'saint teresa': 'سانت تريزا',
    'khalafawy': 'الخلفاوي',
    'mezallat': 'المظلات',
    'kolleyyet el-zeraa': 'كلية الزراعة',
    'kolleyyet el zeraa': 'كلية الزراعة',
    'shubra el-kheima': 'شبرا الخيمة',
    'shubra el kheima': 'شبرا الخيمة',

    // Line 3
    'adly mansour': 'عدلي منصور',
    'el-haykestep': 'الهايكستب',
    'el haykestep': 'الهايكستب',
    'omar ibn el-khattab': 'عمر بن الخطاب',
    'omar ibn el khattab': 'عمر بن الخطاب',
    'qobaa': 'قباء',
    'hesham barakat': 'هشام بركات',
    'el-nozha': 'النزهة',
    'el nozha': 'النزهة',
    'el-shams club': 'نادي الشمس',
    'el shams club': 'نادي الشمس',
    'alf maskan': 'ألف مسكن',
    'heliopolis': 'هليوبوليس',
    'haroun': 'هارون',
    'al-ahram': 'الأهرام',
    'ahram': 'الأهرام',
    'koleyet el-banat': 'كلية البنات',
    'koleyet el banat': 'كلية البنات',
    'stadium': 'الاستاد',
    'fair zone': 'أرض المعارض',
    'abbassiya': 'العباسية',
    'abdou pasha': 'عبده باشا',
    'el-geish': 'الجيش',
    'el geish': 'الجيش',
    'bab el-shaariya': 'باب الشعرية',
    'bab el shaariya': 'باب الشعرية',
    'maspero': 'ماسبيرو',
    'safaa hegazy': 'صفاء حجازي',
    'zamalek': 'الزمالك',
    'kit kat': 'الكيت كات',
    'sudan': 'السودان',
    'imbaba': 'إمبابة',
    'el-bohy': 'البوهي',
    'el bohy': 'البوهي',
    'el-qawmia': 'القومية',
    'el qawmia': 'القومية',
    'ring road': 'الطريق الدائري',
    'rod el-farag corridor': 'محور روض الفرج',
    'rod el farag corridor': 'محور روض الفرج',
    'tawfikia': 'التوفيقية',
    'wadi el-nile': 'وادي النيل',
    'wadi el nile': 'وادي النيل',
    'gamaat el-dowal': 'جامعة الدول',
    'gamaat el dowal': 'جامعة الدول',

    // LRT & Monorail
    'badr': 'بدر',
    'el-shorouk': 'الشروق',
    'el shorouk': 'الشروق',
    'new heliopolis': 'هليوبوليس الجديدة',
    'al-mostaqbal': 'المستقبل',
    'mostaqbal': 'المستقبل',
    'capital airport': 'مطار العاصمة',
    'arts and culture city': 'مدينة الفنون والثقافة',
    'new administrative capital': 'العاصمة الإدارية الجديدة',
    'field marshal tantawy': 'المشير طنطاوي',
    'one ninety': 'ون ناينتي',
    'air force hospital': 'المستشفى الجوي',
    'american university in cairo': 'الجامعة الأمريكية',
    'auc': 'الجامعة الأمريكية',
    'beit al watan': 'بيت الوطن',
  };

  // Common landmarks & Cairo districts
  static const Map<String, String> _landmarksEnToAr = {
    'tahrir square': 'ميدان التحرير',
    'tahrir': 'التحرير',
    'cairo airport': 'مطار القاهرة',
    'cairo international airport': 'مطار القاهرة الدولي',
    'smart village': 'القرية الذكية',
    'mall of arabia': 'مول العرب',
    'mall of egypt': 'مول مصر',
    'cairo festival city': 'كايرو فيستيفال سيتي',
    'citystars': 'سيتي ستارز',
    'baron palace': 'قصر البارون',
    'cairo tower': 'برج القاهرة',
    'egyptian museum': 'المتحف المصري',
    'grand egyptian museum': 'المتحف المصري الكبير',
    'national museum of egyptian civilization': 'متحف الحضارة المصرية',
    'al-azhar mosque': 'جامع الأزهر',
    'azhar mosque': 'جامع الأزهر',
    'khan el-khalili': 'خان الخليلي',
    'khan el khalili': 'خان الخليلي',
    'citadel': 'القلعة',
    'saladin citadel': 'قلعة صلاح الدين',
    'giza pyramids': 'أهرامات الجيزة',
    'pyramids': 'الأهرامات',
    'sphinx': 'أبو الهول',
    'nasr city': 'مدينة نصر',
    'masr el-gedida': 'مصر الجديدة',
    'masr el gedida': 'مصر الجديدة',
    'downtown': 'وسط البلد',
    'downtown cairo': 'وسط البلد',
    'mohandessin': 'المهندسين',
    'tagamoa': 'التجمع',
    'new cairo': 'القاهرة الجديدة',
    '5th settlement': 'التجمع الخامس',
    'fifth settlement': 'التجمع الخامس',
    '1st settlement': 'التجمع الأول',
    'first settlement': 'التجمع الأول',
    '6th of october': 'السادس من أكتوبر',
    '6th of october city': 'مدينة السادس من أكتوبر',
    'sheikh zayed': 'الشيخ زايد',
    'rehab': 'الرحاب',
    'al-rehab': 'الرحاب',
    'madinaty': 'مدينتي',
    'shorouk': 'الشروق',
    'obour': 'العبور',
    'mokattam': 'المقطم',
    'maadi degla': 'دجلة المعادي',
    'new giza': 'نيو جيزة',
  };

  // Inverted reverse lookup maps (Arabic -> English)
  static final Map<String, String> _stationsArToEn = _invertMap(_stationsEnToAr);
  static final Map<String, String> _landmarksArToEn = _invertMap(_landmarksEnToAr);

  // Pre-normalized maps for resilient matching
  static final Map<String, String> _normStationsEnToAr = {
    for (final entry in _stationsEnToAr.entries) _normalize(entry.key): entry.value,
  };
  static final Map<String, String> _normLandmarksEnToAr = {
    for (final entry in _landmarksEnToAr.entries) _normalize(entry.key): entry.value,
  };
  static final Map<String, String> _normStationsArToEn = {
    for (final entry in _stationsArToEn.entries) _normalize(entry.key): entry.value,
  };
  static final Map<String, String> _normLandmarksArToEn = {
    for (final entry in _landmarksArToEn.entries) _normalize(entry.key): entry.value,
  };

  static Map<String, String> _invertMap(Map<String, String> map) {
    final inverted = <String, String>{};
    for (final entry in map.entries) {
      // Avoid overwriting a cleaner/shorter title with an alias
      if (!inverted.containsKey(entry.value)) {
        inverted[entry.value] = _capitalizeWords(entry.key);
      }
    }
    return inverted;
  }

  static String _capitalizeWords(String str) {
    return str.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word.contains('-')) {
        return word.split('-').map((sub) {
          if (sub.isEmpty) return sub;
          return sub[0].toUpperCase() + sub.substring(1);
        }).join('-');
      }
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  /// Returns true if the string consists solely of digits, punctuation, or bare house numbers (e.g. "17", "١٧", "12A").
  static bool isBareNumber(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return false;
    return RegExp(r'^[\d\u0660-\u0669]+([\s\-\/]?[A-Za-z\u0621-\u064A])?$').hasMatch(clean);
  }

  /// Normalizes a name for matching (lowercased, trimmed, hyphens replaced with spaces, strips 'station' / 'metro' / 'terminal' / 'محطة' / 'مترو').
  static String _normalize(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'\b(station|metro|terminal)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'(محطة|مترو)'), '')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Translates and localizes a location name dynamically based on [isArabic].
  /// If [nameAr] or [nameEn] are available, they are preferred.
  static String localize(
    String name, {
    required bool isArabic,
    String? nameAr,
    String? nameEn,
    double? lat,
    double? lon,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;

    // 1. If explicit bilingual fields were stored with the trip
    if (isArabic && nameAr != null && nameAr.trim().isNotEmpty) {
      return nameAr.trim();
    }
    if (!isArabic && nameEn != null && nameEn.trim().isNotEmpty) {
      return nameEn.trim();
    }

    final lower = trimmed.toLowerCase();

    // 2. Sentinels
    if (isArabic) {
      if (_sentinelsEnToAr.containsKey(lower)) {
        return _sentinelsEnToAr[lower]!;
      }
      if (_sentinelsArToEn.containsKey(trimmed)) {
        return trimmed;
      }
    } else {
      if (_sentinelsArToEn.containsKey(trimmed)) {
        return _sentinelsArToEn[trimmed]!;
      }
      if (_sentinelsEnToAr.containsKey(lower)) {
        return _sentinelsArToEn[_sentinelsEnToAr[lower]] ?? trimmed;
      }
    }

    // 3. Station / Landmark direct match
    final norm = _normalize(trimmed);

    if (isArabic) {
      // English -> Arabic lookup
      if (_normStationsEnToAr.containsKey(norm)) {
        final stationName = _normStationsEnToAr[norm]!;
        return trimmed.toLowerCase().contains('station') ? 'محطة $stationName' : stationName;
      }
      if (_normLandmarksEnToAr.containsKey(norm)) {
        return _normLandmarksEnToAr[norm]!;
      }
      // Affix translation if English
      if (trimmed.toLowerCase().startsWith('station ')) {
        final rest = trimmed.substring(8).trim();
        final restAr = localize(rest, isArabic: true);
        return 'محطة $restAr';
      }
      if (trimmed.toLowerCase().endsWith(' station')) {
        final rest = trimmed.substring(0, trimmed.length - 8).trim();
        final restAr = localize(rest, isArabic: true);
        return 'محطة $restAr';
      }
      if (trimmed.toLowerCase().startsWith('square ')) {
        final rest = trimmed.substring(7).trim();
        final restAr = localize(rest, isArabic: true);
        return 'ميدان $restAr';
      }
      if (trimmed.toLowerCase().endsWith(' square')) {
        final rest = trimmed.substring(0, trimmed.length - 7).trim();
        final restAr = localize(rest, isArabic: true);
        return 'ميدان $restAr';
      }
    } else {
      // Arabic -> English lookup
      if (_normStationsArToEn.containsKey(norm)) {
        final stationName = _normStationsArToEn[norm]!;
        return trimmed.contains('محطة') ? '$stationName Station' : stationName;
      }
      if (_normLandmarksArToEn.containsKey(norm)) {
        return _normLandmarksArToEn[norm]!;
      }
      // Affix translation if Arabic
      if (trimmed.startsWith('محطة ')) {
        final rest = trimmed.substring(5).trim();
        final restEn = localize(rest, isArabic: false);
        return '$restEn Station';
      }
      if (trimmed.startsWith('ميدان ')) {
        final rest = trimmed.substring(6).trim();
        final restEn = localize(rest, isArabic: false);
        return '$restEn Square';
      }
      if (trimmed.startsWith('شارع ')) {
        final rest = trimmed.substring(5).trim();
        final restEn = localize(rest, isArabic: false);
        return '$restEn St';
      }
      if (trimmed.startsWith('طريق ')) {
        final rest = trimmed.substring(5).trim();
        final restEn = localize(rest, isArabic: false);
        return '$restEn Rd';
      }
      if (trimmed.startsWith('محور ')) {
        final rest = trimmed.substring(5).trim();
        final restEn = localize(rest, isArabic: false);
        return '$restEn Corridor';
      }
      if (trimmed.startsWith('كوبري ')) {
        final rest = trimmed.substring(6).trim();
        final restEn = localize(rest, isArabic: false);
        return '$restEn Bridge';
      }
    }

    return trimmed;
  }

  /// Generates both English and Arabic versions of a location name.
  static Map<String, String> bilingual(String name, {double? lat, double? lon}) {
    final ar = localize(name, isArabic: true, lat: lat, lon: lon);
    final en = localize(name, isArabic: false, lat: lat, lon: lon);
    return {'ar': ar, 'en': en};
  }
}
