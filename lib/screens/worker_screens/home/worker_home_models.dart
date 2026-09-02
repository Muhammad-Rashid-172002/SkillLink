import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

String workerText(
  Map<String, dynamic> data,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return fallback;
}

int workerInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? workerDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

DateTime? workerDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String normalizeWorkerCategory(String value) {
  final normalized = value
      .toLowerCase()
      .trim()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  const aliases = <String, String>{
    'electric': 'electrician',
    'electrical': 'electrician',
    'electrical work': 'electrician',
    'electric work': 'electrician',
    'electrician service': 'electrician',
    'ac': 'ac technician',
    'air conditioner': 'ac technician',
    'air conditioning': 'ac technician',
    'ac repair': 'ac technician',
    'ac service': 'ac technician',
    'hvac': 'ac technician',
    'plumbing': 'plumber',
    'plumber service': 'plumber',
    'painting': 'painter',
    'home painter': 'painter',
    'paint work': 'painter',
    'carpentry': 'carpenter',
    'wood work': 'carpenter',
    'woodwork': 'carpenter',
    'cleaning': 'cleaner',
    'home cleaning': 'cleaner',
    'appliance repair': 'appliance technician',
    'mobile repair': 'mobile technician',
    'phone repair': 'mobile technician',
  };
  return aliases[normalized] ?? normalized;
}

enum WorkerVerificationState { notStarted, pending, approved, rejected }

enum WorkerReadinessState {
  ready,
  needsCredits,
  incompleteProfile,
  verificationPending,
  verificationRejected,
  verificationRequired,
  acceptanceDisabled,
  blocked,
  inactive,
  invalidRole,
  missingSkill,
}

class WorkerHomeProfile {
  const WorkerHomeProfile({required this.uid, required this.data});

  final String uid;
  final Map<String, dynamic> data;

  String get name => workerText(data, const [
    'name',
    'fullName',
    'displayName',
  ], fallback: 'Professional');
  String get firstName => name.split(RegExp(r'\s+')).first;
  String get skill => workerText(data, const [
    'skill',
    'mainSkill',
    'category',
  ], fallback: 'Professional service');
  String get querySkill =>
      workerText(data, const ['skill', 'mainSkill', 'category']);
  String get photoUrl => workerText(data, const [
    'profileImage',
    'profileImageUrl',
    'photoUrl',
    'imageUrl',
  ]);
  bool get profileCompleted => data['profileCompleted'] == true;
  bool get canAcceptJobs => data['canAcceptJobs'] == true;
  bool get explicitlyBlocked =>
      data['isBlocked'] == true ||
      data['blocked'] == true ||
      data['isDisabled'] == true;
  String get accountStatus =>
      workerText(data, const ['accountStatus']).toLowerCase();
  int get credits => workerInt(data['credits'] ?? data['leadCredits']);
  double? get rating => workerDouble(
    data['rating'] ?? data['averageRating'] ?? data['avgRating'],
  );
  int? get reviewCount =>
      _optionalInt(data, const ['totalReviews', 'reviewsCount', 'reviewCount']);
  int? get completedJobs => _optionalInt(data, const [
    'completedJobs',
    'completedJobCount',
    'jobsCompleted',
  ]);

  WorkerVerificationState get verification {
    final value = workerText(data, const [
      'identityVerificationStatus',
    ], fallback: 'not_submitted').toLowerCase();
    if (value == 'approved') return WorkerVerificationState.approved;
    if (value == 'pending' || value == 'submitted' || value == 'under_review') {
      return WorkerVerificationState.pending;
    }
    if (value == 'rejected' || value == 'more_information_required') {
      return WorkerVerificationState.rejected;
    }
    return WorkerVerificationState.notStarted;
  }

  WorkerCoordinate? get coordinate => WorkerCoordinate.from(
    data['currentLocation'] ?? data['geoPoint'],
    latitude: data['lat'] ?? data['latitude'],
    longitude: data['lng'] ?? data['longitude'],
  );

  String get initials {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'W';
    return parts.length == 1
        ? parts.first.substring(0, 1).toUpperCase()
        : '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
              .toUpperCase();
  }
}

int? _optionalInt(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    if (data[key] != null) return workerInt(data[key]);
  }
  return null;
}

class WorkerReadiness {
  const WorkerReadiness({
    required this.state,
    required this.title,
    required this.message,
  });

  final WorkerReadinessState state;
  final String title;
  final String message;

  bool get canReceiveLeads =>
      state == WorkerReadinessState.ready ||
      state == WorkerReadinessState.needsCredits;
  bool get canAcceptLead => state == WorkerReadinessState.ready;
  bool get needsVerification => switch (state) {
    WorkerReadinessState.verificationPending ||
    WorkerReadinessState.verificationRejected ||
    WorkerReadinessState.verificationRequired => true,
    _ => false,
  };
}

