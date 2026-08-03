import 'package:flutter/material.dart';

import '../voice/voice_session_controller.dart';

/// A dev-flavour strip showing what voice recognition is actually doing.
///
/// The pipeline is four stages deep and every one of them fails silently: the
/// microphone can deliver silence, the detector can find no speech in it, the
/// recogniser can render no words, and the matcher can reject the words it got.
/// From the outside all four look identical — a count that will not move. This
/// bar shows each stage's number so the broken one is obvious at a glance.
class VoiceDebugBar extends StatelessWidget {
  final VoiceSessionController voice;

  const VoiceDebugBar({super.key, required this.voice});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final diagnostics = voice.diagnostics;
    final failed = voice.status == VoiceStatus.failed;

    return Material(
      color: failed
          ? scheme.errorContainer
          : scheme.surfaceContainerHighest.withValues(alpha: 0.9),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: failed ? scheme.onErrorContainer : scheme.onSurfaceVariant,
          ),
          // Always left-to-right: these are numbers and latin labels, and the
          // session around them is right-to-left.
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      voice.status.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _LevelMeter(level: diagnostics.level)),
                    const SizedBox(width: 8),
                    Text('${(diagnostics.bytes / 1024).round()}kB'
                        ' · vad ${diagnostics.chunks}/${diagnostics.segments}'
                        ' · txt ${diagnostics.utterances}'),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _lastLine(diagnostics),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: diagnostics.accepted ? scheme.primary : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _lastLine(VoiceDiagnostics diagnostics) {
    if (diagnostics.error != null) return 'error: ${diagnostics.error}';
    final transcript = diagnostics.lastTranscript;
    if (transcript == null) return 'nothing recognised yet';
    final score = diagnostics.lastScore;
    final verdict = score == null
        ? 'no candidate'
        : '${diagnostics.lastMatchId} ${score.toStringAsFixed(2)}'
            ' ${diagnostics.accepted ? "✓" : "✗"}';
    return '$verdict · $transcript';
  }
}

/// Peak level of the last chunk of audio. Flat means the microphone is the
/// problem, whatever the rest of the numbers say.
class _LevelMeter extends StatelessWidget {
  final double level;

  const _LevelMeter({required this.level});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: level.clamp(0, 1),
        minHeight: 6,
        backgroundColor: scheme.outlineVariant.withValues(alpha: 0.4),
        valueColor: AlwaysStoppedAnimation(
          level > 0.02 ? scheme.primary : scheme.outline,
        ),
      ),
    );
  }
}
