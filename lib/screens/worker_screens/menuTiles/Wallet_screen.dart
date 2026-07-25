import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const Color _primary = Color(0xFF2563EB);
  static const Color _primaryDark = Color(0xFF1D4ED8);
  static const Color _success = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _background = Color(0xFFF5F7FB);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE7ECF3);

  final String uid = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';
  String selectedFilter = 'All';

  final List<String> filters = const [
    'All',
    'Earnings',
    'Credits',
    'Deductions',
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _background,
        foregroundColor: _textPrimary,
        titleSpacing: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 21),
            ),
          ),
        ),
        title: const Text(
          'Wallet & Earnings',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.25,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('transactions')
              .where('workerId', isEqualTo: uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _loadingState();
            }

            if (snapshot.hasError) {
              return _errorState(snapshot.error.toString());
            }

            final docs = snapshot.data?.docs ?? [];

            docs.sort((a, b) {
              final aDate = _extractDate(a.data());
              final bDate = _extractDate(b.data());
              return bDate.compareTo(aDate);
            });

            final summary = _calculateSummary(docs);
            final filteredDocs = _filterTransactions(docs);

            return RefreshIndicator(
              color: _primary,
              onRefresh: () async {
                await Future<void>.delayed(
                  const Duration(milliseconds: 450),
                );
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _earningsCard(summary),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _statCard(
                                title: 'Credits',
                                value: '${summary.totalCredits}',
                                icon: Icons.bolt_rounded,
                                iconColor: const Color(0xFFF59E0B),
                                iconBackground: const Color(0xFFFFF7E8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _statCard(
                                title: 'Transactions',
                                value: '${docs.length}',
                                icon: Icons.receipt_long_rounded,
                                iconColor: _success,
                                iconBackground: const Color(0xFFEAF8EF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _searchField(),
                        const SizedBox(height: 14),
                        _filterChips(),
                        const SizedBox(height: 24),
                        _sectionHeader(filteredDocs.length),
                        const SizedBox(height: 14),
                        if (filteredDocs.isEmpty)
                          _emptyState()
                        else
                          ...filteredDocs.map(
                            (doc) => _transactionCard(doc.data()),
                          ),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _earningsCard(_WalletSummary summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(21, 21, 21, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDark, _primary, Color(0xFF60A5FA)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x302563EB),
            blurRadius: 28,
            offset: Offset(0, 13),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -58,
            right: -45,
            child: Container(
              height: 155,
              width: 155,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            right: 48,
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
                    height: 43,
                    width: 43,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'TOTAL EARNINGS',
                      style: TextStyle(
                        color: Color(0xDFFFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.05,
                      ),
                    ),
                  ),
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
                          Icons.trending_up_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Live',
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
              const SizedBox(height: 23),
              Text(
                'Rs. ${_formatMoney(summary.totalEarnings)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your completed job payments',
                style: TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _miniSummary(
                      label: 'Credits purchased',
                      value: '${summary.totalCredits}',
                      icon: Icons.bolt_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _miniSummary(
                      label: 'Total deductions',
                      value: 'Rs. ${_formatMoney(summary.totalDeductions)}',
                      icon: Icons.remove_circle_outline_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniSummary({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
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

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 21,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: searchController,
      onChanged: (value) {
        setState(() {
          searchQuery = value.trim().toLowerCase();
        });
      },
      decoration: InputDecoration(
        hintText: 'Search transactions...',
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: _textSecondary,
          size: 22,
        ),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                onPressed: () {
                  searchController.clear();
                  setState(() => searchQuery = '');
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: _textSecondary,
                  size: 20,
                ),
              )
            : null,
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(
            color: _primary,
            width: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 39,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = selectedFilter == filter;

          return ChoiceChip(
            selected: selected,
            onSelected: (_) {
              setState(() => selectedFilter = filter);
            },
            showCheckmark: false,
            label: Text(filter),
            backgroundColor: _surface,
            selectedColor: _primary,
            side: BorderSide(
              color: selected ? _primary : _border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : _textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(int count) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent transactions',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Latest wallet and earning activity',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFF4338CA),
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _transactionCard(Map<String, dynamic> data) {
    final title = (data['title'] ?? _fallbackTitle(data)).toString();
    final type = (data['type'] ?? '').toString();
    final amountText = (data['amount'] ?? '0').toString();
    final amount = _extractNumber(amountText);
    final date = _extractDate(data);

    final isIncome = type == 'job_payment' ||
        amountText.trim().startsWith('+');
    final isCreditPurchase = type == 'credit_purchase';

    final color = isIncome
        ? _success
        : isCreditPurchase
            ? const Color(0xFFF59E0B)
            : _danger;

    final icon = isIncome
        ? Icons.south_west_rounded
        : isCreditPurchase
            ? Icons.bolt_rounded
            : Icons.north_east_rounded;

    final formattedAmount = isCreditPurchase
        ? '${amount.toInt()} credits'
        : '${isIncome ? '+' : '-'} Rs. ${_formatMoney(amount)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 22),
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
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      _typeIcon(type),
                      size: 13,
                      color: _textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _typeLabel(type),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 10.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedAmount,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _formatDate(date),
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterTransactions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      final type = (data['type'] ?? '').toString();
      final title = (data['title'] ?? '').toString().toLowerCase();
      final amount = (data['amount'] ?? '').toString().toLowerCase();

      final matchesSearch = searchQuery.isEmpty ||
          title.contains(searchQuery) ||
          type.toLowerCase().contains(searchQuery) ||
          amount.contains(searchQuery);

      bool matchesFilter = true;

      switch (selectedFilter) {
        case 'Earnings':
          matchesFilter = type == 'job_payment';
          break;
        case 'Credits':
          matchesFilter = type == 'credit_purchase';
          break;
        case 'Deductions':
          matchesFilter = type != 'job_payment' &&
              type != 'credit_purchase';
          break;
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  _WalletSummary _calculateSummary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    double totalEarnings = 0;
    double totalDeductions = 0;
    int totalCredits = 0;

    for (final doc in docs) {
      final data = doc.data();
      final type = (data['type'] ?? '').toString();
      final amount = _extractNumber(data['amount']);

      if (type == 'job_payment') {
        totalEarnings += amount;
      } else if (type == 'credit_purchase') {
        totalCredits += amount.toInt();
      } else {
        totalDeductions += amount;
      }
    }

    return _WalletSummary(
      totalEarnings: totalEarnings,
      totalCredits: totalCredits,
      totalDeductions: totalDeductions,
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 31, 24, 30),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Color(0xFFEEF2FF),
            child: Icon(
              Icons.receipt_long_outlined,
              color: _primary,
              size: 31,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'No matching transactions',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Your earnings, credit purchases and deductions will appear here.',
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

  Widget _loadingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      children: [
        Container(
          height: 240,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _loadingBox(height: 90)),
            const SizedBox(width: 12),
            Expanded(child: _loadingBox(height: 90)),
          ],
        ),
        const SizedBox(height: 24),
        ...List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _loadingBox(height: 77),
          ),
        ),
      ],
    );
  }

  Widget _loadingBox({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: _primary,
          strokeWidth: 2.3,
        ),
      ),
    );
  }

  Widget _errorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7F7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: _danger,
                size: 42,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load wallet activity',
                style: TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                error,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 11.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double _extractNumber(dynamic value) {
    if (value is num) return value.toDouble();

    final cleaned = value
        ?.toString()
        .replaceAll(RegExp(r'[^0-9.]'), '');

    return double.tryParse(cleaned ?? '') ?? 0;
  }

  static DateTime _extractDate(Map<String, dynamic> data) {
    final possibleValues = [
      data['createdAt'],
      data['updatedAt'],
      data['completedAt'],
    ];

    for (final value in possibleValues) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return 'Date unavailable';

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

  static String _formatMoney(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }

    return amount.toStringAsFixed(2);
  }

  static String _fallbackTitle(Map<String, dynamic> data) {
    switch ((data['type'] ?? '').toString()) {
      case 'job_payment':
        return 'Job payment received';
      case 'credit_purchase':
        return 'Lead credits purchased';
      default:
        return 'Wallet transaction';
    }
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'job_payment':
        return 'Job earning';
      case 'credit_purchase':
        return 'Credit purchase';
      case 'lead_deduction':
        return 'Lead credit deduction';
      default:
        return 'Wallet activity';
    }
  }

  static IconData _typeIcon(String type) {
    switch (type) {
      case 'job_payment':
        return Icons.work_outline_rounded;
      case 'credit_purchase':
        return Icons.bolt_rounded;
      case 'lead_deduction':
        return Icons.remove_circle_outline_rounded;
      default:
        return Icons.receipt_long_outlined;
    }
  }
}

class _WalletSummary {
  final double totalEarnings;
  final int totalCredits;
  final double totalDeductions;

  const _WalletSummary({
    required this.totalEarnings,
    required this.totalCredits,
    required this.totalDeductions,
  });
}
