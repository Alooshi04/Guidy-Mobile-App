import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/location_localizer.dart';

void main() {
  group('LocationLocalizer station translations', () {
    test('translates English station names to Arabic', () {
      expect(LocationLocalizer.localize('Sadat', isArabic: true), equals('السادات'));
      expect(LocationLocalizer.localize('Dokki', isArabic: true), equals('الدقي'));
      expect(LocationLocalizer.localize('Attaba', isArabic: true), equals('العتبة'));
      expect(LocationLocalizer.localize('Helwan', isArabic: true), equals('حلوان'));
      expect(LocationLocalizer.localize('Cairo University', isArabic: true), equals('جامعة القاهرة'));
      expect(LocationLocalizer.localize('Adly Mansour', isArabic: true), equals('عدلي منصور'));
      expect(LocationLocalizer.localize('Al-Shohadaa', isArabic: true), equals('الشهداء'));
    });

    test('translates Arabic station names to English', () {
      expect(LocationLocalizer.localize('السادات', isArabic: false), equals('Sadat'));
      expect(LocationLocalizer.localize('الدقي', isArabic: false), equals('Dokki'));
      expect(LocationLocalizer.localize('العتبة', isArabic: false), equals('Attaba'));
      expect(LocationLocalizer.localize('حلوان', isArabic: false), equals('Helwan'));
      expect(LocationLocalizer.localize('جامعة القاهرة', isArabic: false), equals('Cairo University'));
      expect(LocationLocalizer.localize('عدلي منصور', isArabic: false), equals('Adly Mansour'));
      expect(LocationLocalizer.localize('الشهداء', isArabic: false), equals('Al-Shohadaa'));
    });

    test('handles Station affix bidirectionally', () {
      expect(LocationLocalizer.localize('Sadat Station', isArabic: true), equals('محطة السادات'));
      expect(LocationLocalizer.localize('Station Sadat', isArabic: true), equals('محطة السادات'));
      expect(LocationLocalizer.localize('محطة السادات', isArabic: false), equals('Sadat Station'));
    });
  });

  group('LocationLocalizer landmarks and sentinels', () {
    test('translates landmarks bidirectionally', () {
      expect(LocationLocalizer.localize('Tahrir Square', isArabic: true), equals('ميدان التحرير'));
      expect(LocationLocalizer.localize('ميدان التحرير', isArabic: false), equals('Tahrir Square'));
      expect(LocationLocalizer.localize('Cairo Airport', isArabic: true), equals('مطار القاهرة'));
      expect(LocationLocalizer.localize('مطار القاهرة', isArabic: false), equals('Cairo Airport'));
      expect(LocationLocalizer.localize('Smart Village', isArabic: true), equals('القرية الذكية'));
      expect(LocationLocalizer.localize('القرية الذكية', isArabic: false), equals('Smart Village'));
    });

    test('translates system sentinels', () {
      expect(LocationLocalizer.localize('My Current Location', isArabic: true), equals('موقعي الحالي'));
      expect(LocationLocalizer.localize('Current Location', isArabic: true), equals('موقعي الحالي'));
      expect(LocationLocalizer.localize('موقعي الحالي', isArabic: false), equals('My Current Location'));
      expect(LocationLocalizer.localize('Origin', isArabic: true), equals('نقطة الانطلاق'));
      expect(LocationLocalizer.localize('نقطة الانطلاق', isArabic: false), equals('Origin'));
      expect(LocationLocalizer.localize('Destination', isArabic: true), equals('الوجهة'));
      expect(LocationLocalizer.localize('الوجهة', isArabic: false), equals('Destination'));
    });
  });

  group('LocationLocalizer bare numbers and bilingual generation', () {
    test('detects bare numbers and house numbers correctly', () {
      expect(LocationLocalizer.isBareNumber('17'), isTrue);
      expect(LocationLocalizer.isBareNumber('1'), isTrue);
      expect(LocationLocalizer.isBareNumber('12A'), isTrue);
      expect(LocationLocalizer.isBareNumber('١٧'), isTrue);
      expect(LocationLocalizer.isBareNumber('17 Tahrir St'), isFalse);
      expect(LocationLocalizer.isBareNumber('Sadat'), isFalse);
    });

    test('honors explicit nameAr and nameEn overrides', () {
      expect(
        LocationLocalizer.localize('Custom Name', isArabic: true, nameAr: 'اسم مخصص'),
        equals('اسم مخصص'),
      );
      expect(
        LocationLocalizer.localize('اسم مخصص', isArabic: false, nameEn: 'Custom Name'),
        equals('Custom Name'),
      );
    });

    test('bilingual produces both Arabic and English forms', () {
      final b1 = LocationLocalizer.bilingual('Sadat');
      expect(b1['ar'], equals('السادات'));
      expect(b1['en'], equals('Sadat'));

      final b2 = LocationLocalizer.bilingual('ميدان التحرير');
      expect(b2['ar'], equals('ميدان التحرير'));
      expect(b2['en'], equals('Tahrir Square'));
    });
  });
}
