import 'package:flutter/material.dart';

class ServiceOption {
  final String title;
  final IconData icon;
  final Color color;

  const ServiceOption({
    required this.title,
    required this.icon,
    required this.color,
  });
}

const List<ServiceOption> allServices = [
  ServiceOption(
    title: 'AC Repair',
    icon: Icons.ac_unit_rounded,
    color: Color(0xFF0EA5E9),
  ),
  ServiceOption(
    title: 'Appliance Repair',
    icon: Icons.home_repair_service_rounded,
    color: Color(0xFF14B8A6),
  ),
  ServiceOption(
    title: 'Beautician',
    icon: Icons.face_retouching_natural_rounded,
    color: Color(0xFFEC4899),
  ),
  ServiceOption(
    title: 'Car Mechanic',
    icon: Icons.car_repair_rounded,
    color: Color(0xFF6366F1),
  ),
  ServiceOption(
    title: 'Carpenter',
    icon: Icons.carpenter_rounded,
    color: Color(0xFFF97316),
  ),
  ServiceOption(
    title: 'Cleaner',
    icon: Icons.cleaning_services_rounded,
    color: Color(0xFF10B981),
  ),
  ServiceOption(
    title: 'Electrician',
    icon: Icons.electrical_services_rounded,
    color: Color(0xFFF59E0B),
  ),
  ServiceOption(
    title: 'Gardener',
    icon: Icons.grass_rounded,
    color: Color(0xFF22C55E),
  ),
  ServiceOption(
    title: 'Home Painter',
    icon: Icons.format_paint_rounded,
    color: Color(0xFF8B5CF6),
  ),
  ServiceOption(
    title: 'Internet Technician',
    icon: Icons.router_rounded,
    color: Color(0xFF3B82F6),
  ),
  ServiceOption(
    title: 'Mobile Repair',
    icon: Icons.phone_android_rounded,
    color: Color(0xFF0F766E),
  ),
  ServiceOption(
    title: 'Pest Control',
    icon: Icons.pest_control_rounded,
    color: Color(0xFF84CC16),
  ),
  ServiceOption(
    title: 'Plumber',
    icon: Icons.plumbing_rounded,
    color: Color(0xFF06B6D4),
  ),
  ServiceOption(
    title: 'Security Guard',
    icon: Icons.security_rounded,
    color: Color(0xFF475569),
  ),
  ServiceOption(
    title: 'Solar Technician',
    icon: Icons.solar_power_rounded,
    color: Color(0xFFFACC15),
  ),
  ServiceOption(
    title: 'Tailor',
    icon: Icons.checkroom_rounded,
    color: Color(0xFFA855F7),
  ),
  ServiceOption(
    title: 'Welder',
    icon: Icons.construction_rounded,
    color: Color(0xFFEF4444),
  ),
];