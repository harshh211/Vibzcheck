import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../session/session_screen.dart';

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
      name: _nameController.text.trim(),
      hostId: widget.hostId,
    );

    if (!mounted) return;

    if (sessionId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionScreen(sessionId: sessionId),
        ),
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
      appBar: AppBar(title: const Text('Create Session')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.queue_music,
                  size: 64,
                  color: Color.fromARGB(255, 98, 13, 105),
                ),
                const SizedBox(height: 16),

                Text(
                  'Start a new vibe',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),

                const SizedBox(height: 8),

                Text(
                  'Give your session a name so friends know what they are joining.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                const SizedBox(height: 32),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Session name',
                    hintText: 'Friday Night Vibes',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.music_note),
                  ),
                  validator: (value) {
                    final name = value?.trim() ?? '';

                    if (name.isEmpty) {
                      return 'Give your session a name';
                    }
                    if (name.length < 2) {
                      return 'At least 2 characters';
                    }
                    if (name.length > 40) {
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