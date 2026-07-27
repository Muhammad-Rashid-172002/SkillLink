import 'package:cloud_firestore/cloud_firestore.dart';

class CreditManagementService {
  CreditManagementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Agar aapke worker documents mein field `leadCredits` ya
  /// `creditBalance` hai to is value ko us field name se replace kar dein.
  static const String balanceField = 'credits';

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection('credit_transactions');

  Stream<QuerySnapshot<Map<String, dynamic>>> workersStream() {
    return _users.where('role', isEqualTo: 'worker').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> transactionsStream() {
    return _transactions.snapshots();
  }

  Future<void> addCredits({
    required String workerId,
    required String workerName,
    required int amount,
    required String reason,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Credit amount must be greater than zero.');
    }

    final transactionRef = _transactions.doc();
    final workerRef = _users.doc(workerId);
    final batch = _firestore.batch();

    batch.set(
      workerRef,
      {
        balanceField: FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(transactionRef, {
      'workerId': workerId,
      'workerName': workerName,
      'amount': amount,
      'type': 'credit',
      'reason': reason.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': 'admin',
    });

    await batch.commit();
  }

  Future<void> deductCredits({
    required String workerId,
    required String workerName,
    required int currentBalance,
    required int amount,
    required String reason,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Credit amount must be greater than zero.');
    }

    if (amount > currentBalance) {
      throw StateError('Worker ke paas itne credits available nahi hain.');
    }

    final transactionRef = _transactions.doc();
    final workerRef = _users.doc(workerId);
    final batch = _firestore.batch();

    batch.set(
      workerRef,
      {
        balanceField: FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(transactionRef, {
      'workerId': workerId,
      'workerName': workerName,
      'amount': amount,
      'type': 'debit',
      'reason': reason.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': 'admin',
    });

    await batch.commit();
  }

  Future<void> setCreditBalance({
    required String workerId,
    required String workerName,
    required int oldBalance,
    required int newBalance,
    required String reason,
  }) async {
    if (newBalance < 0) {
      throw ArgumentError('Credit balance negative nahi ho sakta.');
    }

    final difference = newBalance - oldBalance;
    if (difference == 0) return;

    final transactionRef = _transactions.doc();
    final workerRef = _users.doc(workerId);
    final batch = _firestore.batch();

    batch.set(
      workerRef,
      {
        balanceField: newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(transactionRef, {
      'workerId': workerId,
      'workerName': workerName,
      'amount': difference.abs(),
      'type': difference > 0 ? 'credit' : 'debit',
      'reason': reason.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': 'admin',
      'balanceBefore': oldBalance,
      'balanceAfter': newBalance,
    });

    await batch.commit();
  }
}

class CreditWorker {
  const CreditWorker({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.skill,
    required this.credits,
    required this.completedJobs,
    required this.isBlocked,
    required this.photoUrl,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String skill;
  final int credits;
  final int completedJobs;
  final bool isBlocked;
  final String? photoUrl;
  final DateTime? createdAt;

  factory CreditWorker.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return CreditWorker(
      id: document.id,
      name: _firstString(
        data,
        const ['name', 'fullName', 'displayName', 'userName'],
        fallback: 'Unnamed Worker',
      ),
      email: _firstString(
        data,
        const ['email'],
        fallback: 'No email',
      ),
      phone: _firstString(
        data,
        const ['phone', 'phoneNumber', 'mobile'],
        fallback: 'Not provided',
      ),
      skill: _firstString(
        data,
        const ['skill', 'category', 'profession', 'serviceName'],
        fallback: 'General Worker',
      ),
      credits: _firstInt(
        data,
        const ['credits', 'leadCredits', 'creditBalance'],
      ),
      completedJobs: _firstInt(
        data,
        const ['completedJobs', 'completedJobCount', 'jobsCompleted'],
      ),
      isBlocked: _firstBool(
        data,
        const ['isBlocked', 'blocked', 'isDisabled'],
      ),
      photoUrl: _nullableString(
        data,
        const ['photoUrl', 'profileImage', 'imageUrl'],
      ),
      createdAt: _firstDate(
        data,
        const ['createdAt', 'joinedAt', 'registeredAt'],
      ),
    );
  }
}

class CreditTransaction {
  const CreditTransaction({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.amount,
    required this.type,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String workerId;
  final String workerName;
  final int amount;
  final String type;
  final String reason;
  final DateTime? createdAt;

  bool get isCredit => type == 'credit';

  factory CreditTransaction.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return CreditTransaction(
      id: document.id,
      workerId: _firstString(
        data,
        const ['workerId'],
        fallback: '',
      ),
      workerName: _firstString(
        data,
        const ['workerName'],
        fallback: 'Worker',
      ),
      amount: _firstInt(data, const ['amount']),
      type: _firstString(
        data,
        const ['type'],
        fallback: 'credit',
      ).toLowerCase(),
      reason: _firstString(
        data,
        const ['reason', 'note'],
        fallback: 'Admin adjustment',
      ),
      createdAt: _firstDate(
        data,
        const ['createdAt', 'date'],
      ),
    );
  }
}

String _firstString(
  Map<String, dynamic> data,
  List<String> keys, {
  required String fallback,
}) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return fallback;
}

String? _nullableString(
  Map<String, dynamic> data,
  List<String> keys,
) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

int _firstInt(
  Map<String, dynamic> data,
  List<String> keys,
) {
  for (final key in keys) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

bool _firstBool(
  Map<String, dynamic> data,
  List<String> keys,
) {
  for (final key in keys) {
    final value = data[key];
    if (value is bool) return value;
  }
  return false;
}

DateTime? _firstDate(
  Map<String, dynamic> data,
  List<String> keys,
) {
  for (final key in keys) {
    final value = data[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
  }
  return null;
}
