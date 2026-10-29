import 'package:skill_link/screens/customer_screens/bookings/customer_bookings_screen.dart';

/// Compatibility entry used by the customer shell and historical routes.
/// The canonical implementation lives in [CustomerBookingsScreen].
class MyRequestsScreen extends CustomerBookingsScreen {
  const MyRequestsScreen({
    super.key,
    super.embedded,
    super.dataSource,
    super.onOpenBooking,
    super.onRateBooking,
  });
}
