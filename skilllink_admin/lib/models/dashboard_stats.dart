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
    required this.totalEmergencyAlerts,
    required this.activeEmergencyAlerts,
    this.pendingVerifications = 0,
    this.openSupportRequests = 0,
  });

  final int totalUsers;
  final int totalWorkers;
  final int totalCustomers;
  final int totalJobs;
  final int pendingJobs;
  final int activeJobs;
  final int completedJobs;
  final int totalReviews;
  final int totalEmergencyAlerts;
  final int activeEmergencyAlerts;

  /// Worker identity submissions waiting for an admin decision.
  final int pendingVerifications;

  /// Support requests from the app that are still open.
  final int openSupportRequests;
}
