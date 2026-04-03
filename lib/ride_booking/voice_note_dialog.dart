import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:premium_force_driver/l10n/app_localizations.dart';

class VoiceNoteDialog extends StatefulWidget {
  final String? initialAudioPath;
  const VoiceNoteDialog({super.key, this.initialAudioPath});

  @override
  State<VoiceNoteDialog> createState() => _VoiceNoteDialogState();
}

class _VoiceNoteDialogState extends State<VoiceNoteDialog> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  String? _audioPath;

  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPath = widget.initialAudioPath;
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _audioPosition = Duration.zero;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _audioDuration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _audioPosition = p);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final mins = twoDigits(seconds ~/ 60);
    final secs = twoDigits(seconds % 60);
    return "$mins:$secs";
  }

  Future<void> _playPauseAudio() async {
    if (_audioPath == null) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(_audioPath!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF111111),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.voiceNote,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white60),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Content
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  if (_audioPath != null) ...[
                    GestureDetector(
                      onTap: _playPauseAudio,
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: const Color(0xFFC0C0C0),
                        size: 28,
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.0,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                        ),
                        child: Slider(
                          activeColor: const Color(0xFFC0C0C0),
                          inactiveColor: Colors.white24,
                          value: _audioPosition.inMilliseconds.toDouble().clamp(
                            0.0,
                            _audioDuration.inMilliseconds > 0
                                ? _audioDuration.inMilliseconds.toDouble()
                                : 1.0,
                          ),
                          max: _audioDuration.inMilliseconds > 0
                              ? _audioDuration.inMilliseconds.toDouble()
                              : 1.0,
                          onChanged: (value) {
                            _audioPlayer.seek(
                              Duration(milliseconds: value.toInt()),
                            );
                          },
                        ),
                      ),
                    ),
                    Text(
                      _formatDuration(_audioPosition.inSeconds),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: Text(
                            "No audio file to play",
                            style: TextStyle(color: Colors.white60, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC0C0C0),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Close",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
