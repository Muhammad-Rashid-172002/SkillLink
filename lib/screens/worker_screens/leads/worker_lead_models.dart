import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';

enum WorkerLeadsView { list, map }

enum WorkerLeadSort {
  recommended('Recommended'),
  newest('Newest'),
  nearest('Nearest'),
  highestBudget('Highest posted budget'),
  lowestBudget('Lowest posted budget');

  const WorkerLeadSort(this.label);
  final String label;
}

enum WorkerLeadPostedWithin {
  any('Any time'),
  day('Past 24 hours'),
  week('Past 7 days');

  const WorkerLeadPostedWithin(this.label);
  final String label;
}

class WorkerLeadFilters {
  const WorkerLeadFilters({
    this.category,
    this.urgency,
    this.minimumBudget,
    this.maximumBudget,
    this.maximumDistanceKm,
    this.postedWithin = WorkerLeadPostedWithin.any,
  });

  final String? category;
  final String? urgency;
  final double? minimumBudget;
  final double? maximumBudget;
  final double? maximumDistanceKm;
  final WorkerLeadPostedWithin postedWithin;

  bool get isActive =>
      category != null ||
      urgency != null ||
      minimumBudget != null ||
      maximumBudget != null ||
      maximumDistanceKm != null ||
      postedWithin != WorkerLeadPostedWithin.any;

  int get activeCount => [
    category != null,
    urgency != null,
    minimumBudget != null || maximumBudget != null,
    maximumDistanceKm != null,
    postedWithin != WorkerLeadPostedWithin.any,
  ].where((active) => active).length;
}

class WorkerLeadCustomer {
  const WorkerLeadCustomer({
    required this.id,
    this.name = 'Customer',
    this.photoUrl = '',
    this.city = '',
    this.area = '',
  });

  final String id;
  final String name;
  final String photoUrl;
  final String city;
  final String area;

  String get publicName {
    final clean = name.trim();
    if (clean.isEmpty) return 'Customer';
    return clean.split(RegExp(r'\s+')).first;
  }

  String get serviceArea {
    if (area.isNotEmpty && city.isNotEmpty) return '$area, $city';
    if (city.isNotEmpty) return city;
    if (area.isNotEmpty) return area;
    return '';
  }

  String get initials {
    final clean = publicName.trim();
    return clean.isEmpty ? 'C' : clean.substring(0, 1).toUpperCase();
  }

  factory WorkerLeadCustomer.from(String id, Map<String, dynamic> data) {
    return WorkerLeadCustomer(
      id: id,
      name: workerText(data, const [
        'name',
        'displayName',
        'fullName',
      ], fallback: 'Customer'),
      photoUrl: workerText(data, const [
        'profileImage',
        'profileImageUrl',
        'photoUrl',
      ]),
      city: workerText(data, const ['city']),
      area: workerText(data, const ['area']),
    );
  }
}

class WorkerLead {
  const WorkerLead({
    required this.id,
    required this.data,
    this.customer,
    this.distanceKm,
  });

  final String id;
  final Map<String, dynamic> data;
  final WorkerLeadCustomer? customer;
  final double? distanceKm;

  String get title => workerText(
    data,
    const ['title'],
    fallback: workerText(data, const [
      'category',
      'service',
      'serviceType',
    ], fallback: 'Service request'),
  );
  String get category => workerText(data, const [
    'category',
    'service',
    'serviceType',
    'skill',
  ], fallback: 'Service');
  String get description => workerText(data, const [
    'description',
    'details',
  ], fallback: 'No additional description was provided.');
  String get notes => workerText(data, const ['notes', 'additionalNotes']);
  String get urgency => workerText(data, const ['urgency'], fallback: 'Normal');
  String get status => workerText(data, const ['status']).toLowerCase();
  String get assignedWorkerId =>
      workerText(data, const ['workerId', 'assignedWorkerId']);
  String get customerId => workerText(data, const ['customerId']);
  DateTime? get createdAt => workerDate(data['createdAt']);
  double? get budgetValue => _moneyValue(data['budget']);
  String get postedBudget {
    final raw = workerText(data, const ['budget']);
    if (raw.isEmpty) return 'Not provided';
    if (raw.toLowerCase().startsWith('rs')) return raw;
    return 'Rs. $raw';
  }

