import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../session/session_screen.dart';

/// JoinSessionSheet is a modal bottom sheet where the user enters a
/// 6-character join code. On success it closes itself and pushes
/// SessionScreen for the joined session.
///
/// Why a bottom sheet rather than a full screen: joining is a quick,
/// one-field action. A sheet keeps the home screen context visible
/// behind it and feels lighter than a new route.
class JoinSessionSheet extends StatefulWidget {
  final String userId;
  const JoinSessionSheet({super.key, required this.userId});

  @override
  State<JoinSessionSheet> createState() => _JoinSessionSheetState();
}

class _JoinSessionSheetState extends State<JoinSessionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<SessionProvider>();
    final session = await provider.joinSessionByCode(
      code: _codeController.text,
      userId: widget.userId,
    );

    if (!mounted) return;

    if (session != null) {
      // Close the sheet, then push the session screen.
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SessionScreen(sessionId: session.id)),
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

    // Padding for the on-screen keyboard so the text field isn't hidden.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + bottomInset,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Join a session',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-character code your friend shared.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _codeController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              // Restrict to the alphabet we use for codes (see FirestoreService).
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[A-Za-z0-9]'),
                ),
                UpperCaseTextFormatter(),
              ],
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'Join code',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              validator: (value) {
                if (value == null || value.trim().length != 6) {
                  return 'Codes are 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

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
                  : const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Force all input to uppercase without moving the cursor. Cleaner than
/// listening to controller changes and calling setText — no cursor jumps.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}