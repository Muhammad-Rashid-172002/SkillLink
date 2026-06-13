import 'package:flutter/material.dart';

class CustomerMyRequestsScreen extends StatefulWidget {
  const CustomerMyRequestsScreen({super.key});

  @override
  State<CustomerMyRequestsScreen> createState() =>
      _CustomerMyRequestsScreenState();
}

class _CustomerMyRequestsScreenState extends State<CustomerMyRequestsScreen> {
  int selectedTab = 0;

  final tabs = ["Pending", "Accepted", "Completed"];

  final requests = [
    {
      "title": "Fan is not working",
      "category": "Electrician",
      "location": "Pabbi Bazar, Nowshera",
      "budget": "Rs. 1000",
      "status": "Pending",
      "time": "Today, 2:30 PM",
    },
    {
      "title": "AC cooling issue",
      "category": "AC Repair",
      "location": "Nowshera Cantt",
      "budget": "Rs. 2500",
      "status": "Accepted",
      "time": "Tomorrow, 11:00 AM",
    },
    {
      "title": "Room painting needed",
      "category": "Painter",
      "location": "University Road",
      "budget": "Rs. 5000",
      "status": "Completed",
      "time": "Yesterday, 4:00 PM",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredRequests = requests
        .where((item) => item["status"] == tabs[selectedTab])
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
     
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back),
              ),
              _header(),
              const SizedBox(height: 22),
              _statusTabs(),
              const SizedBox(height: 22),
              if (filteredRequests.isEmpty)
                _emptyState()
              else
                Column(
                  children: filteredRequests.map((request) {
                    return _requestCard(request);
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "My Requests",
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 6),
        Text(
          "Track your service requests",
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _statusTabs() {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = selectedTab == index;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => selectedTab = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF2563EB)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _requestCard(Map<String, String> request) {
    final status = request["status"]!;
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(request["category"]!),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request["title"]!,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      request["category"]!,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(status, statusColor),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow(Icons.location_on_outlined, request["location"]!),
          const SizedBox(height: 8),
          _infoRow(Icons.access_time_rounded, request["time"]!),
          const SizedBox(height: 8),
          _infoRow(Icons.payments_outlined, request["budget"]!),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _outlineButton("View Details")),
              const SizedBox(width: 12),
              Expanded(
                child: _primaryButton(
                  status == "Accepted"
                      ? "Chat Worker"
                      : status == "Completed"
                      ? "Rate Worker"
                      : "Waiting",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBox(String category) {
    IconData icon = Icons.handyman_rounded;

    if (category == "Electrician") icon = Icons.electrical_services_rounded;
    if (category == "AC Repair") icon = Icons.ac_unit_rounded;
    if (category == "Painter") icon = Icons.format_paint_rounded;

    return Container(
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withOpacity(.10),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: const Color(0xFF2563EB), size: 28),
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    if (status == "Accepted") return const Color(0xFF2563EB);
    if (status == "Completed") return const Color(0xFF16A34A);
    return const Color(0xFFF59E0B);
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _outlineButton(String text) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(String text) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF2563EB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.assignment_outlined, size: 52, color: Color(0xFF94A3B8)),
          SizedBox(height: 14),
          Text(
            "No requests found",
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Your service requests will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
