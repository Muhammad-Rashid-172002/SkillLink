import 'package:flutter/material.dart';

/// One bookable service category. [title] is the canonical value stored on
/// requests and matched against worker skills, so it must never change.
class ServiceOption {
  final String title;
  final String description;
  final IconData icon;

  /// Legacy per-category accent. The UI uses one brand tint for every
  /// category; this is kept only for callers that still read it.
  final Color color;

  const ServiceOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

ServiceOption? serviceOptionFor(String title) {
  final normalized = title.trim().toLowerCase();
  for (final service in allServices) {
    if (service.title.toLowerCase() == normalized) return service;
  }
  return null;
}

const List<ServiceOption> allServices = [
  ServiceOption(
    title: 'AC Repair',
    description: 'Cooling and air conditioner service',
    icon: Icons.ac_unit_rounded,
    color: Color(0xFF0EA5E9),
  ),
  ServiceOption(
    title: 'Appliance Repair',
    description: 'Home appliance maintenance',
    icon: Icons.home_repair_service_rounded,
    color: Color(0xFF14B8A6),
  ),
  ServiceOption(
    title: 'Beautician',
    description: 'Beauty and personal care services',
    icon: Icons.face_retouching_natural_rounded,
    color: Color(0xFFEC4899),
  ),
  ServiceOption(
    title: 'Car Mechanic',
    description: 'Vehicle inspection and repair',
    icon: Icons.car_repair_rounded,
    color: Color(0xFF6366F1),
  ),
  ServiceOption(
    title: 'Carpenter',
    description: 'Furniture and woodwork services',
    icon: Icons.carpenter_rounded,
    color: Color(0xFFF97316),
  ),
  ServiceOption(
    title: 'Cleaner',
    description: 'Home and office cleaning',
    icon: Icons.cleaning_services_rounded,
    color: Color(0xFF10B981),
  ),
  ServiceOption(
    title: 'Electrician',
    description: 'Electrical installation and repair',
    icon: Icons.electrical_services_rounded,
    color: Color(0xFFF59E0B),
  ),
  ServiceOption(
    title: 'Gardener',
    description: 'Garden care and maintenance',
    icon: Icons.grass_rounded,
    color: Color(0xFF22C55E),
  ),
  ServiceOption(
    title: 'Home Painter',
    description: 'Interior and exterior painting',
    icon: Icons.format_paint_rounded,
    color: Color(0xFF8B5CF6),
  ),
  ServiceOption(
    title: 'Internet Technician',
    description: 'Router and internet troubleshooting',
    icon: Icons.router_rounded,
    color: Color(0xFF3B82F6),
  ),
  ServiceOption(
    title: 'Mobile Repair',
    description: 'Smartphone diagnosis and repair',
    icon: Icons.phone_android_rounded,
    color: Color(0xFF0F766E),
  ),
  ServiceOption(
    title: 'Pest Control',
    description: 'Safe pest removal services',
    icon: Icons.pest_control_rounded,
    color: Color(0xFF84CC16),
  ),
  ServiceOption(
    title: 'Plumber',
    description: 'Pipes, leaks and water fitting',
    icon: Icons.plumbing_rounded,
    color: Color(0xFF06B6D4),
  ),
  ServiceOption(
    title: 'Security Guard',
    description: 'Trusted security professionals',
    icon: Icons.security_rounded,
    color: Color(0xFF475569),
  ),
  ServiceOption(
    title: 'Solar Technician',
    description: 'Solar installation and maintenance',
    icon: Icons.solar_power_rounded,
    color: Color(0xFFFACC15),
  ),
  ServiceOption(
    title: 'Tailor',
    description: 'Clothing stitching and alterations',
    icon: Icons.checkroom_rounded,
    color: Color(0xFFA855F7),
  ),
  ServiceOption(
    title: 'Welder',
    description: 'Metal fabrication and welding',
    icon: Icons.construction_rounded,
    color: Color(0xFFEF4444),
  ),
];