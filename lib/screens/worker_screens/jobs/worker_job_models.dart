import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';

enum WorkerJobGroup {
  active('Active'),
  completed('Completed'),
  cancelled('Cancelled');

  const WorkerJobGroup(this.label);
  final String label;
}

const Map<WorkerJobGroup, int> workerJobQueryLimits = {
  WorkerJobGroup.active: 20,
  WorkerJobGroup.completed: 50,
  WorkerJobGroup.cancelled: 30,
};

List<String> workerJobQueryStatuses(WorkerJobGroup group) => switch (group) {
  WorkerJobGroup.active => const [
    'accepted',
    'on_the_way',
    'on the way',
    'ontheway',
    'in_progress',
    'in progress',
    'started',
  ],
  WorkerJobGroup.completed => const ['completed'],
  WorkerJobGroup.cancelled => const ['cancelled', 'canceled', 'rejected'],
};

enum WorkerJobStatus {
  accepted,
  onTheWay,
  inProgress,
  completed,
  cancelled,
  unknown,
}

class WorkerJobStatusPresentation {
  const WorkerJobStatusPresentation({
    required this.status,
    required this.label,
    required this.firestoreValue,
  });

  final WorkerJobStatus status;
  final String label;
  final String firestoreValue;

  bool get isActive =>
      status == WorkerJobStatus.accepted ||
      status == WorkerJobStatus.onTheWay ||
      status == WorkerJobStatus.inProgress;

  WorkerJobGroup? get group => switch (status) {
    WorkerJobStatus.accepted ||
    WorkerJobStatus.onTheWay ||
    WorkerJobStatus.inProgress => WorkerJobGroup.active,
    WorkerJobStatus.completed => WorkerJobGroup.completed,
    WorkerJobStatus.cancelled => WorkerJobGroup.cancelled,
    WorkerJobStatus.unknown => null,
  };

  WorkerJobStatus? get next => switch (status) {
    WorkerJobStatus.accepted => WorkerJobStatus.onTheWay,
    WorkerJobStatus.onTheWay => WorkerJobStatus.inProgress,
    WorkerJobStatus.inProgress => WorkerJobStatus.completed,
    _ => null,
  };
}

WorkerJobStatusPresentation workerJobStatusOf(dynamic value) {
  final normalized = value
      ?.toString()
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(RegExp(r'\s+'), '_');
  return switch (normalized) {
    'accepted' => const WorkerJobStatusPresentation(
      status: WorkerJobStatus.accepted,
      label: 'Accepted',
      firestoreValue: 'accepted',
    ),
    'on_the_way' || 'ontheway' => const WorkerJobStatusPresentation(
      status: WorkerJobStatus.onTheWay,
      label: 'On the way',
      firestoreValue: 'on_the_way',
    ),
    'in_progress' || 'started' => const WorkerJobStatusPresentation(
      status: WorkerJobStatus.inProgress,
      label: 'In progress',
      firestoreValue: 'in_progress',
    ),
    'completed' => const WorkerJobStatusPresentation(
      status: WorkerJobStatus.completed,
      label: 'Completed',
      firestoreValue: 'completed',
    ),
    'cancelled' ||
    'canceled' ||
    'rejected' => const WorkerJobStatusPresentation(
      status: WorkerJobStatus.cancelled,
      label: 'Cancelled',
      firestoreValue: 'cancelled',
    ),
    _ => const WorkerJobStatusPresentation(
      status: WorkerJobStatus.unknown,
      label: 'Job status unavailable',
      firestoreValue: '',
    ),
  };
}

class WorkerJobCustomer {
  const WorkerJobCustomer({
    required this.id,
    this.name = 'Customer',
    this.photoUrl = '',
    this.city = '',
    this.area = '',
    this.phone = '',
  });

  final String id;
  final String name;
  final String photoUrl;
  final String city;
  final String area;
  final String phone;

  String get serviceArea {
    if (area.isNotEmpty && city.isNotEmpty) return '$area, $city';
    return area.isNotEmpty ? area : city;
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory WorkerJobCustomer.from(String id, Map<String, dynamic> data) {
    return WorkerJobCustomer(
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
      phone: workerText(data, const ['phone', 'phoneNumber']),
    );
  }
}

class WorkerJobReview {
  const WorkerJobReview({required this.rating, this.text = '', this.createdAt});

