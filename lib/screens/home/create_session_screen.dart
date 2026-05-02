import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../session/session_screen.dart';

/// CreateSessionScreen is a one-field form: the session name. On submit,
/// we call SessionProvider.createSession which generates the join code
/// server-side (well, technically client-side, but deterministically). On success we replace this screen with SessionScreen — the user shouldn't be able to back-navigate into the create form.
class CreateSessionScreen extends StatefulWidget {
  final String hostId;
  const CreateSessionScreen({super.key, required this.hostId});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<SessionProvider>();
    final sessionId = await provider.createSession(
      name: _nameController.text,
      hostId: widget.hostId,
    );

    if (!mounted) return;

    if (sessionId != null) {
      // Replace, don't push — user shouldn't go "back" to the create form.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SessionScreen(sessionId: sessionId)),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('New session')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Name your session',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your friends will see this when they join.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Session name',
                    hintText: 'Friday Night Vibes',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Give your session a name';
                    }
                    if (value.trim().length < 2) {
                      return 'At least 2 characters';
                    }
                    if (value.trim().length > 40) {
                      return 'Keep it under 40 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                FilledButton(
                  onPressed: provider.isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: provider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create session'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}