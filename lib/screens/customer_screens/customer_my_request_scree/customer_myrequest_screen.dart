import 'package:skill_link/screens/customer_screens/bookings/customer_bookings_screen.dart';

/// Legacy class retained so older imports continue to compile.
/// All rendering now delegates to the canonical Bookings implementation.
class CustomerMyRequestsScreen extends CustomerBookingsScreen {
  const CustomerMyRequestsScreen({super.key, super.dataSource});
}
