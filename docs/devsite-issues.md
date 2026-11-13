# MediaPipe devsite issues (Flutter), checked 2026-11-13

Checked against the live devsite pages and google/flutter-mediapipe v0.3.0 on 2026-11-13.

Please review these MediaPipe devsite issues and propose one CL per page that fixes them. Do not submit or mail any CL; show me the diffs first. If you disagree with any item, say so and why.

Source of truth for the Flutter API: google/flutter-mediapipe main (v0.3.0, all six packages live on pub.dev). Leave all Dart code blocks alone: they mirror files in the repo's samples/ folder and change only together with them.

## Page 1: https://developers.google.com/edge/mediapipe/solutions/agents

1. Task table, Audio rows. Audio Transcriber and Text-to-Speech end with "| Web, Android, iOS, Python |". Flutter is missing: both task pages have Flutter tabs, the Audio Classifier row already ends with "Flutter", and setup_flutter says mediapipe_audio holds "Audio Classifier, Audio Transcriber, and Text-to-Speech".
   Fix: "| Web, Android, iOS, Python, Flutter |" on both rows.

2. "## Flutter" package table. "| `mediapipe_audio` | `AudioClassifier` (YAMNet) |" lists one of three tasks; packages/mediapipe-task-audio/lib/mediapipe_audio.dart also exports src/audio_transcriber.dart and src/text_to_speech.dart.
   Fix: "| `mediapipe_audio` | `AudioClassifier` (YAMNet), `AudioTranscriber`, `TextToSpeech` |".

3. Step 5 table, Flutter column, "Rotation and region of interest" says "task options". In Dart these are per-call named arguments: `rotationDegrees` on the image, video and live-stream calls of every vision task except InteractiveSegmenter, and `regionOfInterest` (a `VisionRegionOfInterest`) only on ImageClassifier and ImageEmbedder (packages/mediapipe-task-vision/lib/src/tasks/image_classifier.dart, image_embedder.dart). prepare_data already says "Pass clockwise rotation in 90° multiples with the `rotationDegrees` argument of each call."
   Fix: "`rotationDegrees` argument on each call (90° multiples; not on Interactive Segmenter); `regionOfInterest` on Image Classifier and Image Embedder".

4. Step 5 table, Flutter column, "Audio" says "`Float32List` samples". AudioClassifier.classify, classifyAsync and AudioTranscriber.transcribe take an `AudioData` (packages/mediapipe-task-audio/lib/src/types.dart: `AudioData({required this.samples, required this.sampleRate, this.channels = 1})`). prepare_data already says "`AudioData` (a `Float32List` with its sample rate) in Flutter". UniversalEmbedder.embedAudio does take a bare Float32List; leave that alone.
   Fix: "`AudioData(samples: float32List, sampleRate: 16000)`".

5. "Rules for agents" item 7: "Set rotation through `ImageProcessingOptions` instead of rotating pixels". Flutter has no ImageProcessingOptions and iOS uses the MPImage orientation.
   Fix: "Set rotation through the SDK's rotation input (`ImageProcessingOptions`, the iOS `MPImage` orientation, or Flutter's `rotationDegrees`) instead of rotating pixels".

6. "Setup guides" line. Flutter links https://github.com/google/flutter-mediapipe#quick-start while every other platform links its devsite setup page.
   Fix: link https://developers.google.com/edge/mediapipe/solutions/setup_flutter.

## Page 2: https://developers.google.com/edge/mediapipe/solutions/setup_flutter

7. "Flutter 3.47 or newer." v0.3.0 lowered the floor: every package's pubspec says `flutter: '>=3.44.0'`.
   Fix: "Flutter 3.44 or newer. The latest stable release is recommended."

## Page 3: https://developers.google.com/edge/mediapipe/solutions (index)

8. API Reference card: "Class and method documentation for Java, Swift, TypeScript/JS, and Python." Dart is missing; the agents page already links https://pub.dev/documentation/mediapipe_vision/latest/ as the Flutter API reference.
   Fix: "... Java, Swift, TypeScript/JS, Python, and Dart."

## Contradictions inside Google's docs (report them, do not pick an answer)

9. https://developers.google.com/edge/mediapipe/solutions/vision/holistic_landmarker: `minFaceSuppressionThreshold` and `minPoseSuppressionThreshold` default `0.3` in the Web, Android, iOS and Python tables but `0.5` in the Flutter table. The Flutter package also uses 0.5 (packages/mediapipe-task-vision/lib/src/types/options.dart). Which is the intended default?

10. EmbeddingGemma 2 licence: retrieval/semantic_retriever says "under the [Gemma license](https://ai.google.dev/gemma/terms)" and retrieval/universal_embedder says "under the [Apache 2.0 License](https://gemma.ai/resources/apache-2/)" for the same models. One of them is wrong.

11. https://developers.google.com/edge/mediapipe/solutions/guide still presents "**MediaPipe Studio**: Visualize, evaluate, and benchmark solutions in your browser" (and in the overview diagram's alt text), but Studio is sign-in only now and the task guides link the web demo https://google-ai-edge.github.io/mediapipe-samples-web/ instead. Should the guide drop Studio or point at the web demo?
