# Jetski: build and verify 0.5.0 on this branch

Hugo's plan (November 20, 2026): 0.4.2 is scrapped and never released. The
next release of google/flutter-mediapipe is 0.5.0, next week. It holds:

1. Every model downloaded from Hugging Face (`huggingface.co/litert-community`).
2. Your google3 core fix: the iOS backup FFI code moved to its own file.
3. Two CI fixes for the gallery journey, written by Claude in another session.
   That session has ended. **You now own their verification** (part B).
4. Windows arm64, from your `feat/windows-arm64` branch on this fork.

This file is a work order, not part of the release. Your last step removes it
from the branch history (step 10).

## Where this branch starts

`feat/v0.5.0` starts with these commits, oldest first:

| sha | what |
| --- | --- |
| `69bd5df8` | chore(release): 0.4.1 changelogs and versions (Google PR #99's head) |
| `88ceb1ad` | feat: download every model from Google's LiteRT community on Hugging Face |
| `c59ee2e4` | fix(core): keep dart:ffi out of the Flutter support directory file (your fix, from `fix/core-support-directory-no-ffi` 57cefe1b) |
| `ad7f14f7` | ci: give the gallery journey 40 minutes on iOS and desktop |
| `98de7565` | ci: stop the gallery journey downloading its models on the critical path |
| (top) | this file |

It does NOT contain `5cec3004` (chore(release): 0.4.2 changelogs and
versions). That commit is dropped. Its content returns inside the one 0.5.0
release commit (step 5).

---

# Part A: put Windows arm64 on top and make the release commit

## What to bring over from feat/windows-arm64

`feat/windows-arm64` is `69bd5df8, 88ceb1ad, c59ee2e4, 5cec3004, d7cc0bb8,
cfbc5818, 53070fbc`. Bring over:

- `d7cc0bb8` feat: add Windows arm64 support and bump packages to 0.5.0
- `cfbc5818` fix(ci): avoid runner context in desktop.yaml job-level env
- `53070fbc` fix(windows-arm64): apply MP4 edit list in video_frames and relax
  audio retrieval cosine floor

Claude tried `git cherry-pick d7cc0bb8` on `98de7565`. It conflicts in:

- the 20 files `5cec3004` touched: `README.md`,
  `doc/guides/vision/object_detector.md`, and in each of the six packages
  (`mediapipe-core`, `mediapipe-task-audio`, `-decision`, `-retrieval`,
  `-text`, `-vision`) its `CHANGELOG.md`, `README.md` and `pubspec.yaml`;
- `.github/workflows/desktop.yaml`, in the `face-tasks` job's header, next
  to `ad7f14f7`'s change of `timeout-minutes` from 60 to 80. Keep both: your
  matrix, name and `COVERAGE_PLATFORM` lines, and `timeout-minutes: 80` with
  its comment.

`gallery/tool/test_desktop.py` merges cleanly (your `arch` lines, Claude's
journey limit and prefetch). Every other file applies cleanly.

## Steps

### 1. Check out the branch

```sh
git fetch origin feat/v0.5.0 feat/windows-arm64
git switch feat/v0.5.0
```

### 2. Windows arm64 feature commit, without the version bump

Cherry-pick `d7cc0bb8` and `cfbc5818` and make them ONE commit that holds
only the Windows arm64 work. Versions, version strings in READMEs and docs,
and CHANGELOGs go in the release commit (step 5), not here.

- Conflicted `pubspec.yaml` files: keep this branch's 0.4.1 versions for now
  (`version:` and the `mediapipe_core` constraint).
- Conflicted `README.md` and doc files: take the Windows arm64 wording from
  `d7cc0bb8` (platform lists, setup notes), but keep this branch's version
  numbers. They change in step 5.
- `CHANGELOG.md` files: leave them as this branch has them. Step 5 writes them.
- `desktop.yaml`: as above.
- Message: `feat: add Windows arm64 support`. Keep the body's list of what
  changed. Remove the line `Base: unpublished 0.4.2
  (hugocornellier/mediapipe_flutter ci/hf-042-full, 5cec300).`, and anything
  else that names a sandbox repo, a throwaway branch or 0.4.2. This commit
  goes to Google.

Check: `git diff 98de7565 HEAD --stat` must show no `CHANGELOG.md`, and
`git grep -n '0\.5\.0'` must find no package version. Look at each hit.

### 3. video_frames edit list fix

Cherry-pick `53070fbc`, but split it.

- The `gallery/packages/video_frames/windows/video_frames_plugin.cpp` change is
  its own commit: `fix(gallery): apply the MP4 edit list in video_frames on
  Windows`. The plugin is the same code on Windows x64 and arm64, so the change
  runs on both. In the commit body, say why x64 never needed it (what differs
  on arm64: the decoder, Media Foundation's behaviour, the clip). The gallery's
  Windows x64 desktop job must stay green with it.
- The cosine floor change goes into step 4, not here.

### 4. Cosine floor: 0.995 on Windows arm64 only

`53070fbc` lowered `cosineFloor` in
`packages/mediapipe-task-retrieval/test/native_audio_reference_test.dart`
from 0.998 to 0.995 on every host. That weakens the check everywhere for one
platform. Make it:

- 0.995 when the test runs on Windows arm64 (`Abi.current() ==
  Abi.windowsArm64` from `dart:ffi`, or whatever this test file already uses
  to tell hosts apart; match its style);
- 0.998 everywhere else, as before.

Keep the comment that Windows arm64 sits around cosine 0.997 against the
macOS reference. Fold this into the step 2 commit, or make it a small commit
of its own right after it: `test(retrieval): accept cosine 0.995 for audio on
Windows arm64`.

### 5. One release commit: 0.5.0

One commit, `chore(release): 0.5.0 changelogs and versions`, like `69bd5df8`
(0.4.1) and `5cec3004` (0.4.2). It holds:

- every package at `version: 0.5.0`, and each family requiring
  `mediapipe_core: ^0.5.0`;
- every version string `5cec3004` and `d7cc0bb8` changed in `README.md`,
  `doc/guides/vision/object_detector.md` and the package READMEs, now 0.5.0;
- in each of the six `CHANGELOG.md` files, ONE new `## 0.5.0` section above
  `## 0.4.1`. No `## 0.4.2` section anywhere.

Each 0.5.0 section merges the 0.4.2 and 0.5.0 sections of `53070fbc` (read
them with `git show 53070fbc:packages/<pkg>/CHANGELOG.md`):

- first bullet: "Upgrade every mediapipe package to 0.5.0 together" plus the
  sentence that package's sections used (core: MediaPipe stays at 1.2.3 and
  its option structs keep their layout, so the build still accepts family
  releases from 0.3.0; families: this package now requires `mediapipe_core`
  ^0.5.0);
- then the Windows arm64 bullets from the 0.5.0 section;
- then the Hugging Face bullets from the 0.4.2 section;
- core only: then the 0.4.2 bullet about the iOS backup code in its own file
  (the Bazel fix);
- vision only: keep the 0.4.2 note that the Object Detector and Image
  Classifier models download as `efficientdet_lite0_float32.tflite` and
  `efficientnet_lite0_float32.tflite`.

The CI fixes of part B are not user-facing and need no CHANGELOG line.

Keep the CHANGELOG style: plain sentences, wrapped at 75 columns, no em
dashes, no marketing words. The wording on `53070fbc` is already right; this
step only joins it.

Check: `git grep -n '0\.4\.2'` must find nothing (except docs that quote old
releases, if any; look at each hit).

### 6. Compare with what was tested

```sh
git diff 53070fbc HEAD --stat
```

Expected differences only: the CHANGELOGs (one 0.5.0 section, no 0.4.2), the
cosine floor (Windows arm64 only), Claude's two CI commits (`ios.yaml`,
`desktop.yaml` timeout, `gallery/tool/test_desktop.py`,
`gallery/tool/prefetch_models.dart`), and this file until step 10. Anything
else is a mistake to fix.

