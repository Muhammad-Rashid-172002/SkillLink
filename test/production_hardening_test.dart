import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_lead_models.dart';

/// Guards for the production-hardening changes. The matching rules must stay
/// identical to functions/job_targeting.js, which decides who is notified.
void main() {
  group('lead trade matching', () {
    test('matches the same trade under different names', () {
      expect(workerLeadCategoriesMatch('Plumber', 'Plumbing'), isTrue);
      expect(workerLeadCategoriesMatch('AC Repair', 'AC Technician'), isTrue);
      expect(workerLeadCategoriesMatch('Home Painter', 'Painter'), isTrue);
      expect(workerLeadCategoriesMatch('Pest Control', 'Pest'), isTrue);
    });

    test('generic words like "technician" or "repair" never match alone', () {
      expect(
        workerLeadCategoriesMatch('AC Repair', 'Appliance Repair'),
        isFalse,
      );
      expect(
        workerLeadCategoriesMatch('Mobile Repair', 'Solar Technician'),
        isFalse,
      );
      expect(
        workerLeadCategoriesMatch('Internet Technician', 'AC Technician'),
        isFalse,
      );
      expect(workerLeadCategoriesMatch('Plumber', 'Electrician'), isFalse);
      expect(workerLeadCategoriesMatch('', 'Plumber'), isFalse);
    });
  });

  group('client never writes server-owned data', () {
    String source(String path) => File(path).readAsStringSync();

    test('posting a request does not fan out notifications', () {
      final request = source(
        'lib/screens/customer_screens/Request/Request.dart',
      );
      expect(request, isNot(contains("collection('notifications')")));
      expect(request, isNot(contains("isEqualTo: 'worker'")));
    });

    test('rating a worker submits a review only', () {
      final rate = source(
        'lib/screens/customer_screens/customer_my_request_scree/'
        'RateWorkerScreen.dart',
      );
      expect(rate, contains("collection('reviews')"));
      expect(rate, isNot(contains("'totalReviews'")));
      // It may read the worker's profile to show who is being rated, but
      // never write it.
      expect(rate, isNot(contains('doc(assignedWorkerId).update')));
      expect(rate, isNot(contains("'rating': double")));
    });

    test('rules no longer let customers write worker aggregates', () {
      final rules = source('firestore.rules');
      expect(rules, isNot(contains('reviewAggregateUpdate')));
      expect(rules, contains('protectedProfileKeys'));
    });
  });
}
