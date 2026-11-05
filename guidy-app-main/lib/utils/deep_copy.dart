/// A copy of decoded JSON (maps, lists and plain values) that shares
/// nothing with the original, so a screen can change its copy without
/// changing the screen or cache it came from.
dynamic deepCopyJson(dynamic v) {
  if (v is Map) return <String, dynamic>{for (final e in v.entries) e.key.toString(): deepCopyJson(e.value)};
  if (v is List) return [for (final x in v) deepCopyJson(x)];
  return v;
}

Map<String, dynamic> deepCopyMap(Map v) => deepCopyJson(v) as Map<String, dynamic>;
