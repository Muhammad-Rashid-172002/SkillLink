import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_profile_models.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_profile_repository.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_settings_screen.dart';

/// Legacy route wrapper. New code should open [WorkerSettingsScreen] with the
/// already loaded profile so no extra worker listener is needed.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.repository});

  final WorkerProfileRepository? repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final WorkerProfileRepository _repository;
  late Future<WorkerProfile> _profile;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseWorkerProfileRepository();
    _profile = _repository.loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WorkerProfile>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final profile = snapshot.data;
        if (profile != null) {
          return WorkerSettingsScreen(
            profile: profile,
            repository: _repository,
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Worker Settings')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Your worker settings could not be loaded.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => _profile = _repository.loadProfile()),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
