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
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFDC2626);

  final String uid = FirebaseAuth.instance.currentUser!.uid;

  final List<Map<String, dynamic>> packages = const [
    {
      'credits': 10,
      'price': 300,
      'label': 'Starter',
      'description': 'Best for trying SkillNova',
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

  Stream<QuerySnapshot<Map<String, dynamic>>> get _requestsStream =>
      FirebaseFirestore.instance
          .collection('payment_requests')
          .where('workerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _pendingStream =>
      FirebaseFirestore.instance
          .collection('payment_requests')
          .where('workerId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .snapshots();

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
            await Future<void>.delayed(const Duration(milliseconds: 350));
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
                    const SizedBox(height: 18),
                    _latestStatus(),
                    const SizedBox(height: 28),
                    _sectionHeader(
                      'Buy lead credits',
                      'Choose a package that fits your work',
                    ),
                    const SizedBox(height: 14),
                    _packagesWithGuard(),
                    const SizedBox(height: 28),
                    _sectionHeader(
                      'Payment requests',
                      'Track your submitted payment proofs',
                    ),
                    const SizedBox(height: 14),
                    _paymentRequests(),
                    const SizedBox(height: 28),
                    _sectionHeader(
                      'Recent transactions',
                      'Your latest wallet activity',
                    ),
                    const SizedBox(height: 14),
                    _transactions(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wallet',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Manage credits and payment activity',
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
        ),
        child: const Icon(Icons.account_balance_wallet_outlined),
      ),
    ],
  );

  Widget _walletCard() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final credits = _toInt(snapshot.data?.data()?['credits']);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primaryDark, _primary, Color(0xFF3DD56E)],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0x28FFFFFF),
                    child: Icon(Icons.bolt_rounded, color: Colors.white),
                  ),
                  SizedBox(width: 11),
                  Text(
                    'AVAILABLE CREDITS',
                    style: TextStyle(
                      color: Color(0xDFFFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.verified_rounded, color: Colors.white),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.work_outline_rounded, color: Colors.white),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Enough for approximately $credits '
                        'lead${credits == 1 ? '' : 's'}',
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
        );
      },
    );
  }

  Widget _latestStatus() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.docs.first.data();
        final status = (data['status'] ?? 'pending').toString();
        final credits = _toInt(data['credits']);
        final amount = _toInt(data['amount']);
        final reason = (data['rejectionReason'] ?? '').toString();

        final Color color;
        final IconData icon;
        final String title;
        final String message;

        if (status == 'approved') {
          color = _primary;
          icon = Icons.check_circle_rounded;
          title = 'Payment approved';
          message = '$credits credits approved for Rs. $amount.';
        } else if (status == 'rejected') {
          color = _danger;
          icon = Icons.cancel_rounded;
          title = 'Payment rejected';
          message = reason.isEmpty
              ? 'Your payment proof could not be verified.'
              : reason;
        } else {
          color = _warning;
          icon = Icons.hourglass_top_rounded;
          title = 'Payment under review';
          message =
              '$credits credits for Rs. $amount are waiting for approval.';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      message,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 11.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: _textPrimary,
          fontSize: 21,
          fontWeight: FontWeight.w900,
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

  Widget _packagesWithGuard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pendingStream,
      builder: (context, snapshot) {
        final hasPending = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        return _packages(hasPending);
      },
    );
  }

  Widget _packages(bool hasPending) {
    return Column(
      children: packages.map((item) {
        final credits = item['credits'] as int;
        final price = item['price'] as int;
        final recommended = item['recommended'] as bool;

        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: recommended ? _primary : _border,
              width: recommended ? 1.6 : 1,
            ),
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
                    child: const Icon(Icons.bolt_rounded, color: _primary),
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
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Rs. $price',
                        style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: hasPending
                      ? null
                      : () async {
                          final submitted = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentMethodScreen(
                                credits: credits.toString(),
                                price: 'Rs. $price',
                              ),
                            ),
                          );
                          if (submitted == true && mounted) {
                            setState(() {});
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: recommended ? _primary : _textPrimary,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    hasPending ? 'Payment already under review' : 'Buy package',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _paymentRequests() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loading();
        }
        if (snapshot.hasError) {
          return _empty(
            Icons.error_outline_rounded,
            'Unable to load payment requests',
            'Please check your connection.',
            _danger,
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _empty(
            Icons.receipt_long_outlined,
            'No payment requests yet',
            'Your submitted payment proofs will appear here.',
            _primary,
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final status = (data['status'] ?? 'pending').toString();
            final credits = _toInt(data['credits']);
            final amount = _toInt(data['amount']);
            final createdAt = data['createdAt'] as Timestamp?;

            final color = status == 'approved'
                ? _primary
                : status == 'rejected'
                ? _danger
                : _warning;

            return _listTile(
              icon: status == 'approved'
                  ? Icons.check_rounded
                  : status == 'rejected'
                  ? Icons.close_rounded
                  : Icons.hourglass_top_rounded,
              color: color,
              title: '$credits credits • Rs. $amount',
              subtitle: createdAt == null
                  ? 'Date unavailable'
                  : _formatDate(createdAt.toDate()),
              trailing: status.toUpperCase(),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _transactions() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('workerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loading();
        }
        if (snapshot.hasError) {
          return _empty(
            Icons.error_outline_rounded,
            'Unable to load transactions',
            'Please check your connection.',
            _danger,
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _empty(
            Icons.receipt_long_outlined,
            'No transactions yet',
            'Approved purchases and credit deductions appear here.',
            _primary,
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final amount = (data['amount'] ?? '').toString().trim();
            final plus = amount.startsWith('+');
            final createdAt = data['createdAt'] as Timestamp?;

            return _listTile(
              icon: plus ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: plus ? _primary : _danger,
              title: (data['title'] ?? 'Wallet transaction').toString(),
              subtitle: createdAt == null
                  ? 'Date unavailable'
                  : _formatDate(createdAt.toDate()),
              trailing: amount.isEmpty ? '—' : amount,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _listTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String trailing,
  }) {
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
          CircleAvatar(
            backgroundColor: color.withOpacity(.10),
            child: Icon(icon, color: color),
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
                  subtitle,
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
            trailing,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loading() => Container(
    height: 82,
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border),
    ),
    child: const Center(
      child: CircularProgressIndicator(color: _primary, strokeWidth: 2.3),
    ),
  );

  Widget _empty(IconData icon, String title, String message, Color color) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(.10),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

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
