import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/preferences.dart';
import '../providers/preferences_provider.dart';
import '../utils/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<PreferencesProvider>(
        builder: (_, prefs, __) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── Mode Selection ──
            Text('Assistant Mode',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...AssistantMode.values.map((mode) => _ModeCard(
                  mode: mode,
                  selected: prefs.prefs.mode == mode,
                  onTap: () => prefs.setMode(mode),
                )),
            const SizedBox(height: 28),

            // ── Voice Style ──
            Text('Voice',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer']
                  .map((v) => ChoiceChip(
                        label: Text(v),
                        selected: prefs.prefs.voiceStyle == v,
                        onSelected: (_) => prefs.setVoiceStyle(v),
                        selectedColor: UthoTheme.accent,
                        labelStyle: TextStyle(
                          color: prefs.prefs.voiceStyle == v
                              ? Colors.white
                              : UthoTheme.textSecondary,
                        ),
                        backgroundColor: UthoTheme.surfaceCard,
                        side: BorderSide.none,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 28),

            // ── API Key ──
            Text('OpenAI API Key',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Required for voice features. Stored securely on-device.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: UthoTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            if (prefs.apiKey != null && prefs.apiKey!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: UthoTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: UthoTheme.success, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Key set: sk-...${prefs.apiKey!.substring(prefs.apiKey!.length - 4)}',
                        style: const TextStyle(color: UthoTheme.textPrimary, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () => prefs.clearApiKey(),
                      child: const Text('Remove',
                          style: TextStyle(color: UthoTheme.danger)),
                    ),
                  ],
                ),
              )
            else
              _ApiKeyInput(onSave: prefs.setApiKey),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: UthoTheme.accent.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: UthoTheme.accent.withAlpha(40)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: UthoTheme.accent.withAlpha(180)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'OpenAI recommends not exposing API keys in client-side apps. '
                      'A backend token service is recommended for production.',
                      style: TextStyle(color: UthoTheme.textSecondary, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final AssistantMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({required this.mode, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? UthoTheme.accent.withAlpha(25) : UthoTheme.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? UthoTheme.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(mode.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mode.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected ? UthoTheme.accent : UthoTheme.textPrimary,
                      )),
                  Text(mode.description,
                      style: const TextStyle(
                          fontSize: 12, color: UthoTheme.textSecondary)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: UthoTheme.accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ApiKeyInput extends StatefulWidget {
  final Future<void> Function(String) onSave;
  const _ApiKeyInput({required this.onSave});

  @override
  State<_ApiKeyInput> createState() => _ApiKeyInputState();
}

class _ApiKeyInputState extends State<_ApiKeyInput> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            obscureText: _obscure,
            style: const TextStyle(color: UthoTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'sk-...',
              hintStyle: const TextStyle(color: UthoTheme.textSecondary),
              filled: true,
              fillColor: UthoTheme.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                    size: 18, color: UthoTheme.textSecondary),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              widget.onSave(_controller.text.trim());
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: UthoTheme.accent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
