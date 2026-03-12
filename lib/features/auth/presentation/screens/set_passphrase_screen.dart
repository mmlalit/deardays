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
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'encryption_salt': 'server-side',
          'trial_started_at': DateTime.now().toUtc().toIso8601String(),
        });
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
