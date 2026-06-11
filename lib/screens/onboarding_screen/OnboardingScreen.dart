import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int currentIndex = 0;

  final List<OnboardingData> pages = [
    OnboardingData(
      icon: Icons.search_rounded,
      title: "Find Skilled Workers",
      subtitle:
          "Hire trusted painters, electricians, plumbers, carpenters and more near your location.",
      color1: Color(0xFF2563EB),
      color2: Color(0xFF06B6D4),
    ),
    OnboardingData(
      icon: Icons.handyman_rounded,
      title: "Post Your Job Request",
      subtitle:
          "Describe your work, set your budget, share location and receive offers from professionals.",
      color1: Color(0xFF10B981),
      color2: Color(0xFF059669),
    ),
    OnboardingData(
      icon: Icons.verified_user_rounded,
      title: "Safe & Professional",
      subtitle:
          "Compare ratings, chat with workers, track progress and complete your work with confidence.",
      color1: Color(0xFFF97316),
      color2: Color(0xFFEA580C),
    ),
  ];

  void nextPage() {
    if (currentIndex == pages.length - 1) {
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      // );
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    }
  }

  void skip() {
    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    // );
  }

  @override
  Widget build(BuildContext context) {
    final page = pages[currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "SkillLink",
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextButton(
                    onPressed: skip,
                    child: const Text(
                      "Skip",
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() => currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final item = pages[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 310,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [item.color1, item.color2],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(42),
                            boxShadow: [
                              BoxShadow(
                                color: item.color1.withOpacity(0.35),
                                blurRadius: 35,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: -40,
                                right: -30,
                                child: CircleAvatar(
                                  radius: 90,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.10),
                                ),
                              ),
                              Positioned(
                                bottom: -50,
                                left: -30,
                                child: CircleAvatar(
                                  radius: 95,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.10),
                                ),
                              ),

                              Container(
                                height: 140,
                                width: 140,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.25),
                                  ),
                                ),
                                child: Icon(
                                  item.icon,
                                  size: 75,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 42),

                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          item.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 16,
                            height: 1.55,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: currentIndex == index ? 28 : 8,
                        decoration: BoxDecoration(
                          color: currentIndex == index
                              ? page.color1
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: nextPage,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: page.color1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        currentIndex == pages.length - 1
                            ? "Get Started"
                            : "Next",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color1;
  final Color color2;

  OnboardingData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color1,
    required this.color2,
  });
}