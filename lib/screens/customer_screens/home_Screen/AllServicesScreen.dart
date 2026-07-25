import 'dart:ui';

import 'package:flutter/material.dart';

class AllServicesScreen extends StatefulWidget {
  const AllServicesScreen({super.key});

  @override
  State<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends State<AllServicesScreen> {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;

  static const Color _primary = Color(0xFF2563EB);
  static const Color _secondary = Color(0xFF06B6D4);

  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  final List<ServiceItem> _services = const [
    ServiceItem(
      title: 'AC Repair',
      subtitle: 'Cooling and air conditioner service',
      icon: Icons.ac_unit_rounded,
      color: Color(0xFF0284C7),
    ),
    ServiceItem(
      title: 'Appliance Repair',
      subtitle: 'Home appliance maintenance',
      icon: Icons.home_repair_service_rounded,
      color: Color(0xFF7C3AED),
    ),
    ServiceItem(
      title: 'Beautician',
      subtitle: 'Beauty and personal care services',
      icon: Icons.face_retouching_natural_rounded,
      color: Color(0xFFDB2777),
    ),
    ServiceItem(
      title: 'Car Mechanic',
      subtitle: 'Vehicle inspection and repair',
      icon: Icons.car_repair_rounded,
      color: Color(0xFFEA580C),
    ),
    ServiceItem(
      title: 'Carpenter',
      subtitle: 'Furniture and woodwork services',
      icon: Icons.handyman_rounded,
      color: Color(0xFF92400E),
    ),
    ServiceItem(
      title: 'Cleaner',
      subtitle: 'Home and office cleaning',
      icon: Icons.cleaning_services_rounded,
      color: Color(0xFF0891B2),
    ),
    ServiceItem(
      title: 'Electrician',
      subtitle: 'Electrical installation and repair',
      icon: Icons.electrical_services_rounded,
      color: Color(0xFFF59E0B),
    ),
    ServiceItem(
      title: 'Gardener',
      subtitle: 'Garden care and maintenance',
      icon: Icons.grass_rounded,
      color: Color(0xFF16A34A),
    ),
    ServiceItem(
      title: 'Home Painter',
      subtitle: 'Interior and exterior painting',
      icon: Icons.format_paint_rounded,
      color: Color(0xFF9333EA),
    ),
    ServiceItem(
      title: 'Internet Technician',
      subtitle: 'Router and internet troubleshooting',
      icon: Icons.router_rounded,
      color: Color(0xFF2563EB),
    ),
    ServiceItem(
      title: 'Mobile Repair',
      subtitle: 'Smartphone diagnosis and repair',
      icon: Icons.phone_android_rounded,
      color: Color(0xFF0F766E),
    ),
    ServiceItem(
      title: 'Pest Control',
      subtitle: 'Safe pest removal services',
      icon: Icons.pest_control_rounded,
      color: Color(0xFF65A30D),
    ),
    ServiceItem(
      title: 'Plumber',
      subtitle: 'Pipes, leaks and water fitting',
      icon: Icons.plumbing_rounded,
      color: Color(0xFF0284C7),
    ),
    ServiceItem(
      title: 'Security Guard',
      subtitle: 'Trusted security professionals',
      icon: Icons.security_rounded,
      color: Color(0xFF475569),
    ),
    ServiceItem(
      title: 'Solar Technician',
      subtitle: 'Solar installation and maintenance',
      icon: Icons.solar_power_rounded,
      color: Color(0xFFF97316),
    ),
    ServiceItem(
      title: 'Tailor',
      subtitle: 'Clothing stitching and alterations',
      icon: Icons.checkroom_rounded,
      color: Color(0xFFBE185D),
    ),
    ServiceItem(
      title: 'Welder',
      subtitle: 'Metal fabrication and welding',
      icon: Icons.construction_rounded,
      color: Color(0xFF334155),
    ),
  ];

  List<ServiceItem> get _filteredServices {
    final query = _searchQuery.trim().toLowerCase();

    final results = query.isEmpty
        ? [..._services]
        : _services.where((service) {
            return service.title.toLowerCase().contains(query) ||
                service.subtitle.toLowerCase().contains(query);
          }).toList();

    results.sort((a, b) => a.title.compareTo(b.title));

    return results;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectService(ServiceItem service) {
    Navigator.pop(context, service.title);
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = _filteredServices;

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: _ambientCircle(
              size: 280,
              color: _primary.withOpacity(0.10),
            ),
          ),
          Positioned(
            bottom: -130,
            left: -100,
            child: _ambientCircle(
              size: 300,
              color: _secondary.withOpacity(0.08),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: services.isEmpty
                      ? _buildEmptyState()
                      : _buildServicesList(services),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 25,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Material(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: _textPrimary,
                      size: 21,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Services',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.45,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Choose the service you need',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _secondary],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.20),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.home_repair_service_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSearchField(),
          const SizedBox(height: 15),
          _buildInfoBanner(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: const TextStyle(
          color: _textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: 'Search electrician, plumber, cleaner...',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _textSecondary,
            size: 22,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: _clearSearch,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _textSecondary,
                    size: 20,
                  ),
                )
              : Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: _primary,
                    size: 18,
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primary.withOpacity(0.09),
            _secondary.withOpacity(0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _primary.withOpacity(0.10),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.touch_app_rounded,
              color: _primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'Select a service to continue posting your request.',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 10.5,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList(List<ServiceItem> services) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 35),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _serviceCard(
            service: service,
            index: index,
          ),
        );
      },
    );
  }

  Widget _serviceCard({
    required ServiceItem service,
    required int index,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _selectService(service),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x070F172A),
                blurRadius: 18,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      service.color.withOpacity(0.18),
                      service.color.withOpacity(0.07),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: service.color.withOpacity(0.12),
                  ),
                ),
                child: Icon(
                  service.icon,
                  color: service.color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      service.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 10.2,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: service.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: service.color,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x070F172A),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 82,
                width: 82,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.09),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  color: _primary,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No service found',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Try searching with another service name.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Clear Search'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: BorderSide(
                    color: _primary.withOpacity(0.22),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ambientCircle({
    required double size,
    required Color color,
  }) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: 50,
        sigmaY: 50,
      ),
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class ServiceItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const ServiceItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}