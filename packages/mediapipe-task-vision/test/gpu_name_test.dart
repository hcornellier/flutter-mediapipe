@TestOn('linux')
library;

import 'dart:io';

import 'package:mediapipe_vision/src/io/gpu_name.dart';
import 'package:test/test.dart';

/// The probe is Android's, but EGL and OpenGL ES are the same API on Linux,
/// so a Linux host with Mesa checks every binding and the whole sequence.
/// Without a display, set `EGL_PLATFORM=surfaceless`; CI does, and sets
/// `MEDIAPIPE_REQUIRE_GPU_NAME=1` so that a host that names nothing fails.
void main() {
  const egl = 'libEGL.so.1';
  const gles = 'libGLESv2.so.2';
  final missing =
      [
        for (final directory in [
          '/usr/lib/x86_64-linux-gnu',
          '/usr/lib/aarch64-linux-gnu',
          '/usr/lib64',
          '/usr/lib',
        ])
          if (File('$directory/$egl').existsSync() &&
              File('$directory/$gles').existsSync())
            directory,
      ].isEmpty
      ? 'This host has no $egl and $gles.'
      : null;

  test('a missing library names no GPU', () {
    expect(probeGpuName(egl: 'libNoSuchEgl.so', gles: gles), '');
    expect(probeGpuName(egl: egl, gles: 'libNoSuchGles.so'), '');
  }, skip: missing);

  test('the probe names the renderer and its vendor', () {
    final name = probeGpuName(egl: egl, gles: gles);
    // What this host's OpenGL ES reported, in the log.
    print('GPU_NAME $name');
    if (Platform.environment['MEDIAPIPE_REQUIRE_GPU_NAME'] == '1') {
      expect(name, matches(RegExp(r'^.+ \(.+\)$')));
    } else {
      // A host without a GPU driver or a display may have no context to
      // make; the probe then names nothing instead of throwing.
      expect(name, anyOf(isEmpty, matches(RegExp(r'^.+ \(.+\)$'))));
    }
    // Again: the first probe left nothing current and nothing terminated.
    expect(probeGpuName(egl: egl, gles: gles), name);
  }, skip: missing);

  test('the reader probes on another isolate, once', () async {
    final first = readGpuName(egl: egl, gles: gles);
    expect(readGpuName(egl: egl, gles: gles), same(first));
    expect(await first, probeGpuName(egl: egl, gles: gles));
  }, skip: missing);
}
