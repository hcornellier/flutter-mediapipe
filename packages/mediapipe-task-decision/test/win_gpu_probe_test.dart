// An experiment, not a suite: does Google's Windows decision library take the
// GPU delegate, and what does it answer? PROBE_DELEGATE chooses one run, so a
// native crash ends that run alone.
// ignore_for_file: avoid_print
@TestOn('vm')
library;

import 'dart:io';

import 'package:mediapipe_decision/mediapipe_decision.dart';
import 'package:test/test.dart';

final _delegate = Platform.environment['PROBE_DELEGATE'] == 'gpu'
    ? Delegate.gpu
    : Delegate.cpu;

void main() {
  test('probe', timeout: const Timeout(Duration(minutes: 20)), () async {
    print('PROBE task=decision delegate=${_delegate.name}');
    final watch = Stopwatch()..start();
    final task = await DecisionMaker.create(
      DecisionMakerOptions(
        modelPath: 'models/laya_s256.task',
        delegate: _delegate,
      ),
    );
    print('PROBE create_ms=${watch.elapsedMilliseconds}');
    for (var i = 0; i < 4; i++) {
      watch.reset();
      final refund = await task.evaluateBoolean(
        'My order arrived broken and I want my money back.',
        BooleanQuestion('The customer wants a refund.'),
      );
      final weather = await task.evaluateBoolean(
        'My order arrived broken and I want my money back.',
        BooleanQuestion('The customer asks about the weather.'),
      );
      print('PROBE run=$i ms=${watch.elapsedMilliseconds} $refund $weather');
    }
    await task.dispose();
    print('PROBE done');
  });
}
