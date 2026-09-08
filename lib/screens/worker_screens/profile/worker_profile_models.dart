import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';

String workerProfileText(
  Map<String, dynamic> data,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return fallback;
}

class WorkerIdentity {
  const WorkerIdentity({
    required this.uid,
    this.authDisplayName = '',
    this.email = '',
    this.emailVerified = false,
    this.phone = '',
    this.createdAt,
  });

  final String uid;
  final String authDisplayName;
  final String email;
  final bool emailVerified;
  final String phone;
  final DateTime? createdAt;

  bool get phoneVerified => phone.isNotEmpty;
}

class WorkerProfile {
  const WorkerProfile({required this.identity, required this.data});

  final WorkerIdentity identity;
  final Map<String, dynamic> data;

  WorkerHomeProfile get eligibilityProfile =>
      WorkerHomeProfile(uid: identity.uid, data: data);
  WorkerReadiness get readiness =>
      WorkerEligibilityAdapter.evaluate(eligibilityProfile);
  WorkerReadiness? get availabilityBlocker =>
      WorkerEligibilityAdapter.availabilityBlocker(eligibilityProfile);

  String get name {
    final stored = workerProfileText(data, const [
      'name',
      'fullName',
      'displayName',
    ]);
    if (stored.isNotEmpty) return stored;
    if (identity.authDisplayName.isNotEmpty) return identity.authDisplayName;
    return 'Professional';
  }

  String get photoUrl => workerProfileText(data, const [
    'profileImageUrl',
    'profileImage',
    'photoUrl',
    'imageUrl',
  ]);
  String get skill => workerProfileText(data, const [
    'skill',
    'mainSkill',
    'category',
  ], 'Professional service');
  String get canonicalSkill => workerProfileText(data, const ['skill']);
  String get bio => workerProfileText(data, const ['bio', 'about']);
  String get experience =>
      workerProfileText(data, const ['experience', 'experienceYears']);
  String get hourlyRate =>
      workerProfileText(data, const ['hourlyRate', 'startingRate', 'rate']);
  String get city => workerProfileText(data, const ['city']);
  String get area => workerProfileText(data, const ['area']);
  String get legacyLocation =>
      workerProfileText(data, const ['location', 'serviceArea']);
  String get serviceArea {
    if (area.isNotEmpty && city.isNotEmpty) return '$area, $city';
    if (city.isNotEmpty) return city;
    if (area.isNotEmpty) return area;
    return legacyLocation;
  }

  int get credits => eligibilityProfile.credits;
  double get rating => eligibilityProfile.rating ?? 0;
  int get reviewCount => eligibilityProfile.reviewCount ?? 0;
  bool get canAcceptJobs => data['canAcceptJobs'] == true;
  bool get profileCompleted => data['profileCompleted'] == true;
  bool get blocked =>
      eligibilityProfile.explicitlyBlocked ||
      const {'blocked', 'suspended'}.contains(accountStatus);
  String get role => workerProfileText(data, const ['role'], 'Unknown');
  String get accountStatus =>
      workerProfileText(data, const ['accountStatus'], 'active').toLowerCase();
  String get rawVerificationStatus => workerProfileText(data, const [
    'identityVerificationStatus',
  ], 'not_submitted').toLowerCase();
  bool get publiclyVisible =>
      readiness.canReceiveLeads && canAcceptJobs && !blocked;

  String get verificationLabel => switch (rawVerificationStatus) {
    'approved' => 'Approved',
    'pending' || 'submitted' || 'under_review' => 'Pending review',
    'rejected' => 'Rejected',
    'more_information_required' => 'More information required',
    _ => 'Not started',
  };

  String get verificationAction => switch (rawVerificationStatus) {
    'approved' ||
    'pending' ||
    'submitted' ||
    'under_review' => 'View verification',
    'rejected' || 'more_information_required' => 'Continue verification',
    _ => 'Start verification',
  };

  DateTime? get createdAt {
    if (identity.createdAt != null) return identity.createdAt;
    final value = data['createdAt'];
    return value is Timestamp
        ? value.toDate()
        : value is DateTime
        ? value
        : null;
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'W';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class WorkerProfileUpdate {
  const WorkerProfileUpdate({
    required this.name,
    required this.skill,
    required this.experience,
    required this.hourlyRate,
    required this.city,
    required this.area,
    required this.bio,
    required this.photoUrl,
  });

  final String name;
  final String skill;
  final String experience;
  final String hourlyRate;
  final String city;
  final String area;
  final String bio;
  final String photoUrl;

  String get serviceArea {
    if (area.isNotEmpty && city.isNotEmpty) return '$area, $city';
    return city.isNotEmpty ? city : area;
  }
}

String? validateWorkerRate(String value) {
  final normalized = value.replaceAll(',', '').trim();
  final rate = double.tryParse(normalized);
  if (rate == null || !rate.isFinite || rate <= 0) {
    return 'Enter a valid positive service rate';
  }
  if (rate > 10000000) return 'Enter a service rate below 10,000,000';
  return null;
}

String normalizedWorkerRate(String value) {
  final rate = double.parse(value.replaceAll(',', '').trim());
  return rate == rate.roundToDouble()
      ? rate.toInt().toString()
      : rate.toStringAsFixed(2);
}
