/// A fare amount as riders read it: "5.5", "5", "12.25" -- never "5.0",
/// and never rounded down to a whole pound (5.5 EGP showed as 5).
String fareAmount(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  var s = value.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
