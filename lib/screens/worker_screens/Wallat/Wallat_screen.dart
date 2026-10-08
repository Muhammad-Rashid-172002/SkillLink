import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_models.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_cards.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/design_system/widgets/skillnova_surfaces.dart';
import 'package:skill_link/screens/worker_screens/Wallat/payment_method_screen.dart';

/// A purchasable lead-credit package. Prices are the real SkillNova prices.
@immutable
class CreditPackage {
  const CreditPackage({
    required this.label,
    required this.credits,
    required this.price,
    required this.description,
    this.recommended = false,
  });

  final String label;
  final int credits;
  final int price;
  final String description;
  final bool recommended;

  int get pricePerCredit => (price / credits).round();
}

const List<CreditPackage> creditPackages = [
  CreditPackage(
    label: 'Starter',
    credits: 10,
    price: 300,
    description: 'Try SkillNova with a few leads',
  ),
  CreditPackage(
    label: 'Popular',
    credits: 20,
    price: 600,
    description: 'For steady weekly work',
    recommended: true,
  ),
  CreditPackage(
    label: 'Pro',
    credits: 50,
    price: 1200,
    description: 'Best value per lead',
  ),
];

/// Worker lead-credit wallet: balance, buying credits by manual payment
/// proof, and the history of payments and credit use.
class WallatScreen extends StatefulWidget {
  const WallatScreen({super.key});

  @override
  State<WallatScreen> createState() => _WallatScreenState();
}

