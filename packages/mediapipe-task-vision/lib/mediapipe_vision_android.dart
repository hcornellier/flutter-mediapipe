/// Flutter's registration of the vision package on Android. Not for
/// applications: import `mediapipe_vision.dart`.
library;

import 'package:mediapipe_vision/platform_interface.dart';

import 'src/io/gpu_name.dart';

/// Installs the GPU name reader. The tasks run on Google's MediaPipe vision
/// library through FFI, as on iOS and the desktop, and the reader asks
/// OpenGL ES through FFI too: the package has no Java code.
abstract final class MediaPipeVisionAndroid {
  /// Called by Flutter before the first public task is created.
  static void registerWith() {
    // The GPU's name lets a task declare a GPU family it fails on, such as
    // Image Segmenter on PowerVR, before anything runs there.
    taskPlatformGpuReader = readGpuName;
  }
}
