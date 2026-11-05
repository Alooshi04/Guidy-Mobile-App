import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/metro_ticket_advisor.dart';

void main() {
  group('MetroTicketAdvisor', () {
    test('1-9 stations returns Yellow ticket (10 EGP)', () {
      final advice1 = MetroTicketAdvisor.calculate(stationCount: 1);
      expect(advice1.fareEgp, 10);
      expect(advice1.colorKey, 'yellow');

      final advice9 = MetroTicketAdvisor.calculate(stationCount: 9);
      expect(advice9.fareEgp, 10);
      expect(advice9.colorKey, 'yellow');
    });

    test('10-16 stations returns Green ticket (12 EGP)', () {
      final advice10 = MetroTicketAdvisor.calculate(stationCount: 10);
      expect(advice10.fareEgp, 12);
      expect(advice10.colorKey, 'green');

      final advice16 = MetroTicketAdvisor.calculate(stationCount: 16);
      expect(advice16.fareEgp, 12);
      expect(advice16.colorKey, 'green');
    });

    test('17-23 stations returns Pink ticket (15 EGP)', () {
      final advice17 = MetroTicketAdvisor.calculate(stationCount: 17);
      expect(advice17.fareEgp, 15);
      expect(advice17.colorKey, 'pink');

      final advice23 = MetroTicketAdvisor.calculate(stationCount: 23);
      expect(advice23.fareEgp, 15);
      expect(advice23.colorKey, 'pink');
    });

    test('24+ stations returns Red ticket (20 EGP)', () {
      final advice24 = MetroTicketAdvisor.calculate(stationCount: 24);
      expect(advice24.fareEgp, 20);
      expect(advice24.colorKey, 'red');

      final advice30 = MetroTicketAdvisor.calculate(stationCount: 30);
      expect(advice30.fareEgp, 20);
      expect(advice30.colorKey, 'red');
    });
  });
}
