import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Legacy screen — previously required for social login encryption passphrase.
/// With server-side encryption, this is no longer needed. It auto-completes
/// on mount so any old deep links or router references still work.
class SetPassphraseScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SetPassphraseScreen({super.key, required this.onComplete});

  @override
  State<SetPassphraseScreen> createState() => _SetPassphraseScreenState();
}

class _SetPassphraseScreenState extends State<SetPassphraseScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure the profile has a placeholder encryption_salt (legacy column).
    _ensureProfileAndContinue();
  }

  Future<void> _ensureProfileAndContinue() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Check if profile already exists (and has trial_started_at)
        final existing = await Supabase.instance.client
            .from('profiles')
            .select('id, trial_started_at')
            .eq('id', user.id)
            .maybeSingle();

        if (existing == null) {
          // No profile yet — create with trial_started_at
          await Supabase.instance.client.from('profiles').upsert({
            'id': user.id,
            'encryption_salt': 'server-side',
            'trial_started_at': DateTime.now().toUtc().toIso8601String(),
          });
        } else if (existing['trial_started_at'] == null) {
          // Profile exists but has no trial start — set it now
          await Supabase.instance.client
              .from('profiles')
              .update({
                'encryption_salt': 'server-side',
                'trial_started_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', user.id);
        }
        // If profile exists with trial_started_at, do nothing (preserve it)
      }
    } catch (_) {
      // Non-fatal — profile may already exist from the signup trigger.
    }

    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