abstract final class WorkerEligibilityAdapter {
  static WorkerReadiness evaluate(WorkerHomeProfile worker) {
    if (worker.explicitlyBlocked ||
        worker.accountStatus == 'blocked' ||
        worker.accountStatus == 'suspended') {
      return const WorkerReadiness(
        state: WorkerReadinessState.blocked,
        title: 'Account access restricted',
        message:
            'Your account cannot receive new work. Contact SkillNova support for help.',
      );
    }
    if (worker.accountStatus.isNotEmpty && worker.accountStatus != 'active') {
      return const WorkerReadiness(
        state: WorkerReadinessState.inactive,
        title: 'Account is not active',
        message: 'New work is unavailable while your account is inactive.',
      );
    }
    if (worker.data['role'] != 'worker') {
      return const WorkerReadiness(
        state: WorkerReadinessState.invalidRole,
        title: 'Worker account required',
        message: 'This profile is not configured as a worker account.',
      );
    }
    if (!worker.profileCompleted) {
      return const WorkerReadiness(
        state: WorkerReadinessState.incompleteProfile,
        title: 'Complete your worker profile',
        message: 'Finish the required worker setup before receiving new work.',
      );
    }
    if (worker.querySkill.isEmpty) {
      return const WorkerReadiness(
        state: WorkerReadinessState.missingSkill,
        title: 'Add your primary skill',
        message: 'A primary skill is required to find relevant customer leads.',
      );
    }
    switch (worker.verification) {
      case WorkerVerificationState.pending:
        return const WorkerReadiness(
          state: WorkerReadinessState.verificationPending,
          title: 'Verification under review',
          message:
              'You can view your review status while job acceptance remains locked.',
        );
      case WorkerVerificationState.rejected:
        return const WorkerReadiness(
          state: WorkerReadinessState.verificationRejected,
          title: 'Verification needs attention',
          message:
              'Review the verification request and resubmit the required documents.',
        );
      case WorkerVerificationState.notStarted:
        return const WorkerReadiness(
          state: WorkerReadinessState.verificationRequired,
          title: 'Complete identity verification',
          message:
              'Verified identity is required before accepting customer work.',
        );
      case WorkerVerificationState.approved:
        break;
    }
    if (!worker.canAcceptJobs) {
      return const WorkerReadiness(
        state: WorkerReadinessState.acceptanceDisabled,
        title: 'Not accepting new jobs',
        message:
            'Your profile is verified, but job acceptance is currently disabled.',
      );
    }
    if (worker.credits <= 0) {
      return const WorkerReadiness(
        state: WorkerReadinessState.needsCredits,
        title: 'Add lead credits to accept jobs',
        message:
            'Your profile can receive eligible leads, but accepting one requires a lead credit.',
      );
    }
    return const WorkerReadiness(
      state: WorkerReadinessState.ready,
      title: 'Ready for new jobs',
      message:
          'Your verified profile can receive and accept eligible customer leads.',
    );
  }
}

class WorkerCoordinate {
  const WorkerCoordinate(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  static WorkerCoordinate? from(
    dynamic value, {
    dynamic latitude,
    dynamic longitude,
  }) {
    WorkerCoordinate? coordinate;
    if (value is GeoPoint) {
      coordinate = WorkerCoordinate(value.latitude, value.longitude);
    } else if (value is Map) {
      coordinate = WorkerCoordinate(
        workerDouble(value['lat'] ?? value['latitude']) ?? double.nan,
        workerDouble(value['lng'] ?? value['longitude']) ?? double.nan,
      );
    } else {
      coordinate = WorkerCoordinate(
        workerDouble(latitude) ?? double.nan,
        workerDouble(longitude) ?? double.nan,
      );
    }
    return coordinate.isValid ? coordinate : null;
  }
}

class WorkerLeadPreview {
  const WorkerLeadPreview({
    required this.id,
    required this.data,
    this.distanceKm,
  });

  final String id;
  final Map<String, dynamic> data;
  final double? distanceKm;

  String get title => workerText(data, const [
    'title',
    'category',
  ], fallback: 'Service request');
  String get category => workerText(data, const [
    'category',
    'service',
    'serviceType',
  ], fallback: 'Service');
  String get location => workerText(data, const [
    'location',
    'address',
  ], fallback: 'Location not provided');
  String get urgency => workerText(data, const ['urgency']);
  String get budget => workerText(data, const ['budget']);
  DateTime? get createdAt => workerDate(data['createdAt']);
  String get workerId => workerText(data, const ['workerId']);
  String get status => workerText(data, const ['status']).toLowerCase();

  bool isEligibleFor(WorkerHomeProfile worker) =>
      status == 'searching' &&
      (workerId.isEmpty || workerId == worker.uid) &&
      normalizeWorkerCategory(category) ==
          normalizeWorkerCategory(worker.querySkill);

  WorkerLeadPreview withDistance(double? value) =>
      WorkerLeadPreview(id: id, data: data, distanceKm: value);
}

class WorkerActiveJob {
  const WorkerActiveJob({
    required this.id,
    required this.data,
    this.customerName = 'Customer',
  });
  final String id;
  final Map<String, dynamic> data;
  final String customerName;

  String get status => workerText(data, const ['status']).toLowerCase();
  String get title =>
      workerText(data, const ['title', 'category'], fallback: 'Service job');
  String get category =>
      workerText(data, const ['category', 'service'], fallback: 'Service');
  String get location => workerText(data, const [
    'location',
    'address',
  ], fallback: 'Location not provided');
  String get budget => workerText(data, const ['budget']);
  String get urgency => workerText(data, const ['urgency'], fallback: 'Normal');
  DateTime? get acceptedAt =>
      workerDate(data['acceptedAt'] ?? data['updatedAt'] ?? data['createdAt']);

  int get priority => switch (status) {
    'in_progress' => 3,
    'on_the_way' => 2,
    'accepted' => 1,
    _ => 0,
  };
}

class WorkerActiveJobsSnapshot {
  const WorkerActiveJobsSnapshot({
    this.featured,
    this.hasAdditionalJobs = false,
  });
  final WorkerActiveJob? featured;
  final bool hasAdditionalJobs;
}

double workerDistanceKm(WorkerCoordinate from, WorkerCoordinate to) {
  const radius = 6371.0;
  double radians(double degrees) => degrees * math.pi / 180;
  final dLat = radians(to.latitude - from.latitude);
  final dLng = radians(to.longitude - from.longitude);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(radians(from.latitude)) *
          math.cos(radians(to.latitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return radius *
      2 *
      math.atan2(math.sqrt(a.clamp(0, 1)), math.sqrt(1 - a.clamp(0, 1)));
}
