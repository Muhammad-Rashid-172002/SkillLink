class DashboardStats {
  const DashboardStats({
    required this.totalUsers,
    required this.totalWorkers,
    required this.totalCustomers,
    required this.totalJobs,
    required this.pendingJobs,
    required this.activeJobs,
    required this.completedJobs,
    required this.totalReviews,
    required this.totalTransactions,
    required this.totalEmergencyAlerts,
    required this.activeEmergencyAlerts,
    this.pendingVerifications = 0,
    this.pendingPayments = 0,
  });

  final int totalUsers;
  final int totalWorkers;
  final int totalCustomers;
  final int totalJobs;
  final int pendingJobs;
  final int activeJobs;
  final int completedJobs;
  final int totalReviews;
  final int totalTransactions;
  final int totalEmergencyAlerts;
  final int activeEmergencyAlerts;

  /// Worker identity submissions waiting for an admin decision.
  final int pendingVerifications;

  /// Credit purchase proofs waiting for an admin decision.
  final int pendingPayments;
}