### 7. Local checks

- `dart format --output=none --set-exit-if-changed .` and `dart analyze` /
  `flutter analyze` in every package you touched, and in `gallery/`;
- `python3 -B tool/check_repository.py` and `python3 -B tool/check_docs.py`;
- the unit tests of the packages you touched (`dart test` / `flutter test`),
  at least `packages/mediapipe-core/test/native_assets/family_runtimes_test.dart`,
  `packages/mediapipe-core/test/capabilities_test.dart`,
  `packages/mediapipe-task-vision/test/capabilities_test.dart`,
  `packages/mediapipe-task-vision/test/native_assets/vision_hook_test.dart`
  and `tool/gallery_builder/test/targets_test.dart`.

---

# Part B: finish verifying Claude's two CI commits

## What they do and why

The gallery journey (`gallery/integration_test/gallery_journey_test.dart`)
downloads every first-use model (parakeet 615 MB, phonon 87 MB, laya 678 MB,
EmbeddingGemma 2 270m 165 MB and 440m 388 MB), each within its own limit
(120 s + size at 310 kB/s). On slow runners, with Hugging Face slower than
Google's bucket, it ran out of suite time:

- iOS run 44806542261 (sandbox, old head): the journey re-downloaded
  parakeet (261 s), phonon (40 s), laya (215 s), the 270m (69 s), and was killed
  by the 900 s suite limit while on the 440m;
- a Linux x64 desktop journey took 1154 of its 1200 s.

