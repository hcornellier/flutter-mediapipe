// An experiment, not a suite: does Google's Windows audio library take the
// GPU delegate, and what does it answer? PROBE_TASK and PROBE_DELEGATE choose
// one run, so a native crash ends that run alone.
// ignore_for_file: avoid_print
@TestOn('vm')
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:test/test.dart';

final _task = Platform.environment['PROBE_TASK'] ?? 'transcriber';
final _delegate = Platform.environment['PROBE_DELEGATE'] == 'gpu'
    ? Delegate.gpu
    : Delegate.cpu;

String _model(DownloadAsset asset) =>
    'models/${Uri.parse(asset.url).pathSegments.last}';

void main() {
  test('probe', timeout: const Timeout(Duration(minutes: 20)), () async {
    print('PROBE task=$_task delegate=${_delegate.name}');
    final watch = Stopwatch()..start();
    if (_task == 'transcriber') {
      final audio = decodeWav(
        File('test/fixtures/speech_16000_hz_mono.wav').readAsBytesSync(),
      );
      final task = await AudioTranscriber.create(
        AudioTranscriberOptions(
          modelPath: _model(AudioModels.parakeetTdtV3),
          delegate: _delegate,
        ),
      );
      print('PROBE create_ms=${watch.elapsedMilliseconds}');
      for (var i = 0; i < 4; i++) {
        watch.reset();
        final result = await task.transcribe(audio);
        print(
          'PROBE run=$i ms=${watch.elapsedMilliseconds} '
          'text="${result.text}"',
        );
      }
      await task.dispose();
    } else {
      final task = await TextToSpeech.create(
        TextToSpeechOptions(
          modelPath: _model(AudioModels.kokoro),
          delegate: _delegate,
        ),
      );
      print('PROBE create_ms=${watch.elapsedMilliseconds}');
      for (var i = 0; i < 4; i++) {
        watch.reset();
        final speech = await task.synthesize(
          'The quick brown fox jumps over the lazy dog.',
        );
        var sum = 0.0;
        for (final sample in speech.samples) {
          sum += sample * sample;
        }
        final rms = math.sqrt(sum / math.max(1, speech.samples.length));
        print(
          'PROBE run=$i ms=${watch.elapsedMilliseconds} '
          'samples=${speech.samples.length} rate=${speech.sampleRateHz} '
          'rms=${rms.toStringAsFixed(5)}',
        );
      }
      await task.dispose();
    }
    print('PROBE done');
  });
}