  final double rating;
  final String text;
  final DateTime? createdAt;

  factory WorkerJobReview.from(Map<String, dynamic> data) {
    return WorkerJobReview(
      rating: (workerDouble(data['rating']) ?? 0).clamp(0, 5),
      text: workerText(data, const ['review', 'comment']),
      createdAt: workerDate(data['createdAt']),
    );
  }
}

class WorkerJob {
  const WorkerJob({
    required this.id,
    required this.data,
    this.customer,
    this.review,
    this.distanceKm,
  });

  final String id;
  final Map<String, dynamic> data;
  final WorkerJobCustomer? customer;
  final WorkerJobReview? review;
  final double? distanceKm;

  WorkerJobStatusPresentation get status => workerJobStatusOf(data['status']);
  String get workerId => workerText(data, const ['workerId']);
  String get customerId => workerText(data, const ['customerId']);
  String get title => workerText(data, const [
    'title',
    'category',
    'service',
  ], fallback: 'Service job');
  String get category => workerText(data, const [
    'category',
    'service',
    'serviceType',
  ], fallback: 'Service');
  String get description => workerText(data, const ['description']);
  String get notes => workerText(data, const ['notes']);
  String get urgency => workerText(data, const ['urgency']);
  String get budget => workerText(data, const ['budget']);
  String get address => workerText(data, const ['location', 'address']);
  String get requestServiceArea =>
      workerText(data, const ['serviceArea', 'area', 'city']);
  String get serviceArea {
    if (requestServiceArea.isNotEmpty) return requestServiceArea;
    if (customer?.serviceArea.isNotEmpty == true) return customer!.serviceArea;
    return 'Open job details for the service address';
  }

  String get cancellationReason => workerText(data, const [
    'cancellationReason',
    'cancelReason',
    'cancelledReason',
    'rejectionReason',
  ]);
  String get chatId => workerText(data, const ['chatId']);
  bool get hasActiveEmergency => data['hasActiveEmergency'] == true;

  DateTime? get createdAt => workerDate(data['createdAt']);
  DateTime? get acceptedAt => workerDate(data['acceptedAt']);
  DateTime? get onTheWayAt => workerDate(data['onTheWayAt']);
  DateTime? get startedAt => workerDate(data['startedAt']);
  DateTime? get completedAt => workerDate(data['completedAt']);
  DateTime? get cancelledAt => workerDate(
    data['cancelledAt'] ?? data['canceledAt'] ?? data['rejectedAt'],
  );
  DateTime? get updatedAt => workerDate(data['updatedAt']);

  DateTime? get relevantDate => switch (status.status) {
    WorkerJobStatus.accepted => acceptedAt ?? updatedAt ?? createdAt,
    WorkerJobStatus.onTheWay => onTheWayAt ?? updatedAt ?? acceptedAt,
    WorkerJobStatus.inProgress => startedAt ?? updatedAt ?? acceptedAt,
    WorkerJobStatus.completed => completedAt ?? updatedAt,
    WorkerJobStatus.cancelled => cancelledAt ?? updatedAt,
    WorkerJobStatus.unknown => updatedAt ?? createdAt,
  };

  List<String> get imageUrls {
    final value = data['imageUrls'];
    if (value is! List) return const [];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .take(5)
        .toList(growable: false);
  }

  WorkerCoordinate? get serviceCoordinate => WorkerCoordinate.from(
    data['customerLocation'] ?? data['geoPoint'] ?? data['locationPoint'],
    latitude: data['latitude'] ?? data['lat'],
    longitude: data['longitude'] ?? data['lng'],
  );

  WorkerJob copyWith({
    WorkerJobCustomer? customer,
    WorkerJobReview? review,
    double? distanceKm,
    bool preserveReview = true,
    bool preserveDistance = true,
  }) {
    return WorkerJob(
      id: id,
      data: data,
      customer: customer ?? this.customer,
      review: review ?? (preserveReview ? this.review : null),
      distanceKm: distanceKm ?? (preserveDistance ? this.distanceKm : null),
    );
  }
}

bool isWorkerJobInGroup(
  WorkerJob job,
  String authenticatedWorkerId,
  WorkerJobGroup group,
) {
  return authenticatedWorkerId.isNotEmpty &&
      job.workerId == authenticatedWorkerId &&
      job.status.group == group;
}

enum WorkerJobTransitionFailure {
  signedOut,
  missing,
  wrongWorker,
  stale,
  invalid,
  network,
  unknown,
}

class WorkerJobTransitionException implements Exception {
  const WorkerJobTransitionException(this.failure, this.message);