`ad7f14f7` gives the journey 2400 s (40 min) on iOS (`ios.yaml`) and desktop
(`gallery/tool/test_desktop.py`), the iOS job 150 min, and the desktop CPU
job 80.

`98de7565` takes the downloads off the critical path:

- **iOS** (`ios.yaml`): `decision_maker_test`, `retrieval_test` and
  `speech_test` run with `--no-uninstall` (Flutter 3.43+, CI uses 3.50.0), and
  `gallery_journey_test` now runs right after them (before `runtime_test` and
  `face_landmarker_still_image_test`). The app's data container survives, so
  the journey finds laya, the 440m and parakeet (about 1.7 GB) already in its
  model store. The journey itself uninstalls, so the suites after it start
  fresh. Phonon and the 270m are still real downloads in the journey.
- **Desktop** (`test_desktop.py` + new `gallery/tool/prefetch_models.dart`):
  right after `flutter pub get`, `test_desktop.py` starts
  `dart run tool/prefetch_models.dart <store> parakeet_tdt_v3 laya_s256
  embedding_gemma_2_text embedding_gemma_2_text_vision` in the background,
  into the gallery's own store (`model_store()`: Linux
  `$XDG_DATA_HOME|~/.local/share/com.example.mediapipe_gallery/mediapipe/models`,
  Windows `%APPDATA%\com.example\mediapipe_gallery\mediapipe\models`). It
  waits for the line `MODEL_PREFETCH started`, so the prefetch's build hooks
  (which fetch the family runtimes the app's build then reuses) finish before
  the app builds. The store's cross-process claim file (`<folder>.lock`) makes
  the app wait for a model still downloading instead of downloading it twice.
  Phonon is left out on purpose, so the journey still proves a real in-app
  download. After the journey, `check_prefetch()` warns if the prefetch exited
  non-zero, and FAILS if the app wrote no model folder of its own besides the
  prefetched ones (that would mean `model_store()` points at the wrong
  folder).

## Results so far (sandbox, which you cannot see)

- `ad7f14f7` alone, trimmed to the iOS phone suites and the desktop CPU jobs:
  run 44824382017 (iOS) and 44824382156 (desktop Linux x64, Linux arm64,
  Windows x64): all green. The iOS journey took about 6 min on a fast runner,
  re-downloading parakeet 69 s, phonon 10 s, laya 76 s, 270m 11 s, 440m 27 s.
- `98de7565`: targeted runs 44831930567 (iOS) and 44831930554 (desktop) were
  still in progress when the session ended. Treat it as unverified. Your runs
  below replace them.
- Windows arm64 was not covered by either. Your `windows-11-arm` desktop job
  is new to these changes.

## Step 8: verify part B on the fork

Do it on a throwaway branch of this fork, `ci/v050-journey-targeted`, made from
`feat/v0.5.0` once part A is done (so Windows arm64 is in it). On that branch
only, trim the workflows the way Claude did:

- delete every workflow except `ios.yaml` and `desktop.yaml`;
- in both, `on:` becomes `push: branches: [ci/v050-journey-targeted]`, and
  drop the `workflow_call` inputs (replace `inputs.side && ...` expressions
  with `''`);
- in `desktop.yaml`, keep only the `face-tasks` job (the CPU matrix: Linux
  x64, Windows x64, Linux arm64, Windows arm64).

Pass criteria:

- **iOS**: every suite green. In the journey's log, the
  `GALLERY_JOURNEY_MODEL <file>: ready in N s` lines show laya, the 440m and
  parakeet ready in a few seconds (reused), not a download time. The decision,
  retrieval and speech suites still pass with `--no-uninstall`, and the
  suites after the journey still pass on their fresh install.
- **Desktop, every host including windows-11-arm**: green. The job prints
  `prefetch.log` with one `MODEL_PREFETCH <name>: <16 hex> in N s` line per
  prefetched model and no `::warning::`. The journey's `GALLERY_JOURNEY_MODEL`
  lines show the four prefetched models ready in a few seconds, or waiting only
  for the remainder of a download already running; phonon is a real download.
  `check_prefetch` does not fail. If it fails on Windows arm64, the app's
  store there is not `%APPDATA%\com.example\mediapipe_gallery`: find where
  path_provider puts it and fix `model_store()`.
- No suite comes near its limit. Report the journey's time per host.

Then the **10x count** (Hugo's rule for any changed limit or new check): run
the same trimmed jobs 10 times, as a matrix of 10 or 10 pushes, on every host:
iOS simulator, Linux x64, Linux arm64, Windows x64, Windows arm64. It counts
only at 10 of 10 green per host. One failure means find the cause, fix it on
the throwaway branch, and start the count again from zero on the fixed
version. "Passed on rerun" does not count. Before writing a new fix, look for
an existing one: in this repo's other workflows, then Hugo's other repos
(flutter_litert, AgeLapse, mediapipe_flutter), then well-run Flutter repos
(flutter/flutter, flutter/packages).

A fix found here goes into `ad7f14f7` or `98de7565` itself (fixup and rebase),
keeping their messages accurate, and author Hugo Cornellier
<cornellier@google.com>.

---

# Part C: CI for the whole release

### 9. CI on this fork

Use `workflow_dispatch` on `feat/v0.5.0`, as you did on
`feat/windows-arm64` (the workflows run on push only for `main`).

a. **Targeted first.** Before the full CI, run only what is new or changed,
   once, on every runner kind that runs it:
   - `windows-arm64.yaml` (Native hooks / Windows arm64);
   - Desktop tasks (all hosts, including `windows-2025` x64 for the
     video_frames change);
   - Retrieval (all hosts: the cosine floor must hold at 0.998 off Windows
     arm64);
   - Bundled models, Samples, and the families' jobs that gained
     `windows-11-arm`.

b. **10x count for every changed test or comparison.** A new test, or a test
   whose comparison or tolerance changed, runs ALONE 10 or more times in a row
   on every runner kind CI uses, and counts only at N of N green:
   - `native_audio_reference_test.dart`, on every host Retrieval runs it on;
   - every new or changed test in `d7cc0bb8` (`family_runtimes_test`,
     `capabilities_test` in core, vision and text, `vision_hook_test`,
     `targets_test`, `decision_unit_test`, `retrieval_unit_test`,
     `speech_test`) on every host its workflow runs it on;
   - part B's count (step 8).

   Each count on its own throwaway branch (`ci/v050-10x-<test>`) holding a
   workflow that runs only that test. Never on `feat/v0.5.0`. Same failure
   rule as step 8.

c. **Then the full CI once** on `feat/v0.5.0`'s final head (every workflow
   via `workflow_dispatch`, iOS and Android included). Record every run id
   with its conclusion. If a job fails, fix the cause, then rerun only the
   failed job plus any job that builds or tests what the fix touched. Rerun
   everything only if the fix changes something every job depends on (the
   setup action, a shared workflow).

d. **Delete every throwaway branch** (remote and local) as soon as its runs
   are done and their result is in your report. Write down each one's sha
   first.

### 10. Remove this file from the history

When everything above is done, drop the commit that adds this file:

```sh
git rebase --onto <this file's commit>~1 <this file's commit>
git push --force-with-lease origin feat/v0.5.0
```

Final history, oldest first: `69bd5df8` (0.4.1), `88ceb1ad` (Hugging Face),
`c59ee2e4` (core fix), `ad7f14f7` and `98de7565` (CI, or their fixed
versions), feat: add Windows arm64 support, the video_frames fix (and the
cosine floor commit, if separate), chore(release): 0.5.0. Rebasing changes
the shas; give the new ones in the report. If you dropped this file after the
full CI, the tree is unchanged apart from this file, so the CI result stands.

---

# Rules

- Every commit authored AND committed as `Hugo Cornellier
  <cornellier@google.com>`:
  `git -c user.name="Hugo Cornellier" -c user.email=cornellier@google.com commit ...`.
  Check: `git log --format='%an <%ae> | %cn <%ce>' 69bd5df8..HEAD`.
- No AI attribution anywhere: no `Co-Authored-By`, no "Generated with", no
  session links, in commits, branch names, comments or reports to Google.
- No em dashes in commit messages, CHANGELOGs, docs or comments.
- Push ONLY `feat/v0.5.0` and your own `ci/v050-*` throwaway branches.
  Never push to `feat/linux-arm64-gpu` (that updates Google PR #99), `main`,
  or anything on google/flutter-mediapipe. Open no PR, anywhere.
- Never publish to pub.dev, and never run `dart pub publish --force` or
  `flutter pub publish --force`.
- Temporary files go in a scratch folder you own, and you delete them when
  done.
- If something here is wrong or does not work, stop and say so in the
  report. Do not work around it silently.

# Report (to Hugo)

- `feat/v0.5.0` head sha and commit list (`git log --oneline 69bd5df8..HEAD`);
- the output of the author check;
- `git diff 53070fbc HEAD --stat`, with a line on each difference;
- part B: the per-host journey times and the `GALLERY_JOURNEY_MODEL` and
  `MODEL_PREFETCH` lines of one run per host;
- every CI run id with its workflow, host and conclusion (targeted runs and
  the final full runs);
- each 10x count as N of N per host, with run ids;
- throwaway branches made and deleted, with shas;
- anything not done, failing, or uncertain.

# After you

Hugo decides when the Google PR opens: after #99 (0.4.1) merges, rebased onto
Google's main, and only on his go.
