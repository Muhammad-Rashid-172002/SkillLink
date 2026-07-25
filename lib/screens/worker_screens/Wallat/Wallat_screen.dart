import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/worker_screens/Wallat/payment_method_screen.dart';

class WallatScreen extends StatefulWidget {
  const WallatScreen({super.key});

  @override
  State<WallatScreen> createState() => _WallatScreenState();
}

class _WallatScreenState extends State<WallatScreen> {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _primaryDark = Color(0xFF0F7A38);
  static const Color _background = Color(0xFFF5F7FB);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE7ECF3);

  final String uid = FirebaseAuth.instance.currentUser!.uid;

  final List<Map<String, dynamic>> packages = [
    {
      'credits': 10,
      'price': 300,
      'label': 'Starter',
      'description': 'Best for trying SkillLink',
      'recommended': false,
    },
    {
      'credits': 20,
      'price': 600,
      'label': 'Popular',
      'description': 'Perfect for regular workers',
      'recommended': true,
    },
    {
      'credits': 50,
      'price': 1200,
      'label': 'Pro',
      'description': 'Maximum value for professionals',
      'recommended': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: const WorkerBottomBar(selectedIndex: 2),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _primary,
          onRefresh: () async {
            setState(() {});
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _header(),
                    const SizedBox(height: 22),
                    _walletCard(),
                    const SizedBox(height: 28),
                    _sectionHeader(
                      title: 'Buy lead credits',
                      subtitle: 'Choose a package that fits your work',
                    ),
                    const SizedBox(height: 14),
                    _packages(),
                    const SizedBox(height: 28),
                    _sectionHeader(
                      title: 'Recent transactions',
                      subtitle: 'Your latest wallet activity',
                    ),
                    const SizedBox(height: 14),
                    _transactionsList(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Wallet',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Manage credits and wallet activity',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 50,
          width: 50,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: _textPrimary,
            size: 25,
          ),
        ),
      ],
    );
  }

  Widget _walletCard() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final credits = _toInt(data?['credits']);
        final estimatedLeads = credits;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 22, 18, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryDark, _primary, Color(0xFF3DD56E)],
              stops: [0, 0.58, 1],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3516A34A),
                blurRadius: 28,
                offset: Offset(0, 13),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -58,
                right: -42,
                child: Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -70,
                right: 50,
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 11),
                      const Text(
                        'AVAILABLE CREDITS',
                        style: TextStyle(
                          color: Color(0xDFFFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Lead wallet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$credits',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 5),
                        child: Text(
                          'credits',
                          style: TextStyle(
                            color: Color(0xD9FFFFFF),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.work_outline_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Enough for approximately $estimatedLeads lead${estimatedLeads == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 21,
            height: 1.1,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.35,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _packages() {
    return Column(
      children: packages.map((item) {
        final int credits = item['credits'] as int;
        final int price = item['price'] as int;
        final bool recommended = item['recommended'] as bool;
        final int perCredit = (price / credits).round();

        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: recommended ? _primary : _border,
              width: recommended ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: recommended
                    ? const Color(0x1F16A34A)
                    : const Color(0x080F172A),
                blurRadius: recommended ? 22 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (recommended)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: const BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(22),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'RECOMMENDED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  17,
                  recommended ? 25 : 17,
                  17,
                  17,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 54,
                          width: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF8EF),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: _primary,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['label'].toString(),
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['description'].toString(),
                                style: const TextStyle(
                                  color: _textSecondary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$credits credits',
                              style: const TextStyle(
                                color: _primaryDark,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Rs. $price',
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.sell_outlined,
                            color: _textSecondary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Only Rs. $perCredit per lead credit',
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (credits == 50)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'BEST VALUE',
                                style: TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentMethodScreen(
                                credits: credits.toString(),
                                price: 'Rs. $price',
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor:
                              recommended ? _primary : _textPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Buy package',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _transactionsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('workerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _transactionsLoading();
        }

        if (snapshot.hasError) {
          return _transactionError();
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _emptyTransactions();
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final timestamp = data['createdAt'] as Timestamp?;

            return _transactionTile(
              title: (data['title'] ?? 'Wallet transaction').toString(),
              amount: (data['amount'] ?? '').toString(),
              date: timestamp == null ? '' : _formatDate(timestamp.toDate()),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _transactionTile({
    required String title,
    required String amount,
    required String date,
  }) {
    final normalizedAmount = amount.trim();
    final isPlus = normalizedAmount.startsWith('+');
    final transactionColor =
        isPlus ? _primary : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: transactionColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isPlus
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              color: transactionColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date.isEmpty ? 'Date unavailable' : date,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            normalizedAmount.isEmpty ? '—' : normalizedAmount,
            style: TextStyle(
              color: transactionColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionsLoading() {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          height: 75,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: _primary,
              strokeWidth: 2.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyTransactions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 27),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: Color(0xFFEAF8EF),
            child: Icon(
              Icons.receipt_long_outlined,
              color: _primary,
              size: 29,
            ),
          ),
          SizedBox(height: 15),
          Text(
            'No transactions yet',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Your credit purchases and deductions will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 35,
          ),
          SizedBox(height: 10),
          Text(
            'Unable to load transactions',
            style: TextStyle(
              color: Color(0xFF991B1B),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _formatDate(DateTime date) {
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
}
