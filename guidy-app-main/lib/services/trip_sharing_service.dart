import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Formats and shares trip status and ETA with family or colleagues.
/// Adheres strictly to formal, secular Egyptian Arabic transit phrasing
/// without any religious expressions.
class TripSharingService {
  /// Arabic minutes with the right plural (the share text has no
  /// BuildContext, so it can't use AppLocalizations.minutesCount).
  static String _arMinutes(String raw) {
    final n = int.tryParse(raw.trim()) ?? double.tryParse(raw.trim())?.round();
    if (n == null) return '$raw دقيقة';
    if (n == 1) return 'دقيقة';
    if (n == 2) return 'دقيقتين';
    if (n >= 3 && n <= 10) return '$n دقائق';
    return '$n دقيقة';
  }

  TripSharingService._();

  static const String appUrl = "https://guidyapp.com";

  static Future<void> shareTrip({
    required BuildContext context,
    required String destinationName,
    String? transitMode,
    String? estimatedArrival,
    String? durationMinutes,
    String lang = 'ar',
  }) {
    final String text;
    if (lang == 'ar') {
      final modeText = transitMode != null && transitMode.isNotEmpty
          ? 'بـ$transitMode'
          : 'بالمواصلات العامة';
      final timeText = estimatedArrival != null && estimatedArrival.isNotEmpty
          ? 'وهوصل على الساعة $estimatedArrival تقريبًا'
          : (durationMinutes != null ? 'في حوالي ${_arMinutes(durationMinutes)}' : '');

      text = 'أنا في الطريق لـ$destinationName $modeText $timeText.\n'
          'تقدر تتابع المشوار على تطبيق Guidy:\n'
          '$appUrl';
    } else {
      final modeText = transitMode != null && transitMode.isNotEmpty
          ? 'via $transitMode'
          : 'via public transit';
      final timeText = estimatedArrival != null && estimatedArrival.isNotEmpty
          ? 'estimated arrival around $estimatedArrival'
          : (durationMinutes != null ? 'in about $durationMinutes minutes' : '');

      text = 'I am on my way to $destinationName $modeText $timeText.\n'
          'You can track the trip on Guidy:\n'
          '$appUrl';
    }

    final box = context.findRenderObject() as RenderBox?;
    // ignore: deprecated_member_use
    return Share.share(
      text,
      subject: lang == 'ar' ? 'تفاصيل مشواري' : 'Trip Details',
      sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }
}
