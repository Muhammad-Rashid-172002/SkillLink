import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/Map/worker_job_detail.dart';

class JobsByStatusScreen extends StatefulWidget {
  final String title;
  final String status;
  final bool embedded;

  const JobsByStatusScreen({
    super.key,
    required this.title,
    required this.status,
    this.embedded = false,
  });

  @override
  State<JobsByStatusScreen> createState() => _JobsByStatusScreenState();
}

class _JobsByStatusScreenState extends State<JobsByStatusScreen> {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF16A34A);
  static const Color _secondary = Color(0xFF14B8A6);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFEF4444);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final Future<_WorkerJobProfile> _workerProfileFuture;

  String get _status => widget.status.trim().toLowerCase();
  bool get _isAvailableJobs => _status == 'searching';

  @override
  void initState() {
    super.initState();
    _workerProfileFuture = _loadWorkerProfile();
  }

  Future<_WorkerJobProfile> _loadWorkerProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Your session has expired. Please sign in again.');
    }

    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    final data = snapshot.data() ?? <String, dynamic>{};

    final skill = _safeText(
      data['skill'] ?? data['mainSkill'] ?? data['category'],
      fallback: 'General Service',
    );

    return _WorkerJobProfile(
      uid: user.uid,
      skill: skill,
      normalizedSkill: _normalizeCategory(skill),
    );
  }

  Query<Map<String, dynamic>> _jobsQuery(_WorkerJobProfile worker) {
    Query<Map<String, dynamic>> query = _firestore.collection('requests');

    if (_status == 'searching') {
      return query.where('status', isEqualTo: 'searching');
    }

    if (_status == 'active') {
      return query
          .where('workerId', isEqualTo: worker.uid)
          .where(
            'status',
            whereIn: const ['accepted', 'on_the_way', 'in_progress'],
          );
    }

    if (_status == 'completed') {
      return query
          .where('workerId', isEqualTo: worker.uid)
          .where('status', isEqualTo: 'completed');
    }

    return query.where('workerId', isEqualTo: worker.uid);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterJobs({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
    required _WorkerJobProfile worker,
  }) {
    if (!_isAvailableJobs) return documents;

    return documents.where((document) {
      final data = document.data();

      final assignedWorkerId = data['workerId']?.toString().trim() ?? '';

      final isPublic = assignedWorkerId.isEmpty;
      final isAssignedToCurrentWorker = assignedWorkerId == worker.uid;

      if (!isPublic && !isAssignedToCurrentWorker) return false;

      final category = _safeText(
        data['category'] ??
            data['skill'] ??
            data['service'] ??
            data['serviceType'],
        fallback: '',
      );

      if (category.isEmpty) return false;

      final normalizedJobCategory = _normalizeCategory(category);

      return _categoriesMatch(
        workerCategory: worker.normalizedSkill,
        jobCategory: normalizedJobCategory,
      );
    }).toList();
  }

  bool _categoriesMatch({
    required String workerCategory,
    required String jobCategory,
  }) {
    if (workerCategory.isEmpty || jobCategory.isEmpty) return false;

    if (workerCategory == jobCategory) return true;

    final workerTokens = workerCategory.split(' ').toSet();
    final jobTokens = jobCategory.split(' ').toSet();

    return workerTokens.intersection(jobTokens).isNotEmpty;
  }

  String _normalizeCategory(String value) {
    var text = value
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
      'paint work': 'painter',
      'carpentry': 'carpenter',
      'wood work': 'carpenter',
      'woodwork': 'carpenter',
      'cleaning': 'cleaner',
      'home cleaning': 'cleaner',
      'appliance repair': 'appliance technician',
      'home appliance': 'appliance technician',
      'mobile repair': 'mobile technician',
      'phone repair': 'mobile technician',
    };

    return aliases[text] ?? text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: FutureBuilder<_WorkerJobProfile>(
          future: _workerProfileFuture,
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return Column(
                children: [
                  _buildTopSection(worker: null),
                  Expanded(child: _buildLoadingState()),
                ],
              );
            }

            if (profileSnapshot.hasError || !profileSnapshot.hasData) {
              return Column(
                children: [
                  _buildTopSection(worker: null),
                  Expanded(
                    child: _buildErrorState(
                      profileSnapshot.error?.toString() ??
                          'Worker profile could not be loaded.',
                    ),
                  ),
                ],
              );
            }

            final worker = profileSnapshot.data!;
            final query = _jobsQuery(worker);

            return Column(
              children: [
                _buildTopSection(worker: worker),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: query.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _buildErrorState(snapshot.error.toString());
                      }

                      if (!snapshot.hasData) {
                        return _buildLoadingState();
                      }

                      final jobs = _filterJobs(
                        documents: snapshot.data!.docs,
                        worker: worker,
                      );

                      if (jobs.isEmpty) {
                        return _buildEmptyState(worker: worker);
                      }

                      return RefreshIndicator(
                        color: _primary,
                        onRefresh: () async {
                          await Future<void>.delayed(
                            const Duration(milliseconds: 450),
                          );
                          if (mounted) setState(() {});
                        },
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                          itemCount: jobs.length,
                          itemBuilder: (context, index) {
                            final document = jobs[index];

                            return _buildJobCard(
                              context: context,
                              requestId: document.id,
                              job: document.data(),
                              worker: worker,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopSection({_WorkerJobProfile? worker}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 26,
            offset: Offset(0, 11),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildHeroCard(worker: worker),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        if (!widget.embedded) ...[
          Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => Navigator.maybePop(context),
              child: Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _border),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: _textPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.45,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isAvailableJobs
                    ? 'Personalized opportunities for your skill'
                    : 'Track your assigned jobs and progress',
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: _primary.withOpacity(.09),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            _isAvailableJobs
                ? Icons.auto_awesome_rounded
                : Icons.assignment_turned_in_outlined,
            color: _primary,
            size: 21,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard({_WorkerJobProfile? worker}) {
    final skill = worker?.skill ?? 'Loading your skill';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _secondary],
        ),
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(.23),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -65,
            right: -45,
            child: Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -85,
            left: -45,
            child: Container(
              height: 145,
              width: 145,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isAvailableJobs
                            ? 'SKILL-MATCHED JOBS'
                            : 'YOUR ASSIGNED WORK',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _isAvailableJobs
                          ? 'Jobs selected for you'
                          : 'Manage your current jobs',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _isAvailableJobs
                          ? 'Only opportunities related to your registered skill are shown.'
                          : 'View accepted, on-the-way and in-progress work.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(.83),
                        fontSize: 10.6,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_isAvailableJobs) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(.16),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.handyman_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                skill,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 88,
                width: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.14),
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: Colors.white.withOpacity(.18)),
                ),
                child: Icon(
                  _isAvailableJobs
                      ? _categoryIcon(worker?.normalizedSkill ?? '')
                      : Icons.work_history_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard({
    required BuildContext context,
    required String requestId,
    required Map<String, dynamic> job,
    required _WorkerJobProfile worker,
  }) {
    final jobTitle = _safeText(job['title'], fallback: 'Untitled Job');

    final category = _safeText(
      job['category'] ?? job['skill'] ?? job['service'] ?? job['serviceType'],
      fallback: 'General Service',
    );

    final location = _safeText(
      job['location'],
      fallback: 'Location not provided',
    );

    final budget = _formatBudget(job['budget']);
    final urgency = _safeText(job['urgency'], fallback: 'Normal');
    final description = _safeText(
      job['description'],
      fallback: 'No description available.',
    );
    final jobStatus = _safeText(job['status'], fallback: _status);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkerJobDetailScreen(
                requestId: requestId,
                title: jobTitle,
                category: category,
                location: location,
                distance: 'Nearby',
                budget: budget,
                urgency: urgency,
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isAvailableJobs ? _primary.withOpacity(.15) : _border,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 17,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_primary, _secondary],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      _categoryIcon(_normalizeCategory(category)),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jobTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 14.5,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            _buildTag(
                              icon: _categoryIcon(_normalizeCategory(category)),
                              label: category,
                              color: _primary,
                            ),
                            _buildTag(
                              icon: Icons.bolt_rounded,
                              label: urgency,
                              color: _warning,
                            ),
                            if (_isAvailableJobs)
                              _buildTag(
                                icon: Icons.auto_awesome_rounded,
                                label: 'Skill match',
                                color: const Color(0xFF2563EB),
                              ),
                            if (!_isAvailableJobs)
                              _buildTag(
                                icon: _statusIcon(jobStatus),
                                label: _statusLabel(jobStatus),
                                color: _statusColor(jobStatus),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(.08),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      budget,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 15),
              Container(height: 1, color: const Color(0xFFF1F5F9)),
              const SizedBox(height: 13),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: _primary,
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(.09),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: _primary,
                      size: 17,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 7.8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          height: 178,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _JobSkeleton(width: 52, height: 52, radius: 18),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _JobSkeleton(width: 185, height: 12, radius: 8),
                        SizedBox(height: 9),
                        _JobSkeleton(width: 125, height: 9, radius: 8),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18),
              _JobSkeleton(width: double.infinity, height: 9, radius: 8),
              SizedBox(height: 9),
              _JobSkeleton(width: 220, height: 9, radius: 8),
              SizedBox(height: 18),
              _JobSkeleton(width: double.infinity, height: 38, radius: 13),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required _WorkerJobProfile worker}) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 30),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Container(
                height: 84,
                width: 84,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _primary.withOpacity(.14),
                      _secondary.withOpacity(.09),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(
                  _isAvailableJobs
                      ? _categoryIcon(worker.normalizedSkill)
                      : Icons.assignment_late_outlined,
                  color: _primary,
                  size: 39,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _isAvailableJobs
                    ? 'No ${worker.skill} jobs available'
                    : 'No jobs found',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isAvailableJobs
                    ? 'New customer requests matching your registered skill will appear here automatically.'
                    : 'Your assigned jobs will appear here when available.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10.6,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_isAvailableJobs) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(.07),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Your current skill: ${worker.skill}',
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  color: _danger.withOpacity(.09),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: _danger,
                  size: 33,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to load jobs',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBudget(dynamic value) {
    final text = _safeText(value, fallback: 'Budget not set');

    if (text == 'Budget not set') return text;

    final number = num.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), ''));

    if (number == null) return text;
    return 'Rs. ${number.toStringAsFixed(number % 1 == 0 ? 0 : 2)}';
  }

  String _safeText(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return fallback;
    }

    return text;
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'accepted':
        return 'Accepted';
      case 'on_the_way':
        return 'On the way';
      case 'in_progress':
        return 'In progress';
      case 'completed':
        return 'Completed';
      default:
        return value.replaceAll('_', ' ');
    }
  }

  IconData _statusIcon(String value) {
    switch (value) {
      case 'accepted':
        return Icons.check_circle_outline_rounded;
      case 'on_the_way':
        return Icons.directions_run_rounded;
      case 'in_progress':
        return Icons.construction_rounded;
      case 'completed':
        return Icons.task_alt_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'accepted':
        return const Color(0xFF2563EB);
      case 'on_the_way':
        return _warning;
      case 'in_progress':
        return const Color(0xFF8B5CF6);
      case 'completed':
        return _primary;
      default:
        return _textSecondary;
    }
  }

  IconData _categoryIcon(String category) {
    final normalized = _normalizeCategory(category);

    if (normalized.contains('electrician')) {
      return Icons.electrical_services_rounded;
    }

    if (normalized.contains('ac technician')) {
      return Icons.ac_unit_rounded;
    }

    if (normalized.contains('plumber')) {
      return Icons.plumbing_rounded;
    }

    if (normalized.contains('painter')) {
      return Icons.format_paint_rounded;
    }

    if (normalized.contains('carpenter')) {
      return Icons.carpenter_rounded;
    }

    if (normalized.contains('cleaner')) {
      return Icons.cleaning_services_rounded;
    }

    if (normalized.contains('appliance')) {
      return Icons.home_repair_service_rounded;
    }

    if (normalized.contains('mobile')) {
      return Icons.phone_android_rounded;
    }

    return Icons.handyman_rounded;
  }
}

class _WorkerJobProfile {
  final String uid;
  final String skill;
  final String normalizedSkill;

  const _WorkerJobProfile({
    required this.uid,
    required this.skill,
    required this.normalizedSkill,
  });
}

class _JobSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _JobSkeleton({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF4),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
