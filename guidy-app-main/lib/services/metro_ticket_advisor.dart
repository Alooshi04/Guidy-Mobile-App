import 'package:flutter/material.dart';

/// Metro ticket pricing advisor for Cairo Metro.
///
/// Advises commuters on the exact ticket color, price in EGP,
/// and station range to request at the ticket counter based on
/// the number of stations / hops.
///
/// Official Cairo Metro tariff tiers:
/// - 1 to 9 stations (up to 8 hops): 10 EGP (Yellow / صفراء)
/// - 10 to 16 stations (up to 15 hops): 12 EGP (Green / خضراء)
/// - 17 to 23 stations (up to 22 hops): 15 EGP (Pink / وردية)
/// - 24+ stations (23+ hops): 20 EGP (Red / حمراء)
class MetroTicketAdvice {
  final int fareEgp;
  final String colorKey;
  final Color color;
  final String ticketNameAr;
  final String ticketNameEn;
  final int stationCount;

  const MetroTicketAdvice({
    required this.fareEgp,
    required this.colorKey,
    required this.color,
    required this.ticketNameAr,
    required this.ticketNameEn,
    required this.stationCount,
  });

  String adviceText(String lang) {
    if (lang == 'ar') {
      return '$ticketNameAr ($fareEgp جنيه - $stationCount محطات)';
    }
    return '$ticketNameEn ($fareEgp EGP - $stationCount stations)';
  }
}

class MetroTicketAdvisor {
  MetroTicketAdvisor._();

  static MetroTicketAdvice calculate({int stationCount = 1}) {
    final count = stationCount < 1 ? 1 : stationCount;

    if (count <= 9) {
      return MetroTicketAdvice(
        fareEgp: 10,
        colorKey: 'yellow',
        color: const Color(0xFFF4A261),
        ticketNameAr: 'تذكرة صفراء',
        ticketNameEn: 'Yellow Ticket',
        stationCount: count,
      );
    } else if (count <= 16) {
      return MetroTicketAdvice(
        fareEgp: 12,
        colorKey: 'green',
        color: const Color(0xFF2A9D8F),
        ticketNameAr: 'تذكرة خضراء',
        ticketNameEn: 'Green Ticket',
        stationCount: count,
      );
    } else if (count <= 23) {
      return MetroTicketAdvice(
        fareEgp: 15,
        colorKey: 'pink',
        color: const Color(0xFFE76F51),
        ticketNameAr: 'تذكرة وردية',
        ticketNameEn: 'Pink Ticket',
        stationCount: count,
      );
    } else {
      return MetroTicketAdvice(
        fareEgp: 20,
        colorKey: 'red',
        color: const Color(0xFFE63946),
        ticketNameAr: 'تذكرة حمراء',
        ticketNameEn: 'Red Ticket',
        stationCount: count,
      );
    }
  }

}
