import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show TemplateType;
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';
import '../services/map_marker_service.dart';
import '../widgets/metro_report_sheet.dart';
import '../widgets/native_ad_card.dart';

/// Interactive map and diagram of Greater Cairo's rapid transit rail network:
/// - Metro Line 1 (Helwan <-> New El Marg)
/// - Metro Line 2 (Shubra El Kheima <-> El Mounib)
/// - Metro Line 3 (Rod El Farag / Cairo Univ <-> Adly Mansour)
/// - Monorail East Nile (Cairo Stadium <-> New Administrative Capital)
/// - LRT Capital Train (Adly Mansour <-> City of Arts & Culture / Knowledge City)
class RailNetworkMapScreen extends StatefulWidget {
  /// false in widget tests, where the platform map view can't render.
  final bool showMap;

  const RailNetworkMapScreen({
    super.key,
    this.showMap = true,
  });

  @override
  State<RailNetworkMapScreen> createState() => _RailNetworkMapScreenState();
}

class _RailMapStation {
  final String name;
  final String nameEn;
  final LatLng position;
  final List<String> lines;
  final bool isInterchange;

  const _RailMapStation({
    required this.name,
    required this.nameEn,
    required this.position,
    required this.lines,
    this.isInterchange = false,
  });
}

/// Keeps a [TabBarView] page in the tree while another tab is showing.
class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _RailNetworkMapScreenState extends State<RailNetworkMapScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GoogleMapController? _googleMapController;
  String? _selectedStation;
  String? _selectedLine;
  String _searchQuery = '';

  // Line colours from GuidyModeStyle, as on every card and map.
  static final List<Map<String, dynamic>> _lines = [
    {
      'id': 'L1',
      'nameAr': 'الخط الأول (المرج - حلوان)',
      'nameEn': 'Line 1 (Helwan - New El Marg)',
      'color': GuidyModeStyle.metroLine('1')!,
      'stations': [
        'حلوان', 'عين حلوان', 'جامعة حلوان', 'وادي حوف', 'حدائق حلوان', 'المعصرة', 'طرة الأسمنت', 'كوتسيكا', 'طرة البلد', 'ثكنات المعادي', 'المعادي', 'حدائق المعادي', 'دار السلام', 'الزهراء', 'مار جرجس', 'الملك الصالح', 'السيدة زينب', 'سعد زغلول', 'السادات', 'جمال عبد الناصر', 'أحمد عرابي', 'الشهداء', 'غمرة', 'الدمرداش', 'منشية الصدر', 'كوبري القبة', 'حمامات القبة', 'سراي القبة', 'حدائق الزيتون', 'حلمية الزيتون', 'المطرية', 'عين شمس', 'عزبة النخل', 'المرج', 'المرج الجديدة'
      ],
    },
    {
      'id': 'L2',
      'nameAr': 'الخط الثاني (شبرا الخيمة - المنيب)',
      'nameEn': 'Line 2 (Shubra - El Mounib)',
      'color': GuidyModeStyle.metroLine('2')!,
      'stations': [
        'شبرا الخيمة', 'كلية الزراعة', 'المظلات', 'الخلفاوي', 'سانت تريزا', 'روض الفرج', 'مسرة', 'الشهداء', 'العتبة', 'محمد نجيب', 'السادات', 'الأوبرا', 'الدقي', 'البحوث', 'جامعة القاهرة', 'فيصل', 'الجيزة', 'أم المصريين', 'ساقية مكي', 'المنيب'
      ],
    },
    {
      'id': 'L3',
      'nameAr': 'الخط الثالث (عدلي منصور - روض الفرج / جامعة القاهرة)',
      'nameEn': 'Line 3 (Adly Mansour - Rod El Farag / Cairo Univ)',
      'color': GuidyModeStyle.metroLine('3')!,
      'stations': [
        'عدلي منصور', 'الهايكستب', 'عمر بن الخطاب', 'قباء', 'هشام بركات', 'النزهة', 'نادي الشمس', 'ألف مسكن', 'ميدان هليوبوليس', 'هارون', 'الأهرام', 'كلية البنات', 'استاد القاهرة', 'أرض المعارض', 'العباسية', 'عبده باشا', 'الجيش', 'باب الشعرية', 'العتبة', 'جمال عبد الناصر', 'ماسبيرو', 'صفاء حجازي', 'الكيت كات', 'السودان', 'إمبابة', 'البوهي', 'القومية العربية', 'الطريق الدائري', 'محور روض الفرج', 'التوفيقية', 'وادي النيل', 'جامعة الدول', 'بولاق الدكرور', 'جامعة القاهرة'
      ],
    },
    {
      'id': 'MONORAIL',
      'nameAr': 'مونوريل شرق النيل (الاستاد - مدينة العدالة)',
      'nameEn': 'East Nile Monorail (Stadium - Justice City)',
      'color': GuidyModeStyle.color('monorail'),
      'stations': [
        'استاد القاهرة', 'هشام بركات', 'جامعة الازهر', 'الحي السابع', 'المشير احمد اسماعيل', 'جيهان السادات', 'المشير طنطاوي', 'وان ناينتي', 'مستشفى القوات الجوية', 'النرجس', 'المستثمرين', 'اللوتس', 'جولدن سكوير', 'بيت الوطن', 'مسجد الفتاح العليم', 'الحي R1', 'الحي R2', 'حي المال والاعمال', 'مدينة الفنون والثقافة', 'الحي الحكومي', 'مسجد مصر', 'مدينة العدالة'
      ],
    },
    {
      'id': 'LRT',
      'nameAr': 'القطار الكهربائي الخفيف (عدلي منصور - الفنون والثقافة / مدينة المعرفة)',
      'nameEn': 'LRT Capital Train (Adly Mansour - Arts & Culture / Knowledge City)',
      'color': GuidyModeStyle.color('lrt'),
      'stations': [
        'عدلي منصور', 'العبور', 'المستقبل', 'الشروق', 'نيو هليوبوليس', 'بدر', 'الروبيكي', 'حدائق العاصمة', 'مطار العاصمة', 'مدينة الفنون والثقافة', 'المنطقة الصناعية', 'مدينة المعرفة'
      ],
    },
  ];

  static const Map<String, List<List<LatLng>>> _lineCoordsMap = {
    'L1': [
      [
        LatLng(29.84882, 31.33425), // Helwan
        LatLng(29.86260, 31.32503), // Ain Helwan
        LatLng(29.86904, 31.32009), // Helwan University
        LatLng(29.87905, 31.31344), // Wadi Hof
        LatLng(29.89719, 31.30404), // Hadayek Helwan
        LatLng(29.90636, 31.29953), // El-Maasara
        LatLng(29.92597, 31.28755), // Tora El-Asmant
        LatLng(29.93645, 31.28142), // Kozzika
        LatLng(29.94672, 31.27288), // Tora El-Balad
        LatLng(29.95331, 31.26296), // Sakanat El-Maadi
        LatLng(29.96030, 31.25773), // Maadi
        LatLng(29.96978, 31.25083), // Hadayek El-Maadi
        LatLng(29.98199, 31.24204), // Dar El-Salam
        LatLng(29.99554, 31.23123), // El-Zahraa
        LatLng(30.00617, 31.22958), // Mar Girgis
        LatLng(30.01772, 31.23118), // El-Malek El-Saleh
        LatLng(30.02924, 31.23543), // Al-Sayeda Zeinab
        LatLng(30.03567, 31.23782), // Saad Zaghloul
        LatLng(30.04392, 31.23566), // Sadat
        LatLng(30.05346, 31.23865), // Nasser
        LatLng(30.05703, 31.24231), // Orabi
        LatLng(30.06164, 31.24629), // Al-Shohadaa
        LatLng(30.06819, 31.26400), // Ghamra
        LatLng(30.07719, 31.27786), // El-Demerdash
        LatLng(30.08198, 31.28755), // Manshiet El-Sadr
        LatLng(30.08720, 31.29413), // Kobri El-Qobba
        LatLng(30.09119, 31.29901), // Hammamat El-Qobba
        LatLng(30.09772, 31.30447), // Saray El-Qobba
        LatLng(30.10596, 31.31040), // Hadayeq El-Zaitoun
        LatLng(30.11325, 31.31400), // Helmeyet El-Zaitoun
        LatLng(30.12090, 31.31373), // El-Matareyya
        LatLng(30.13100, 31.31912), // Ain Shams
        LatLng(30.13922, 31.32462), // Ezbet El-Nakhl
        LatLng(30.15211, 31.33581), // El-Marg
        LatLng(30.16355, 31.33834), // New El-Marg
      ],
    ],
    'L2': [
      [
        LatLng(30.12251, 31.24469), // Shubra El-Kheima
        LatLng(30.11366, 31.24875), // Kolleyyet El-Zeraa
        LatLng(30.10407, 31.24557), // Mezallat
        LatLng(30.09785, 31.24500), // Khalafawy
        LatLng(30.08796, 31.24549), // St. Teresa
        LatLng(30.08059, 31.24540), // Rod El Farag
        LatLng(30.07090, 31.24510), // Masarra
        LatLng(30.06164, 31.24629), // Al-Shohadaa
        LatLng(30.05235, 31.24680), // Attaba
        LatLng(30.04534, 31.24415), // Mohamed Naguib
        LatLng(30.04392, 31.23566), // Sadat
        LatLng(30.04193, 31.22499), // Opera
        LatLng(30.03739, 31.21133), // Dokki
        LatLng(30.03584, 31.20025), // Bohooth
        LatLng(30.02615, 31.20087), // Cairo University
        LatLng(30.01749, 31.20375), // Faisal
        LatLng(30.01066, 31.20705), // El-Giza
        LatLng(30.00599, 31.20813), // Omm El-Misryeen
        LatLng(29.99557, 31.20849), // Sakiat Mekki
        LatLng(29.98103, 31.21231), // El-Mounib
      ],
    ],
    'L3': [
      [
        LatLng(30.14690, 31.42140), // Adly Mansour
        LatLng(30.14390, 31.40470), // El Haykestep
        LatLng(30.14060, 31.39420), // Omar Ibn El-Khattab
        LatLng(30.13480, 31.38403), // Qobaa
        LatLng(30.13083, 31.37294), // Hesham Barakat
        LatLng(30.12798, 31.36017), // El-Nozha
        LatLng(30.12548, 31.34888), // Nadi El-Shams
        LatLng(30.11842, 31.34048), // Alf Maskan
        LatLng(30.10809, 31.33893), // Heliopolis Square
        LatLng(30.10137, 31.33297), // Haroun
        LatLng(30.09183, 31.32634), // Al-Ahram
        LatLng(30.08416, 31.32901), // Koleyet El-Banat
        LatLng(30.07216, 31.31749), // Cairo Stadium
        LatLng(30.07296, 31.30063), // Fair Zone
        LatLng(30.06976, 31.28078), // Abbassia
        LatLng(30.06467, 31.27485), // Abdou Pasha
        LatLng(30.06172, 31.26696), // El Geish
        LatLng(30.05390, 31.25602), // Bab El Shaaria
        LatLng(30.05235, 31.24680), // Attaba
        LatLng(30.05346, 31.23865), // Nasser
        LatLng(30.05572, 31.23212), // Maspero
        LatLng(30.06228, 31.22329), // Safaa Hegazy
        LatLng(30.06655, 31.21302), // Kit Kat
        LatLng(30.06996, 31.20447), // Sudan
        LatLng(30.07636, 31.20736), // Imbaba
        LatLng(30.08213, 31.21053), // El-Bohy
        LatLng(30.09317, 31.20908), // El-Qawmia
        LatLng(30.09642, 31.19947), // Ring Road
        LatLng(30.10191, 31.18443), // Rod El-Farag Corridor
      ],
      [
        LatLng(30.06655, 31.21302), // Kit Kat
        LatLng(30.06502, 31.20244), // Tawfikia
        LatLng(30.05708, 31.20120), // Wadi El-Nile
        LatLng(30.05016, 31.19896), // Gamat El-Dowal
        LatLng(30.03757, 31.19560), // Boulak El-Dakrour
        LatLng(30.02615, 31.20087), // Cairo University
      ],
    ],
    'MONORAIL': [
      [
        LatLng(30.07216, 31.31749), // Cairo Stadium
        LatLng(30.06347, 31.32181), // Hesham Barakat
        LatLng(30.05378, 31.32472), // El Azhar University
        LatLng(30.04377, 31.33091), // The Seventh District
        LatLng(30.04545, 31.34639), // El Musheer Ahmed Ismail
        LatLng(30.03924, 31.35548), // Jehan el Sadat
        LatLng(30.01916, 31.38331), // Moushir Tantawi
        LatLng(30.01619, 31.40897), // One Ninety
        LatLng(30.01616, 31.43341), // Air Force Hospital
        LatLng(30.02545, 31.45991), // El Narges
        LatLng(30.02531, 31.49066), // Investors
        LatLng(30.01322, 31.51953), // Al Lotus
        LatLng(30.02696, 31.53304), // Golden Square
        LatLng(30.02684, 31.56059), // Beit el Watan
        LatLng(30.02472, 31.59890), // Al Fattah al Alim Mosque
        LatLng(30.01690, 31.63100), // R1
        LatLng(30.01824, 31.66337), // R2
        LatLng(30.01725, 31.68915), // Central Business District
        LatLng(30.01084, 31.72526), // Arts & Culture City
        LatLng(30.00794, 31.74481), // Governmental District
        LatLng(29.99528, 31.75006), // Misr Mosque
        LatLng(30.00594, 31.77011), // Justice City
      ],
    ],
    'LRT': [
      [
        LatLng(30.14690, 31.42140), // Adly Mansour
        LatLng(30.16294, 31.48152), // El-Obour
        LatLng(30.17314, 31.55407), // Future
        LatLng(30.17954, 31.60581), // El-Shorouk
        LatLng(30.18401, 31.65266), // New Heliopolis
        LatLng(30.17516, 31.71605), // Badr
        LatLng(30.16654, 31.75251), // El-Robaiky
        LatLng(30.13668, 31.80682), // Hadayek al-Assema
        LatLng(30.07587, 31.78250), // Capital Airport
        LatLng(30.01084, 31.72526), // Arts & Culture City
      ],
      [
        LatLng(30.17516, 31.71605), // Badr
        LatLng(30.20393, 31.71558), // Industrial Park
        LatLng(30.23069, 31.69155), // Knowledge City
      ],
    ],
  };

  static const List<_RailMapStation> _geoStations = [
    _RailMapStation(name: 'حلوان', nameEn: 'Helwan', position: LatLng(29.84882, 31.33425), lines: ['L1']),
    _RailMapStation(name: 'عين حلوان', nameEn: 'Ain Helwan', position: LatLng(29.86260, 31.32503), lines: ['L1']),
    _RailMapStation(name: 'جامعة حلوان', nameEn: 'Helwan University', position: LatLng(29.86904, 31.32009), lines: ['L1']),
    _RailMapStation(name: 'وادي حوف', nameEn: 'Wadi Hof', position: LatLng(29.87905, 31.31344), lines: ['L1']),
    _RailMapStation(name: 'حدائق حلوان', nameEn: 'Hadayek Helwan', position: LatLng(29.89719, 31.30404), lines: ['L1']),
    _RailMapStation(name: 'المعصرة', nameEn: 'El-Maasara', position: LatLng(29.90636, 31.29953), lines: ['L1']),
    _RailMapStation(name: 'طرة الأسمنت', nameEn: 'Tora El-Asmant', position: LatLng(29.92597, 31.28755), lines: ['L1']),
    _RailMapStation(name: 'كوتسيكا', nameEn: 'Kozzika', position: LatLng(29.93645, 31.28142), lines: ['L1']),
    _RailMapStation(name: 'طرة البلد', nameEn: 'Tora El-Balad', position: LatLng(29.94672, 31.27288), lines: ['L1']),
    _RailMapStation(name: 'ثكنات المعادي', nameEn: 'Sakanat El-Maadi', position: LatLng(29.95331, 31.26296), lines: ['L1']),
    _RailMapStation(name: 'المعادي', nameEn: 'Maadi', position: LatLng(29.96030, 31.25773), lines: ['L1']),
    _RailMapStation(name: 'حدائق المعادي', nameEn: 'Hadayek El-Maadi', position: LatLng(29.96978, 31.25083), lines: ['L1']),
    _RailMapStation(name: 'دار السلام', nameEn: 'Dar El-Salam', position: LatLng(29.98199, 31.24204), lines: ['L1']),
    _RailMapStation(name: 'الزهراء', nameEn: 'El-Zahraa', position: LatLng(29.99554, 31.23123), lines: ['L1']),
    _RailMapStation(name: 'مار جرجس', nameEn: 'Mar Girgis', position: LatLng(30.00617, 31.22958), lines: ['L1']),
    _RailMapStation(name: 'الملك الصالح', nameEn: 'El-Malek El-Saleh', position: LatLng(30.01772, 31.23118), lines: ['L1']),
    _RailMapStation(name: 'السيدة زينب', nameEn: 'Al-Sayeda Zeinab', position: LatLng(30.02924, 31.23543), lines: ['L1']),
    _RailMapStation(name: 'سعد زغلول', nameEn: 'Saad Zaghloul', position: LatLng(30.03567, 31.23782), lines: ['L1']),
    _RailMapStation(name: 'السادات', nameEn: 'Sadat', position: LatLng(30.04392, 31.23566), lines: ['L1', 'L2'], isInterchange: true),
    _RailMapStation(name: 'جمال عبد الناصر', nameEn: 'Nasser', position: LatLng(30.05346, 31.23865), lines: ['L1', 'L3'], isInterchange: true),
    _RailMapStation(name: 'أحمد عرابي', nameEn: 'Orabi', position: LatLng(30.05703, 31.24231), lines: ['L1']),
    _RailMapStation(name: 'الشهداء', nameEn: 'Al-Shohadaa', position: LatLng(30.06164, 31.24629), lines: ['L1', 'L2'], isInterchange: true),
    _RailMapStation(name: 'غمرة', nameEn: 'Ghamra', position: LatLng(30.06819, 31.26400), lines: ['L1']),
    _RailMapStation(name: 'الدمرداش', nameEn: 'El-Demerdash', position: LatLng(30.07719, 31.27786), lines: ['L1']),
    _RailMapStation(name: 'منشية الصدر', nameEn: 'Manshiet El-Sadr', position: LatLng(30.08198, 31.28755), lines: ['L1']),
    _RailMapStation(name: 'كوبري القبة', nameEn: 'Kobri El-Qobba', position: LatLng(30.08720, 31.29413), lines: ['L1']),
    _RailMapStation(name: 'حمامات القبة', nameEn: 'Hammamat El-Qobba', position: LatLng(30.09119, 31.29901), lines: ['L1']),
    _RailMapStation(name: 'سراي القبة', nameEn: 'Saray El-Qobba', position: LatLng(30.09772, 31.30447), lines: ['L1']),
    _RailMapStation(name: 'حدائق الزيتون', nameEn: 'Hadayeq El-Zaitoun', position: LatLng(30.10596, 31.31040), lines: ['L1']),
    _RailMapStation(name: 'حلمية الزيتون', nameEn: 'Helmeyet El-Zaitoun', position: LatLng(30.11325, 31.31400), lines: ['L1']),
    _RailMapStation(name: 'المطرية', nameEn: 'El-Matareyya', position: LatLng(30.12090, 31.31373), lines: ['L1']),
    _RailMapStation(name: 'عين شمس', nameEn: 'Ain Shams', position: LatLng(30.13100, 31.31912), lines: ['L1']),
    _RailMapStation(name: 'عزبة النخل', nameEn: 'Ezbet El-Nakhl', position: LatLng(30.13922, 31.32462), lines: ['L1']),
    _RailMapStation(name: 'المرج', nameEn: 'El-Marg', position: LatLng(30.15211, 31.33581), lines: ['L1']),
    _RailMapStation(name: 'المرج الجديدة', nameEn: 'New El-Marg', position: LatLng(30.16355, 31.33834), lines: ['L1']),
    _RailMapStation(name: 'شبرا الخيمة', nameEn: 'Shubra El-Kheima', position: LatLng(30.12251, 31.24469), lines: ['L2']),
    _RailMapStation(name: 'كلية الزراعة', nameEn: 'Kolleyyet El-Zeraa', position: LatLng(30.11366, 31.24875), lines: ['L2']),
    _RailMapStation(name: 'المظلات', nameEn: 'Mezallat', position: LatLng(30.10407, 31.24557), lines: ['L2']),
    _RailMapStation(name: 'الخلفاوي', nameEn: 'Khalafawy', position: LatLng(30.09785, 31.24500), lines: ['L2']),
    _RailMapStation(name: 'سانت تريزا', nameEn: 'St. Teresa', position: LatLng(30.08796, 31.24549), lines: ['L2']),
    _RailMapStation(name: 'روض الفرج', nameEn: 'Rod El Farag', position: LatLng(30.08059, 31.24540), lines: ['L2']),
    _RailMapStation(name: 'مسرة', nameEn: 'Masarra', position: LatLng(30.07090, 31.24510), lines: ['L2']),
    _RailMapStation(name: 'العتبة', nameEn: 'Attaba', position: LatLng(30.05235, 31.24680), lines: ['L2', 'L3'], isInterchange: true),
    _RailMapStation(name: 'محمد نجيب', nameEn: 'Mohamed Naguib', position: LatLng(30.04534, 31.24415), lines: ['L2']),
    _RailMapStation(name: 'الأوبرا', nameEn: 'Opera', position: LatLng(30.04193, 31.22499), lines: ['L2']),
    _RailMapStation(name: 'الدقي', nameEn: 'Dokki', position: LatLng(30.03739, 31.21133), lines: ['L2']),
    _RailMapStation(name: 'البحوث', nameEn: 'Bohooth', position: LatLng(30.03584, 31.20025), lines: ['L2']),
    _RailMapStation(name: 'جامعة القاهرة', nameEn: 'Cairo University', position: LatLng(30.02615, 31.20087), lines: ['L2', 'L3'], isInterchange: true),
    _RailMapStation(name: 'فيصل', nameEn: 'Faisal', position: LatLng(30.01749, 31.20375), lines: ['L2']),
    _RailMapStation(name: 'الجيزة', nameEn: 'El-Giza', position: LatLng(30.01066, 31.20705), lines: ['L2']),
    _RailMapStation(name: 'أم المصريين', nameEn: 'Omm El-Misryeen', position: LatLng(30.00599, 31.20813), lines: ['L2']),
    _RailMapStation(name: 'ساقية مكي', nameEn: 'Sakiat Mekki', position: LatLng(29.99557, 31.20849), lines: ['L2']),
    _RailMapStation(name: 'المنيب', nameEn: 'El-Mounib', position: LatLng(29.98103, 31.21231), lines: ['L2']),
    _RailMapStation(name: 'عدلي منصور', nameEn: 'Adly Mansour', position: LatLng(30.14690, 31.42140), lines: ['L3', 'LRT'], isInterchange: true),
    _RailMapStation(name: 'الهايكستب', nameEn: 'El Haykestep', position: LatLng(30.14390, 31.40470), lines: ['L3']),
    _RailMapStation(name: 'عمر بن الخطاب', nameEn: 'Omar Ibn El-Khattab', position: LatLng(30.14060, 31.39420), lines: ['L3']),
    _RailMapStation(name: 'قباء', nameEn: 'Qobaa', position: LatLng(30.13480, 31.38403), lines: ['L3']),
    _RailMapStation(name: 'هشام بركات', nameEn: 'Hesham Barakat', position: LatLng(30.13083, 31.37294), lines: ['L3']),
    _RailMapStation(name: 'النزهة', nameEn: 'El-Nozha', position: LatLng(30.12798, 31.36017), lines: ['L3']),
    _RailMapStation(name: 'نادي الشمس', nameEn: 'Nadi El-Shams', position: LatLng(30.12548, 31.34888), lines: ['L3']),
    _RailMapStation(name: 'ألف مسكن', nameEn: 'Alf Maskan', position: LatLng(30.11842, 31.34048), lines: ['L3']),
    _RailMapStation(name: 'ميدان هليوبوليس', nameEn: 'Heliopolis Square', position: LatLng(30.10809, 31.33893), lines: ['L3']),
    _RailMapStation(name: 'هارون', nameEn: 'Haroun', position: LatLng(30.10137, 31.33297), lines: ['L3']),
    _RailMapStation(name: 'الأهرام', nameEn: 'Al-Ahram', position: LatLng(30.09183, 31.32634), lines: ['L3']),
    _RailMapStation(name: 'كلية البنات', nameEn: 'Koleyet El-Banat', position: LatLng(30.08416, 31.32901), lines: ['L3']),
    _RailMapStation(name: 'استاد القاهرة', nameEn: 'Cairo Stadium', position: LatLng(30.07216, 31.31749), lines: ['L3', 'MONORAIL'], isInterchange: true),
    _RailMapStation(name: 'أرض المعارض', nameEn: 'Fair Zone', position: LatLng(30.07296, 31.30063), lines: ['L3']),
    _RailMapStation(name: 'العباسية', nameEn: 'Abbassia', position: LatLng(30.06976, 31.28078), lines: ['L3']),
    _RailMapStation(name: 'عبده باشا', nameEn: 'Abdou Pasha', position: LatLng(30.06467, 31.27485), lines: ['L3']),
    _RailMapStation(name: 'الجيش', nameEn: 'El Geish', position: LatLng(30.06172, 31.26696), lines: ['L3']),
    _RailMapStation(name: 'باب الشعرية', nameEn: 'Bab El Shaaria', position: LatLng(30.05390, 31.25602), lines: ['L3']),
    _RailMapStation(name: 'ماسبيرو', nameEn: 'Maspero', position: LatLng(30.05572, 31.23212), lines: ['L3']),
    _RailMapStation(name: 'صفاء حجازي', nameEn: 'Safaa Hegazy', position: LatLng(30.06228, 31.22329), lines: ['L3']),
    _RailMapStation(name: 'الكيت كات', nameEn: 'Kit Kat', position: LatLng(30.06655, 31.21302), lines: ['L3']),
    _RailMapStation(name: 'السودان', nameEn: 'Sudan', position: LatLng(30.06996, 31.20447), lines: ['L3']),
    _RailMapStation(name: 'إمبابة', nameEn: 'Imbaba', position: LatLng(30.07636, 31.20736), lines: ['L3']),
    _RailMapStation(name: 'البوهي', nameEn: 'El-Bohy', position: LatLng(30.08213, 31.21053), lines: ['L3']),
    _RailMapStation(name: 'القومية العربية', nameEn: 'El-Qawmia', position: LatLng(30.09317, 31.20908), lines: ['L3']),
    _RailMapStation(name: 'الطريق الدائري', nameEn: 'Ring Road', position: LatLng(30.09642, 31.19947), lines: ['L3']),
    _RailMapStation(name: 'محور روض الفرج', nameEn: 'Rod El-Farag Corridor', position: LatLng(30.10191, 31.18443), lines: ['L3']),
    _RailMapStation(name: 'التوفيقية', nameEn: 'Tawfikia', position: LatLng(30.06502, 31.20244), lines: ['L3']),
    _RailMapStation(name: 'وادي النيل', nameEn: 'Wadi El-Nile', position: LatLng(30.05708, 31.20120), lines: ['L3']),
    _RailMapStation(name: 'جامعة الدول', nameEn: 'Gamat El-Dowal', position: LatLng(30.05016, 31.19896), lines: ['L3']),
    _RailMapStation(name: 'بولاق الدكرور', nameEn: 'Boulak El-Dakrour', position: LatLng(30.03757, 31.19560), lines: ['L3']),
    _RailMapStation(name: 'هشام بركات', nameEn: 'Hesham Barakat', position: LatLng(30.06347, 31.32181), lines: ['MONORAIL']),
    _RailMapStation(name: 'جامعة الازهر', nameEn: 'El Azhar University', position: LatLng(30.05378, 31.32472), lines: ['MONORAIL']),
    _RailMapStation(name: 'الحي السابع', nameEn: 'The Seventh District', position: LatLng(30.04377, 31.33091), lines: ['MONORAIL']),
    _RailMapStation(name: 'المشير احمد اسماعيل', nameEn: 'El Musheer Ahmed Ismail', position: LatLng(30.04545, 31.34639), lines: ['MONORAIL']),
    _RailMapStation(name: 'جيهان السادات', nameEn: 'Jehan el Sadat', position: LatLng(30.03924, 31.35548), lines: ['MONORAIL']),
    _RailMapStation(name: 'المشير طنطاوي', nameEn: 'Moushir Tantawi', position: LatLng(30.01916, 31.38331), lines: ['MONORAIL']),
    _RailMapStation(name: 'وان ناينتي', nameEn: 'One Ninety', position: LatLng(30.01619, 31.40897), lines: ['MONORAIL']),
    _RailMapStation(name: 'مستشفى القوات الجوية', nameEn: 'Air Force Hospital', position: LatLng(30.01616, 31.43341), lines: ['MONORAIL']),
    _RailMapStation(name: 'النرجس', nameEn: 'El Narges', position: LatLng(30.02545, 31.45991), lines: ['MONORAIL']),
    _RailMapStation(name: 'المستثمرين', nameEn: 'Investors', position: LatLng(30.02531, 31.49066), lines: ['MONORAIL']),
    _RailMapStation(name: 'اللوتس', nameEn: 'Al Lotus', position: LatLng(30.01322, 31.51953), lines: ['MONORAIL']),
    _RailMapStation(name: 'جولدن سكوير', nameEn: 'Golden Square', position: LatLng(30.02696, 31.53304), lines: ['MONORAIL']),
    _RailMapStation(name: 'بيت الوطن', nameEn: 'Beit el Watan', position: LatLng(30.02684, 31.56059), lines: ['MONORAIL']),
    _RailMapStation(name: 'مسجد الفتاح العليم', nameEn: 'Al Fattah al Alim Mosque', position: LatLng(30.02472, 31.59890), lines: ['MONORAIL']),
    _RailMapStation(name: 'الحي R1', nameEn: 'R1', position: LatLng(30.01690, 31.63100), lines: ['MONORAIL']),
    _RailMapStation(name: 'الحي R2', nameEn: 'R2', position: LatLng(30.01824, 31.66337), lines: ['MONORAIL']),
    _RailMapStation(name: 'حي المال والاعمال', nameEn: 'Central Business District', position: LatLng(30.01725, 31.68915), lines: ['MONORAIL']),
    _RailMapStation(name: 'مدينة الفنون والثقافة', nameEn: 'Arts & Culture City', position: LatLng(30.01084, 31.72526), lines: ['LRT', 'MONORAIL'], isInterchange: true),
    _RailMapStation(name: 'الحي الحكومي', nameEn: 'Governmental District', position: LatLng(30.00794, 31.74481), lines: ['MONORAIL']),
    _RailMapStation(name: 'مسجد مصر', nameEn: 'Misr Mosque', position: LatLng(29.99528, 31.75006), lines: ['MONORAIL']),
    _RailMapStation(name: 'مدينة العدالة', nameEn: 'Justice City', position: LatLng(30.00594, 31.77011), lines: ['MONORAIL']),
    _RailMapStation(name: 'العبور', nameEn: 'El-Obour', position: LatLng(30.16294, 31.48152), lines: ['LRT']),
    _RailMapStation(name: 'المستقبل', nameEn: 'Future', position: LatLng(30.17314, 31.55407), lines: ['LRT']),
    _RailMapStation(name: 'الشروق', nameEn: 'El-Shorouk', position: LatLng(30.17954, 31.60581), lines: ['LRT']),
    _RailMapStation(name: 'نيو هليوبوليس', nameEn: 'New Heliopolis', position: LatLng(30.18401, 31.65266), lines: ['LRT']),
    _RailMapStation(name: 'بدر', nameEn: 'Badr', position: LatLng(30.17516, 31.71605), lines: ['LRT']),
    _RailMapStation(name: 'الروبيكي', nameEn: 'El-Robaiky', position: LatLng(30.16654, 31.75251), lines: ['LRT']),
    _RailMapStation(name: 'حدائق العاصمة', nameEn: 'Hadayek al-Assema', position: LatLng(30.13668, 31.80682), lines: ['LRT']),
    _RailMapStation(name: 'مطار العاصمة', nameEn: 'Capital Airport', position: LatLng(30.07587, 31.78250), lines: ['LRT']),
    _RailMapStation(name: 'المنطقة الصناعية', nameEn: 'Industrial Park', position: LatLng(30.20393, 31.71558), lines: ['LRT']),
    _RailMapStation(name: 'مدينة المعرفة', nameEn: 'Knowledge City', position: LatLng(30.23069, 31.69155), lines: ['LRT']),
  ];

  static const Map<String, List<String>> _interchanges = {
    'السادات': ['L1', 'L2'],
    'جمال عبد الناصر': ['L1', 'L3'],
    'الشهداء': ['L1', 'L2'],
    'العتبة': ['L2', 'L3'],
    'جامعة القاهرة': ['L2', 'L3'],
    'عدلي منصور': ['L3', 'LRT'],
    'استاد القاهرة': ['L3', 'MONORAIL'],
    'مدينة الفنون والثقافة': ['LRT', 'MONORAIL'],
  };

  BitmapDescriptor? _interchangeMarkerIcon;
  final Map<String, BitmapDescriptor> _lineMarkerIcons = {};

  Future<void> _loadMarkers() async {
    try {
      final transfer = await MapMarkerService.getTransferMarker();
      final icons = <String, BitmapDescriptor>{};
      for (final line in _lines) {
        final id = line['id'] as String;
        final color = line['color'] as Color;
        icons[id] = await MapMarkerService.getStationStopMarker(color: color);
      }
      if (mounted) {
        setState(() {
          _interchangeMarkerIcon = transfer;
          _lineMarkerIcons.addAll(icons);
        });
      }
    } catch (e) {
      debugPrint("Error loading rail network markers: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMarkers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _googleMapController?.dispose();
    super.dispose();
  }

  void _fitLine(String lineId) {
    final segments = _lineCoordsMap[lineId];
    if (segments == null || segments.isEmpty) return;

    double? minLat, maxLat, minLng, maxLng;
    for (final seg in segments) {
      for (final c in seg) {
        minLat = (minLat == null) ? c.latitude : (c.latitude < minLat ? c.latitude : minLat);
        maxLat = (maxLat == null) ? c.latitude : (c.latitude > maxLat ? c.latitude : maxLat);
        minLng = (minLng == null) ? c.longitude : (c.longitude < minLng ? c.longitude : minLng);
        maxLng = (maxLng == null) ? c.longitude : (c.longitude > maxLng ? c.longitude : maxLng);
      }
    }
    if (minLat == null || maxLat == null || minLng == null || maxLng == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    _googleMapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 48),
    );
  }

  Set<Polyline> _buildPolylines(bool isDark) {
    final polylines = <Polyline>{};
    for (final line in _lines) {
      final id = line['id'] as String;
      final color = line['color'] as Color;
      final segments = _lineCoordsMap[id];
      if (segments == null || segments.isEmpty) continue;

      final isSelected = _selectedLine == null || _selectedLine == id;
      final polyColor = isSelected ? color : color.withValues(alpha: 0.22);
      final casingColor = isSelected
          ? (isDark ? const Color(0xFF1E2630) : Colors.white)
          : (isDark ? const Color(0xFF1E2630).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.25));

      int segIdx = 0;
      for (final seg in segments) {
        segIdx++;
        polylines.add(
          Polyline(
            polylineId: PolylineId('${id}_casing_$segIdx'),
            points: seg,
            color: casingColor,
            width: isSelected ? 8 : 4,
            zIndex: isSelected ? 2 : 0,
          ),
        );

        polylines.add(
          Polyline(
            polylineId: PolylineId('${id}_$segIdx'),
            points: seg,
            color: polyColor,
            width: isSelected ? 5 : 2,
            zIndex: isSelected ? 3 : 1,
          ),
        );
      }
    }
    return polylines;
  }

  Set<Marker> _buildMarkers(bool isAr) {
    final markers = <Marker>{};
    for (final st in _geoStations) {
      if (_selectedLine != null && !st.lines.contains(_selectedLine)) {
        continue;
      }
      final isInterchange = st.isInterchange;
      final name = isAr ? st.name : st.nameEn;
      final linesStr = st.lines.join(' • ');
      final primaryLineId = st.lines.isNotEmpty ? st.lines.first : '';

      final icon = isInterchange
          ? (_interchangeMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow))
          : (_lineMarkerIcons[primaryLineId] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure));

      markers.add(
        Marker(
          markerId: MarkerId('${st.nameEn}_${st.lines.join("_")}'),
          position: st.position,
          icon: icon,
          anchor: MapMarkerService.centerAnchor,
          zIndexInt: isInterchange ? 5 : 2,
          infoWindow: InfoWindow(
            title: name,
            snippet: isInterchange
                ? (isAr ? 'محطة تبادلية ($linesStr)' : 'Interchange ($linesStr)')
                : (isAr ? 'خط: $linesStr' : 'Line: $linesStr'),
            onTap: () {
              setState(() => _selectedStation = st.name);
              _showStationDetails(context, st.name, st.lines, isAr);
            },
          ),
          onTap: () {
            setState(() => _selectedStation = st.name);
            _showStationDetails(context, st.name, st.lines, isAr);
          },
        ),
      );
    }
    return markers;
  }

  Widget _buildTopControlOverlay(BuildContext context, bool isDark, bool isAr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2630).withValues(alpha: 0.94) : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ActionChip(
                      avatar: Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.brandAmberDark),
                      label: Text(
                        isAr ? 'دليل الأسعار والاشتراكات' : 'Fares & Pass Guide',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      backgroundColor: isDark ? const Color(0xFF263238) : Colors.amber.shade50,
                      side: BorderSide(color: AppColors.brandAmberDark.withValues(alpha: 0.5)),
                      onPressed: () => _showFareGuideSheet(context, isDark, isAr),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      label: Text(
                        isAr ? 'الكل' : 'All',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _selectedLine == null ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      selected: _selectedLine == null,
                      selectedColor: AppColors.primaryTeal,
                      onSelected: (sel) {
                        if (sel) {
                          setState(() => _selectedLine = null);
                          {
                            _googleMapController?.animateCamera(
                              CameraUpdate.newCameraPosition(
                                const CameraPosition(target: LatLng(30.0444, 31.2357), zoom: 11.2),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  ..._lines.map((l) {
                    final id = l['id'] as String;
                    final color = l['color'] as Color;
                    final isSel = _selectedLine == id;
                    String shortLabel;
                    if (id == 'L1') {
                      shortLabel = isAr ? 'الخط 1' : 'Line 1';
                    } else if (id == 'L2') {
                      shortLabel = isAr ? 'الخط 2' : 'Line 2';
                    } else if (id == 'L3') {
                      shortLabel = isAr ? 'الخط 3' : 'Line 3';
                    } else if (id == 'MONORAIL') {
                      shortLabel = isAr ? 'مونوريل' : 'Monorail';
                    } else {
                      shortLabel = isAr ? 'القطار الخفيف LRT' : 'LRT Train';
                    }

                    return Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(
                        avatar: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        label: Text(
                          shortLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        selected: isSel,
                        selectedColor: color,
                        onSelected: (sel) {
                          setState(() => _selectedLine = sel ? id : null);
                          if (sel) {
                            _fitLine(id);
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'خريطة شبكة قطارات ومترو القاهرة' : 'Cairo Rail & Metro Network',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryTeal,
          labelColor: AppColors.primaryTeal,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          tabs: [
            Tab(icon: const Icon(Icons.map_outlined, size: 20), text: isAr ? 'الخريطة' : 'Map'),
            Tab(icon: const Icon(Icons.format_list_bulleted_rounded, size: 20), text: isAr ? 'دليل المحطات' : 'Station Directory'),
          ],
        ),
        actions: [
          ...GuidyLanguageToggle.appBarActions,
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Tab 1: the real map (the schematic diagram was removed). Kept
          // alive while the directory is open: "View on Real Map" moves
          // its camera, and a map thrown away with the tab would leave
          // _googleMapController pointing at a map that is gone.
          widget.showMap ? _KeepAlivePage(child: _buildRealMapView(context, isDark, isAr)) : const SizedBox.shrink(),

          // Tab 2: Searchable Line & Station Directory
          _buildDirectoryView(context, isDark, isAr),
        ],
      ),
    );
  }

  Widget _buildRealMapView(BuildContext context, bool isDark, bool isAr) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(30.0444, 31.2357),
            zoom: 11.2,
          ),
          style: isDark ? darkMapStyleJson : null,
          onMapCreated: (controller) => _googleMapController = controller,
          polylines: _buildPolylines(isDark),
          markers: _buildMarkers(isAr),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          rotateGesturesEnabled: false,
        ),

        // Top Controls Overlay
        Positioned(
          top: 12,
          left: 14,
          right: 14,
          child: _buildTopControlOverlay(context, isDark, isAr),
        ),

        // Floating Map Controls
        Positioned(
          bottom: 24,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'real_map_recenter',
                backgroundColor: isDark ? const Color(0xFF263238) : Colors.white,
                foregroundColor: AppColors.primaryTeal,
                tooltip: isAr ? 'إعادة ضبط المنظور' : 'Recenter Cairo',
                onPressed: () {
                  _googleMapController?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      const CameraPosition(target: LatLng(30.0444, 31.2357), zoom: 11.2),
                    ),
                  );
                },
                child: const Icon(Icons.my_location),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'real_map_zoom_in',
                backgroundColor: isDark ? const Color(0xFF263238) : Colors.white,
                foregroundColor: AppColors.primaryTeal,
                onPressed: () => _googleMapController?.animateCamera(CameraUpdate.zoomIn()),
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'real_map_zoom_out',
                backgroundColor: isDark ? const Color(0xFF263238) : Colors.white,
                foregroundColor: AppColors.primaryTeal,
                onPressed: () => _googleMapController?.animateCamera(CameraUpdate.zoomOut()),
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDirectoryView(BuildContext context, bool isDark, bool isAr) {
    final filteredLines = _lines.map((line) {
      final stations = (line['stations'] as List<String>).where((s) {
        if (_searchQuery.trim().isEmpty) return true;
        final q = _searchQuery.trim().toLowerCase();
        final geo = _geoStations.where((g) => g.name == s).firstOrNull;
        final matchAr = s.toLowerCase().contains(q);
        final matchEn = geo != null && geo.nameEn.toLowerCase().contains(q);
        return matchAr || matchEn;
      }).toList();
      return {
        ...line,
        'stations': stations,
      };
    }).where((line) => (line['stations'] as List).isNotEmpty).toList();

    return Column(
      children: [
        // Search box
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: isAr ? 'ابحث عن محطة في الشبكة...' : 'Search station across network...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),

        // Interchanges quick bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: _interchanges.entries.map((e) {
              final stName = e.key;
              final geo = _geoStations.where((g) => g.name == stName).firstOrNull;
              final chipLabel = (isAr || geo == null) ? stName : geo.nameEn;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.swap_horiz, size: 16, color: Colors.white),
                  backgroundColor: AppColors.primaryTeal,
                  label: Text(
                    chipLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedStation = stName;
                      _selectedLine = null;
                    });
                    _showStationDetails(context, stName, e.value, isAr);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const Divider(height: 12),

        // Network List with interactive station expanders
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            // One extra slot after the last line card, only while there are
            // cards to follow (not on an empty search result).
            itemCount: filteredLines.length + (filteredLines.isEmpty ? 0 : 1),
            itemBuilder: (context, idx) {
              if (idx == filteredLines.length) return const NativeAdCard(template: TemplateType.small);
              final line = filteredLines[idx];
              final lineId = line['id'] as String;
              final lineColor = line['color'] as Color;
              final lineName = isAr ? line['nameAr'] : line['nameEn'];
              final stations = line['stations'] as List<String>;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: lineColor.withValues(alpha: 0.3), width: 1.5),
                ),
                child: ExpansionTile(
                  initiallyExpanded: _searchQuery.isNotEmpty || _selectedLine == lineId,
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: lineColor, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      lineId.replaceAll('MONORAIL', 'M'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  title: Text(
                    lineName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        isAr ? '${stations.length} محطة' : '${stations.length} stations',
                        style: TextStyle(color: context.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: lineColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: lineColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _fareSummaryForLine(lineId, isAr),
                          style: TextStyle(
                            color: lineColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: stations.asMap().entries.map((entry) {
                          final i = entry.key;
                          final station = entry.value;
                          final geo = _geoStations.where((g) => g.name == station && g.lines.contains(lineId)).firstOrNull ??
                              _geoStations.where((g) => g.name == station).firstOrNull;
                          final isInterchange = _interchanges.containsKey(station);
                          final isFirst = i == 0;
                          final isLast = i == stations.length - 1;
                          final isSelected = _selectedStation == station;
                          final displayName = (isAr || geo == null) ? station : geo.nameEn;
                          final subtitleName = (geo != null && !isAr) ? geo.name : (geo != null && isAr ? geo.nameEn : null);

                          return InkWell(
                            onTap: () {
                              setState(() => _selectedStation = station);
                              final meetingLines = _interchanges[station] ?? [lineId];
                              _showStationDetails(context, station, meetingLines, isAr);
                            },
                            child: Container(
                              color: isSelected ? lineColor.withValues(alpha: 0.12) : Colors.transparent,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    height: 36,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (!isFirst)
                                          Positioned(top: 0, bottom: 18, child: Container(width: 3, color: lineColor)),
                                        if (!isLast)
                                          Positioned(top: 18, bottom: 0, child: Container(width: 3, color: lineColor)),
                                        Container(
                                          width: isInterchange ? 14 : 9,
                                          height: isInterchange ? 14 : 9,
                                          decoration: BoxDecoration(
                                            color: isInterchange ? Colors.white : lineColor,
                                            shape: BoxShape.circle,
                                            border: isInterchange ? Border.all(color: lineColor, width: 3) : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: isInterchange ? FontWeight.bold : FontWeight.normal,
                                            color: isInterchange ? lineColor : (isDark ? Colors.white70 : Colors.black87),
                                          ),
                                        ),
                                        if (subtitleName != null)
                                          Text(
                                            subtitleName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.white38 : Colors.black38,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isInterchange)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: lineColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isAr ? 'محطة تبادلية' : 'Interchange',
                                        style: TextStyle(color: lineColor, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showStationDetails(BuildContext context, String station, List<String> lines, bool isAr) {
    final geoMatch = _geoStations.where((s) =>
      (s.name == station || s.nameEn == station || (station == 'ناصر' && s.name == 'جمال عبد الناصر')) &&
      (lines.isEmpty || s.lines.any(lines.contains))
    ).firstOrNull ?? _geoStations.where((s) =>
      s.name == station || s.nameEn == station || (station == 'ناصر' && s.name == 'جمال عبد الناصر')
    ).firstOrNull;

    final primaryName = geoMatch != null ? (isAr ? geoMatch.name : geoMatch.nameEn) : station;
    final secondaryName = geoMatch != null ? (isAr ? geoMatch.nameEn : geoMatch.name) : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      // Sized to its content: the default 9/16 cap cut the bottom off on
      // short phones. Scrolls when even the whole screen is too short.
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_railway, color: AppColors.primaryTeal, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primaryName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                        ),
                        if (secondaryName != null && secondaryName != primaryName) ...[
                          const SizedBox(height: 2),
                          Text(
                            secondaryName,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                lines.length > 1
                    ? (isAr ? 'محطة تبادلية تخدم الخطوط التالية:' : 'Interchange serving:')
                    : (isAr ? 'محطة تخدم خط:' : 'Line served:'),
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: lines.map((lid) {
                  final lineInfo = _lines.firstWhere((l) => l['id'] == lid, orElse: () => _lines.first);
                  return Chip(
                    backgroundColor: (lineInfo['color'] as Color).withValues(alpha: 0.15),
                    avatar: CircleAvatar(
                      backgroundColor: lineInfo['color'] as Color,
                      radius: 8,
                    ),
                    label: Text(
                      isAr ? lineInfo['nameAr'] : lineInfo['nameEn'],
                      style: TextStyle(color: lineInfo['color'] as Color, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
              if (geoMatch != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.pin_drop_rounded, size: 20),
                    label: Text(
                      isAr ? 'عرض المحطة على الخريطة الحقيقية' : 'View on Real Map',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedStation = station;
                      });
                      _tabController.animateTo(0);
                      _googleMapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(geoMatch.position, 14.5),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textSecondary,
                    side: BorderSide(color: context.isDark ? const Color(0xFF3A4352) : Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: Text(
                    isAr ? 'بلّغ عن مشكلة في المحطة دي' : 'Report an issue with this station',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    MetroReportSheet.show(
                      context,
                      station: {
                        'name': station,
                        'lines': lines,
                        'is_interchange': lines.length > 1,
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  String _fareSummaryForLine(String lineId, bool isAr) {
    if (lineId == 'L1' || lineId == 'L2' || lineId == 'L3') {
      return isAr ? 'التذكرة: 10 - 20 ج.م' : 'Fare: 10 - 20 EGP';
    } else if (lineId == 'LRT') {
      return isAr ? 'التذكرة: 10 - 20 ج.م' : 'Fare: 10 - 20 EGP';
    } else if (lineId.contains('MONORAIL')) {
      return isAr ? 'التذكرة: 20 - 80 ج.م' : 'Fare: 20 - 80 EGP';
    }
    return isAr ? '10 - 20 ج.م' : '10 - 20 EGP';
  }

  void _showFareGuideSheet(BuildContext context, bool isDark, bool isAr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          expand: false,
          builder: (sheetCtx, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryTeal, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAr ? 'دليل تذاكر واشتراكات النقل السككي' : 'Cairo Rail Fares & Pass Guide',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
                            ),
                            Text(
                              isAr ? 'التعريفة الرسمية المحدثة لشبكة مترو وقطارات القاهرة' : 'Official updated Cairo Metro & Rail tariffs',
                              style: TextStyle(color: context.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Cairo Metro Single Tickets Card
                  _buildFareSectionCard(
                    title: isAr ? 'مترو أنفاق القاهرة (الخطوط 1، 2، 3)' : 'Cairo Metro Single Tickets (Lines 1, 2, 3)',
                    color: GuidyModeStyle.color('metro'),
                    icon: Icons.subway_rounded,
                    isDark: isDark,
                    items: [
                      _FareRowItem(
                        stage: isAr ? 'المرحلة الأولى (1 - 9 محطات)' : 'Stage 1 (1 - 9 stations)',
                        price: isAr ? '10 ج.م' : '10 EGP',
                        discountText: isAr ? 'كبار السن 60+: 5 ج.م | ذوي الهمم: 5 ج.م' : 'Seniors 60+: 5 EGP | Special: 5 EGP',
                      ),
                      _FareRowItem(
                        stage: isAr ? 'المرحلة الثانية (10 - 16 محطة)' : 'Stage 2 (10 - 16 stations)',
                        price: isAr ? '12 ج.م' : '12 EGP',
                        discountText: isAr ? 'كبار السن 60+: 6 ج.م | ذوي الهمم: 5 ج.م' : 'Seniors 60+: 6 EGP | Special: 5 EGP',
                      ),
                      _FareRowItem(
                        stage: isAr ? 'المرحلة الثالثة (17 - 23 محطة)' : 'Stage 3 (17 - 23 stations)',
                        price: isAr ? '15 ج.م' : '15 EGP',
                        discountText: isAr ? 'كبار السن 60+: 7.5 ج.م | ذوي الهمم: 5 ج.م' : 'Seniors 60+: 7.5 EGP | Special: 5 EGP',
                      ),
                      _FareRowItem(
                        stage: isAr ? 'المرحلة الرابعة (أكثر من 24 محطة)' : 'Stage 4 (24+ stations)',
                        price: isAr ? '20 ج.م' : '20 EGP',
                        discountText: isAr ? 'كبار السن 60+: 10 ج.م | ذوي الهمم: 5 ج.م' : 'Seniors 60+: 10 EGP | Special: 5 EGP',
                      ),
                    ],
                    footerNote: isAr
                        ? '• كبار السن فوق 70 عاماً مجاناً بموجب بطاقة الرقم القومي.\n• تذكرة ذوي الهمم موحدة بقيمة 5 ج.م لكافة المراحل.'
                        : '• Seniors 70+ ride free with National ID.\n• Special needs tickets flat 5 EGP across all zones.',
                  ),
                  const SizedBox(height: 14),

                  // LRT & Monorail Card
                  _buildFareSectionCard(
                    title: isAr ? 'القطار الكهربائي الخفيف والمونوريل' : 'LRT & Monorail Fares',
                    color: GuidyModeStyle.color('monorail'),
                    icon: Icons.tram_rounded,
                    isDark: isDark,
                    items: [
                      _FareRowItem(
                        stage: isAr ? 'القطار الخفيف (LRT) - حتى 3 محطات' : 'LRT - Up to 3 stations',
                        price: isAr ? '10 ج.م' : '10 EGP',
                        discountText: null,
                      ),
                      _FareRowItem(
                        stage: isAr ? 'القطار الخفيف (LRT) - حتى 7 محطات' : 'LRT - Up to 7 stations',
                        price: isAr ? '15 ج.م' : '15 EGP',
                        discountText: null,
                      ),
                      _FareRowItem(
                        stage: isAr ? 'القطار الخفيف (LRT) - أكثر من 7 محطات' : 'LRT - More than 7 stations',
                        price: isAr ? '20 ج.م' : '20 EGP',
                        discountText: null,
                      ),
                      _FareRowItem(
                        stage: isAr ? 'مونوريل شرق وغرب النيل' : 'East & West Monorail',
                        price: isAr ? '20 - 80 ج.م' : '20 - 80 EGP',
                        discountText: isAr ? 'تتدرج حسب مسافة ومحطات الرحلة' : 'Graduated based on journey distance',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Metro Subscriptions Overview Card
                  _buildFareSectionCard(
                    title: isAr ? 'اشتراكات المترو (توفير شهري وربع سنوي)' : 'Metro Subscription Passes',
                    color: GuidyModeStyle.color('metro'),
                    icon: Icons.card_membership_rounded,
                    isDark: isDark,
                    items: [
                      _FareRowItem(
                        stage: isAr ? 'الاشتراك الشهري العام (مرحلة واحدة)' : 'Public Monthly (Stage 1 / 1 zone)',
                        price: isAr ? '390 ج.م / شهر' : '390 EGP / month',
                        discountText: isAr ? 'وفر أكثر من 35% مقارنة بالتذاكر اليومية' : 'Save >35% vs daily single tickets',
                      ),
                      _FareRowItem(
                        stage: isAr ? 'الاشتراك الشهري العام (مرحلتين)' : 'Public Monthly (Stage 2 / 2 zones)',
                        price: isAr ? '440 ج.م / شهر' : '440 EGP / month',
                        discountText: null,
                      ),
                      _FareRowItem(
                        stage: isAr ? 'اشتراك الطلبة الربع سنوي' : 'Student Quarterly (3 Months)',
                        price: isAr ? '150 - 300 ج.م' : '150 - 300 EGP',
                        discountText: isAr ? 'مدعوم حكومياً بنسبة تصل إلى 95%' : 'Government subsidized up to 95%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFareSectionCard({
    required String title,
    required Color color,
    required IconData icon,
    required bool isDark,
    required List<_FareRowItem> items,
    String? footerNote,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252C38) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.stage,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (item.discountText != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.discountText!,
                            style: TextStyle(fontSize: 10.5, color: context.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.price,
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (footerNote != null) ...[
            const SizedBox(height: 6),
            Text(
              footerNote,
              style: TextStyle(fontSize: 10.5, color: context.textSecondary, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

class _FareRowItem {
  final String stage;
  final String price;
  final String? discountText;

  const _FareRowItem({
    required this.stage,
    required this.price,
    this.discountText,
  });
}
