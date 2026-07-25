import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AllJobsScreen extends StatefulWidget {
  const AllJobsScreen({super.key});

  @override
  State<AllJobsScreen> createState() => _AllJobsScreenState();
}

class _AllJobsScreenState extends State<AllJobsScreen> {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _primary = Color(0xFF16A34A);
  static const Color _secondary = Color(0xFF14B8A6);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSection(context),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("requests")
                    .orderBy("createdAt", descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState(
                      snapshot.error.toString(),
                    );
                  }

                  if (!snapshot.hasData) {
                    return _buildLoadingState();
                  }

                  final jobs = snapshot.data!.docs.where((doc) {
                    final job = doc.data() as Map<String, dynamic>;

                    if (_searchQuery.isEmpty) {
                      return true;
                    }

                    final title =
                        job["title"]?.toString().toLowerCase() ?? "";
                    final location =
                        job["location"]?.toString().toLowerCase() ?? "";
                    final category =
                        job["category"]?.toString().toLowerCase() ?? "";

                    return title.contains(_searchQuery) ||
                        location.contains(_searchQuery) ||
                        category.contains(_searchQuery);
                  }).toList();

                  if (jobs.isEmpty) {
                    return _buildEmptyState(
                      isSearching: _searchQuery.isNotEmpty,
                    );
                  }

                  return ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      30,
                    ),
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      final document = jobs[index];
                      final job =
                          document.data() as Map<String, dynamic>;

                      return _buildJobCard(
                        context: context,
                        jobId: document.id,
                        job: job,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 18),
          _buildHeroCard(),
          const SizedBox(height: 16),
          _buildSearchField(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
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
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "All Jobs",
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.45,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Explore the latest work opportunities",
                style: TextStyle(
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
          child: const Icon(
            Icons.work_outline_rounded,
            color: _primary,
            size: 21,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primary,
            _secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(.22),
            blurRadius: 24,
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
                      child: const Text(
                        "JOB MARKETPLACE",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Find your next job",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      "Browse nearby jobs and connect with customers.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(.82),
                        fontSize: 10.6,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 84,
                width: 74,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.14),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withOpacity(.18),
                  ),
                ),
                child: const Icon(
                  Icons.handyman_rounded,
                  color: Colors.white,
                  size: 37,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          color: _textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: "Search jobs, category or location...",
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10.7,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _textSecondary,
            size: 21,
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _textSecondary,
                    size: 18,
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard({
    required BuildContext context,
    required String jobId,
    required Map<String, dynamic> job,
  }) {
    final title = _safeText(
      job["title"],
      fallback: "Untitled Job",
    );

    final location = _safeText(
      job["location"],
      fallback: "Location not provided",
    );

    final budget = _safeText(
      job["budget"],
      fallback: "Budget not set",
    );

    final category = _safeText(
      job["category"],
      fallback: "General Service",
    );

    final description = _safeText(
      job["description"],
      fallback: "No description available.",
    );

    final urgency = _safeText(
      job["urgency"],
      fallback: "Normal",
    );

    final createdAt = job["createdAt"];

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: () {
          // Job Detail Screen open karo
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x070F172A),
                blurRadius: 15,
                offset: Offset(0, 7),
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
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          _primary,
                          _secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.work_outline_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 14.5,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _smallTag(
                              icon: Icons.category_outlined,
                              label: category,
                            ),
                            const SizedBox(width: 7),
                            _smallTag(
                              icon: Icons.bolt_rounded,
                              label: urgency,
                              accent: const Color(0xFFF59E0B),
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
                      vertical: 7,
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
              Container(
                height: 1,
                color: const Color(0xFFF1F5F9),
              ),
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
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.schedule_rounded,
                    color: Color(0xFF94A3B8),
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(createdAt),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "View Details",
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 10.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          _primary,
                          _secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 19,
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

  Widget _smallTag({
    required IconData icon,
    required String label,
    Color accent = _primary,
  }) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: accent.withOpacity(.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: accent,
              size: 11,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 7.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        30,
      ),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          height: 180,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: _border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SkeletonBox(
                    width: 48,
                    height: 48,
                    radius: 16,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(
                          width: 180,
                          height: 12,
                          radius: 8,
                        ),
                        SizedBox(height: 9),
                        _SkeletonBox(
                          width: 110,
                          height: 9,
                          radius: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18),
              _SkeletonBox(
                width: double.infinity,
                height: 9,
                radius: 8,
              ),
              SizedBox(height: 9),
              _SkeletonBox(
                width: 220,
                height: 9,
                radius: 8,
              ),
              SizedBox(height: 18),
              _SkeletonBox(
                width: double.infinity,
                height: 44,
                radius: 14,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required bool isSearching,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            24,
            32,
            24,
            30,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Container(
                height: 82,
                width: 82,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(.09),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  isSearching
                      ? Icons.search_off_rounded
                      : Icons.work_off_outlined,
                  color: _primary,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isSearching
                    ? "No matching jobs"
                    : "No jobs found",
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSearching
                    ? "Try searching with another title, category or location."
                    : "New job opportunities will appear here.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10.6,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
            color: Colors.white,
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
                  color: const Color(0xFFEF4444).withOpacity(.09),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: Color(0xFFEF4444),
                  size: 33,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Unable to load jobs",
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

  String _safeText(
    dynamic value, {
    required String fallback,
  }) {
    final text = value?.toString().trim() ?? "";

    if (text.isEmpty || text.toLowerCase() == "null") {
      return fallback;
    }

    return text;
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) {
      return "Recently";
    }

    final date = value.toDate();
    final difference = DateTime.now().difference(date);

    if (difference.inMinutes < 1) {
      return "Just now";
    }

    if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m ago";
    }

    if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    }

    if (difference.inDays < 7) {
      return "${difference.inDays}d ago";
    }

    return "${date.day}/${date.month}/${date.year}";
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
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