  String get privateLocation => workerText(data, const [
    'location',
    'address',
  ], fallback: 'Location not provided');

  String get publicServiceArea {
    final requestArea = workerText(data, const ['serviceArea', 'area', 'city']);
    if (requestArea.isNotEmpty) return requestArea;
    final customerArea = customer?.serviceArea ?? '';
    return customerArea.isEmpty
        ? 'Location shared after acceptance'
        : customerArea;
  }

  WorkerCoordinate? get coordinate => WorkerCoordinate.from(
    data['customerLocation'] ?? data['geoPoint'] ?? data['locationPoint'],
    latitude: data['latitude'] ?? data['lat'],
    longitude: data['longitude'] ?? data['lng'],
  );

  /// The map intentionally shows an approximate service-area pin before the
  /// worker accepts the lead. Distance still uses the original valid point.
  WorkerCoordinate? get approximateMapCoordinate {
    final point = coordinate;
    if (point == null) return null;
    double roundArea(double value) => (value * 100).roundToDouble() / 100;
    return WorkerCoordinate(
      roundArea(point.latitude),
      roundArea(point.longitude),
    );
  }

  List<String> get imageUrls {
    final raw = data['imageUrls'] ?? data['images'] ?? data['requestImages'];
    if (raw is! List) return const [];
    return raw
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.startsWith('http'))
        .take(5)
        .toList(growable: false);
  }

  bool isVisibleTo(WorkerHomeProfile worker) {
    return status == 'searching' &&
        (assignedWorkerId.isEmpty || assignedWorkerId == worker.uid) &&
        workerLeadCategoriesMatch(category, worker.querySkill);
  }

  bool get isAvailable => status == 'searching';

  WorkerLead copyWith({
    WorkerLeadCustomer? customer,
    double? distanceKm,
    bool preserveDistance = true,
  }) {
    return WorkerLead(
      id: id,
      data: data,
      customer: customer ?? this.customer,
      distanceKm: preserveDistance ? distanceKm ?? this.distanceKm : distanceKm,
    );
  }
}

class WorkerLeadDetailData {
  const WorkerLeadDetailData({required this.lead});
  final WorkerLead lead;
}

enum WorkerLeadAcceptanceFailure {
  signedOut,
  workerMissing,
  workerIneligible,
  insufficientCredits,
  leadMissing,
  unavailable,
  skillMismatch,
  network,
  unknown,
}

class WorkerLeadAcceptanceException implements Exception {
  const WorkerLeadAcceptanceException(this.failure, this.message);
  final WorkerLeadAcceptanceFailure failure;
  final String message;

  @override
  String toString() => message;
}

class WorkerLeadAcceptancePlan {
  const WorkerLeadAcceptancePlan({
    required this.workerId,
    required this.balanceBefore,
  });

  final String workerId;
  final int balanceBefore;
  int get balanceAfter => balanceBefore - 1;
  String get nextStatus => 'accepted';
}

