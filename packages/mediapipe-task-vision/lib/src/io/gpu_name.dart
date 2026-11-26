/// Names the device's GPU through OpenGL ES, for the vision capabilities on
/// Android.
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

const _eglNone = 0x3038;
const _eglRenderableType = 0x3040;
const _eglOpenGlEs2Bit = 0x0004;
const _eglSurfaceType = 0x3033;
const _eglPbufferBit = 0x0001;
const _eglContextClientVersion = 0x3098;
const _eglWidth = 0x3057;
const _eglHeight = 0x3056;
const _glVendor = 0x1F00;
const _glRenderer = 0x1F01;

Future<String>? _gpuName;

/// The GPU's `renderer (vendor)`, such as `Mali-G715 (ARM)`, read once for
/// this isolate. Empty when no OpenGL ES context can be made, or none within
/// five seconds; then no GPU family is singled out.
///
/// The probe runs on an isolate of its own, so that no caller's GL state
/// moves: it makes a GL context current on the thread it runs on.
Future<String> readGpuName({
  String egl = 'libEGL.so',
  String gles = 'libGLESv2.so',
}) => _gpuName ??= _readGpuName(egl, gles);

Future<String> _readGpuName(String egl, String gles) async {
  try {
    return await Isolate.run(
      () => probeGpuName(egl: egl, gles: gles),
    ).timeout(const Duration(seconds: 5));
  } on Object {
    return '';
  }
}

/// `renderer (vendor)` from a 1x1 offscreen OpenGL ES 2 context made with the
/// [egl] and [gles] libraries, or empty.
String probeGpuName({String egl = 'libEGL.so', String gles = 'libGLESv2.so'}) {
  final DynamicLibrary eglLibrary, glesLibrary;
  try {
    eglLibrary = DynamicLibrary.open(egl);
    glesLibrary = DynamicLibrary.open(gles);
  } on ArgumentError {
    return '';
  }
  final getDisplay = eglLibrary
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)
      >('eglGetDisplay');
  final initialize = eglLibrary
      .lookupFunction<
        Uint32 Function(Pointer<Void>, Pointer<Int32>, Pointer<Int32>),
        int Function(Pointer<Void>, Pointer<Int32>, Pointer<Int32>)
      >('eglInitialize');
  final chooseConfig = eglLibrary
      .lookupFunction<
        Uint32 Function(
          Pointer<Void>,
          Pointer<Int32>,
          Pointer<Pointer<Void>>,
          Int32,
          Pointer<Int32>,
        ),
        int Function(
          Pointer<Void>,
          Pointer<Int32>,
          Pointer<Pointer<Void>>,
          int,
          Pointer<Int32>,
        )
      >('eglChooseConfig');
  final createContext = eglLibrary
      .lookupFunction<
        Pointer<Void> Function(
          Pointer<Void>,
          Pointer<Void>,
          Pointer<Void>,
          Pointer<Int32>,
        ),
        Pointer<Void> Function(
          Pointer<Void>,
          Pointer<Void>,
          Pointer<Void>,
          Pointer<Int32>,
        )
      >('eglCreateContext');
  final createPbufferSurface = eglLibrary
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Pointer<Void>, Pointer<Int32>),
        Pointer<Void> Function(Pointer<Void>, Pointer<Void>, Pointer<Int32>)
      >('eglCreatePbufferSurface');
  final makeCurrent = eglLibrary
      .lookupFunction<
        Uint32 Function(
          Pointer<Void>,
          Pointer<Void>,
          Pointer<Void>,
          Pointer<Void>,
        ),
        int Function(Pointer<Void>, Pointer<Void>, Pointer<Void>, Pointer<Void>)
      >('eglMakeCurrent');
  final destroySurface = eglLibrary
      .lookupFunction<
        Uint32 Function(Pointer<Void>, Pointer<Void>),
        int Function(Pointer<Void>, Pointer<Void>)
      >('eglDestroySurface');
  final destroyContext = eglLibrary
      .lookupFunction<
        Uint32 Function(Pointer<Void>, Pointer<Void>),
        int Function(Pointer<Void>, Pointer<Void>)
      >('eglDestroyContext');
  final releaseThread = eglLibrary
      .lookupFunction<Uint32 Function(), int Function()>('eglReleaseThread');
  final getString = glesLibrary
      .lookupFunction<
        Pointer<Utf8> Function(Uint32),
        Pointer<Utf8> Function(int)
      >('glGetString');

  return using((arena) {
    Pointer<Int32> attributes(List<int> values) {
      final list = arena<Int32>(values.length);
      for (var i = 0; i < values.length; i++) {
        list[i] = values[i];
      }
      return list;
    }

    // EGL_DEFAULT_DISPLAY.
    final display = getDisplay(nullptr);
    final version = arena<Int32>(2);
    if (display == nullptr || initialize(display, version, version + 1) == 0) {
      return '';
    }
    final configs = arena<Pointer<Void>>();
    final count = arena<Int32>();
    final wanted = attributes([
      _eglRenderableType,
      _eglOpenGlEs2Bit,
      _eglSurfaceType,
      _eglPbufferBit,
      _eglNone,
    ]);
    if (chooseConfig(display, wanted, configs, 1, count) == 0 ||
        count.value < 1) {
      return '';
    }
    final context = createContext(
      display,
      configs.value,
      nullptr,
      attributes([_eglContextClientVersion, 2, _eglNone]),
    );
    final surface = createPbufferSurface(
      display,
      configs.value,
      attributes([_eglWidth, 1, _eglHeight, 1, _eglNone]),
    );
    var name = '';
    try {
      if (context != nullptr &&
          surface != nullptr &&
          makeCurrent(display, surface, surface, context) != 0) {
        final renderer = getString(_glRenderer);
        final vendor = getString(_glVendor);
        name =
            (renderer == nullptr ? '' : renderer.toDartString()) +
            (vendor == nullptr ? '' : ' (${vendor.toDartString()})');
        makeCurrent(display, nullptr, nullptr, nullptr);
      }
    } finally {
      if (surface != nullptr) destroySurface(display, surface);
      if (context != nullptr) destroyContext(display, context);
      // The default display is shared with Flutter and MediaPipe: never
      // terminated.
      releaseThread();
    }
    return name;
  });
}
