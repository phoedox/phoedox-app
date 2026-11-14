import 'package:flutter_test/flutter_test.dart';
import 'package:phoedox/features/entity/voice_notes.dart';
import 'package:phoedox/sync/uploads.dart';

void main() {
  test('voice note names and durations', () {
    expect(voiceNoteName(DateTime(2026, 11, 4, 9, 5)),
        'voice-note-2026-11-04-0905.m4a');
    expect(voiceNoteName(DateTime(2026, 1, 2, 13, 45), ext: 'wav'),
        'voice-note-2026-01-02-1345.wav');
    expect(clock(const Duration(minutes: 4, seconds: 7)), '4:07');
    expect(clock(maxVoiceNote), '5:00');
  });

  test('audio attachments by type or name', () {
    final files = [
      {'id': 'a', 'name': 'voice-note.m4a', 'mime': 'application/octet-stream'},
      {'id': 'b', 'name': 'memo', 'mime': 'audio/mpeg'},
      {'id': 'c', 'name': 'nameplate.jpg', 'mime': 'image/jpeg'},
      {'id': 'd', 'name': 'Recording.WAV', 'mime': ''},
    ];
    expect(audioFiles(files).map((f) => f['id']), ['a', 'b', 'd']);
    expect(isAudioName('plan-photo-1.jpg'), isFalse);
  });
}