class _WallatScreenState extends State<WallatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  int _refreshKey = 0;

  Stream<QuerySnapshot<Map<String, dynamic>>> get _paymentRequests => _firestore
      .collection('payment_requests')
      .where('workerId', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .limit(5)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _transactions => _firestore
      .collection('transactions')
      .where('workerId', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots();

  Future<void> _buy(CreditPackage package) async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodScreen(
          credits: package.credits.toString(),
          price: formatWorkerJobBudget('${package.price}'),
        ),
      ),
    );
    if (submitted == true && mounted) {
      SkillNovaToast.show(
        context,
        'Payment proof sent. Credits are added once it’s approved.',
        tone: SkillNovaTone.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lead credits')),
        body: const Center(
          child: EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Sign in to see your credits',
            message: 'Your balance and payments appear once you sign in.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Lead credits')),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _refreshKey++),
        child: ListView(
          key: ValueKey(_refreshKey),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            SkillNovaSpacing.gutter,
            SkillNovaSpacing.xs,
            SkillNovaSpacing.gutter,
            SkillNovaSpacing.xxxl,
          ),
          children: [
            ContentWidth(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _paymentRequests,
                builder: (context, payments) {
                  final requests = payments.data?.docs ?? const [];
                  final pending = requests.any(
                    (doc) => _status(doc.data()) == 'pending',
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _balance(),
                      if (requests.isNotEmpty) ...[
                        const SizedBox(height: SkillNovaSpacing.md),
                        _latestPayment(requests.first.data()),
                      ],
                      const SizedBox(height: SkillNovaSpacing.xl),
                      const SectionHeader(
                        title: 'Buy credits',
                        subtitle:
                            'Pay by bank transfer, then upload the receipt.',
                      ),
                      const SizedBox(height: SkillNovaSpacing.md),
                      for (final package in creditPackages) ...[
                        _PackageCard(
                          package: package,
                          enabled: !pending,
                          onBuy: () => _buy(package),
                        ),
                        const SizedBox(height: SkillNovaSpacing.sm),
                      ],
                      if (requests.isNotEmpty) ...[
                        const SizedBox(height: SkillNovaSpacing.lg),
                        ListGroup(
                          title: 'Payments',
                          children: [
                            for (final doc in requests)
                              _PaymentRow(data: doc.data()),
                          ],
                        ),
                      ],
                      const SizedBox(height: SkillNovaSpacing.xl),
                      _history(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balance() {
    final text = Theme.of(context).textTheme;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(_uid).snapshots(),
      builder: (context, snapshot) {
        final loading = !snapshot.hasData && !snapshot.hasError;
        final credits = _toInt(snapshot.data?.data()?['credits']);
        return SkillNovaCard(
          padding: const EdgeInsets.all(SkillNovaSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Available credits', style: text.bodyMedium),
                    const SizedBox(height: SkillNovaSpacing.xxs),
                    loading
                        ? const SkeletonBox(width: 80, height: 36)
                        : Semantics(
                            label: '$credits lead credits available',
                            excludeSemantics: true,
                            child: Text('$credits', style: text.displaySmall),
                          ),
                    const SizedBox(height: SkillNovaSpacing.xxs),
                    Text(
                      credits == 0
                          ? 'Buy credits to start accepting leads.'
                          : '1 credit is used each time you accept a lead.',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              IconTile(
                icon: Icons.bolt_rounded,
                tone: credits == 0 ? SkillNovaTone.warning : SkillNovaTone.info,
                size: 52,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _latestPayment(Map<String, dynamic> data) {
    final status = _status(data);
    final credits = _toInt(data['credits']);
    final amount = _toInt(data['amount']);
    final reason = (data['rejectionReason'] ?? '').toString().trim();
    return switch (status) {
      'approved' => InfoBanner(
        tone: SkillNovaTone.success,
        title: 'Payment approved',
        message:
            '$credits credits were added for ${formatWorkerJobBudget('$amount')}.',
      ),
      'rejected' => InfoBanner(
        tone: SkillNovaTone.error,
        title: 'Payment couldn’t be verified',
        message: reason.isEmpty
            ? 'Check the receipt details and submit a new payment.'
            : reason,
      ),
      _ => InfoBanner(
        tone: SkillNovaTone.warning,
        icon: Icons.hourglass_top_rounded,
        title: 'Payment under review',
        message:
            'We’re checking your ${formatWorkerJobBudget('$amount')} payment for $credits credits. '
            'You can buy more once it’s reviewed.',
      ),
    };
  }

  Widget _history() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _transactions,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const ErrorState(
            title: 'History unavailable',
            message: 'We couldn’t load your credit history right now.',
          );
        }
        if (!snapshot.hasData) {
          return const SkeletonCard(height: 160);
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No credit activity yet',
            message:
                'Approved purchases and credits used on leads will appear '
                'here.',
          );
        }
        return ListGroup(
          title: 'Credit history',
          children: [for (final doc in docs) _TransactionRow(data: doc.data())],
        );
      },
    );
  }
}

String _status(Map<String, dynamic> data) =>
    (data['status'] ?? 'pending').toString().trim().toLowerCase();

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '0') ?? 0;
}

String _date(Object? value) {
  final date = value is Timestamp ? value.toDate() : null;
  if (date == null) return 'Just now';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.enabled,
    required this.onBuy,
  });

  final CreditPackage package;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return SkillNovaCard(
      borderColor: package.recommended ? colors.primary : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: SkillNovaSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${package.credits} credits', style: text.titleMedium),
                    if (package.recommended)
                      const StatusBadge(
                        label: 'Most popular',
                        tone: SkillNovaTone.info,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${package.description} · ${formatWorkerJobBudget('${package.pricePerCredit}')} '
                  'per lead',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: SkillNovaSpacing.sm),
          package.recommended
              ? FilledButton(
                  onPressed: enabled ? onBuy : null,
                  child: Text(formatWorkerJobBudget('${package.price}')),
                )
              : OutlinedButton(
                  onPressed: enabled ? onBuy : null,
                  child: Text(formatWorkerJobBudget('${package.price}')),
                ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status = _status(data);
    final (label, tone, icon) = switch (status) {
      'approved' => ('Approved', SkillNovaTone.success, Icons.check_rounded),
      'rejected' => ('Rejected', SkillNovaTone.error, Icons.close_rounded),
      _ => ('In review', SkillNovaTone.warning, Icons.schedule_rounded),
    };
    return ListRow(
      icon: Icons.receipt_outlined,
      title:
          '${_toInt(data['credits'])} credits · ${formatWorkerJobBudget('${_toInt(data['amount'])}')}',
      subtitle: _date(data['createdAt']),
      trailing: StatusBadge(label: label, tone: tone, icon: icon),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final amount = (data['amount'] ?? '').toString().trim();
    final added = amount.startsWith('+');
    final colors = Theme.of(context).colorScheme;
    return ListRow(
      icon: added ? Icons.add_rounded : Icons.bolt_rounded,
      tone: added ? SkillNovaTone.success : SkillNovaTone.neutral,
      title: (data['title'] ?? 'Credit update').toString(),
      subtitle: _date(data['createdAt']),
      trailing: Text(
        amount,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: added ? SkillNovaColors.success : colors.onSurface,
        ),
      ),
    );
  }
}