WorkerLeadAcceptancePlan planWorkerLeadAcceptance({
  required String workerId,
  required Map<String, dynamic>? workerData,
  required String requestId,
  required Map<String, dynamic>? requestData,
}) {
  if (workerId.trim().isEmpty) {
    throw const WorkerLeadAcceptanceException(
      WorkerLeadAcceptanceFailure.signedOut,
      'Please sign in again before accepting a lead.',
    );
  }
  if (workerData == null) {
    throw const WorkerLeadAcceptanceException(
      WorkerLeadAcceptanceFailure.workerMissing,
      'Your worker profile could not be found.',
    );
  }
  if (requestData == null) {
    throw const WorkerLeadAcceptanceException(
      WorkerLeadAcceptanceFailure.leadMissing,
      'This lead is no longer available.',
    );
  }
  final worker = WorkerHomeProfile(uid: workerId, data: workerData);
  final readiness = WorkerEligibilityAdapter.evaluate(worker);
  if (readiness.state == WorkerReadinessState.needsCredits) {
    throw const WorkerLeadAcceptanceException(
      WorkerLeadAcceptanceFailure.insufficientCredits,
      'You need at least 1 lead credit to accept this lead.',
    );
  }
  if (!readiness.canAcceptLead) {
    throw WorkerLeadAcceptanceException(
      WorkerLeadAcceptanceFailure.workerIneligible,
      readiness.message,
    );
  }
  final lead = WorkerLead(id: requestId, data: requestData);
  if (lead.status != 'searching' ||
      (lead.assignedWorkerId.isNotEmpty && lead.assignedWorkerId != workerId)) {
    throw const WorkerLeadAcceptanceException(
      WorkerLeadAcceptanceFailure.unavailable,
      'This lead was changed or accepted by another worker.',
    );
  }
  if (!workerLeadCategoriesMatch(lead.category, worker.querySkill)) {
    throw const WorkerLeadAcceptanceException(
      WorkerLeadAcceptanceFailure.skillMismatch,
      'This lead no longer matches your primary skill.',
    );
  }
  if (worker.credits < 1) {
    throw const WorkerLeadAcceptanceException(
      WorkerLeadAcceptanceFailure.insufficientCredits,
      'You need at least 1 lead credit to accept this lead.',
    );
  }
  return WorkerLeadAcceptancePlan(
    workerId: workerId,
    balanceBefore: worker.credits,
  );
}

class WorkerLeadEligibility {
  const WorkerLeadEligibility({
    required this.canAccept,
    required this.title,
    required this.message,
    this.needsCredits = false,
  });

  final bool canAccept;
  final bool needsCredits;
  final String title;
  final String message;

  factory WorkerLeadEligibility.evaluate(
    WorkerHomeProfile worker,
    WorkerLead lead,
  ) {
    final readiness = WorkerEligibilityAdapter.evaluate(worker);
    if (!readiness.canAcceptLead) {
      return WorkerLeadEligibility(
        canAccept: false,
        needsCredits: readiness.state == WorkerReadinessState.needsCredits,
        title: readiness.title,
        message: readiness.message,
      );
    }
    if (lead.status != 'searching') {
      return const WorkerLeadEligibility(
        canAccept: false,
        title: 'Lead no longer available',
        message: 'This request has changed or was accepted by another worker.',
      );
    }
    if (lead.assignedWorkerId.isNotEmpty &&
        lead.assignedWorkerId != worker.uid) {
      return const WorkerLeadEligibility(
        canAccept: false,
        title: 'Lead assigned to another worker',
        message: 'This request is no longer available for acceptance.',
      );
    }
    if (!workerLeadCategoriesMatch(lead.category, worker.querySkill)) {
      return const WorkerLeadEligibility(
        canAccept: false,
        title: 'Skill does not match',
        message: 'This lead does not match the primary skill on your profile.',
      );
    }
    return const WorkerLeadEligibility(
      canAccept: true,
      title: 'Eligible to accept',
      message: 'Accepting this lead uses 1 lead credit.',
    );
  }
}

