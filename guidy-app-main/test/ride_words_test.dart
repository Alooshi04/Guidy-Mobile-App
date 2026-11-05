import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/step_action.dart';
import 'package:guidy_app/services/step_copy.dart';
import 'package:guidy_app/utils/ride_words.dart';

// Every mode, with and without a line number, EN and AR: road vehicles take
// "a"/no article, fixed lines keep "the", a numbered line reads as a name.
Map<String, dynamic> _step(String vehicleType, {String? number, String? routeId}) => {
      'action': 'board',
      'vehicle_type': vehicleType,
      'route_number': ?number,
      'route_id': ?routeId,
      'station': 'Sadat',
      'alight_station': 'Nasr City',
    };

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  group('English', () {
    final cases = <(String, Map<String, dynamic>, String, String)>[
      // (name, step, thing, action)
      ('bus', _step('bus'), 'a bus', 'Take a bus'),
      ('minibus', _step('minibus'), 'a minibus', 'Take a minibus'),
      ('microbus', _step('microbus'), 'a microbus', 'Take a microbus'),
      ('bus 1064', _step('bus', number: '1064'), 'bus 1064', 'Take bus 1064'),
      ('microbus 24', _step('microbus', number: '24'), 'microbus 24', 'Take microbus 24'),
      ('minibus 66', _step('minibus', number: '66'), 'minibus 66', 'Take minibus 66'),
      ('metro', _step('metro'), 'the metro', 'Ride the metro'),
      ('metro line 2', _step('metro', routeId: 'METRO_L2'), 'Metro Line 2', 'Take Metro Line 2'),
      ('monorail', _step('monorail'), 'the monorail', 'Ride the monorail'),
      ('lrt', _step('lrt'), 'the LRT', 'Ride the LRT'),
      ('tram', _step('tram'), 'the tram', 'Ride the tram'),
    ];
    for (final (name, step, thing, action) in cases) {
      test(name, () {
        expect(RideWords.thing(en, step), thing);
        expect(RideWords.action(en, step), action);
      });
    }

    test('mid-sentence the verb is lower case', () {
      expect(RideWords.action(en, _step('microbus'), lowerFirst: true), 'take a microbus');
      expect(RideWords.action(en, _step('metro', routeId: 'METRO_L1'), lowerFirst: true), 'take Metro Line 1');
      expect(en.navWalkThenBoard(RideWords.action(en, _step('bus', number: '27'), lowerFirst: true)), 'Then take bus 27');
    });

    test('the sentences the app builds read naturally', () {
      expect(StepCopy.of(en, [_step('microbus')], 0).title, 'Take a microbus');
      expect(StepCopy.of(en, [_step('bus', number: '1064')], 0).title, 'Take bus 1064');
      expect(StepCopy.of(en, [_step('metro')], 0).title, 'Ride the metro');
      expect(en.navRiding(RideWords.thing(en, _step('microbus'))), 'On a microbus');
      expect(en.navRiding(RideWords.thing(en, _step('metro', routeId: 'METRO_L1'))), 'On Metro Line 1');
      expect(en.simpleRideTo(RideWords.action(en, _step('minibus')), 'Nasr City'), 'Take a minibus to Nasr City');
      expect(en.actWaveDown(RideWords.thing(en, _step('microbus'))), 'Wave down a microbus on');
      expect(en.instrBoardTitleWithVehicle(RideWords.thing(en, _step('bus'))), 'Board a bus');
    });

    test('the transit header says the same', () {
      final hail = {..._step('microbus'), 'hail': true};
      expect(StepAction.of(en, [hail], 0).header, 'Wave down a microbus on');
      final stop = _step('bus', number: '871');
      expect(StepAction.of(en, [stop], 0).header, 'Take bus 871 at');
    });
  });

  group('Arabic', () {
    test('road vehicles are the bare noun, fixed lines keep their own "ال"', () {
      expect(RideWords.action(ar, _step('microbus')), 'اركب ميكروباص');
      expect(RideWords.action(ar, _step('minibus')), 'اركب ميني باص');
      expect(RideWords.action(ar, _step('bus')), 'اركب أتوبيس');
      expect(RideWords.action(ar, _step('metro')), 'اركب المترو');
      expect(RideWords.action(ar, _step('monorail')), 'اركب المونوريل');
      expect(RideWords.action(ar, _step('lrt')), 'اركب القطار الكهربائي الخفيف');
    });

    test('numbered lines and metro lines', () {
      expect(RideWords.action(ar, _step('bus', number: '1064')), 'اركب أتوبيس رقم 1064');
      expect(RideWords.action(ar, _step('microbus', number: '24')), 'اركب ميكروباص رقم 24');
      expect(RideWords.action(ar, _step('metro', routeId: 'METRO_L2')), 'اركب الخط التاني');
    });

    test('sentences', () {
      expect(ar.navWalkThenBoard(RideWords.action(ar, _step('microbus'), lowerFirst: true)), 'وبعدين اركب ميكروباص');
      expect(ar.simpleRideTo(RideWords.action(ar, _step('bus')), 'مدينة نصر'), 'اركب أتوبيس لحد مدينة نصر');
      expect(ar.navRiding(RideWords.thing(ar, _step('microbus'))), 'راكب ميكروباص');
    });
  });
}