  final WorkerJobTransitionFailure failure;
  final String message;

  @override
  String toString() => message;
}

class WorkerJobTransitionPlan {
  const WorkerJobTransitionPlan({
    required this.workerId,
    required this.nextStatus,
  });

  final String workerId;
  final WorkerJobStatus nextStatus;

  String get firestoreValue =>
      workerJobStatusPresentation(nextStatus).firestoreValue;
}

WorkerJobStatusPresentation workerJobStatusPresentation(
  WorkerJobStatus status,
) {
  return switch (status) {
    WorkerJobStatus.accepted => workerJobStatusOf('accepted'),
    WorkerJobStatus.onTheWay => workerJobStatusOf('on_the_way'),
    WorkerJobStatus.inProgress => workerJobStatusOf('in_progress'),
    WorkerJobStatus.completed => workerJobStatusOf('completed'),
    WorkerJobStatus.cancelled => workerJobStatusOf('cancelled'),
    WorkerJobStatus.unknown => workerJobStatusOf(null),
  };
}

WorkerJobTransitionPlan planWorkerJobTransition({
  required String authenticatedWorkerId,
  required Map<String, dynamic>? requestData,
  required WorkerJobStatus expectedStatus,
  required WorkerJobStatus requestedStatus,
}) {
  if (authenticatedWorkerId.trim().isEmpty) {
    throw const WorkerJobTransitionException(
      WorkerJobTransitionFailure.signedOut,
      'Please sign in again before updating this job.',
    );
  }
  if (requestData == null) {
    throw const WorkerJobTransitionException(
      WorkerJobTransitionFailure.missing,
      'This job no longer exists.',
    );
  }
  final job = WorkerJob(id: '', data: requestData);
  if (job.workerId != authenticatedWorkerId) {
    throw const WorkerJobTransitionException(
      WorkerJobTransitionFailure.wrongWorker,
      'This job is not assigned to your worker account.',
    );
  }
  if (job.status.status != expectedStatus) {
    throw const WorkerJobTransitionException(
      WorkerJobTransitionFailure.stale,
      'This job changed before your update. Review its latest status.',
    );
  }
  final expectedNext = job.status.next;
  if (expectedNext == null || expectedNext != requestedStatus) {
    throw const WorkerJobTransitionException(
      WorkerJobTransitionFailure.invalid,
      'That lifecycle step is not available for this job.',
    );
  }
  return WorkerJobTransitionPlan(
    workerId: authenticatedWorkerId,
    nextStatus: requestedStatus,
  );
}

String workerJobPrimaryAction(WorkerJobStatus status) => switch (status) {
  WorkerJobStatus.accepted => 'On my way',
  WorkerJobStatus.onTheWay => 'Start job',
  WorkerJobStatus.inProgress => 'Complete job',
  _ => '',
};

String formatWorkerJobBudget(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return 'Not provided';
  if (RegExp(r'[a-zA-Z]').hasMatch(clean)) return clean;
  final number = double.tryParse(clean.replaceAll(RegExp(r'[^0-9.]'), ''));
  if (number == null) return clean;
  final whole = number.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < whole.length; index++) {
    if (index > 0 && (whole.length - index) % 3 == 0) buffer.write(',');
    buffer.write(whole[index]);
  }
  return 'Rs ${buffer.toString()}';
}

String workerJobDateLabel(DateTime? date) {
  if (date == null) return 'Date unavailable';
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

List<WorkerJob> searchWorkerJobs(List<WorkerJob> jobs, String search) {
  final query = search.trim().toLowerCase();
  if (query.isEmpty) return jobs;
  return jobs
      .where((job) {
        return [
          job.title,
          job.category,
          job.customer?.name ?? '',
          job.serviceArea,
        ].any((value) => value.toLowerCase().contains(query));
      })
      .toList(growable: false);
}
