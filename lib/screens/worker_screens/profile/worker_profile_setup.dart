import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/home_screen/worker_dashbaord.dart';

class WorkerProfileSetupScreen extends StatefulWidget {
  const WorkerProfileSetupScreen({super.key});

  @override
  State<WorkerProfileSetupScreen> createState() =>
      _WorkerProfileSetupScreenState();
}

class _WorkerProfileSetupScreenState extends State<WorkerProfileSetupScreen> {
  String selectedSkill = "Electrician";

  final skills = [
    "Electrician",
    "Plumber",
    "Painter",
    "Carpenter",
    "Mechanic",
    "AC Technician",
    "Cleaner",
    "Mason",
  ];

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final experienceController = TextEditingController();
  final rateController = TextEditingController();
  final locationController = TextEditingController();
  final bioController = TextEditingController();

  // save worker profile
  Future<void> saveWorkerProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "uid": uid,
        "role": "worker",
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "skill": selectedSkill,
        "experience": experienceController.text.trim(),
        "hourlyRate": rateController.text.trim(),
        "location": locationController.text.trim(),
        "bio": bioController.text.trim(),
        "profileCompleted": true,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WorkerHomeScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(context),
              const SizedBox(height: 24),
              _headerCard(),
              const SizedBox(height: 26),
              _profilePhoto(),
              const SizedBox(height: 28),
              _sectionTitle("Basic Information"),
              const SizedBox(height: 14),
              _textField(
                "Full Name",
                "Enter your full name",
                Icons.person,
                nameController,
              ),
              const SizedBox(height: 16),
              _textField(
                "Phone Number",
                "+92 300 0000000",
                Icons.phone,
                phoneController,
              ),
              const SizedBox(height: 16),
              _skillDropdown(),
              const SizedBox(height: 26),
              _sectionTitle("Work Details"),
              const SizedBox(height: 14),
              _textField(
                "Experience",
                "Example: 3 years",
                Icons.work,
                experienceController,
              ),
              const SizedBox(height: 16),
              _textField(
                "Hourly Rate",
                "Example: Rs. 800",
                Icons.payments,
                rateController,
              ),
              const SizedBox(height: 16),
              _textField(
                "Location",
                "City / Area",
                Icons.location_on,
                locationController,
              ),
              const SizedBox(height: 16),
              _bioField(),
              const SizedBox(height: 30),
              _submitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withOpacity(.10),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Text(
            "WORKER SETUP",
            style: TextStyle(
              color: Color(0xFF16A34A),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withOpacity(.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.handyman_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Complete Your Profile",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Add your skills and work details to get jobs",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profilePhoto() {
    return Center(
      child: Stack(
        children: [
          Container(
            height: 112,
            width: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.08),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 56,
              color: Color(0xFF94A3B8),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 6,
            child: Container(
              height: 36,
              width: 36,
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _textField(
    String label,
    String hint,
    IconData icon,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextField(
          controller: controller,
          decoration: _inputDecoration(hint, icon),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF334155),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.8),
      ),
    );
  }

  Widget _skillDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label("Main Skill"),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedSkill,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: skills.map((skill) {
                return DropdownMenuItem(
                  value: skill,
                  child: Text(
                    skill,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => selectedSkill = value!);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _bioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label("Short Bio"),
        TextField(
          maxLines: 4,
          decoration: _inputDecoration(
            "Tell customers about your work experience...",
            Icons.description_outlined,
          ),
        ),
      ],
    );
  }

  Widget _submitButton() {
    return SizedBox(
      height: 60,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          await saveWorkerProfile();
        },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF16A34A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: const Text(
          "Save & Continue",
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