List<WorkerLead> filterAndSortWorkerLeads({
  required List<WorkerLead> leads,
  required String search,
  required WorkerLeadFilters filters,
  required WorkerLeadSort sort,
  DateTime? now,
}) {
  final query = search.trim().toLowerCase();
  final clock = now ?? DateTime.now();
  final filtered = leads
      .where((lead) {
        if (query.isNotEmpty) {
          final searchable = [
            lead.title,
            lead.category,
            lead.description,
            lead.publicServiceArea,
          ].join(' ').toLowerCase();
          if (!searchable.contains(query)) return false;
        }
        if (filters.category != null &&
            normalizeWorkerCategory(lead.category) !=
                normalizeWorkerCategory(filters.category!)) {
          return false;
        }
        if (filters.urgency != null &&
            lead.urgency.toLowerCase() != filters.urgency!.toLowerCase()) {
          return false;
        }
        final budget = lead.budgetValue;
        if (filters.minimumBudget != null &&
            (budget == null || budget < filters.minimumBudget!)) {
          return false;
        }
        if (filters.maximumBudget != null &&
            (budget == null || budget > filters.maximumBudget!)) {
          return false;
        }
        if (filters.maximumDistanceKm != null &&
            (lead.distanceKm == null ||
                lead.distanceKm! > filters.maximumDistanceKm!)) {
          return false;
        }
        final createdAt = lead.createdAt;
        final cutoff = switch (filters.postedWithin) {
          WorkerLeadPostedWithin.any => null,
          WorkerLeadPostedWithin.day => clock.subtract(const Duration(days: 1)),
          WorkerLeadPostedWithin.week => clock.subtract(
            const Duration(days: 7),
          ),
        };
        return cutoff == null ||
            (createdAt != null && !createdAt.isBefore(cutoff));
      })
      .toList(growable: false);

  int compareNullableNum(double? first, double? second, {bool high = false}) {
    if (first == null && second == null) return 0;
    if (first == null) return 1;
    if (second == null) return -1;
    return high ? second.compareTo(first) : first.compareTo(second);
  }

  int newest(WorkerLead first, WorkerLead second) {
    final old = DateTime.fromMillisecondsSinceEpoch(0);
    return (second.createdAt ?? old).compareTo(first.createdAt ?? old);
  }

  int recommended(WorkerLead first, WorkerLead second) {
    int urgencyScore(WorkerLead lead) => switch (lead.urgency.toLowerCase()) {
      'emergency' => 3,
      'urgent' => 2,
      _ => 1,
    };
    final urgency = urgencyScore(second).compareTo(urgencyScore(first));
    if (urgency != 0) return urgency;
    final distance = compareNullableNum(first.distanceKm, second.distanceKm);
    return distance != 0 ? distance : newest(first, second);
  }

  filtered.sort((first, second) {
    return switch (sort) {
      WorkerLeadSort.recommended => recommended(first, second),
      WorkerLeadSort.newest => newest(first, second),
      WorkerLeadSort.nearest => compareNullableNum(
        first.distanceKm,
        second.distanceKm,
      ),
      WorkerLeadSort.highestBudget => compareNullableNum(
        first.budgetValue,
        second.budgetValue,
        high: true,
      ),
      WorkerLeadSort.lowestBudget => compareNullableNum(
        first.budgetValue,
        second.budgetValue,
      ),
    };
  });
  return filtered;
}

bool workerLeadCategoriesMatch(String first, String second) {
  final left = normalizeWorkerCategory(first);
  final right = normalizeWorkerCategory(second);
  if (left.isEmpty || right.isEmpty) return false;
  if (left == right) return true;
  return left
      .split(' ')
      .toSet()
      .intersection(right.split(' ').toSet())
      .isNotEmpty;
}

List<String> workerLeadCategoryQueryValues(String skill) {
  final normalized = normalizeWorkerCategory(skill);
  final values = <String>{skill.trim()};
  const aliases = <String, List<String>>{
    'ac technician': ['AC Repair', 'AC Technician', 'AC', 'AC Service'],
    'appliance technician': ['Appliance Repair', 'Appliance Technician'],
    'mobile technician': ['Mobile Repair', 'Mobile Technician', 'Phone Repair'],
    'painter': ['Home Painter', 'Painter', 'Painting'],
    'plumber': ['Plumber', 'Plumbing'],
    'electrician': ['Electrician', 'Electrical Work'],
    'carpenter': ['Carpenter', 'Carpentry'],
    'cleaner': ['Cleaner', 'Cleaning'],
  };
  values.addAll(aliases[normalized] ?? const <String>[]);
  return values
      .where((value) => value.isNotEmpty)
      .take(10)
      .toList(growable: false);
}

String workerLeadRelativeTime(DateTime? value, {DateTime? now}) {
  if (value == null) return 'Recently posted';
  final elapsed = (now ?? DateTime.now()).difference(value);
  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  return '${value.day}/${value.month}/${value.year}';
}

String workerLeadDistance(double? value) {
  if (value == null) return 'Distance unavailable';
  if (value < 1) return '${(value * 1000).round()} m away';
  return '${value.toStringAsFixed(value < 10 ? 1 : 0)} km away';
}

double? _moneyValue(dynamic value) {
  if (value is num) return value.toDouble();
  final cleaned = value?.toString().replaceAll(',', '') ?? '';
  final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(cleaned);
  return double.tryParse(match?.group(0) ?? '');
}
