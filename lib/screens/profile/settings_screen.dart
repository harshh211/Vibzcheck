import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/preferences_service.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = PreferencesService();

  UserPreferences _prefs = const UserPreferences();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().currentUser?.uid;
    if (userId == null) return;
    final prefs = await _service.load(userId);
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _loading = false;
    });
  }

  Future<void> _persist(UserPreferences next) async {
    final userId = context.read<AuthProvider>().currentUser?.uid;
    if (userId == null) return;

    // Optimistic update — the slider/switch is already showing the
    // new value, so we update local state synchronously and write to
    // Firestore in the background. If the write fails we surface a
    // snackbar but DON'T revert (the user has moved on).
    setState(() {
      _prefs = next;
      _saving = true;
    });
    try {
      await _service.save(userId, next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save settings.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _SectionHeader('Notifications'),
                SwitchListTile(
                  title: const Text('Push notifications'),
                  subtitle: const Text(
                    'Get a ping when someone adds a track to your session.',
                  ),
                  value: _prefs.notificationsEnabled,
                  onChanged: (v) => _persist(
                    _prefs.copyWith(notificationsEnabled: v),
                  ),
                ),

                const Divider(),
                _SectionHeader('Recommendations'),
                _AboutRecommendationsBlurb(),

                _SliderTile(
                  label: 'Popularity weight',
                  description:
                      'How much group votes drive the suggestion ranking.',
                  value: _prefs.popularityWeight,
                  onChanged: (v) => _persist(
                    _prefs.copyWith(popularityWeight: v),
                  ),
                ),
                _SliderTile(
                  label: 'Mood match weight',
                  description:
                      'How much shared mood tags drive the ranking.',
                  value: _prefs.moodWeight,
                  onChanged: (v) => _persist(
                    _prefs.copyWith(moodWeight: v),
                  ),
                ),

                const Divider(),
                _SectionHeader('About'),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Vibzcheck'),
                  subtitle: Text('Version 1.0.0 · Class project build'),
                ),
                const ListTile(
                  leading: Icon(Icons.shield_outlined),
                  title: Text('Privacy'),
                  subtitle: Text(
                    'Your data stays scoped to your sessions. We never sell or '
                    'share session data.',
                  ),
                ),
              ],
            ),
    );
  }
}

// -------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  // ignore: unused_element_parameter
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _AboutRecommendationsBlurb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Text(
        'These sliders nudge the suggestion engine. The engine uses a '
        'transparent set of if-then rules — no AI black box.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String label;
  final String description;
  final int value;
  final ValueChanged<int> onChanged;

  const _SliderTile({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Slider(
            value: value.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}