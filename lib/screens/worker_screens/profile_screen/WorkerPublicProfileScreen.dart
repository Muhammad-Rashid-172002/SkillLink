import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/customer_screens/Chat/chat_detail_screen.dart';
import 'package:skill_link/screens/customer_screens/Request/Request.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkerPublicProfileScreen extends StatelessWidget {
  final String workerId;

  const WorkerPublicProfileScreen({super.key, required this.workerId});

  static const Color _background = Color(0xFFF4F7FB);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _primaryDark = Color(0xFF1D4ED8);
  static const Color _success = Color(0xFF16A34A);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  Future<void> _callWorker(BuildContext context, String phone) async {
    if (phone.isEmpty) {
      _showSnackBar(context, message: "Phone number not found", isError: true);
      return;
    }

    final Uri uri = Uri(scheme: "tel", path: phone);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!context.mounted) return;

      _showSnackBar(
        context,
        message: "Cannot open phone dialer",
        isError: true,
      );
    }
  }

  Future<void> _openChat(
    BuildContext context,
    Map<String, dynamic> worker,
  ) async {
    final customerId = FirebaseAuth.instance.currentUser!.uid;

    final existingChat = await FirebaseFirestore.instance
        .collection("chats")
        .where("customerId", isEqualTo: customerId)
        .where("workerId", isEqualTo: workerId)
        .limit(1)
        .get();

    String chatId;

    if (existingChat.docs.isNotEmpty) {
      chatId = existingChat.docs.first.id;
    } else {
      chatId = FirebaseFirestore.instance.collection("chats").doc().id;
    }

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          chatId: chatId,
          workerId: workerId,
          workerName: worker["name"] ?? "Worker",
          workerSkill: worker["skill"] ?? "",
          workerPhone: worker["phone"]?.toString(),
          workerImageUrl:
              worker["profileImageUrl"]?.toString() ??
              worker["profileImage"]?.toString() ??
              worker["imageUrl"]?.toString() ??
              worker["photoUrl"]?.toString(),
        ),
      ),
    );
  }

  // Future<void> _hireWorker(
  //   BuildContext context,
  //   Map<String, dynamic> worker,
  // ) async {
  //   final customerId = FirebaseAuth.instance.currentUser!.uid;

  //   await FirebaseFirestore.instance.collection("requests").add({
  //     "customerId": customerId,
  //     "workerId": workerId,
  //     "category": worker["skill"] ?? "",
  //     "title": "Direct Hire Request",
  //     "description": "Customer hired worker from public profile.",
  //     "location": "",
  //     "budget": worker["hourlyRate"] ?? "",
  //     "urgency": "Normal",
  //     "status": "accepted",
  //     "createdAt": FieldValue.serverTimestamp(),
  //     "acceptedAt": FieldValue.serverTimestamp(),
  //     "updatedAt": FieldValue.serverTimestamp(),
  //   });

  //   if (!context.mounted) return;

  //   _showSnackBar(context, message: "Hire request created successfully");
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection("users")
              .doc(workerId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState(context);
            }

            if (snapshot.hasError) {
              return _buildErrorState(
                context,
                message: "Unable to load worker profile",
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return _buildErrorState(
                context,
                message: "Worker profile not found",
              );
            }

            final worker = snapshot.data!.data() as Map<String, dynamic>;

            return Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 118),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileHero(worker),
                        const SizedBox(height: 18),
                        _buildTrustStrip(worker),
                        const SizedBox(height: 22),
                        _sectionTitle(
                          title: "Professional Overview",
                          subtitle:
                              "Skills, work history and service information",
                        ),
                        const SizedBox(height: 12),
                        _buildStatsSection(worker),
                        const SizedBox(height: 18),
                        _buildAboutCard(worker),
                        const SizedBox(height: 18),
                        _buildServiceDetails(worker),
                        const SizedBox(height: 22),
                        _sectionTitle(
                          title: "Customer Feedback",
                          subtitle: "Verified ratings from completed services",
                        ),
                        const SizedBox(height: 12),
                        _reviewsSection(),
                        const SizedBox(height: 18),
                        _safetyTrustCard(worker),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(workerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox.shrink();
          }

          final worker = snapshot.data!.data() as Map<String, dynamic>;

          return _buildBottomActions(context, worker);
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 17),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _headerIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Worker Profile",
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.45,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "View skills, ratings and customer reviews",
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10,
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
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: _primary,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Icon(icon, color: _textPrimary, size: 20),
        ),
      ),
    );
  }

  Widget _buildProfileHero(Map<String, dynamic> worker) {
    final bool isVerified =
        worker["identityVerificationStatus"] == "approved" ||
        worker["isVerified"] == true;

    final bool isOnline = worker["isOnline"] == true;
    final bool canAcceptJobs = worker["canAcceptJobs"] == true;

    final String imageUrl =
        worker["profileImageUrl"]?.toString() ??
        worker["profileImage"]?.toString() ??
        worker["imageUrl"]?.toString() ??
        worker["photoUrl"]?.toString() ??
        "";

    final String name = worker["name"]?.toString().trim().isNotEmpty == true
        ? worker["name"].toString().trim()
        : "Worker";

    final String skill = worker["skill"]?.toString().trim().isNotEmpty == true
        ? worker["skill"].toString().trim()
        : "Service Professional";

    final String location =
        worker["location"]?.toString().trim().isNotEmpty == true
        ? worker["location"].toString().trim()
        : worker["city"]?.toString().trim().isNotEmpty == true
        ? worker["city"].toString().trim()
        : "Location not provided";

    final double rating = _toDouble(worker["rating"]);
    final int totalReviews = _toInt(worker["totalReviews"]);
    final String experience =
        worker["experience"]?.toString().trim().isNotEmpty == true
        ? worker["experience"].toString().trim()
        : "Experience not added";

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(.24),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0B3E91),
                    Color(0xFF175FDD),
                    Color(0xFF2563EB),
                    Color(0xFF06B6D4),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -95,
            right: -70,
            child: Container(
              height: 220,
              width: 220,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -75,
            child: Container(
              height: 230,
              width: 230,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildProfileImage(imageUrl, workerName: name),
                        Positioned(
                          right: 1,
                          bottom: 5,
                          child: Container(
                            height: 25,
                            width: 25,
                            decoration: BoxDecoration(
                              color: isOnline ? _success : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                          ),
                        ),
                        if (isVerified)
                          Positioned(
                            left: -2,
                            bottom: 3,
                            child: Container(
                              height: 29,
                              width: 29,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF2563EB),
                                size: 24,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                height: 1.08,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.45,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(.14),
                                ),
                              ),
                              child: Text(
                                skill,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: Color(0xDDFFFFFF),
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xDDFFFFFF),
                                      fontSize: 9.8,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                const Icon(
                                  Icons.workspace_premium_outlined,
                                  color: Color(0xDDFFFFFF),
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    experience,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xDDFFFFFF),
                                      fontSize: 9.6,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(.14)),
                  ),
                  child: Row(
                    children: [
                      _heroMetric(
                        icon: Icons.star_rounded,
                        value: rating.toStringAsFixed(1),
                        label: "$totalReviews reviews",
                      ),
                      _heroDivider(),
                      _heroMetric(
                        icon: Icons.verified_user_outlined,
                        value: isVerified ? "Verified" : "Active",
                        label: "Identity",
                      ),
                      _heroDivider(),
                      _heroMetric(
                        icon: Icons.bolt_rounded,
                        value: canAcceptJobs ? "Available" : "Busy",
                        label: isOnline ? "Online now" : "Offline",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMetric({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.7,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xCFFFFFFF),
              fontSize: 7.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() {
    return Container(
      width: 1,
      height: 38,
      color: Colors.white.withOpacity(.18),
    );
  }

  Widget _buildProfileImage(String imageUrl, {required String workerName}) {
    return Container(
      height: 100,
      width: 100,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.20),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(.36), width: 2),
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;

                  return const ColoredBox(
                    color: Colors.white,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _primary,
                        strokeWidth: 2.2,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) {
                  return _profilePlaceholder(workerName);
                },
              )
            : _profilePlaceholder(workerName),
      ),
    );
  }

  Widget _profilePlaceholder(String workerName) {
    final parts = workerName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    final initials = parts.isEmpty
        ? "WK"
        : parts.length == 1
        ? parts.first.substring(0, 1).toUpperCase()
        : "${parts.first.substring(0, 1)}"
                  "${parts.last.substring(0, 1)}"
              .toUpperCase();

    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFDDEBFF)],
        ),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: _primaryDark,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildTrustStrip(Map<String, dynamic> worker) {
    final bool verified =
        worker["identityVerificationStatus"] == "approved" ||
        worker["isVerified"] == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _trustItem(
            icon: verified
                ? Icons.verified_user_rounded
                : Icons.person_outline_rounded,
            title: verified ? "Verified" : "Active",
            subtitle: "Identity",
            color: _success,
          ),
          _trustDivider(),
          _trustItem(
            icon: Icons.chat_bubble_outline_rounded,
            title: "Direct",
            subtitle: "Chat",
            color: _primary,
          ),
          _trustDivider(),
          _trustItem(
            icon: Icons.phone_outlined,
            title: "Quick",
            subtitle: "Contact",
            color: const Color(0xFF0891B2),
          ),
          _trustDivider(),
          _trustItem(
            icon: Icons.lock_outline_rounded,
            title: "Secure",
            subtitle: "Booking",
            color: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  Widget _trustItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 37,
            width: 37,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            maxLines: 1,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 9.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            maxLines: 1,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 7.7,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trustDivider() {
    return Container(width: 1, height: 45, color: _border);
  }

  Widget _sectionTitle({required String title, required String subtitle}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 31,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_primary, Color(0xFF06B6D4)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 9.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _safetyTrustCard(Map<String, dynamic> worker) {
    final bool verified =
        worker["identityVerificationStatus"] == "approved" ||
        worker["isVerified"] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFF8FBFF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8E7FF)),
      ),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primary, Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verified
                      ? "Verified Professional"
                      : "Protected SkillNova Profile",
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  verified
                      ? "This worker's identity has been reviewed and approved."
                      : "Bookings, chat and contact actions are managed through SkillNova.",
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 9.4,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: _success, size: 22),
        ],
      ),
    );
  }

  Widget _buildStatsSection(Map<String, dynamic> worker) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("requests")
          .where("workerId", isEqualTo: workerId)
          .where("status", isEqualTo: "completed")
          .snapshots(),
      builder: (context, snapshot) {
        final int completedJobs = snapshot.data?.docs.length ?? 0;
        final double rating = _toDouble(worker["rating"]);
        final String rate = worker["hourlyRate"]?.toString() ?? "0";

        return Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.task_alt_rounded,
                iconColor: _success,
                value: completedJobs.toString(),
                label: "Jobs Done",
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: Icons.star_rounded,
                iconColor: _warning,
                value: rating.toStringAsFixed(1),
                label: "Rating",
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: Icons.payments_outlined,
                iconColor: _primary,
                value: "Rs $rate",
                label: "Rate",
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 37,
            width: 37,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(Map<String, dynamic> worker) {
    final String bio =
        worker["bio"]?.toString() ??
        "Experienced and trusted worker available for professional home services.";

    return _sectionCard(
      icon: Icons.person_outline_rounded,
      title: "About Worker",
      subtitle: "Professional background and introduction",
      child: Text(
        bio,
        style: const TextStyle(
          color: _textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.65,
        ),
      ),
    );
  }

  Widget _buildServiceDetails(Map<String, dynamic> worker) {
    final String skill = worker["skill"]?.toString() ?? "Not provided";
    final String experience =
        worker["experience"]?.toString() ??
        worker["experienceYears"]?.toString() ??
        "Not provided";
    final String phone = worker["phone"]?.toString() ?? "Not provided";
    final String rate = worker["hourlyRate"]?.toString() ?? "0";

    return _sectionCard(
      icon: Icons.workspace_premium_outlined,
      title: "Service Details",
      subtitle: "Worker's expertise and availability",
      child: Column(
        children: [
          _detailRow(
            icon: Icons.handyman_outlined,
            label: "Primary Skill",
            value: skill,
            iconColor: _primary,
          ),
          _divider(),
          _detailRow(
            icon: Icons.history_edu_outlined,
            label: "Experience",
            value: experience,
            iconColor: const Color(0xFF7C3AED),
          ),
          _divider(),
          _detailRow(
            icon: Icons.payments_outlined,
            label: "Service Rate",
            value: "Rs $rate",
            iconColor: _success,
          ),
          _divider(),
          _detailRow(
            icon: Icons.phone_outlined,
            label: "Contact",
            value: phone,
            iconColor: const Color(0xFF0891B2),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 43,
                width: 43,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(.09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _primary, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            height: 39,
            width: 39,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: _border),
    );
  }

  Widget _reviewsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("reviews")
          .where("workerId", isEqualTo: workerId)
          // .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _reviewsLoadingCard();
        }

        if (snapshot.hasError) {
          print(snapshot.error);

          return _reviewEmptyState(
            icon: Icons.error_outline_rounded,
            title: "Reviews unavailable",
            subtitle: snapshot.error.toString(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _reviewEmptyState(
            icon: Icons.rate_review_outlined,
            title: "No reviews yet",
            subtitle:
                "Customer feedback will appear here after completed jobs.",
          );
        }

        final docs = snapshot.data!.docs;
        double totalRating = 0;

        for (final doc in docs) {
          final review = doc.data() as Map<String, dynamic>;
          totalRating += _toDouble(review["rating"]);
        }

        final double averageRating = docs.isEmpty
            ? 0
            : totalRating / docs.length;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: _box(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reviewsHeader(
                averageRating: averageRating,
                totalReviews: docs.length,
              ),
              const SizedBox(height: 18),
              _ratingOverview(
                averageRating: averageRating,
                totalReviews: docs.length,
              ),
              const SizedBox(height: 18),
              ...List.generate(docs.length, (index) {
                final review = docs[index].data() as Map<String, dynamic>;

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == docs.length - 1 ? 0 : 12,
                  ),
                  child: _reviewCard(review),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _reviewsHeader({
    required double averageRating,
    required int totalReviews,
  }) {
    return Row(
      children: [
        Container(
          height: 43,
          width: 43,
          decoration: BoxDecoration(
            color: _warning.withOpacity(.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.reviews_outlined, color: _warning, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Customer Reviews",
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "$totalReviews verified customer reviews",
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _warning.withOpacity(.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, color: _warning, size: 15),
              const SizedBox(width: 4),
              Text(
                averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ratingOverview({
    required double averageRating,
    required int totalReviews,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 3),
              _buildStars(averageRating),
              const SizedBox(height: 4),
              Text(
                "$totalReviews reviews",
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                _ratingBar(stars: 5, value: averageRating >= 4.5 ? 1 : .74),
                const SizedBox(height: 6),
                _ratingBar(stars: 4, value: averageRating >= 3.5 ? .55 : .30),
                const SizedBox(height: 6),
                _ratingBar(stars: 3, value: averageRating >= 2.5 ? .25 : .15),
                const SizedBox(height: 6),
                _ratingBar(stars: 2, value: .08),
                const SizedBox(height: 6),
                _ratingBar(stars: 1, value: .03),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingBar({required int stars, required double value}) {
    return Row(
      children: [
        SizedBox(
          width: 13,
          child: Text(
            stars.toString(),
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Icon(Icons.star_rounded, color: _warning, size: 11),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: value.clamp(0, 1),
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(_warning),
            ),
          ),
        ),
      ],
    );
  }

  Widget _reviewCard(Map<String, dynamic> review) {
    final String reviewText =
        review["review"]?.toString() ??
        review["comment"]?.toString() ??
        "No review text provided.";

    final double rating = _toDouble(review["rating"]);

    final String customerName =
        review["customerName"]?.toString() ??
        review["reviewerName"]?.toString() ??
        "Verified Customer";

    final Timestamp? createdAt = review["createdAt"] is Timestamp
        ? review["createdAt"] as Timestamp
        : null;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 43,
                width: 43,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _primary.withOpacity(.16),
                      _primary.withOpacity(.07),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: _primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildStars(rating),
                        const SizedBox(width: 7),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (createdAt != null)
                Text(
                  _formatReviewDate(createdAt),
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            reviewText,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 10.5,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: _success.withOpacity(.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: _success, size: 13),
                SizedBox(width: 5),
                Text(
                  "Verified Job",
                  style: TextStyle(
                    color: _success,
                    fontSize: 7.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.round()
              ? Icons.star_rounded
              : Icons.star_border_rounded,
          color: _warning,
          size: 14,
        );
      }),
    );
  }

  Widget _reviewEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _box(),
      child: Column(
        children: [
          Container(
            height: 68,
            width: 68,
            decoration: BoxDecoration(
              color: _primary.withOpacity(.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _primary, size: 31),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 9.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewsLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _box(),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2.4, color: _primary),
      ),
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    Map<String, dynamic> worker,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 20,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _smallActionButton(
              icon: Icons.call_rounded,
              onTap: () =>
                  _callWorker(context, worker["phone"]?.toString() ?? ""),
            ),
            const SizedBox(width: 10),
            _smallActionButton(
              icon: Icons.chat_bubble_outline_rounded,
              onTap: () => _openChat(context, worker),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Request(selectedWorkerId: workerId),
                    ),
                  ),
                  label: const Text(
                    "Hire Worker",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Icon(icon, color: _primary, size: 21),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        const Expanded(
          child: Center(
            child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, {required String message}) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 82,
                    width: 82,
                    decoration: BoxDecoration(
                      color: _danger.withOpacity(.09),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_off_outlined,
                      color: _danger,
                      size: 37,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Something went wrong",
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x060F172A),
          blurRadius: 16,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? "0") ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? "") ?? 0;
  }

  String _formatReviewDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "Today";
    }

    if (difference.inDays == 1) {
      return "Yesterday";
    }

    if (difference.inDays < 7) {
      return "${difference.inDays}d ago";
    }

    return "${date.day}/${date.month}/${date.year}";
  }

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final Color firstColor = isError ? const Color(0xFFDC2626) : _success;
    final Color secondColor = isError
        ? const Color(0xFFEF4444)
        : const Color(0xFF14B8A6);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [firstColor, secondColor]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: firstColor.withOpacity(.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 37,
                width: 37,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isError ? Icons.error_rounded : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
