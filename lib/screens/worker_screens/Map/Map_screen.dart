import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:skill_link/screens/worker_screens/Bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/worker_screens/Map/worker_job_detail.dart';

class MapSreen extends StatefulWidget {
  const MapSreen({super.key});

  @override
  State<MapSreen> createState() => _MapSreenState();
}

class _MapSreenState extends State<MapSreen> {
  static const LatLng pabbiCenter = LatLng(34.0097, 71.9970);

  GoogleMapController? mapController;

  Stream<QuerySnapshot> getRequestsStream() {
    return FirebaseFirestore.instance
        .collection("requests")
        .where("status", isEqualTo: "pending")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  Set<Marker> _buildMarkers(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      final lat = (data["lat"] ?? 34.0097).toDouble();
      final lng = (data["lng"] ?? 71.9970).toDouble();

      return Marker(
        markerId: MarkerId(doc.id),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(
          title: data["title"] ?? "Job Request",
          snippet: data["location"] ?? "",
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: const WorkerBottomBar(selectedIndex: 1),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: getRequestsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF16A34A)),
              );
            }

            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }

            final docs = snapshot.data?.docs ?? [];

            return Column(
              children: [
                _header(docs.length),
                _googleMap(docs),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader(),
                        const SizedBox(height: 14),
                        if (docs.isEmpty)
                          _emptyState()
                        else
                          ...docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return _requestCard(doc.id, data);
                          }),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "Nearby Requests",
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "$count Jobs",
              style: const TextStyle(
                color: Color(0xFF16A34A),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _googleMap(List<QueryDocumentSnapshot> docs) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      height: 230,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: pabbiCenter,
          zoom: 13,
        ),
        markers: _buildMarkers(docs),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: false,
        onMapCreated: (controller) {
          mapController = controller;
        },
      ),
    );
  }

  Widget _sectionHeader() {
    return const Text(
      "Available Jobs",
      style: TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _requestCard(String requestId, Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(item["category"] ?? ""),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item["title"] ?? "No Title",
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item["category"] ?? "",
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                item["budget"] ?? "",
                style: const TextStyle(
                  color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow(Icons.location_on_outlined, item["location"] ?? ""),
          const SizedBox(height: 8),
          _infoRow(Icons.near_me_outlined, "Nearby"),
          const SizedBox(height: 14),
          Row(
            children: [
              _badge(item["urgency"] ?? "Normal"),
              const Spacer(),
              _acceptButton(requestId, item),
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
    if (category == "Plumber") icon = Icons.plumbing_rounded;

    return Container(
      height: 52,
      width: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withOpacity(.10),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: const Color(0xFF16A34A), size: 27),
    );
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

  Widget _badge(String text) {
    final isUrgent = text == "Urgent" || text == "Emergency";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isUrgent
            ? const Color(0xFFEF4444).withOpacity(.10)
            : const Color(0xFF16A34A).withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _acceptButton(String requestId, Map<String, dynamic> item) {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkerJobDetailScreen(
                title: item["title"] ?? "",
                category: item["category"] ?? "",
                location: item["location"] ?? "",
                distance: "Nearby",
                budget: item["budget"] ?? "",
                urgency: item["urgency"] ?? "",
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF16A34A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: const Text(
          "View Job",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.work_off_rounded, size: 46, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text(
            "No pending jobs",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 6),
          Text(
            "New customer requests will appear here.",
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}