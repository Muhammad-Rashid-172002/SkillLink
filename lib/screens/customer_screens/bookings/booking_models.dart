import 'package:cloud_firestore/cloud_firestore.dart';

import 'booking_status.dart';

class BookingCoordinate {
  const BookingCoordinate(this.latitude, this.longitude);

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

class CustomerBooking {
  const CustomerBooking({
    required this.id,
    required this.data,
    this.worker,
    this.review,
  });

  final String id;
  final Map<String, dynamic> data;
  final Map<String, dynamic>? worker;
  final Map<String, dynamic>? review;

  BookingStatusPresentation get status => bookingStatusOf(data['status']);
  String get workerId => bookingText(data, const ['workerId']);
  String get service => bookingText(data, const [
    'category',
    'serviceName',
    'title',
  ], fallback: 'Service request');
  String get title =>
      bookingText(data, const ['title', 'category'], fallback: service);
  String get description => bookingText(data, const ['description']);
  String get location => bookingText(data, const ['location', 'address']);
  String get urgency => bookingText(data, const ['urgency']);
  String get notes => bookingText(data, const ['notes']);
  String get budget => bookingText(data, const ['budget']);
  String get cancellationReason => bookingText(data, const [
    'cancellationReason',
    'cancelReason',
    'cancelledReason',
  ]);
  DateTime? get createdAt => bookingDate(data['createdAt']);
  DateTime? get completedAt =>
      bookingDate(data['completedAt']) ?? bookingDate(data['updatedAt']);
  DateTime? get cancelledAt =>
      bookingDate(data['cancelledAt']) ?? bookingDate(data['updatedAt']);
  List<String> get imageUrls => bookingImageUrls(data['imageUrls']);
  BookingCoordinate? get customerCoordinate => bookingCoordinate(
    data['customerLocation'],
    latitude: data['latitude'] ?? data['lat'],
    longitude: data['longitude'] ?? data['lng'],
  );
  BookingCoordinate? get workerTrackingCoordinate {
    if (status.semantic != BookingSemanticStatus.onTheWay) return null;
    if (bookingDate(worker?['locationUpdatedAt']) == null) return null;
    return bookingCoordinate(
      worker?['currentLocation'],
      latitude: worker?['lat'] ?? worker?['latitude'],
      longitude: worker?['lng'] ?? worker?['longitude'],
    );
  }

  String get workerName => bookingText(worker ?? data, const [
    'name',
    'workerName',
  ], fallback: 'Assigned professional');
  String get workerSkill => bookingText(worker ?? data, const [
    'skill',
    'workerSkill',
  ], fallback: service);
  String get workerPhoto => bookingText(worker ?? data, const [
    'profileImage',
    'profileImageUrl',
    'photoUrl',
    'workerImage',
  ]);
  String get workerPhone => bookingText(worker ?? data, const [
    'phone',
    'phoneNumber',
    'workerPhone',
  ]);
  double? get workerRating => bookingNumber(worker?['rating']);
  bool get workerVerified =>
      worker?['identityVerificationStatus'] == 'approved';

  bool get hasReview => data['reviewed'] == true || review != null;
  double? get submittedRating => bookingNumber(review?['rating']);
}

String bookingText(
  Map<String, dynamic>? data,
  List<String> keys, {
  String fallback = '',
}) {
  if (data == null) return fallback;
  for (final key in keys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return fallback;
}

double? bookingNumber(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

DateTime? bookingDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

List<String> bookingImageUrls(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

BookingCoordinate? bookingCoordinate(
  dynamic value, {
  dynamic latitude,
  dynamic longitude,
}) {
  if (value is GeoPoint) {
    return _validCoordinate(value.latitude, value.longitude);
  }
  if (value is Map) {
    final nested = bookingCoordinate(
      null,
      latitude: value['lat'] ?? value['latitude'],
      longitude: value['lng'] ?? value['longitude'],
    );
    if (nested != null) return nested;
  }
  final lat = bookingNumber(latitude);
  final lng = bookingNumber(longitude);
  if (lat == null || lng == null) return null;
  return _validCoordinate(lat, lng);
}

BookingCoordinate? _validCoordinate(double latitude, double longitude) {
  final coordinate = BookingCoordinate(latitude, longitude);
  return coordinate.isValid ? coordinate : null;
}

String bookingDateLabel(DateTime? date, {bool includeTime = false}) {
  if (date == null) return '';
  final local = date.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final dateText = '${months[local.month - 1]} ${local.day}, ${local.year}';
  if (!includeTime) return dateText;
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$dateText • $hour:$minute $period';
}

String formatPostedBudget(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  if (value.toLowerCase().startsWith('rs')) return value;
  return 'Rs $value';
}
