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
}
