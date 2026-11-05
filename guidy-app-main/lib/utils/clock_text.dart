import 'package:flutter/material.dart';

/// [text] with Arabic-Indic and Persian digits as 0-9.
///
/// The app writes every other number in Western digits in Arabic too
/// ("32 دقيقة", "5 جنيه"); the platform's clock text used ٦:٣٢ and read as a
/// different number system beside them.
String westernDigits(String text) => text.replaceAllMapped(
      RegExp('[\u0660-\u0669\u06F0-\u06F9]'),
      (m) {
        final unit = m[0]!.codeUnitAt(0);
        return String.fromCharCode(unit >= 0x06F0 ? unit - 0x06F0 + 0x30 : unit - 0x0660 + 0x30);
      },
    );

/// A time of day as the rider reads it, in the app's language: "6:32 AM",
/// "6:32 ص".
String clockText(BuildContext context, TimeOfDay time) =>
    westernDigits(MaterialLocalizations.of(context).formatTimeOfDay(time));
