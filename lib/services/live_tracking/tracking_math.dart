// Pure Dart helpers (no Flutter/Firebase imports) so they can be unit tested
// with `dart test` as well as `flutter test`.

/// Decodes a Google encoded polyline (precision 5).
List<(double, double)> decodePolyline(String encoded) {
  final points = <(double, double)>[];
  var index = 0;
  var lat = 0;
  var lng = 0;
  while (index < encoded.length) {
    int decodeValue() {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        if (index >= encoded.length) return 0;
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      // `-(n) - 1` instead of `~n`: on the web `~` yields an unsigned 32-bit
      // value, which broke negative deltas.
      return (result & 1) != 0 ? -(result >> 1) - 1 : (result >> 1);
    }

    lat += decodeValue();
    lng += decodeValue();
    points.add((lat / 1e5, lng / 1e5));
  }
  return points;
}

/// "4.2 km" / "650 m".
String formatTrackingDistance(double meters) {
  if (meters < 1000) return '${(meters / 10).round() * 10} m';
  final km = meters / 1000;
  return '${km < 10 ? km.toStringAsFixed(1) : km.round()} km';
}
