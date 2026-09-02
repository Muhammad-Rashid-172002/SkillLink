import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/customer_screens/Chat/chat_screen.dart';
import 'package:skill_link/screens/customer_screens/Explore/explore_models.dart';
import 'package:skill_link/screens/customer_screens/bookings/customer_bookings_screen.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_account_screens.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_edit_profile_screen.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_components.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_models.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_repository.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_settings_screen.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_support_screens.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key, this.onSelectTab, this.repository});
  final ValueChanged<int>? onSelectTab;
  final CustomerProfileRepository? repository;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  late final CustomerProfileRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseCustomerProfileRepository();
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  void _openTabOrPage(int index, Widget fallback) {
    final select = widget.onSelectTab;
    select == null ? _open(fallback) : select(index);
  }

  @override
  Widget build(BuildContext context) {
    if (_repository.currentIdentity == null) {
      return const _ProfileSignedOutState();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<CustomerProfile>(
        stream: _repository.watchProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _ProfileErrorState(
              message:
                  snapshot.error?.toString() ?? 'Your profile is unavailable.',
            );
          }
          final profile = snapshot.data!;
          final hasCoordinate = customerCoordinate(profile.data) != null;
          return ListView(
            key: const Key('customer-profile-content'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              ProfileHeader(
                profile: profile,
                onEdit: () => _open(
                  CustomerEditProfileScreen(
                    initialProfile: profile,
                    repository: _repository,
                  ),
                ),
                onSettings: () => _open(
                  CustomerSettingsScreen(
                    profile: profile,
                    repository: _repository,
                  ),
                ),
              ),
              if (profile.serviceArea.isNotEmpty ||
                  profile.address.isNotEmpty ||
                  hasCoordinate) ...[
                const SizedBox(height: 20),
                _LocationCard(
                  profile: profile,
                  onEdit: () => _open(
                    CustomerEditProfileScreen(
                      initialProfile: profile,
                      repository: _repository,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Your account',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              SettingsSection(
                title: 'Profile',
                children: [
                  ProfileMenuTile(
                    icon: Icons.person_outline,
                    title: 'Personal information',
                    subtitle: 'Name, photo, and verified account details',
                    onTap: () => _open(
                      CustomerAccountInformationScreen(profile: profile),
                    ),
                  ),
                  const Divider(height: 1),
                  ProfileMenuTile(
                    icon: Icons.location_on_outlined,
                    title: 'Saved / service location',
                    subtitle: profile.serviceArea.isEmpty
                        ? 'Add city and service area'
                        : profile.serviceArea,
                    onTap: () => _open(
                      CustomerEditProfileScreen(
                        initialProfile: profile,
                        repository: _repository,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ProfileMenuTile(
                    icon: Icons.calendar_month_outlined,
                    title: 'Bookings',
                    subtitle: 'View and track service requests',
                    onTap: () =>
                        _openTabOrPage(2, const CustomerBookingsScreen()),
                  ),
                  const Divider(height: 1),
                  ProfileMenuTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Messages',
                    subtitle: 'Continue your conversations',
                    onTap: () => _openTabOrPage(3, const CustomerChatsScreen()),
                  ),
                  const Divider(height: 1),
                  ProfileMenuTile(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Safety & support',
                    subtitle: 'Safety guidance and existing support options',
                    onTap: () => _open(const CustomerSafetyScreen()),
                  ),
                  const Divider(height: 1),
                  ProfileMenuTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Appearance, notifications, privacy, and account',
                    onTap: () => _open(
                      CustomerSettingsScreen(
                        profile: profile,
                        repository: _repository,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.profile, required this.onEdit});
  final CustomerProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final coordinate = customerCoordinate(profile.data);
    final colors = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (coordinate != null)
            SizedBox(
              key: const Key('profile-map-preview'),
              height: 145,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(coordinate.latitude, coordinate.longitude),
                  zoom: 13,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('customer-location'),
                    position: LatLng(coordinate.latitude, coordinate.longitude),
                  ),
                },
                liteModeEnabled: true,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                scrollGesturesEnabled: false,
                zoomGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service location',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.serviceArea.isEmpty
                            ? 'City not added'
                            : profile.serviceArea,
                      ),
                      if (profile.address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          profile.address,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (coordinate == null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Map preview unavailable until valid saved coordinates exist.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit service location',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSignedOutState extends StatelessWidget {
  const _ProfileSignedOutState();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Please sign in again to view your profile.')),
  );
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
