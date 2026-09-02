import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

class SkillNovaCoordinate {
  const SkillNovaCoordinate(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

enum ExploreSort {
  recommended('Recommended'),
  highestRated('Highest rated'),
  lowestRate('Lowest rate'),
  highestRate('Highest rate'),
  nearest('Nearest');

  const ExploreSort(this.label);
  final String label;
}

class ExploreFilters {
  const ExploreFilters({
    this.category = 'All',
    this.minimumRating = 0,
    this.minimumRate,
    this.maximumRate,
    this.maximumDistanceKm,
  });

  final String category;
  final double minimumRating;
  final double? minimumRate;
  final double? maximumRate;
  final double? maximumDistanceKm;

  bool get isActive =>
      category != 'All' ||
      minimumRating > 0 ||
      minimumRate != null ||
      maximumRate != null ||
      maximumDistanceKm != null;

  int get activeCount => [
    category != 'All',
    minimumRating > 0,
    minimumRate != null || maximumRate != null,
    maximumDistanceKm != null,
  ].where((active) => active).length;
}

class ExploreProfessional {
  const ExploreProfessional({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get name => firstText(data, const ['name'], 'Professional');
  String get skill => firstText(data, const ['skill'], 'Professional service');
  String get city => firstText(data, const ['city', 'location'], '');
  String get photoUrl => firstText(data, const [
    'profileImage',
    'profileImageUrl',
    'photoUrl',
    'imageUrl',
  ], '');
  String get experience =>
      firstText(data, const ['experience', 'experienceYears'], '');
  String get rateText =>
      firstText(data, const ['hourlyRate', 'startingRate'], '');
  double get rating => numberOf(data['rating']) ?? 0;
  int get reviewCount => integerOf(
    data['totalReviews'] ?? data['reviewsCount'] ?? data['reviewCount'],
  );
  double? get numericRate => parseRate(rateText);
  SkillNovaCoordinate? get publicCoordinate => publicWorkerCoordinate(data);

  bool get isEligible {
    final status = firstText(data, const ['accountStatus'], '').toLowerCase();
    final explicitlyBlocked =
        data['isBlocked'] == true || data['blocked'] == true;
    return data['role'] == 'worker' &&
        data['profileCompleted'] == true &&
        data['identityVerificationStatus'] == 'approved' &&
        data['canAcceptJobs'] == true &&
        !explicitlyBlocked &&
        (status.isEmpty || status == 'active');
  }
}

String firstText(
  Map<String, dynamic> data,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return fallback;
}

double? numberOf(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

int integerOf(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? parseRate(String value) {
  if (value.trim().isEmpty) return null;
  final match = RegExp(
    r'\d+(?:[,.]\d+)?',
  ).firstMatch(value.replaceAll(',', ''));
  return double.tryParse(match?.group(0) ?? '');
}

String formatRate(String value) {
  final rate = value.trim();
  if (rate.isEmpty) return '';
  if (rate.toLowerCase().contains('rs')) return rate;
  return 'Rs $rate/hr';
}

SkillNovaCoordinate? customerCoordinate(Map<String, dynamic>? profile) {
  if (profile == null) return null;
  final location = _coordinateFromValue(
    profile['currentLocation'] ?? profile['geoPoint'],
  );
  if (location != null) return location;
  if (profile['locationAdded'] != true) return null;
  return _coordinateFromPair(
    profile['lat'] ?? profile['latitude'],
    profile['lng'] ?? profile['longitude'],
  );
}

String customerLocationLabel(Map<String, dynamic>? profile) {
  if (profile == null) return 'Location unavailable';
  final city = firstText(profile, const ['city'], '');
  final area = firstText(profile, const ['area'], '');
  if (area.isNotEmpty && city.isNotEmpty) return '$area, $city';
  if (city.isNotEmpty) return '$city, Pakistan';
  return firstText(profile, const [
    'location',
    'address',
  ], 'Location unavailable');
}

SkillNovaCoordinate? publicWorkerCoordinate(Map<String, dynamic> worker) {
  final pairs = [
    [worker['publicLat'], worker['publicLng']],
    [worker['serviceAreaLat'], worker['serviceAreaLng']],
    [worker['baseLatitude'], worker['baseLongitude']],
  ];
  for (final pair in pairs) {
    final coordinate = _coordinateFromPair(pair[0], pair[1]);
    if (coordinate != null) return coordinate;
  }

  for (final key in const [
    'publicLocation',
    'serviceAreaLocation',
    'baseLocation',
  ]) {
    final coordinate = _coordinateFromValue(worker[key]);
    if (coordinate != null) return coordinate;
  }

  if (worker['shareLocationOnExplore'] == true) {
    return _coordinateFromPair(
      worker['lat'] ?? worker['latitude'],
      worker['lng'] ?? worker['longitude'],
    );
  }
  return null;
}

SkillNovaCoordinate? _coordinateFromValue(dynamic value) {
  if (value is GeoPoint) {
    return _validatedCoordinate(value.latitude, value.longitude);
  }
  if (value is Map) {
    return _coordinateFromPair(
      value['lat'] ?? value['latitude'],
      value['lng'] ?? value['longitude'],
    );
  }
  return null;
}

SkillNovaCoordinate? _coordinateFromPair(dynamic latitude, dynamic longitude) {
  final lat = numberOf(latitude);
  final lng = numberOf(longitude);
  if (lat == null || lng == null) return null;
  return _validatedCoordinate(lat, lng);
}

SkillNovaCoordinate? _validatedCoordinate(double latitude, double longitude) {
  final coordinate = SkillNovaCoordinate(latitude, longitude);
  return coordinate.isValid ? coordinate : null;
}

double distanceInKilometers(SkillNovaCoordinate from, SkillNovaCoordinate to) {
  const earthRadiusKm = 6371.0;
  final latitudeDelta = _radians(to.latitude - from.latitude);
  final longitudeDelta = _radians(to.longitude - from.longitude);
  final firstLatitude = _radians(from.latitude);
  final secondLatitude = _radians(to.latitude);
  final a =
      math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(firstLatitude) *
          math.cos(secondLatitude) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  final normalized = a.clamp(0.0, 1.0);
  return earthRadiusKm *
      2 *
      math.atan2(math.sqrt(normalized), math.sqrt(1 - normalized));
}

double _radians(double degrees) => degrees * math.pi / 180;
