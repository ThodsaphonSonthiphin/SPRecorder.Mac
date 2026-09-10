# Plan 1 — Foundation and First Demo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use sp-subagent-driven-development (recommended) or sp-executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the SPRecorder.Mac Xcode project and its tested foundation — settings file, Diary, Session folder naming, hotkey text, and the Recording Session orchestrator — ending in a menu-bar app whose **⌃⌥R** hotkey records `Computer audio.m4a` and `My microphone.m4a` into a Session folder.

**Architecture:** One Xcode project with three targets (`sprecorder-mac-0007`). `SPRecorderCore` is a framework that imports **Foundation only**, enforced by a build-phase script; it holds the domain types, the `RecordingSession` orchestrator, and the two seams it needs from the platform (`AudioCapturing`, `DiarySink`). `SPRecorderApp` implements those seams with ScreenCaptureKit, AVFoundation, Carbon and `os.Logger`, and owns the menu-bar icon. `SPRecorderCoreTests` runs the whole Core — including a complete Recording Session — against fakes, with Swift Testing. The project uses **folder-synchronized groups**: any file placed in a target's folder is compiled into that target, so no task edits the project file after Task 1.

**Tech Stack:** Swift 6.3.3 in Swift 6 language mode · Xcode 26.6 · macOS 26.0, arm64 · Swift Testing · ScreenCaptureKit (`capturesAudio` + `captureMicrophone`) · AVFoundation (`AVAssetWriter`, AAC in `.m4a`) · Carbon HIToolbox (`RegisterEventHotKey`) · `os.Logger` · GitHub Actions `macos-26`.

**Spec:** `docs/superpowers/plans/2026-09-10-sprecorder-mac-roadmap.md` (row 1) and the ADRs it implements, in `docs/adr/`: `sprecorder-mac-0001`, `0002` (+ correction), `0003` (+ amendment), `0004`, `0005`, `0006` (+ amendment), `0007`, `0009`, `0010`, `0013`, `0014`, `0015`, `0016`, `0018`, `0019` (+ correction), `0021`, `0034`, `0038`. Glossary: `CONTEXT.md`. Research: GitHub issues #3 (system audio), #5 (global hotkey), #6 (AAC).

## Global Constraints

- Deployment target **macOS 26.0**, architecture **arm64 only** (`sprecorder-mac-0009`).
- `SPRecorderCore` imports **Foundation only**. The build fails on `^import (AppKit|SwiftUI|ScreenCaptureKit|AVFoundation|Carbon|CoreAudio)` in `SPRecorderCore/` (`sprecorder-mac-0002` correction, `sprecorder-mac-0007`).
- `Info.plist` keys and usage strings belong to the **App target only** (`sprecorder-mac-0007`).
- **No captured keystroke is ever written anywhere, in any form** — not the key, not a count, not a placeholder (`sprecorder-mac-0014`). Plan 1 captures no keystrokes; add no API that accepts one.
- **No failure is silent:** every `catch` writes a Diary line before it does anything else (`sprecorder-mac-0013`).
- Settings: `~/Library/Application Support/SPRecorder/settings.json`, readable JSON (`sprecorder-mac-0004`). Recordings: `~/Movies/SPRecorder` by default, stored as a plain path, never a bookmark (`sprecorder-mac-0005`). Diary: `~/Library/Logs/SPRecorder`, one file per day, kept 7 days (`sprecorder-mac-0013`, `sprecorder-mac-0014`).
- Session folder name: `yyyy-MM-dd EEE HH.mm`, formatter pinned to `en_US_POSIX` and the Gregorian calendar; `/` and `:` become `-`; a collision appends ` (2)` (`sprecorder-mac-0019`). Track files: `Computer audio.m4a` (System track), `My microphone.m4a` (Mic track).
- Every live `AVAssetWriter` sets `movieFragmentInterval` to **2 seconds** from creation; no tidy re-save after stop (`sprecorder-mac-0034`, `sprecorder-mac-0038` rules 1–2).
- **Never gate a Recording Session on a permission preflight.** Attempt capture and read the error (`sprecorder-mac-0006` amendment).
- Use `CONTEXT.md`'s terms in code, Diary lines and messages, and its *Avoid* words nowhere (`sprecorder-mac-0039`). Files on disk use the plain names above (`sprecorder-mac-0019`).
- The Windows repo `/Users/liusp/Documents/repo/SPRecorder` is read-only.
- **Parallel Claude sessions share this working tree.** Stage and commit explicit paths only (`git add <paths> && git commit -m … -- <paths>`); never `git add -A` or `git commit -a`. Pushing is the user's decision; before any push run `git log origin/master..HEAD` and name every commit this plan did not make.
- Signing is ad-hoc (`CODE_SIGN_IDENTITY = "-"`) until Plan 9 moves to the one certificate (`sprecorder-mac-0040`). Consequence on the development Mac: **each rebuild is a new app to macOS, and permissions are asked again.**
- `tccutil reset` is only ever run scoped to a bundle id, never unscoped (`sprecorder-mac-0041`).

## Decisions this plan settles

No ADR fixed these. They were chosen while writing the plan; each is cheap to change before Plan 2.

| decision | chosen | why |
|---|---|---|
| Bundle identifier | `com.sprecorder.mac` | matches the `os_log` subsystem `sprecorder-mac-0013` already names |
| Audio bitrate setting | `AudioBitrateKbps`, default **64** | `sprecorder-mac-0004` calls `Mp3BitrateKbps` misnamed; research #6 and both probes used 64 kbps |
| Hotkeys in `settings.json` | `Control+Option+R` text; display `⌃⌥R`; must include Control or Command | readable in a hand-edited file; Carbon refuses Option/Shift-only combinations (research #5) |
| Track format | AAC, **mono**, at the source's sample rate (48 kHz requested from ScreenCaptureKit) | research #6 recommends mono AAC for voice |
| Where `DiaryFile` lives | **Core** (Foundation file I/O); only `OSLogSink` is in the App | `sprecorder-mac-0018`'s leak test must read the Diary file a faked session wrote. Recorded as an amendment to `sprecorder-mac-0013` in Task 3 |
| Two tracks in step | both writers start their timeline at the **first buffer of the stream** | keeps the files aligned for Plan 2's Mixed file |
| Project file | hand-written, `objectVersion = 77`, folder-synchronized groups | files added later need no project edit; `sprecorder-mac-0007` rejected generators |
| Guard script | `scripts/forbid-core-platform-imports.sh`, called from the Run Script phase | the ADR's exact `grep`, readable and diffable outside the project file |
| Language mode | Swift 6 | concurrency errors caught at compile time; the whole plan compiles in it with zero warnings |

## Verified while writing this plan — 2026-09-10, this Mac

Every file in this plan was built and run in a throwaway copy of the project, then the tasks were replayed in order in a fresh folder:

- `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS'` **works** (the command `sprecorder-mac-0007` and `sprecorder-mac-0015` recorded as unverified): **53 tests in 8 suites passed**.
- `-only-testing:SPRecorderCoreTests/<SuiteName>` selects a Swift Testing suite.
- Each task's test **fails before** its implementation exists and **passes after**.
- The import guard **fails the build** on a planted `import AppKit` and passes once it is removed.
- The App target builds with **zero compiler warnings** in Swift 6 mode; its `Info.plist` carries `LSUIElement = true`, `NSMicrophoneUsageDescription`, `CFBundleIdentifier = com.sprecorder.mac`, `LSMinimumSystemVersion = 26.0`; it embeds `SPRecorderCore.framework` and is signed ad-hoc.
- All 48 key codes and the 4 modifier flags in `HotkeySpec` equal Carbon's `kVK_*`, `cmdKey`, `shiftKey`, `optionKey`, `controlKey`.
- `tools/track-seconds/track-seconds.swift` reads a real `.m4a` (3.21 s, matching `afinfo`).

**Not verified — only Task 11 can:** that `captureMicrophone` delivers the Mic track on macOS 26.6.2 (research #3 says yes; no probe has run it), the real sample format of each track, the permission prompts in this app, and the hotkey conflict status code on macOS 26 (research #5 item 1). Task 11 measures all four.

## File structure

```
SPRecorder.xcodeproj/                          Task 1  project, two shared schemes
scripts/forbid-core-platform-imports.sh        Task 1  the Core import guard
.gitignore                                     Task 1  (modified) ignore Xcode output
.github/workflows/tests.yml                    Task 2  build + Core tests on every push

SPRecorderCore/                                Foundation only
  Session/TrackFile.swift                      Task 1  the fixed file names inside a Session folder
  Diary/Diary.swift                            Task 3  levels, categories, DiarySink, Diary
  Diary/DiaryFile.swift                        Task 3  one file per day, 7-day retention
  Settings/AppSettings.swift                   Task 4  the 26 settings, decoding, validation
  Settings/SettingsStore.swift                 Task 5  load / create / atomic save
  Session/SessionFolderName.swift              Task 6  folder name, sanitizer, collisions
  Hotkey/HotkeySpec.swift                      Task 7  "Control+Option+R" ⇄ Carbon numbers
  Session/AudioCapturing.swift                 Task 8  the capture seam + CaptureError
  Session/RecordingSession.swift               Task 8  the orchestrator

SPRecorderCoreTests/
  TrackFileTests.swift                         Task 1
  Support/TestSupport.swift                    Task 3  RecordingDiarySink, TestTime, temp folders
  DiaryTests.swift                             Task 3  DiaryTests + DiaryFileTests
  AppSettingsTests.swift                       Task 4
  SettingsStoreTests.swift                     Task 5
  SessionFolderNameTests.swift                 Task 6
  HotkeySpecTests.swift                        Task 7
  Support/FakeAudioCapture.swift               Task 8
  RecordingSessionTests.swift                  Task 8  the headline test of sprecorder-mac-0015

SPRecorderApp/                                 platform adapters and UI
  AppDelegate.swift                            Task 1 scaffold, Task 10 real
  Diary/OSLogSink.swift                        Task 9
  Capture/TrackWriter.swift                    Task 9  one AAC file, 2-second pieces
  Capture/ScreenCaptureAudioRecorder.swift     Task 9  AudioCapturing via ScreenCaptureKit
  Hotkey/CarbonHotkeyCenter.swift              Task 10
  MenuBar/StatusItemController.swift           Task 10

tools/track-seconds/track-seconds.swift        Task 11 decodable seconds of a track
docs/adr/sprecorder-mac-0007-…md               Task 1  (amended) command verified
docs/adr/sprecorder-mac-0013-…md               Task 3  (amended) file sink in the Core
docs/adr/sprecorder-mac-0005-…md               Task 11 (amended) ~/Movies prompt measured
docs/superpowers/plans/2026-09-10-plan-1-first-demo-results.md   Task 11
```

## Not in this plan

The Mixed file, splitting, crash recovery (Plan 2) · Markers, `HotkeyStatus` and the marker hotkeys (Plan 3) · Screen recording and the keystroke leak test (Plan 4) · call detection (Plan 5) · the full menu, Settings window, `HotkeyValidation`, Named session prompt and rename-at-stop (Plan 6) · Check my setup (Plan 7) · Problem report (Plan 8) · certificate signing (Plan 9).

## How to read test output

`xcodebuild` prints thousands of lines. Every test step pipes through:

```sh
grep -E "error: |✘|Test run with|\*\* TEST"
```

A red run shows `error: cannot find … in scope` lines and `** TEST FAILED **`. A green run shows `✔ Test run with N tests in M suites passed` and `** TEST SUCCEEDED **`. A `✘` line names a failing test.

---

### Task 1: Create the Xcode project, the import guard and the first Core type

**Files:**
- Create: `SPRecorder.xcodeproj/project.pbxproj`
- Create: `SPRecorder.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
- Create: `SPRecorder.xcodeproj/xcshareddata/xcschemes/SPRecorderCore.xcscheme`
- Create: `SPRecorder.xcodeproj/xcshareddata/xcschemes/SPRecorderApp.xcscheme`
- Create: `scripts/forbid-core-platform-imports.sh`
- Create: `SPRecorderCore/Session/TrackFile.swift`
- Create: `SPRecorderApp/AppDelegate.swift` (scaffold; replaced in Task 10)
- Test: `SPRecorderCoreTests/TrackFileTests.swift`
- Modify: `.gitignore`
- Modify: `docs/adr/sprecorder-mac-0007-one-xcode-project-two-targets.md` (append amendment)

**Interfaces:**
- Consumes: nothing.
- Produces: schemes `SPRecorderCore` (builds the framework; its Test action runs `SPRecorderCoreTests`) and `SPRecorderApp` (builds `SPRecorder.app`, bundle id `com.sprecorder.mac`). Target folders `SPRecorderCore/`, `SPRecorderApp/`, `SPRecorderCoreTests/` compile every file inside them. `public enum TrackFile: String, Sendable, CaseIterable { case systemTrack, micTrack; var fileName: String; func url(in folder: URL) -> URL }`.

- [ ] **Step 1: Write the project file**

Create `SPRecorder.xcodeproj/project.pbxproj` with exactly this content. The IDs are arbitrary but must stay as written — the schemes below refer to `5C5C00000000000000000020` (Core), `…21` (App) and `…22` (Tests).

```text
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 77;
	objects = {

/* Begin PBXBuildFile section */
		5C5C00000000000000000040 /* SPRecorderCore.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = 5C5C00000000000000000010 /* SPRecorderCore.framework */; };
		5C5C00000000000000000041 /* SPRecorderCore.framework in Embed Frameworks */ = {isa = PBXBuildFile; fileRef = 5C5C00000000000000000010 /* SPRecorderCore.framework */; settings = {ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }; };
		5C5C00000000000000000042 /* SPRecorderCore.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = 5C5C00000000000000000010 /* SPRecorderCore.framework */; };
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		5C5C00000000000000000050 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = 5C5C00000000000000000001 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = 5C5C00000000000000000020;
			remoteInfo = SPRecorderCore;
		};
		5C5C00000000000000000051 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = 5C5C00000000000000000001 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = 5C5C00000000000000000020;
			remoteInfo = SPRecorderCore;
		};
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
		5C5C00000000000000000037 /* Embed Frameworks */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 10;
			files = (
				5C5C00000000000000000041 /* SPRecorderCore.framework in Embed Frameworks */,
			);
			name = "Embed Frameworks";
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
		5C5C00000000000000000010 /* SPRecorderCore.framework */ = {isa = PBXFileReference; explicitFileType = wrapper.framework; includeInIndex = 0; path = SPRecorderCore.framework; sourceTree = BUILT_PRODUCTS_DIR; };
		5C5C00000000000000000011 /* SPRecorder.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SPRecorder.app; sourceTree = BUILT_PRODUCTS_DIR; };
		5C5C00000000000000000012 /* SPRecorderCoreTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = SPRecorderCoreTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		5C5C00000000000000000004 /* SPRecorderCore */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = SPRecorderCore;
			sourceTree = "<group>";
		};
		5C5C00000000000000000005 /* SPRecorderApp */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = SPRecorderApp;
			sourceTree = "<group>";
		};
		5C5C00000000000000000006 /* SPRecorderCoreTests */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = SPRecorderCoreTests;
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		5C5C00000000000000000032 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		5C5C00000000000000000035 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				5C5C00000000000000000040 /* SPRecorderCore.framework in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		5C5C00000000000000000039 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				5C5C00000000000000000042 /* SPRecorderCore.framework in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		5C5C00000000000000000002 = {
			isa = PBXGroup;
			children = (
				5C5C00000000000000000004 /* SPRecorderCore */,
				5C5C00000000000000000005 /* SPRecorderApp */,
				5C5C00000000000000000006 /* SPRecorderCoreTests */,
				5C5C00000000000000000003 /* Products */,
			);
			sourceTree = "<group>";
		};
		5C5C00000000000000000003 /* Products */ = {
			isa = PBXGroup;
			children = (
				5C5C00000000000000000010 /* SPRecorderCore.framework */,
				5C5C00000000000000000011 /* SPRecorder.app */,
				5C5C00000000000000000012 /* SPRecorderCoreTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		5C5C00000000000000000020 /* SPRecorderCore */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 5C5C00000000000000000063 /* Build configuration list for PBXNativeTarget "SPRecorderCore" */;
			buildPhases = (
				5C5C00000000000000000030 /* Forbid platform imports */,
				5C5C00000000000000000031 /* Sources */,
				5C5C00000000000000000032 /* Frameworks */,
				5C5C00000000000000000033 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				5C5C00000000000000000004 /* SPRecorderCore */,
			);
			name = SPRecorderCore;
			packageProductDependencies = (
			);
			productName = SPRecorderCore;
			productReference = 5C5C00000000000000000010 /* SPRecorderCore.framework */;
			productType = "com.apple.product-type.framework";
		};
		5C5C00000000000000000021 /* SPRecorderApp */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 5C5C00000000000000000066 /* Build configuration list for PBXNativeTarget "SPRecorderApp" */;
			buildPhases = (
				5C5C00000000000000000034 /* Sources */,
				5C5C00000000000000000035 /* Frameworks */,
				5C5C00000000000000000036 /* Resources */,
				5C5C00000000000000000037 /* Embed Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
				5C5C00000000000000000052 /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				5C5C00000000000000000005 /* SPRecorderApp */,
			);
			name = SPRecorderApp;
			packageProductDependencies = (
			);
			productName = SPRecorder;
			productReference = 5C5C00000000000000000011 /* SPRecorder.app */;
			productType = "com.apple.product-type.application";
		};
		5C5C00000000000000000022 /* SPRecorderCoreTests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 5C5C00000000000000000069 /* Build configuration list for PBXNativeTarget "SPRecorderCoreTests" */;
			buildPhases = (
				5C5C00000000000000000038 /* Sources */,
				5C5C00000000000000000039 /* Frameworks */,
				5C5C0000000000000000003A /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				5C5C00000000000000000053 /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				5C5C00000000000000000006 /* SPRecorderCoreTests */,
			);
			name = SPRecorderCoreTests;
			packageProductDependencies = (
			);
			productName = SPRecorderCoreTests;
			productReference = 5C5C00000000000000000012 /* SPRecorderCoreTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		5C5C00000000000000000001 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2600;
				LastUpgradeCheck = 2600;
				TargetAttributes = {
					5C5C00000000000000000020 = {
						CreatedOnToolsVersion = 26.6;
					};
					5C5C00000000000000000021 = {
						CreatedOnToolsVersion = 26.6;
					};
					5C5C00000000000000000022 = {
						CreatedOnToolsVersion = 26.6;
					};
				};
			};
			buildConfigurationList = 5C5C00000000000000000060 /* Build configuration list for PBXProject "SPRecorder" */;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 5C5C00000000000000000002;
			minimizedProjectReferenceProxies = 1;
			preferredProjectObjectVersion = 77;
			productRefGroup = 5C5C00000000000000000003 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				5C5C00000000000000000020 /* SPRecorderCore */,
				5C5C00000000000000000021 /* SPRecorderApp */,
				5C5C00000000000000000022 /* SPRecorderCoreTests */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		5C5C00000000000000000033 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		5C5C00000000000000000036 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		5C5C0000000000000000003A /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXShellScriptBuildPhase section */
		5C5C00000000000000000030 /* Forbid platform imports */ = {
			isa = PBXShellScriptBuildPhase;
			alwaysOutOfDate = 1;
			buildActionMask = 2147483647;
			files = (
			);
			inputFileListPaths = (
			);
			inputPaths = (
			);
			name = "Forbid platform imports";
			outputFileListPaths = (
			);
			outputPaths = (
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "\"$SRCROOT/scripts/forbid-core-platform-imports.sh\"\n";
		};
/* End PBXShellScriptBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		5C5C00000000000000000031 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		5C5C00000000000000000034 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		5C5C00000000000000000038 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		5C5C00000000000000000052 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = 5C5C00000000000000000020 /* SPRecorderCore */;
			targetProxy = 5C5C00000000000000000050 /* PBXContainerItemProxy */;
		};
		5C5C00000000000000000053 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = 5C5C00000000000000000020 /* SPRecorderCore */;
			targetProxy = 5C5C00000000000000000051 /* PBXContainerItemProxy */;
		};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		5C5C00000000000000000061 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ARCHS = arm64;
				CLANG_ENABLE_MODULES = YES;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Manual;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				DEVELOPMENT_TEAM = "";
				ENABLE_HARDENED_RUNTIME = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				MACOSX_DEPLOYMENT_TARGET = 26.0;
				MARKETING_VERSION = 0.1;
				CURRENT_PROJECT_VERSION = 1;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 6.0;
			};
			name = Debug;
		};
		5C5C00000000000000000062 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ARCHS = arm64;
				CLANG_ENABLE_MODULES = YES;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Manual;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				DEVELOPMENT_TEAM = "";
				ENABLE_HARDENED_RUNTIME = NO;
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = NO;
				MACOSX_DEPLOYMENT_TARGET = 26.0;
				MARKETING_VERSION = 0.1;
				CURRENT_PROJECT_VERSION = 1;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_VERSION = 6.0;
			};
			name = Release;
		};
		5C5C00000000000000000064 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				DEFINES_MODULE = YES;
				DYLIB_INSTALL_NAME_BASE = "@rpath";
				GENERATE_INFOPLIST_FILE = YES;
				INSTALL_PATH = "@rpath";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
					"@loader_path/Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.sprecorder.mac.core;
				PRODUCT_NAME = "$(TARGET_NAME:c99extidentifier)";
				SKIP_INSTALL = YES;
			};
			name = Debug;
		};
		5C5C00000000000000000065 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				DEFINES_MODULE = YES;
				DYLIB_INSTALL_NAME_BASE = "@rpath";
				GENERATE_INFOPLIST_FILE = YES;
				INSTALL_PATH = "@rpath";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
					"@loader_path/Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.sprecorder.mac.core;
				PRODUCT_NAME = "$(TARGET_NAME:c99extidentifier)";
				SKIP_INSTALL = YES;
			};
			name = Release;
		};
		5C5C00000000000000000067 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				COMBINE_HIDPI_IMAGES = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = SPRecorder;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
				INFOPLIST_KEY_LSUIElement = YES;
				INFOPLIST_KEY_NSMicrophoneUsageDescription = "SPRecorder records your voice into My microphone while a Recording Session runs.";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.sprecorder.mac;
				PRODUCT_NAME = SPRecorder;
			};
			name = Debug;
		};
		5C5C00000000000000000068 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				COMBINE_HIDPI_IMAGES = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = SPRecorder;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
				INFOPLIST_KEY_LSUIElement = YES;
				INFOPLIST_KEY_NSMicrophoneUsageDescription = "SPRecorder records your voice into My microphone while a Recording Session runs.";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.sprecorder.mac;
				PRODUCT_NAME = SPRecorder;
			};
			name = Release;
		};
		5C5C0000000000000000006A /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				GENERATE_INFOPLIST_FILE = YES;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
					"@loader_path/../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.sprecorder.mac.coretests;
				PRODUCT_NAME = "$(TARGET_NAME)";
			};
			name = Debug;
		};
		5C5C0000000000000000006B /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				GENERATE_INFOPLIST_FILE = YES;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
					"@loader_path/../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.sprecorder.mac.coretests;
				PRODUCT_NAME = "$(TARGET_NAME)";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		5C5C00000000000000000060 /* Build configuration list for PBXProject "SPRecorder" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				5C5C00000000000000000061 /* Debug */,
				5C5C00000000000000000062 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		5C5C00000000000000000063 /* Build configuration list for PBXNativeTarget "SPRecorderCore" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				5C5C00000000000000000064 /* Debug */,
				5C5C00000000000000000065 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		5C5C00000000000000000066 /* Build configuration list for PBXNativeTarget "SPRecorderApp" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				5C5C00000000000000000067 /* Debug */,
				5C5C00000000000000000068 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		5C5C00000000000000000069 /* Build configuration list for PBXNativeTarget "SPRecorderCoreTests" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				5C5C0000000000000000006A /* Debug */,
				5C5C0000000000000000006B /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = 5C5C00000000000000000001 /* Project object */;
}
```

- [ ] **Step 2: Write the workspace file and the two shared schemes**

`SPRecorder.xcodeproj/project.xcworkspace/contents.xcworkspacedata`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
```

`SPRecorder.xcodeproj/xcshareddata/xcschemes/SPRecorderCore.xcscheme` — its Test action is what makes `xcodebuild test -scheme SPRecorderCore` run the suite:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "5C5C00000000000000000020"
               BuildableName = "SPRecorderCore.framework"
               BlueprintName = "SPRecorderCore"
               ReferencedContainer = "container:SPRecorder.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "5C5C00000000000000000022"
               BuildableName = "SPRecorderCoreTests.xctest"
               BlueprintName = "SPRecorderCoreTests"
               ReferencedContainer = "container:SPRecorder.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
```

`SPRecorder.xcodeproj/xcshareddata/xcschemes/SPRecorderApp.xcscheme`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "5C5C00000000000000000021"
               BuildableName = "SPRecorder.app"
               BlueprintName = "SPRecorderApp"
               ReferencedContainer = "container:SPRecorder.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "5C5C00000000000000000021"
            BuildableName = "SPRecorder.app"
            BlueprintName = "SPRecorderApp"
            ReferencedContainer = "container:SPRecorder.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
```

- [ ] **Step 3: Write the import guard and make it executable**

`scripts/forbid-core-platform-imports.sh` — the `grep` is `sprecorder-mac-0007`'s, verbatim:

```sh
#!/bin/sh
# Fails the SPRecorderCore build when a Core source imports a platform framework.
# The Swift compiler does not enforce this (sprecorder-mac-0002 correction); this does
# (sprecorder-mac-0007). Runs as the first build phase of the SPRecorderCore target.
if grep -rlE '^import (AppKit|SwiftUI|ScreenCaptureKit|AVFoundation|Carbon|CoreAudio)' "$SRCROOT/SPRecorderCore"; then
  echo "error: SPRecorderCore must not import a platform framework (sprecorder-mac-0002)"
  exit 1
fi
```

Run: `chmod +x scripts/forbid-core-platform-imports.sh`

The project sets `ENABLE_USER_SCRIPT_SANDBOXING = NO`: a sandboxed build script may read only its declared inputs, and this one must read the whole Core folder.

- [ ] **Step 4: Ignore Xcode output**

Append to `.gitignore` (it currently holds `__pycache__/`, `*.pyc`, `.DS_Store`):

```gitignore
# Xcode
/build/
DerivedData/
xcuserdata/
*.xcuserstate
```

- [ ] **Step 5: Write the failing test**

`SPRecorderCoreTests/TrackFileTests.swift`:

```swift
import Foundation
import Testing
@testable import SPRecorderCore

struct TrackFileTests {
    @Test func tracksHavePlainEnglishFileNames() {
        let folder = URL(fileURLWithPath: "/x/2026-09-10 Thu 14.30", isDirectory: true)
        #expect(TrackFile.systemTrack.url(in: folder).path == "/x/2026-09-10 Thu 14.30/Computer audio.m4a")
        #expect(TrackFile.micTrack.url(in: folder).path == "/x/2026-09-10 Thu 14.30/My microphone.m4a")
    }
}
```

- [ ] **Step 6: Run it to make sure it fails**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' -only-testing:SPRecorderCoreTests/TrackFileTests 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `error: Unable to resolve module dependency: 'SPRecorderCore'` and `** TEST FAILED **` — the framework has no sources yet.

- [ ] **Step 7: Write the first Core type and the App scaffold**

`SPRecorderCore/Session/TrackFile.swift`:

```swift
import Foundation

/// The fixed, plain-English file names inside a Session folder (sprecorder-mac-0019). The disk
/// does not speak the glossary: the System track is `Computer audio.m4a`.
/// Later plans add the Mixed file, Screen recording, Marker log and Marker review page.
public enum TrackFile: String, Sendable, CaseIterable {
    case systemTrack = "Computer audio.m4a"
    case micTrack = "My microphone.m4a"

    public var fileName: String { rawValue }

    public func url(in folder: URL) -> URL {
        folder.appendingPathComponent(fileName, isDirectory: false)
    }
}
```

`SPRecorderApp/AppDelegate.swift` (the App target needs an entry point to build; do not run this app — it has no icon and no way to quit):

```swift
import AppKit
import SPRecorderCore

/// Scaffold entry point so the App target builds. Task 10 replaces this file.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
```

- [ ] **Step 8: Run the test to make sure it passes**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' -only-testing:SPRecorderCoreTests/TrackFileTests 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `✔ Test run with 1 test in 1 suite passed` and `** TEST SUCCEEDED **`.

- [ ] **Step 9: Build the app**

Run: `xcodebuild build -scheme SPRecorderApp -destination 'platform=macOS' 2>&1 | grep -E ": error:|: warning:|\*\* BUILD"`

Expected: `** BUILD SUCCEEDED **` and no `warning:` lines.

- [ ] **Step 10: Prove the guard fails the build, then remove the planted import**

Run: `printf 'import AppKit\n' > SPRecorderCore/Planted.swift && xcodebuild build -scheme SPRecorderCore -destination 'platform=macOS' 2>&1 | grep -E "Planted.swift|error: |\*\* BUILD"`

Expected: the path of `SPRecorderCore/Planted.swift`, then `error: SPRecorderCore must not import a platform framework (sprecorder-mac-0002)` and `** BUILD FAILED **`.

Run: `rm SPRecorderCore/Planted.swift && xcodebuild build -scheme SPRecorderCore -destination 'platform=macOS' 2>&1 | grep -E "\*\* BUILD"`

Expected: `** BUILD SUCCEEDED **`. Do not continue until `Planted.swift` is gone — `git status --short SPRecorderCore` must not list it.

- [ ] **Step 11: Record the verification in `sprecorder-mac-0007`**

Append to the end of `docs/adr/sprecorder-mac-0007-one-xcode-project-two-targets.md`:

```markdown

---

## Amendment — 2026-09-10, measured. The test command works.

`xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS'` runs the
`SPRecorderCoreTests` suite, which is Swift Testing (`sprecorder-mac-0015`). Verified on
macOS 26.6.2 with Xcode 26.6, first in a throwaway copy while Plan 1 was written and again
when the project was created. `-only-testing:SPRecorderCoreTests/<SuiteName>` selects one suite.

How the project is built, so it is not rediscovered:

- The project file is hand-written, `objectVersion = 77`, with **folder-synchronized groups**:
  every file inside `SPRecorderCore/`, `SPRecorderApp/` or `SPRecorderCoreTests/` belongs to
  that target with no project-file edit. The `.xcodeproj` diff problem recorded above is
  therefore mostly confined to build settings.
- Both schemes are shared (`xcshareddata/xcschemes`), because `xcodebuild` on a fresh clone
  sees no schemes otherwise.
- The forbidden-import `grep` above lives in `scripts/forbid-core-platform-imports.sh` and runs
  as the Core target's first build phase. A planted `import AppKit` failed the build with the
  message above; removing it passed. `ENABLE_USER_SCRIPT_SANDBOXING = NO`, so the script may
  read the whole Core folder.
- Signing is ad-hoc (`CODE_SIGN_IDENTITY = "-"`) until `sprecorder-mac-0040`'s certificate exists.
```

- [ ] **Step 12: Commit**

```bash
git add SPRecorder.xcodeproj scripts/forbid-core-platform-imports.sh SPRecorderCore/Session/TrackFile.swift SPRecorderApp/AppDelegate.swift SPRecorderCoreTests/TrackFileTests.swift .gitignore docs/adr/sprecorder-mac-0007-one-xcode-project-two-targets.md
git commit -m "Create the Xcode project with the Core import guard

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -- SPRecorder.xcodeproj scripts/forbid-core-platform-imports.sh SPRecorderCore/Session/TrackFile.swift SPRecorderApp/AppDelegate.swift SPRecorderCoreTests/TrackFileTests.swift .gitignore docs/adr/sprecorder-mac-0007-one-xcode-project-two-targets.md
```

---

### Task 2: Run the build and the Core tests on GitHub for every push

**Files:**
- Create: `.github/workflows/tests.yml`

**Interfaces:**
- Consumes: the `SPRecorderApp` and `SPRecorderCore` schemes from Task 1.
- Produces: a check named **Tests / build-and-test** on every push and pull request.

- [ ] **Step 1: Write the workflow**

`.github/workflows/tests.yml`:

```yaml
# Builds both targets and runs the Core suite on a fresh Mac for every push
# (sprecorder-mac-0016). The Core suite is all fakes, so it needs no microphone,
# no screen and no permission (sprecorder-mac-0015).
name: Tests

on:
  push:
  pull_request:

jobs:
  build-and-test:
    runs-on: macos-26
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v5

      - name: Show the Xcode in use
        run: xcodebuild -version

      - name: Build the app (builds the Core first, with its import guard)
        run: xcodebuild build -project SPRecorder.xcodeproj -scheme SPRecorderApp -destination 'platform=macOS'

      - name: Run the Core tests
        run: xcodebuild test -project SPRecorder.xcodeproj -scheme SPRecorderCore -destination 'platform=macOS'
```

- [ ] **Step 2: Check the file parses**

Run: `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/tests.yml"); puts "yaml ok"'`

Expected: `yaml ok`

- [ ] **Step 3: Run locally exactly what the runner will run**

Run: `xcodebuild build -project SPRecorder.xcodeproj -scheme SPRecorderApp -destination 'platform=macOS' 2>&1 | grep -E "\*\* BUILD" && xcodebuild test -project SPRecorder.xcodeproj -scheme SPRecorderCore -destination 'platform=macOS' 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `** BUILD SUCCEEDED **`, then `✔ Test run with 1 test in 1 suite passed` and `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/tests.yml
git commit -m "Run the build and the Core tests on GitHub for every push

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -- .github/workflows/tests.yml
```

- [ ] **Step 5: Ask the user before pushing, then watch the run**

Do **not** push on your own. Ask the user. When they agree, run `git log origin/master..HEAD --oneline` and name any commit this plan did not make before pushing. After `git push`, run `gh run watch --repo ThodsaphonSonthiphin/SPRecorder.Mac --exit-status`.

Expected: the run ends `✓` with both steps green. If the runner's `xcodebuild -version` is not 26.x, stop and report it — `sprecorder-mac-0016` assumed Xcode 26.6 on `macos-26`.

---

### Task 3: The Diary — one logging seam, a file per day, seven days kept

**Files:**
- Create: `SPRecorderCore/Diary/Diary.swift`
- Create: `SPRecorderCore/Diary/DiaryFile.swift`
- Create: `SPRecorderCoreTests/Support/TestSupport.swift`
- Test: `SPRecorderCoreTests/DiaryTests.swift`
- Modify: `docs/adr/sprecorder-mac-0013-two-log-sinks-oslog-plus-a-file.md` (append amendment)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `public enum DiaryLevel: Int, Sendable, Comparable, CaseIterable { case debug, notice, warning, error; var name: String }`
  - `public enum DiaryCategory: String, Sendable, CaseIterable { case app = "App", settings = "Settings", recordingSession = "RecordingSession", systemTrack = "SystemTrack", micTrack = "MicTrack", hotkey = "Hotkey", permissions = "Permissions" }`
  - `public struct DiaryEntry: Sendable, Equatable { date: Date; level: DiaryLevel; category: DiaryCategory; message: String }`
  - `public protocol DiarySink: Sendable { func write(_ entry: DiaryEntry) }`
  - `public final class Diary: Sendable { init(sinks: [any DiarySink], debugEnabled: Bool = false, now: @escaping @Sendable () -> Date = { Date() }); func debug/notice/warning/error(_ category: DiaryCategory, _ message: String) }`
  - `public final class DiaryFile: DiarySink { static let keptDays = 7; init(directory: URL, timeZone: TimeZone = .current, now: Date = Date()); func fileURL(for date: Date) -> URL }` — line format `2026-09-10 14:30:05.000 [notice] RecordingSession: message`, file `2026-09-10.log`.
  - Test helpers: `final class RecordingDiarySink: DiarySink { var entries: [DiaryEntry]; func lines(_ level: DiaryLevel) -> [String] }`, `enum TestTime { static let bangkok: TimeZone; static func date(_ y, _ mo, _ d, _ h, _ mi, _ s = 0) -> Date }`, `func makeTemporaryDirectory() throws -> URL`.

- [ ] **Step 1: Write the test helpers**

`SPRecorderCoreTests/Support/TestSupport.swift`:

```swift
import Foundation
@testable import SPRecorderCore

/// Keeps every Diary entry in memory, so a test can assert the line a failure left behind
/// (sprecorder-mac-0015).
final class RecordingDiarySink: DiarySink, @unchecked Sendable {
    private let lock = NSLock()
    private var _entries: [DiaryEntry] = []

    var entries: [DiaryEntry] { lock.withLock { _entries } }

    func write(_ entry: DiaryEntry) { lock.withLock { _entries.append(entry) } }

    func lines(_ level: DiaryLevel) -> [String] {
        entries.filter { $0.level == level }.map(\.message)
    }
}

enum TestTime {
    static let bangkok = TimeZone(identifier: "Asia/Bangkok")!

    /// A wall-clock time in Bangkok.
    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = bangkok
        return c.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }
}

/// A fresh, empty folder under the system temporary directory.
func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("SPRecorderCoreTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
```

- [ ] **Step 2: Write the failing tests**

`SPRecorderCoreTests/DiaryTests.swift`:

```swift
import Foundation
import Testing
@testable import SPRecorderCore

struct DiaryTests {
    @Test func noticeWarningAndErrorAreAlwaysWritten() {
        let sink = RecordingDiarySink()
        let diary = Diary(sinks: [sink])
        diary.notice(.app, "a")
        diary.warning(.settings, "b")
        diary.error(.recordingSession, "c")
        #expect(sink.entries.map(\.level) == [.notice, .warning, .error])
        #expect(sink.entries.map(\.category) == [.app, .settings, .recordingSession])
        #expect(sink.entries.map(\.message) == ["a", "b", "c"])
    }

    @Test func debugIsOffByDefault() {
        let sink = RecordingDiarySink()
        Diary(sinks: [sink]).debug(.app, "hidden")
        #expect(sink.entries.isEmpty)

        let loud = RecordingDiarySink()
        Diary(sinks: [loud], debugEnabled: true).debug(.app, "shown")
        #expect(loud.lines(.debug) == ["shown"])
    }

    @Test func everySinkGetsEveryEntry() {
        let first = RecordingDiarySink(), second = RecordingDiarySink()
        Diary(sinks: [first, second]).notice(.hotkey, "both")
        #expect(first.entries == second.entries)
        #expect(first.entries.count == 1)
    }
}

struct DiaryFileTests {
    @Test func writesOneReadableLinePerEntryIntoTheDaysFile() throws {
        let dir = try makeTemporaryDirectory()
        let when = TestTime.date(2026, 9, 10, 14, 30, 5)
        let file = DiaryFile(directory: dir, timeZone: TestTime.bangkok, now: when)
        file.write(DiaryEntry(date: when, level: .notice, category: .recordingSession, message: "Recording Session started"))
        file.write(DiaryEntry(date: when, level: .error, category: .micTrack, message: "no sound"))

        let text = try String(contentsOf: dir.appendingPathComponent("2026-09-10.log"), encoding: .utf8)
        #expect(text == """
        2026-09-10 14:30:05.000 [notice] RecordingSession: Recording Session started
        2026-09-10 14:30:05.000 [error] MicTrack: no sound

        """)
    }

    @Test func aNewDayStartsANewFile() throws {
        let dir = try makeTemporaryDirectory()
        let evening = TestTime.date(2026, 9, 10, 23, 59, 59)
        let morning = TestTime.date(2026, 9, 11, 0, 0, 1)
        let file = DiaryFile(directory: dir, timeZone: TestTime.bangkok, now: evening)
        file.write(DiaryEntry(date: evening, level: .notice, category: .app, message: "late"))
        file.write(DiaryEntry(date: morning, level: .notice, category: .app, message: "early"))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("2026-09-10.log").path))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("2026-09-11.log").path))
    }

    @Test func keepsSevenDaysAndDeletesOlderFilesOnOpen() throws {
        let dir = try makeTemporaryDirectory()
        for day in 1...10 {
            let name = String(format: "2026-09-%02d.log", day)
            FileManager.default.createFile(atPath: dir.appendingPathComponent(name).path, contents: Data("x\n".utf8))
        }
        FileManager.default.createFile(atPath: dir.appendingPathComponent("notes.txt").path, contents: nil)

        _ = DiaryFile(directory: dir, timeZone: TestTime.bangkok, now: TestTime.date(2026, 9, 10, 9, 0))

        let left = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
        #expect(left == ["2026-09-04.log", "2026-09-05.log", "2026-09-06.log", "2026-09-07.log",
                         "2026-09-08.log", "2026-09-09.log", "2026-09-10.log", "notes.txt"])
    }

    @Test func deletesTheOldestFileWhenTheDayChanges() throws {
        let dir = try makeTemporaryDirectory()
        let opened = TestTime.date(2026, 9, 10, 23, 0)
        let file = DiaryFile(directory: dir, timeZone: TestTime.bangkok, now: opened)
        FileManager.default.createFile(atPath: dir.appendingPathComponent("2026-09-04.log").path, contents: nil)

        file.write(DiaryEntry(date: TestTime.date(2026, 9, 11, 0, 5), level: .notice, category: .app, message: "midnight"))

        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("2026-09-04.log").path))
    }

    @Test func appendsToAnExistingFileForToday() throws {
        let dir = try makeTemporaryDirectory()
        let when = TestTime.date(2026, 9, 10, 8, 0)
        let url = dir.appendingPathComponent("2026-09-10.log")
        try Data("earlier line\n".utf8).write(to: url)

        let file = DiaryFile(directory: dir, timeZone: TestTime.bangkok, now: when)
        file.write(DiaryEntry(date: when, level: .notice, category: .app, message: "after relaunch"))

        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.hasPrefix("earlier line\n"))
        #expect(text.hasSuffix("[notice] App: after relaunch\n"))
    }
}
```

- [ ] **Step 3: Run them to make sure they fail**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' -only-testing:SPRecorderCoreTests/DiaryTests -only-testing:SPRecorderCoreTests/DiaryFileTests 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `error: cannot find type 'DiaryEntry' in scope` (and similar for `DiarySink`, `DiaryLevel`) and `** TEST FAILED **`.

- [ ] **Step 4: Write the Diary**

`SPRecorderCore/Diary/Diary.swift`:

```swift
import Foundation

/// How serious a Diary line is (sprecorder-mac-0014). `notice` and above are always written;
/// `debug` only when switched on.
public enum DiaryLevel: Int, Sendable, Comparable, CaseIterable {
    case debug, notice, warning, error

    public var name: String {
        switch self {
        case .debug: "debug"
        case .notice: "notice"
        case .warning: "warning"
        case .error: "error"
        }
    }

    public static func < (lhs: DiaryLevel, rhs: DiaryLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Diary categories use the glossary's words, not class names (sprecorder-mac-0013).
public enum DiaryCategory: String, Sendable, CaseIterable {
    case app = "App"
    case settings = "Settings"
    case recordingSession = "RecordingSession"
    case systemTrack = "SystemTrack"
    case micTrack = "MicTrack"
    case hotkey = "Hotkey"
    case permissions = "Permissions"
}

public struct DiaryEntry: Sendable, Equatable {
    public let date: Date
    public let level: DiaryLevel
    public let category: DiaryCategory
    public let message: String

    public init(date: Date, level: DiaryLevel, category: DiaryCategory, message: String) {
        self.date = date
        self.level = level
        self.category = category
        self.message = message
    }
}

/// Somewhere Diary lines go: the Diary file, os_log, or a test's recorder.
public protocol DiarySink: Sendable {
    func write(_ entry: DiaryEntry)
}

/// The one logging seam every part of the app writes through (sprecorder-mac-0013).
/// No failure is silent: every catch writes a line here before doing anything else.
/// Never pass a captured keystroke to it, in any form (sprecorder-mac-0014).
public final class Diary: Sendable {
    private let sinks: [any DiarySink]
    private let now: @Sendable () -> Date
    private let debugEnabled: Bool

    public init(sinks: [any DiarySink], debugEnabled: Bool = false, now: @escaping @Sendable () -> Date = { Date() }) {
        self.sinks = sinks
        self.debugEnabled = debugEnabled
        self.now = now
    }

    public func debug(_ category: DiaryCategory, _ message: String) { write(.debug, category, message) }
    public func notice(_ category: DiaryCategory, _ message: String) { write(.notice, category, message) }
    public func warning(_ category: DiaryCategory, _ message: String) { write(.warning, category, message) }
    public func error(_ category: DiaryCategory, _ message: String) { write(.error, category, message) }

    private func write(_ level: DiaryLevel, _ category: DiaryCategory, _ message: String) {
        if level == .debug && !debugEnabled { return }
        let entry = DiaryEntry(date: now(), level: level, category: category, message: message)
        for sink in sinks { sink.write(entry) }
    }
}
```

`SPRecorderCore/Diary/DiaryFile.swift`:

```swift
import Foundation

/// The Diary on disk: one readable file per day, `2026-09-10.log`, in a directory the caller
/// chooses — `~/Library/Logs/SPRecorder` in the app, a temporary folder in tests
/// (sprecorder-mac-0018 needs the directory injected). Files older than seven days are
/// deleted when the Diary opens and whenever the day changes (sprecorder-mac-0014).
public final class DiaryFile: DiarySink, @unchecked Sendable {
    public static let keptDays = 7

    private let directory: URL
    private let calendar: Calendar
    private let lock = NSLock()
    private var openDay: String?
    private var handle: FileHandle?

    private let dayFormatter: DateFormatter
    private let lineFormatter: DateFormatter

    public init(directory: URL, timeZone: TimeZone = .current, now: Date = Date()) {
        self.directory = directory
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        dayFormatter = DiaryFile.formatter("yyyy-MM-dd", calendar)
        lineFormatter = DiaryFile.formatter("yyyy-MM-dd HH:mm:ss.SSS", calendar)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        lock.withLock { deleteOldFiles(today: now) }
    }

    deinit { try? handle?.close() }

    public func fileURL(for date: Date) -> URL {
        directory.appendingPathComponent(dayFormatter.string(from: date) + ".log")
    }

    public func write(_ entry: DiaryEntry) {
        let line = "\(lineFormatter.string(from: entry.date)) [\(entry.level.name)] \(entry.category.rawValue): \(entry.message)\n"
        lock.withLock {
            let day = dayFormatter.string(from: entry.date)
            if day != openDay {
                try? handle?.close()
                handle = nil
                openDay = day
                deleteOldFiles(today: entry.date)
                let url = fileURL(for: entry.date)
                if !FileManager.default.fileExists(atPath: url.path) {
                    FileManager.default.createFile(atPath: url.path, contents: nil)
                }
                handle = try? FileHandle(forWritingTo: url)
                _ = try? handle?.seekToEnd()
            }
            try? handle?.write(contentsOf: Data(line.utf8))
        }
    }

    /// Keeps today and the six days before it; deletes every older `yyyy-MM-dd.log`.
    private func deleteOldFiles(today: Date) {
        let startOfToday = calendar.startOfDay(for: today)
        guard let oldestKept = calendar.date(byAdding: .day, value: -(DiaryFile.keptDays - 1), to: startOfToday),
              let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        for name in names where name.hasSuffix(".log") {
            guard let day = dayFormatter.date(from: String(name.dropLast(4))) else { continue }
            if day < oldestKept {
                try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
            }
        }
    }

    private static func formatter(_ format: String, _ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = format
        return f
    }
}
```

- [ ] **Step 5: Run the tests to make sure they pass**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' -only-testing:SPRecorderCoreTests/DiaryTests -only-testing:SPRecorderCoreTests/DiaryFileTests 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `✔ Test run with 8 tests in 2 suites passed` and `** TEST SUCCEEDED **`.

- [ ] **Step 6: Record where the file sink lives in `sprecorder-mac-0013`**

Append to the end of `docs/adr/sprecorder-mac-0013-two-log-sinks-oslog-plus-a-file.md`:

```markdown

---

## Amendment — 2026-09-10. The file sink lives in the Core.

The Consequences above say the app target supplies both the `os_log` and the file
implementations. Plan 1 puts the **file sink (`DiaryFile`) in `SPRecorderCore`** and keeps only
the `os_log` sink (`OSLogSink`) in the app.

The reason that sentence gave — the Core may not import a platform framework — does not reach
the file sink, which is Foundation file I/O and passes the import guard of `sprecorder-mac-0007`.
And `sprecorder-mac-0018`'s leak test must read the Diary file that a faked Recording Session
wrote; the Core test target can do that only if the file sink is Core code. The seam is
unchanged: the Core declares `DiarySink`, and the directory is injected, as 0018 requires.
```

- [ ] **Step 7: Commit**

```bash
git add SPRecorderCore/Diary/Diary.swift SPRecorderCore/Diary/DiaryFile.swift SPRecorderCoreTests/Support/TestSupport.swift SPRecorderCoreTests/DiaryTests.swift docs/adr/sprecorder-mac-0013-two-log-sinks-oslog-plus-a-file.md
git commit -m "Add the Diary: one seam, a file per day, seven days kept

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -- SPRecorderCore/Diary/Diary.swift SPRecorderCore/Diary/DiaryFile.swift SPRecorderCoreTests/Support/TestSupport.swift SPRecorderCoreTests/DiaryTests.swift docs/adr/sprecorder-mac-0013-two-log-sinks-oslog-plus-a-file.md
```

---

### Task 4: The 26 settings, with the Windows validation carried over

**Files:**
- Create: `SPRecorderCore/Settings/AppSettings.swift`
- Test: `SPRecorderCoreTests/AppSettingsTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `public struct AppSettings: Codable, Equatable, Sendable` with `var` properties `outputDirectory, fileNamePattern, hotkey, quickMarkHotkey, markWithNoteHotkey, markerLogFormat: String`, `autoOpenMarkerReview: Bool`, `audioBitrateKbps: Int`, `microphoneDeviceId, systemAudioDeviceId: String`, `mixedFileEnabled: Bool`, `mixedFileFormat: String`, `mixedFileSampleRate: Int`, `promptForSessionName, autoDetectCallsEnabled: Bool`, `splitMode: String`, `splitTimeMinutes, splitSizeMb: Int`, `splitSystemTrack, splitMicTrack, splitMixedTrack, screenRecordingEnabled: Bool`, `screenFrameRate: Int`, `screenQuality: String`, `showMouseClicks, showKeystrokes: Bool`; JSON keys are the PascalCase Windows names; `static let defaultFileNamePattern = "{timestamp:yyyy-MM-dd EEE HH.mm}"`; `init()`; `func validated() -> AppSettings`; `func outputDirectoryURL(home: URL) -> URL`.

- [ ] **Step 1: Write the failing tests**

`SPRecorderCoreTests/AppSettingsTests.swift`:

```swift
import Foundation
import Testing
@testable import SPRecorderCore

struct AppSettingsTests {
    private func decode(_ json: String) throws -> AppSettings {
        try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    }

    @Test func defaultsFollowTheMacADRs() {
        let s = AppSettings()
        #expect(s.outputDirectory == "~/Movies/SPRecorder")                    // sprecorder-mac-0005
        #expect(s.fileNamePattern == "{timestamp:yyyy-MM-dd EEE HH.mm}")         // sprecorder-mac-0019
        #expect(s.hotkey == "Control+Option+R")
        #expect(s.quickMarkHotkey == "Control+Option+M")
        #expect(s.markWithNoteHotkey == "Control+Option+N")
        #expect(s.audioBitrateKbps == 64)                                         // research #6
        #expect(s.markerLogFormat == "Markdown")
        #expect(s.autoOpenMarkerReview == false)
        #expect(s.splitMode == "None")
        #expect(s.splitTimeMinutes == 30)
        #expect(s.splitSizeMb == 195)
        #expect(s.screenRecordingEnabled == false)
        #expect(s.screenFrameRate == 30)
        #expect(s.screenQuality == "Medium")
    }

    @Test func thereAreTwentySixSettingsWithTheWindowsKeyNames() throws {
        let data = try JSONEncoder().encode(AppSettings())
        let keys = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any]).keys.sorted()
        #expect(keys.count == 26)
        #expect(keys.contains("OutputDirectory"))
        #expect(keys.contains("SplitTimeMinutes"))
        #expect(keys.contains("AudioBitrateKbps"))
        #expect(!keys.contains("Mp3BitrateKbps"))
        #expect(!keys.contains("ScreenMonitorDeviceName"))                        // sprecorder-mac-0021
    }

    @Test func missingKeysTakeTheirDefaults() throws {
        let s = try decode(#"{ "SplitMode": "Time" }"#)
        var expected = AppSettings()
        expected.splitMode = "Time"
        #expect(s == expected)
    }

    @Test func aValueOfTheWrongTypeFallsBackForThatSettingOnly() throws {
        let s = try decode(#"{ "SplitTimeMinutes": "forty", "SplitSizeMb": 180 }"#)
        #expect(s.splitTimeMinutes == 30)
        #expect(s.splitSizeMb == 180)
    }

    @Test func unknownKeysAreIgnored() throws {
        let s = try decode(#"{ "Mp3BitrateKbps": 128, "ScreenMonitorDeviceName": "\\\\.\\DISPLAY2" }"#)
        #expect(s == AppSettings())
    }

    @Test func clampsAndFallsBackInvalidSplitFields() throws {
        let s = try decode(#"{ "SplitMode": "Garbage", "SplitTimeMinutes": 99999, "SplitSizeMb": 0 }"#).validated()
        #expect(s.splitMode == "None")
        #expect(s.splitTimeMinutes == 1440)
        #expect(s.splitSizeMb == 1)
    }

    @Test(arguments: [(99, 30), (0, 15), (20, 15), (24, 25), (28, 30), (25, 25)])
    func snapsTheFrameRateToFifteenTwentyFiveOrThirty(input: Int, expected: Int) {
        var s = AppSettings()
        s.screenFrameRate = input
        #expect(s.validated().screenFrameRate == expected)
    }

    @Test func unknownQualityAndMarkerFormatFallBack() throws {
        let s = try decode(#"{ "ScreenQuality": "ultra", "MarkerLogFormat": "yaml" }"#).validated()
        #expect(s.screenQuality == "Medium")
        #expect(s.markerLogFormat == "Markdown")
    }

    @Test func keepsValidChoices() throws {
        let s = try decode(#"{ "ScreenQuality": "High", "MarkerLogFormat": "Csv", "SplitMode": "Size" }"#).validated()
        #expect(s.screenQuality == "High")
        #expect(s.markerLogFormat == "Csv")
        #expect(s.splitMode == "Size")
    }

    @Test func aPatternWithoutTheTimestampFallsBackToTheDefault() {
        var s = AppSettings()
        s.fileNamePattern = "{timestamp:yyyy-MM-dd_HH-mm-ss}_{track}.mp3"
        #expect(s.validated().fileNamePattern == s.fileNamePattern)   // has {timestamp: keep
        s.fileNamePattern = "meeting"
        #expect(s.validated().fileNamePattern == AppSettings.defaultFileNamePattern)
    }

    @Test func outputDirectoryExpandsATildeAgainstTheGivenHome() {
        let home = URL(fileURLWithPath: "/Users/her", isDirectory: true)
        var s = AppSettings()
        #expect(s.outputDirectoryURL(home: home).path == "/Users/her/Movies/SPRecorder")
        s.outputDirectory = "/Volumes/Archive/Meetings"
        #expect(s.outputDirectoryURL(home: home).path == "/Volumes/Archive/Meetings")
        s.outputDirectory = "   "
        #expect(s.validated().outputDirectoryURL(home: home).path == "/Users/her/Movies/SPRecorder")
    }
}
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' -only-testing:SPRecorderCoreTests/AppSettingsTests 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `error: cannot find type 'AppSettings' in scope` and `** TEST FAILED **`.

- [ ] **Step 3: Write the settings type**

`SPRecorderCore/Settings/AppSettings.swift`:

```swift
import Foundation

/// The settings in `settings.json` (sprecorder-mac-0004). Keys keep the Windows `AppConfig`
/// names so a support conversation reads the same on both platforms, except where a Mac ADR
/// changed them: `OutputDirectory` (sprecorder-mac-0005), `FileNamePattern`
/// (sprecorder-mac-0019), the three hotkeys (Carbon, research #5), `AudioBitrateKbps`
/// (was `Mp3BitrateKbps`; AAC, research #6) and no `ScreenMonitorDeviceName`
/// (sprecorder-mac-0021). 26 settings.
public struct AppSettings: Codable, Equatable, Sendable {
    public var outputDirectory = "~/Movies/SPRecorder"
    public var fileNamePattern = AppSettings.defaultFileNamePattern
    public var hotkey = "Control+Option+R"
    public var quickMarkHotkey = "Control+Option+M"
    public var markWithNoteHotkey = "Control+Option+N"
    public var markerLogFormat = "Markdown"
    public var autoOpenMarkerReview = false
    public var audioBitrateKbps = 64
    public var microphoneDeviceId = ""
    public var systemAudioDeviceId = ""
    public var mixedFileEnabled = true
    public var mixedFileFormat = "Mono"
    public var mixedFileSampleRate = 44100
    public var promptForSessionName = false
    public var autoDetectCallsEnabled = false
    public var splitMode = "None"
    public var splitTimeMinutes = 30
    public var splitSizeMb = 195
    public var splitSystemTrack = true
    public var splitMicTrack = true
    public var splitMixedTrack = true
    public var screenRecordingEnabled = false
    public var screenFrameRate = 30
    public var screenQuality = "Medium"
    public var showMouseClicks = true
    public var showKeystrokes = true

    public static let defaultFileNamePattern = "{timestamp:yyyy-MM-dd EEE HH.mm}"

    public init() {}

    enum CodingKeys: String, CodingKey, CaseIterable {
        case outputDirectory = "OutputDirectory"
        case fileNamePattern = "FileNamePattern"
        case hotkey = "Hotkey"
        case quickMarkHotkey = "QuickMarkHotkey"
        case markWithNoteHotkey = "MarkWithNoteHotkey"
        case markerLogFormat = "MarkerLogFormat"
        case autoOpenMarkerReview = "AutoOpenMarkerReview"
        case audioBitrateKbps = "AudioBitrateKbps"
        case microphoneDeviceId = "MicrophoneDeviceId"
        case systemAudioDeviceId = "SystemAudioDeviceId"
        case mixedFileEnabled = "MixedFileEnabled"
        case mixedFileFormat = "MixedFileFormat"
        case mixedFileSampleRate = "MixedFileSampleRate"
        case promptForSessionName = "PromptForSessionName"
        case autoDetectCallsEnabled = "AutoDetectCallsEnabled"
        case splitMode = "SplitMode"
        case splitTimeMinutes = "SplitTimeMinutes"
        case splitSizeMb = "SplitSizeMb"
        case splitSystemTrack = "SplitSystemTrack"
        case splitMicTrack = "SplitMicTrack"
        case splitMixedTrack = "SplitMixedTrack"
        case screenRecordingEnabled = "ScreenRecordingEnabled"
        case screenFrameRate = "ScreenFrameRate"
        case screenQuality = "ScreenQuality"
        case showMouseClicks = "ShowMouseClicks"
        case showKeystrokes = "ShowKeystrokes"
    }

    /// A hand-edited file is the expected support path, so a missing key or a value of the
    /// wrong type falls back to that one setting's default instead of failing the whole file.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            ((try? c.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        outputDirectory = value(.outputDirectory, d.outputDirectory)
        fileNamePattern = value(.fileNamePattern, d.fileNamePattern)
        hotkey = value(.hotkey, d.hotkey)
        quickMarkHotkey = value(.quickMarkHotkey, d.quickMarkHotkey)
        markWithNoteHotkey = value(.markWithNoteHotkey, d.markWithNoteHotkey)
        markerLogFormat = value(.markerLogFormat, d.markerLogFormat)
        autoOpenMarkerReview = value(.autoOpenMarkerReview, d.autoOpenMarkerReview)
        audioBitrateKbps = value(.audioBitrateKbps, d.audioBitrateKbps)
        microphoneDeviceId = value(.microphoneDeviceId, d.microphoneDeviceId)
        systemAudioDeviceId = value(.systemAudioDeviceId, d.systemAudioDeviceId)
        mixedFileEnabled = value(.mixedFileEnabled, d.mixedFileEnabled)
        mixedFileFormat = value(.mixedFileFormat, d.mixedFileFormat)
        mixedFileSampleRate = value(.mixedFileSampleRate, d.mixedFileSampleRate)
        promptForSessionName = value(.promptForSessionName, d.promptForSessionName)
        autoDetectCallsEnabled = value(.autoDetectCallsEnabled, d.autoDetectCallsEnabled)
        splitMode = value(.splitMode, d.splitMode)
        splitTimeMinutes = value(.splitTimeMinutes, d.splitTimeMinutes)
        splitSizeMb = value(.splitSizeMb, d.splitSizeMb)
        splitSystemTrack = value(.splitSystemTrack, d.splitSystemTrack)
        splitMicTrack = value(.splitMicTrack, d.splitMicTrack)
        splitMixedTrack = value(.splitMixedTrack, d.splitMixedTrack)
        screenRecordingEnabled = value(.screenRecordingEnabled, d.screenRecordingEnabled)
        screenFrameRate = value(.screenFrameRate, d.screenFrameRate)
        screenQuality = value(.screenQuality, d.screenQuality)
        showMouseClicks = value(.showMouseClicks, d.showMouseClicks)
        showKeystrokes = value(.showKeystrokes, d.showKeystrokes)
    }

    /// The validation `AppConfig.Load` did on Windows, which must survive (sprecorder-mac-0004),
    /// plus the folder-name rule of sprecorder-mac-0019's correction.
    public func validated() -> AppSettings {
        var s = self
        if !["None", "Time", "Size"].contains(s.splitMode) { s.splitMode = "None" }
        s.splitTimeMinutes = min(max(s.splitTimeMinutes, 1), 1440)
        s.splitSizeMb = min(max(s.splitSizeMb, 1), 10000)
        s.screenFrameRate = AppSettings.nearestFrameRate(s.screenFrameRate)
        if !["Low", "Medium", "High"].contains(s.screenQuality) { s.screenQuality = "Medium" }
        if !["Markdown", "Csv"].contains(s.markerLogFormat) { s.markerLogFormat = "Markdown" }
        if !s.fileNamePattern.contains("{timestamp") { s.fileNamePattern = AppSettings.defaultFileNamePattern }
        if s.outputDirectory.trimmingCharacters(in: .whitespaces).isEmpty { s.outputDirectory = AppSettings().outputDirectory }
        return s
    }

    /// 15, 25 or 30; a tie goes to the lower rate, as on Windows.
    static func nearestFrameRate(_ fps: Int) -> Int {
        var best = 15
        for allowed in [15, 25, 30] where abs(allowed - fps) < abs(best - fps) { best = allowed }
        return best
    }

    /// The recordings folder as a URL. A plain path, never a bookmark (sprecorder-mac-0005);
    /// a leading `~` means the given home folder.
    public func outputDirectoryURL(home: URL) -> URL {
        if outputDirectory == "~" { return home }
        if outputDirectory.hasPrefix("~/") {
            return home.appendingPathComponent(String(outputDirectory.dropFirst(2)), isDirectory: true)
        }
        return URL(fileURLWithPath: outputDirectory, isDirectory: true)
    }
}
```

- [ ] **Step 4: Run the tests to make sure they pass**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' -only-testing:SPRecorderCoreTests/AppSettingsTests 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `✔ Test run with 11 tests in 1 suite passed` and `** TEST SUCCEEDED **`. (Swift Testing counts a parameterized test once.)

- [ ] **Step 5: Commit**

```bash
git add SPRecorderCore/Settings/AppSettings.swift SPRecorderCoreTests/AppSettingsTests.swift
git commit -m "Add the 26 settings with the Windows validation carried over

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -- SPRecorderCore/Settings/AppSettings.swift SPRecorderCoreTests/AppSettingsTests.swift
```

---

### Task 5: Read and write `settings.json`

**Files:**
- Create: `SPRecorderCore/Settings/SettingsStore.swift`
- Test: `SPRecorderCoreTests/SettingsStoreTests.swift`

**Interfaces:**
- Consumes: `AppSettings` (Task 4); `Diary`, `RecordingDiarySink`, `makeTemporaryDirectory()` (Task 3).
- Produces: `public final class SettingsStore: @unchecked Sendable { let fileURL: URL; var current: AppSettings { get }; init(fileURL: URL, diary: Diary); func save(_ settings: AppSettings) throws }`. A missing file is created with the defaults; unreadable JSON leaves the file untouched and uses the defaults with a warning; out-of-range values are corrected in memory with one warning and the file is not rewritten.

- [ ] **Step 1: Write the failing tests**

`SPRecorderCoreTests/SettingsStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import SPRecorderCore

struct SettingsStoreTests {
    @Test func aMissingFileIsCreatedWithTheDefaults() throws {
        let dir = try makeTemporaryDirectory()
        let url = dir.appendingPathComponent("SPRecorder/settings.json")
        let sink = RecordingDiarySink()

        let store = SettingsStore(fileURL: url, diary: Diary(sinks: [sink]))

        #expect(store.current == AppSettings())
        let onDisk = try JSONDecoder().decode(AppSettings.self, from: Data(contentsOf: url))
        #expect(onDisk == AppSettings())
        #expect(sink.lines(.notice).contains { $0.contains("created") })
    }

    @Test func theFileIsReadableJSONWithPlainSlashes() throws {
        let dir = try makeTemporaryDirectory()
        let url = dir.appendingPathComponent("settings.json")
        _ = SettingsStore(fileURL: url, diary: Diary(sinks: []))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains(#""OutputDirectory" : "~/Movies/SPRecorder""#))
        #expect(text.contains("\n"))
    }

    @Test func saveRoundTripsAndReplacesTheFileLeavingNoTemporaryFile() throws {
        let dir = try makeTemporaryDirectory()
        let url = dir.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url, diary: Diary(sinks: []))

        var changed = AppSettings()
        changed.outputDirectory = "/Volumes/Archive"
        changed.splitMode = "Size"
        changed.splitSizeMb = 180
        changed.splitSystemTrack = false
        try store.save(changed)

        #expect(store.current == changed)
        #expect(SettingsStore(fileURL: url, diary: Diary(sinks: [])).current == changed)
        #expect(!FileManager.default.fileExists(atPath: url.path + ".tmp"))
    }

    @Test func saveValidatesFirst() throws {
        let dir = try makeTemporaryDirectory()
        let store = SettingsStore(fileURL: dir.appendingPathComponent("settings.json"), diary: Diary(sinks: []))
        var wild = AppSettings()
        wild.splitTimeMinutes = 0
        try store.save(wild)
        #expect(store.current.splitTimeMinutes == 1)
    }

    @Test func outOfRangeValuesAreCorrectedInMemoryWithAWarning() throws {
        let dir = try makeTemporaryDirectory()
        let url = dir.appendingPathComponent("settings.json")
        try Data(#"{ "SplitSizeMb": 0 }"#.utf8).write(to: url)
        let sink = RecordingDiarySink()

        let store = SettingsStore(fileURL: url, diary: Diary(sinks: [sink]))

        #expect(store.current.splitSizeMb == 1)
        #expect(sink.lines(.warning).count == 1)
        #expect(try String(contentsOf: url, encoding: .utf8) == #"{ "SplitSizeMb": 0 }"#)   // her file is not rewritten
    }

    @Test func aFileThatIsNotJSONIsLeftAloneAndTheDefaultsAreUsed() throws {
        let dir = try makeTemporaryDirectory()
        let url = dir.appendingPathComponent("settings.json")
        try Data("{ this is not json".utf8).write(to: url)
        let sink = RecordingDiarySink()

        let store = SettingsStore(fileURL: url, diary: Diary(sinks: [sink]))

        #expect(store.current == AppSettings())
        #expect(try String(contentsOf: url, encoding: .utf8) == "{ this is not json")
        #expect(sink.lines(.warning).first?.contains("using the defaults") == true)
    }
}
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' -only-testing:SPRecorderCoreTests/SettingsStoreTests 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `error: cannot find 'SettingsStore' in scope` and `** TEST FAILED **`.

- [ ] **Step 3: Write the store**

`SPRecorderCore/Settings/SettingsStore.swift`:

```swift
import Foundation

/// Reads and writes `~/Library/Application Support/SPRecorder/settings.json`
/// (sprecorder-mac-0004). A rewrite of the Windows `AppConfigStore` (sprecorder-mac-0003).
public final class SettingsStore: @unchecked Sendable {
    public let fileURL: URL
    private let diary: Diary
    private let lock = NSLock()
    private var _current: AppSettings

    public var current: AppSettings { lock.withLock { _current } }

    /// Loads the file. A missing file is created with the defaults, so there is always a
    /// readable file to attach to a problem report. A file that is not JSON is left untouched
    /// and the defaults are used, with a warning in the Diary.
    public init(fileURL: URL, diary: Diary) {
        self.fileURL = fileURL
        self.diary = diary
        _current = AppSettings()

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            do {
                try write(AppSettings())
                diary.notice(.settings, "No settings file; created \(fileURL.path) with the defaults")
            } catch {
                diary.error(.settings, "Could not create \(fileURL.path): \(error.localizedDescription)")
            }
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode(AppSettings.self, from: data)
            let valid = loaded.validated()
            if valid != loaded {
                diary.warning(.settings, "Some settings in \(fileURL.lastPathComponent) were out of range and were corrected in memory")
            }
            _current = valid
        } catch {
            diary.warning(.settings, "Could not read \(fileURL.path), using the defaults: \(error.localizedDescription)")
        }
    }

    /// Validates, then writes atomically: a temporary file beside the real one, then
    /// `FileManager.replaceItemAt` (sprecorder-mac-0004).
    public func save(_ settings: AppSettings) throws {
        let valid = settings.validated()
        try write(valid)
        lock.withLock { _current = valid }
        diary.notice(.settings, "Settings saved")
    }

    private func write(_ settings: AppSettings) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(settings)
        let fm = FileManager.default
        try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temp = fileURL.deletingLastPathComponent().appendingPathComponent(fileURL.lastPathComponent + ".tmp")
        try data.write(to: temp)
        if fm.fileExists(atPath: fileURL.path) {
            _ = try fm.replaceItemAt(fileURL, withItemAt: temp)
        } else {
            try fm.moveItem(at: temp, to: fileURL)
        }
    }
}
```

- [ ] **Step 4: Run the tests to make sure they pass**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' -only-testing:SPRecorderCoreTests/SettingsStoreTests 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `✔ Test run with 6 tests in 1 suite passed` and `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add SPRecorderCore/Settings/SettingsStore.swift SPRecorderCoreTests/SettingsStoreTests.swift
git commit -m "Read and write settings.json, atomically, never losing her file

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -- SPRecorderCore/Settings/SettingsStore.swift SPRecorderCoreTests/SettingsStoreTests.swift
```

---

### Task 6: Name the Session folder

**Files:**
- Create: `SPRecorderCore/Session/SessionFolderName.swift`
- Test: `SPRecorderCoreTests/SessionFolderNameTests.swift`

**Interfaces:**
- Consumes: `AppSettings.defaultFileNamePattern` (Task 4); `TestTime`, `makeTemporaryDirectory()` (Task 3).
- Produces: `public enum SessionFolderName { static let defaultTimestampFormat = "yyyy-MM-dd EEE HH.mm"; static let maxBytes = 255; static func make(pattern: String, startedAt: Date, sessionName: String? = nil, timeZone: TimeZone = .current) -> String; static func sanitize(_ raw: String, maxBytes: Int = 255) -> String; static func uniqueFolderURL(in parent: URL, name: String, fileManager: FileManager = .default) -> URL }`.

- [ ] **Step 1: Write the failing tests**

`SPRecorderCoreTests/SessionFolderNameTests.swift`:

```swift
import Foundation
import Testing
@testable import SPRecorderCore

struct SessionFolderNameTests {
    let startedAt = TestTime.date(2026, 9, 10, 14, 30, 22)

    @Test func theDefaultPatternNamesTheFolderByDateWeekdayAndTime() {
        let name = SessionFolderName.make(pattern: AppSettings.defaultFileNamePattern, startedAt: startedAt, timeZone: TestTime.bangkok)
        #expect(name == "2026-09-10 Thu 14.30")
    }

    @Test func theYearIsGregorianAndTheWeekdayEnglishWhateverTheMacsRegion() {
        // The formatter is pinned, so this holds on a Mac set to Thailand (Buddhist year 2569).
        let name = SessionFolderName.make(pattern: "{timestamp:yyyy EEEE}", startedAt: startedAt, timeZone: TestTime.bangkok)
        #expect(name == "2026 Thursday")
    }

    @Test func aBareTimestampTokenUsesTheDefaultFormat() {
        #expect(SessionFolderName.make(pattern: "{timestamp}", startedAt: startedAt, timeZone: TestTime.bangkok) == "2026-09-10 Thu 14.30")
    }

    @Test func textAroundTheTokenIsKept() {
        #expect(SessionFolderName.make(pattern: "Meeting {timestamp:yyyy-MM-dd}", startedAt: startedAt, timeZone: TestTime.bangkok) == "Meeting 2026-09-10")
    }

    @Test func aSessionNameGoesAfterTheStamp() {
        let name = SessionFolderName.make(pattern: AppSettings.defaultFileNamePattern, startedAt: startedAt,
                                          sessionName: "  Team standup ", timeZone: TestTime.bangkok)
        #expect(name == "2026-09-10 Thu 14.30 — Team standup")
    }

    @Test func aBlankSessionNameAddsNothing() {
        let name = SessionFolderName.make(pattern: AppSettings.defaultFileNamePattern, startedAt: startedAt,
                                          sessionName: "   ", timeZone: TestTime.bangkok)
        #expect(name == "2026-09-10 Thu 14.30")
    }

    @Test func colonsInTheFormatNeverReachTheDisk() {
        #expect(SessionFolderName.make(pattern: "{timestamp:HH:mm}", startedAt: startedAt, timeZone: TestTime.bangkok) == "14-30")
    }

    @Test(arguments: [
        ("Q2 Planning", "Q2 Planning"),
        ("foo/bar:baz", "foo-bar-baz"),
        ("..hidden", "hidden"),
        ("trailing dots...", "trailing dots"),
        ("trailing space  ", "trailing space"),
        ("Bad<>|chars?", "Bad<>|chars?"),
    ])
    func sanitizeAppliesTheMacRules(input: String, expected: String) {
        #expect(SessionFolderName.sanitize(input) == expected)
    }

    @Test func sanitizeCapsAt255BytesWithoutSplittingACharacter() {
        let thai = String(repeating: "ประชุม", count: 20)          // 3 bytes per character
        let capped = SessionFolderName.sanitize(thai)
        #expect(capped.utf8.count <= 255)
        #expect(capped.utf8.count > 250)
        #expect(thai.hasPrefix(capped))
    }

    @Test func aFolderThatAlreadyExistsGetsANumber() throws {
        let parent = try makeTemporaryDirectory()
        let name = "2026-09-10 Thu 14.30"
        let first = SessionFolderName.uniqueFolderURL(in: parent, name: name)
        #expect(first.lastPathComponent == name)
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: false)

        let second = SessionFolderName.uniqueFolderURL(in: parent, name: name)
        #expect(second.lastPathComponent == "2026-09-10 Thu 14.30 (2)")
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: false)

        #expect(SessionFolderName.uniqueFolderURL(in: parent, name: name).lastPathComponent == "2026-09-10 Thu 14.30 (3)")
    }
}
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' -only-testing:SPRecorderCoreTests/SessionFolderNameTests 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `error: cannot find 'SessionFolderName' in scope` and `** TEST FAILED **`.

- [ ] **Step 3: Write the folder namer**

`SPRecorderCore/Session/SessionFolderName.swift`:

```swift
import Foundation

/// Names a Session folder (sprecorder-mac-0019): `2026-09-10 Thu 14.30`, or
/// `2026-09-10 Thu 14.30 — Team standup` for a Named session. The rewrite of the Windows
/// `FileNameBuilder` (sprecorder-mac-0003): ICU date letters, macOS character rules.
public enum SessionFolderName {
    public static let defaultTimestampFormat = "yyyy-MM-dd EEE HH.mm"
    public static let maxBytes = 255

    /// Fills `{timestamp:FORMAT}` (or `{timestamp}`) in `pattern`, appends ` — name` when a
    /// session name is given, and makes the result safe as one macOS folder name.
    public static func make(pattern: String, startedAt: Date, sessionName: String? = nil, timeZone: TimeZone = .current) -> String {
        let regex = /\{timestamp(?::([^}]+))?\}/
        var name = pattern.replacing(regex) { match in
            let format = match.output.1.map(String.init) ?? defaultTimestampFormat
            return formatter(format, timeZone).string(from: startedAt)
        }
        if let label = sessionName?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            name += " — " + label
        }
        let clean = sanitize(name)
        return clean.isEmpty ? formatter(defaultTimestampFormat, timeZone).string(from: startedAt) : clean
    }

    /// The macOS rule of sprecorder-mac-0019: `/` and `:` become `-`, leading dots are removed
    /// (a leading dot hides the folder), trailing spaces and dots are trimmed, and the name is
    /// capped at 255 UTF-8 bytes without cutting a character in half.
    public static func sanitize(_ raw: String, maxBytes: Int = SessionFolderName.maxBytes) -> String {
        var s = raw.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        while s.hasPrefix(".") { s.removeFirst() }
        s = capped(s, maxBytes)
        while let last = s.last, last == " " || last == "." { s.removeLast() }
        return s
    }

    /// The folder to create inside `parent`: `name`, or `name (2)`, `name (3)`… when a folder
    /// of that name already exists — Finder's own convention.
    public static func uniqueFolderURL(in parent: URL, name: String, fileManager: FileManager = .default) -> URL {
        var candidate = parent.appendingPathComponent(name, isDirectory: true)
        var n = 2
        while fileManager.fileExists(atPath: candidate.path) {
            let suffix = " (\(n))"
            let base = sanitize(name, maxBytes: maxBytes - suffix.utf8.count)
            candidate = parent.appendingPathComponent(base + suffix, isDirectory: true)
            n += 1
        }
        return candidate
    }

    private static func capped(_ s: String, _ maxBytes: Int) -> String {
        guard s.utf8.count > maxBytes else { return s }
        var out = ""
        var bytes = 0
        for ch in s {
            let size = String(ch).utf8.count
            if bytes + size > maxBytes { break }
            out.append(ch)
            bytes += size
        }
        return out
    }

    /// Pinned to en_US_POSIX and the Gregorian calendar: a Mac set to Thailand would otherwise
    /// write the Buddhist year, 2569 (sprecorder-mac-0019).
    private static func formatter(_ format: String, _ timeZone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = timeZone
        f.dateFormat = format
        return f
    }
}
```

- [ ] **Step 4: Run the tests to make sure they pass**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' -only-testing:SPRecorderCoreTests/SessionFolderNameTests 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `✔ Test run with 10 tests in 1 suite passed` and `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add SPRecorderCore/Session/SessionFolderName.swift SPRecorderCoreTests/SessionFolderNameTests.swift
git commit -m "Name each Session folder for when it started

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -- SPRecorderCore/Session/SessionFolderName.swift SPRecorderCoreTests/SessionFolderNameTests.swift
```

---

### Task 7: Read a hotkey from its text

**Files:**
- Create: `SPRecorderCore/Hotkey/HotkeySpec.swift`
- Test: `SPRecorderCoreTests/HotkeySpecTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `public struct HotkeySpec: Equatable, Hashable, Sendable { struct Modifiers: OptionSet { .control, .option, .shift, .command }; enum ParseError: Error, Equatable, CustomStringConvertible { case empty, unknownToken(String), noKey, moreThanOneKey, needsControlOrCommand }; let modifiers: Modifiers; let key: String; init(modifiers:key:); static func parse(_ text: String) throws -> HotkeySpec; var displayString: String; var macVirtualKeyCode: UInt32; var macModifierFlags: UInt32; static let keyCodes: [String: UInt32] }`.

- [ ] **Step 1: Write the failing tests**

`SPRecorderCoreTests/HotkeySpecTests.swift`:

```swift
import Testing
@testable import SPRecorderCore

struct HotkeySpecTests {
    @Test func parsesTheDefaultStartStopHotkey() throws {
        let spec = try HotkeySpec.parse("Control+Option+R")
        #expect(spec.modifiers == [.control, .option])
        #expect(spec.key == "R")
        #expect(spec.displayString == "⌃⌥R")
    }

    @Test func acceptsAliasesAnyCaseAndSpaces() throws {
        #expect(try HotkeySpec.parse("ctrl + alt + m") == HotkeySpec(modifiers: [.control, .option], key: "M"))
        #expect(try HotkeySpec.parse("Cmd+Shift+F5") == HotkeySpec(modifiers: [.command, .shift], key: "F5"))
        #expect(try HotkeySpec.parse("Opt+Control+7").displayString == "⌃⌥7")
    }

    @Test func displaysModifiersInMacOrder() throws {
        #expect(try HotkeySpec.parse("Command+Shift+Option+Control+K").displayString == "⌃⌥⇧⌘K")
    }

    @Test(arguments: [
        ("", HotkeySpec.ParseError.empty),
        ("Control+Option", .noKey),
        ("Control+R+M", .moreThanOneKey),
        ("Control+Enter", .unknownToken("Enter")),
        ("Option+Shift+R", .needsControlOrCommand),
        ("R", .needsControlOrCommand),
    ])
    func rejectsWhatCarbonCannotRegister(text: String, error: HotkeySpec.ParseError) {
        #expect(throws: error) { try HotkeySpec.parse(text) }
    }

    @Test func producesCarbonKeyCodesAndModifierFlags() throws {
        let r = try HotkeySpec.parse("Control+Option+R")
        #expect(r.macVirtualKeyCode == 0x0F)            // kVK_ANSI_R
        #expect(r.macModifierFlags == 0x1000 | 0x0800)  // controlKey | optionKey
        #expect(try HotkeySpec.parse("Control+Option+M").macVirtualKeyCode == 0x2E)
        #expect(try HotkeySpec.parse("Control+Option+N").macVirtualKeyCode == 0x2D)
        #expect(try HotkeySpec.parse("Command+Shift+A").macModifierFlags == 0x0100 | 0x0200)
    }

    @Test func everyLetterDigitAndFunctionKeyHasACode() {
        let letters = (UInt8(ascii: "A")...UInt8(ascii: "Z")).map { String(UnicodeScalar($0)) }
        let digits = (0...9).map(String.init)
        let functionKeys = (1...12).map { "F\($0)" }
        #expect(Set(HotkeySpec.keyCodes.keys) == Set(letters + digits + functionKeys))
        #expect(Set(HotkeySpec.keyCodes.values).count == 48)   // no two keys share a code
    }
}
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' -only-testing:SPRecorderCoreTests/HotkeySpecTests 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `error: cannot find 'HotkeySpec' in scope` and `** TEST FAILED **`.

- [ ] **Step 3: Write the hotkey text type**

`SPRecorderCore/Hotkey/HotkeySpec.swift`. The numbers were checked against the macOS 26 SDK's Carbon headers: all 48 key codes and the four modifier flags match.

```swift
import Foundation

/// A global hotkey as written in `settings.json`, e.g. `Control+Option+R`, shown as `⌃⌥R`.
/// Replaces the dropped Windows `HotkeyParser` (sprecorder-mac-0003). The numbers it produces
/// are the values Carbon's `RegisterEventHotKey` takes (research #5); they are plain numbers
/// here so the Core never imports Carbon (sprecorder-mac-0002).
public struct HotkeySpec: Equatable, Hashable, Sendable {
    public struct Modifiers: OptionSet, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    public enum ParseError: Error, Equatable, CustomStringConvertible {
        case empty
        case unknownToken(String)
        case noKey
        case moreThanOneKey
        case needsControlOrCommand

        public var description: String {
            switch self {
            case .empty: "The hotkey is empty."
            case .unknownToken(let t): "“\(t)” is not a key SPRecorder knows."
            case .noKey: "The hotkey has no key, only modifiers."
            case .moreThanOneKey: "The hotkey has more than one key."
            case .needsControlOrCommand: "The hotkey must include Control or Command."
            }
        }
    }

    public let modifiers: Modifiers
    /// One of `HotkeySpec.keyCodes`' keys: `A`–`Z`, `0`–`9`, `F1`–`F12`.
    public let key: String

    public init(modifiers: Modifiers, key: String) {
        self.modifiers = modifiers
        self.key = key
    }

    /// Case-insensitive, `+`-separated. Accepts `Control`/`Ctrl`, `Option`/`Opt`/`Alt`,
    /// `Shift`, `Command`/`Cmd`. Carbon refuses combinations of only Option and Shift
    /// (research #5), so Control or Command is required.
    public static func parse(_ text: String) throws -> HotkeySpec {
        let tokens = text.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !tokens.isEmpty else { throw ParseError.empty }
        var modifiers: Modifiers = []
        var key: String?
        for token in tokens {
            switch token.lowercased() {
            case "control", "ctrl": modifiers.insert(.control)
            case "option", "opt", "alt": modifiers.insert(.option)
            case "shift": modifiers.insert(.shift)
            case "command", "cmd": modifiers.insert(.command)
            default:
                let upper = token.uppercased()
                guard keyCodes[upper] != nil else { throw ParseError.unknownToken(token) }
                guard key == nil else { throw ParseError.moreThanOneKey }
                key = upper
            }
        }
        guard let key else { throw ParseError.noKey }
        guard modifiers.contains(.control) || modifiers.contains(.command) else { throw ParseError.needsControlOrCommand }
        return HotkeySpec(modifiers: modifiers, key: key)
    }

    /// `⌃⌥⇧⌘` order, as macOS menus show it.
    public var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + key
    }

    /// Carbon virtual key code (`kVK_ANSI_R` is 0x0F).
    public var macVirtualKeyCode: UInt32 { HotkeySpec.keyCodes[key]! }

    /// Carbon modifier flags: `cmdKey` 0x0100, `shiftKey` 0x0200, `optionKey` 0x0800, `controlKey` 0x1000.
    public var macModifierFlags: UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.command) { flags |= 0x0100 }
        if modifiers.contains(.shift) { flags |= 0x0200 }
        if modifiers.contains(.option) { flags |= 0x0800 }
        if modifiers.contains(.control) { flags |= 0x1000 }
        return flags
    }

    /// The keys a hotkey may use, with their Carbon `kVK_*` codes (Events.h, HIToolbox).
    public static let keyCodes: [String: UInt32] = [
        "A": 0x00, "S": 0x01, "D": 0x02, "F": 0x03, "H": 0x04, "G": 0x05, "Z": 0x06, "X": 0x07,
        "C": 0x08, "V": 0x09, "B": 0x0B, "Q": 0x0C, "W": 0x0D, "E": 0x0E, "R": 0x0F, "Y": 0x10,
        "T": 0x11, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17, "9": 0x19,
        "7": 0x1A, "8": 0x1C, "0": 0x1D, "O": 0x1F, "U": 0x20, "I": 0x22, "P": 0x23, "L": 0x25,
        "J": 0x26, "K": 0x28, "N": 0x2D, "M": 0x2E,
        "F1": 0x7A, "F2": 0x78, "F3": 0x63, "F4": 0x76, "F5": 0x60, "F6": 0x61, "F7": 0x62, "F8": 0x64,
        "F9": 0x65, "F10": 0x6D, "F11": 0x67, "F12": 0x6F,
    ]
}
```

- [ ] **Step 4: Run the tests to make sure they pass**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' -only-testing:SPRecorderCoreTests/HotkeySpecTests 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `✔ Test run with 6 tests in 1 suite passed` and `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add SPRecorderCore/Hotkey/HotkeySpec.swift SPRecorderCoreTests/HotkeySpecTests.swift
git commit -m "Read a hotkey such as Control+Option+R from settings

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -- SPRecorderCore/Hotkey/HotkeySpec.swift SPRecorderCoreTests/HotkeySpecTests.swift
```

---

### Task 8: The Recording Session, run whole against a fake

**Files:**
- Create: `SPRecorderCore/Session/AudioCapturing.swift`
- Create: `SPRecorderCore/Session/RecordingSession.swift`
- Create: `SPRecorderCoreTests/Support/FakeAudioCapture.swift`
- Test: `SPRecorderCoreTests/RecordingSessionTests.swift`

**Interfaces:**
- Consumes: `AppSettings` (Task 4), `Diary` (Task 3), `SessionFolderName` (Task 6), `TrackFile` (Task 1); test helpers from Task 3.
- Produces:
  - `public enum CaptureError: Error, Equatable, Sendable { case microphoneNotAllowed, computerAudioNotAllowed, failed(String); init(_ error: any Error); var plainWords: String }`
  - `public protocol AudioCapturing: AnyObject, Sendable { func start(systemTrack: URL, micTrack: URL, onInterrupted: @escaping @Sendable (CaptureError) -> Void) async throws; func stop() async throws }`
  - `@MainActor public final class RecordingSession { enum State: Equatable, Sendable { case idle, starting, recording(folder: URL, startedAt: Date), stopping }; private(set) var state: State; var onStateChange: ((State) -> Void)?; var onFailure: ((String) -> Void)?; init(settings: @escaping () -> AppSettings, capture: any AudioCapturing, diary: Diary, home: URL, now: @escaping () -> Date = { Date() }, timeZone: TimeZone = .current); func toggle() async; func start() async; func stop() async }`

- [ ] **Step 1: Write the fake**

`SPRecorderCoreTests/Support/FakeAudioCapture.swift`:

```swift
import Foundation
@testable import SPRecorderCore

/// Stands in for ScreenCaptureKit in tests (sprecorder-mac-0015). Writes a placeholder file per
/// track on start, so the session can be checked against a real folder, and can be told to
/// fail, to hold `start` open, or to stop by itself.
@MainActor
final class FakeAudioCapture: AudioCapturing {
    var startError: CaptureError?
    var stopError: CaptureError?
    /// When true, `start` waits until `releaseStart()` is called.
    var holdStart = false

    private(set) var startCalls: [(systemTrack: URL, micTrack: URL)] = []
    private(set) var stopCalls = 0
    private var onInterrupted: (@Sendable (CaptureError) -> Void)?
    private var heldStart: CheckedContinuation<Void, Never>?

    func start(systemTrack: URL, micTrack: URL, onInterrupted: @escaping @Sendable (CaptureError) -> Void) async throws {
        startCalls.append((systemTrack, micTrack))
        if holdStart {
            await withCheckedContinuation { heldStart = $0 }
        }
        if let startError { throw startError }
        FileManager.default.createFile(atPath: systemTrack.path, contents: Data("system".utf8))
        FileManager.default.createFile(atPath: micTrack.path, contents: Data("mic".utf8))
        self.onInterrupted = onInterrupted
    }

    func stop() async throws {
        stopCalls += 1
        if let stopError { throw stopError }
    }

    func releaseStart() {
        heldStart?.resume()
        heldStart = nil
    }

    var isHoldingStart: Bool { heldStart != nil }

    /// Simulates the capture stopping by itself mid-session.
    func interrupt(_ reason: CaptureError) {
        onInterrupted?(reason)
    }
}
```

- [ ] **Step 2: Write the failing tests**

`SPRecorderCoreTests/RecordingSessionTests.swift`. Every failure path asserts its Diary line, as `sprecorder-mac-0015` requires.

```swift
import Foundation
import Testing
@testable import SPRecorderCore

@MainActor
struct RecordingSessionTests {
    let home: URL
    let sink = RecordingDiarySink()
    let capture = FakeAudioCapture()
    var clock = TestTime.date(2026, 9, 10, 14, 30, 5)

    init() throws {
        home = try makeTemporaryDirectory()
    }

    func makeSession(settings: AppSettings = AppSettings(), clock: @escaping () -> Date) -> RecordingSession {
        RecordingSession(settings: { settings }, capture: capture, diary: Diary(sinks: [sink]), home: home,
                         now: clock, timeZone: TestTime.bangkok)
    }

    var recordings: URL { home.appendingPathComponent("Movies/SPRecorder", isDirectory: true) }

    @Test func startCreatesTheSessionFolderAndRecordsBothTracksIntoIt() async throws {
        let session = makeSession { clock }
        await session.start()

        let folder = recordings.appendingPathComponent("2026-09-10 Thu 14.30", isDirectory: true)
        #expect(session.state == .recording(folder: folder, startedAt: clock))
        #expect(capture.startCalls.count == 1)
        #expect(capture.startCalls.first?.systemTrack == folder.appendingPathComponent("Computer audio.m4a"))
        #expect(capture.startCalls.first?.micTrack == folder.appendingPathComponent("My microphone.m4a"))
        #expect(sink.lines(.notice) == ["Recording Session started: \(folder.path)"])
    }

    @Test func stopFinishesCaptureAndReturnsToIdle() async throws {
        var now = clock
        let session = makeSession { now }
        await session.start()
        now = now.addingTimeInterval(95)
        await session.stop()

        #expect(session.state == .idle)
        #expect(capture.stopCalls == 1)
        let folder = recordings.appendingPathComponent("2026-09-10 Thu 14.30")
        #expect(sink.lines(.notice).last == "Recording Session stopped after 0:01:35: \(folder.path)")
        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("Computer audio.m4a").path))
    }

    @Test func toggleStartsThenStops() async {
        let session = makeSession { clock }
        await session.toggle()
        #expect(capture.startCalls.count == 1)
        await session.toggle()
        #expect(capture.stopCalls == 1)
        #expect(session.state == .idle)
    }

    @Test func aSecondSessionInTheSameMinuteGetsItsOwnFolder() async {
        let session = makeSession { clock }
        await session.start()
        await session.stop()
        await session.start()

        guard case let .recording(folder, _) = session.state else {
            Issue.record("not recording")
            return
        }
        #expect(folder.lastPathComponent == "2026-09-10 Thu 14.30 (2)")
    }

    @Test func theRecordingsFolderComesFromSettings() async {
        var settings = AppSettings()
        settings.outputDirectory = home.appendingPathComponent("Elsewhere").path
        settings.fileNamePattern = "Call {timestamp:yyyy-MM-dd HH.mm}"
        let session = makeSession(settings: settings) { clock }
        await session.start()

        #expect(capture.startCalls.first?.micTrack.path == home.appendingPathComponent("Elsewhere/Call 2026-09-10 14.30/My microphone.m4a").path)
    }

    @Test func aRefusedPermissionLeavesNoFolderALineInTheDiaryAndPlainWords() async throws {
        capture.startError = .computerAudioNotAllowed
        var failures: [String] = []
        let session = makeSession { clock }
        session.onFailure = { failures.append($0) }

        await session.start()

        #expect(session.state == .idle)
        #expect(try FileManager.default.contentsOfDirectory(atPath: recordings.path).isEmpty)
        #expect(sink.lines(.error) == ["Recording Session could not start (2026-09-10 Thu 14.30): SPRecorder is not allowed to record computer audio."])
        #expect(failures == ["Not recording. SPRecorder is not allowed to record computer audio."])
    }

    @Test func aFolderThatCannotBeCreatedIsReported() async throws {
        let blocker = home.appendingPathComponent("Movies")
        FileManager.default.createFile(atPath: blocker.path, contents: nil)   // a file where the folder should be
        var failures: [String] = []
        let session = makeSession { clock }
        session.onFailure = { failures.append($0) }

        await session.start()

        #expect(session.state == .idle)
        #expect(capture.startCalls.isEmpty)
        #expect(sink.lines(.error).count == 1)
        #expect(failures.first?.hasPrefix("Not recording. Could not create a folder in") == true)
    }

    @Test func aStopThatFailsIsLoggedAndStillEndsTheSession() async {
        capture.stopError = .failed("The Mic track could not be finished.")
        var failures: [String] = []
        let session = makeSession { clock }
        session.onFailure = { failures.append($0) }
        await session.start()
        await session.stop()

        #expect(session.state == .idle)
        #expect(sink.lines(.error) == ["Recording Session did not finish cleanly (2026-09-10 Thu 14.30): The Mic track could not be finished."])
        #expect(failures == ["The recording did not finish cleanly. The Mic track could not be finished."])
    }

    @Test func captureThatStopsByItselfEndsTheSessionWithADiaryLine() async {
        var failures: [String] = []
        let session = makeSession { clock }
        session.onFailure = { failures.append($0) }
        await session.start()

        capture.interrupt(.failed("The audio stream stopped."))
        for _ in 0..<50 where session.state != .idle { await Task.yield() }

        #expect(session.state == .idle)
        #expect(capture.stopCalls == 1)
        #expect(sink.lines(.error) == ["Capture stopped by itself during the Recording Session (2026-09-10 Thu 14.30): The audio stream stopped."])
        #expect(failures == ["Recording stopped by itself. The audio stream stopped."])
    }

    @Test func aSecondPressWhileStartingIsIgnored() async {
        capture.holdStart = true
        let session = makeSession { clock }
        let first = Task { await session.toggle() }
        for _ in 0..<50 where !capture.isHoldingStart { await Task.yield() }
        #expect(session.state == .starting)

        await session.toggle()          // pressed again while macOS is still asking
        #expect(capture.startCalls.count == 1)
        #expect(capture.stopCalls == 0)

        capture.releaseStart()
        await first.value
        #expect(capture.startCalls.count == 1)
        guard case .recording = session.state else {
            Issue.record("expected recording, got \(session.state)")
            return
        }
    }

    @Test func everyStateChangeIsReported() async {
        var seen: [RecordingSession.State] = []
        let session = makeSession { clock }
        session.onStateChange = { seen.append($0) }
        await session.start()
        await session.stop()
        let folder = recordings.appendingPathComponent("2026-09-10 Thu 14.30", isDirectory: true)
        #expect(seen == [.starting, .recording(folder: folder, startedAt: clock), .stopping, .idle])
    }
}
```

- [ ] **Step 3: Run them to make sure they fail**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' -only-testing:SPRecorderCoreTests/RecordingSessionTests 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `error: cannot find type 'AudioCapturing' in scope`, `error: cannot find type 'CaptureError' in scope` and `** TEST FAILED **`.

- [ ] **Step 4: Write the capture seam**

`SPRecorderCore/Session/AudioCapturing.swift`:

```swift
import Foundation

/// Why capture could not start, or stopped. The adapter translates platform errors into these,
/// so the Core can name the problem in plain words without knowing any platform framework.
public enum CaptureError: Error, Equatable, Sendable {
    case microphoneNotAllowed
    case computerAudioNotAllowed
    case failed(String)

    public init(_ error: any Error) {
        self = (error as? CaptureError) ?? .failed(error.localizedDescription)
    }

    public var plainWords: String {
        switch self {
        case .microphoneNotAllowed: "SPRecorder is not allowed to use the microphone."
        case .computerAudioNotAllowed: "SPRecorder is not allowed to record computer audio."
        case .failed(let detail): detail
        }
    }
}

/// What a Recording Session needs from the platform to record the System track and the
/// Mic track (sprecorder-mac-0002). The app implements it with ScreenCaptureKit (research #3);
/// tests implement it with a fake (sprecorder-mac-0015).
public protocol AudioCapturing: AnyObject, Sendable {
    /// Begins writing computer audio to `systemTrack` and the microphone to `micTrack`.
    /// Throws a `CaptureError` when capture cannot begin. `onInterrupted` is called at most
    /// once if capture stops by itself after starting.
    func start(systemTrack: URL, micTrack: URL, onInterrupted: @escaping @Sendable (CaptureError) -> Void) async throws

    /// Stops capture and finishes both files.
    func stop() async throws
}
```

- [ ] **Step 5: Write the orchestrator**

`SPRecorderCore/Session/RecordingSession.swift`:

```swift
import Foundation

/// One start-to-stop capture (glossary: Recording Session). Plan 1 records the System track
/// and the Mic track into a Session folder; later plans add the Mixed file, Markers and the
/// Screen recording. It builds nothing itself: capture is injected (sprecorder-mac-0002), so
/// the whole flow runs against a fake (sprecorder-mac-0015).
@MainActor
public final class RecordingSession {
    public enum State: Equatable, Sendable {
        case idle
        case starting
        case recording(folder: URL, startedAt: Date)
        case stopping
    }

    public private(set) var state: State = .idle {
        didSet { onStateChange?(state) }
    }

    /// Called on every state change.
    public var onStateChange: ((State) -> Void)?
    /// Called with a plain-words sentence when a session fails to start, stops by itself,
    /// or does not finish cleanly. The Diary already has the line when this is called.
    public var onFailure: ((String) -> Void)?

    private let settings: () -> AppSettings
    private let capture: any AudioCapturing
    private let diary: Diary
    private let home: URL
    private let now: () -> Date
    private let timeZone: TimeZone

    public init(settings: @escaping () -> AppSettings, capture: any AudioCapturing, diary: Diary, home: URL,
                now: @escaping () -> Date = { Date() }, timeZone: TimeZone = .current) {
        self.settings = settings
        self.capture = capture
        self.diary = diary
        self.home = home
        self.now = now
        self.timeZone = timeZone
    }

    /// What the start/stop hotkey does. A press while starting or stopping is ignored.
    public func toggle() async {
        switch state {
        case .idle: await start()
        case .recording: await stop()
        case .starting, .stopping:
            diary.notice(.recordingSession, "Start/stop pressed while \(state == .starting ? "starting" : "stopping"); ignored")
        }
    }

    public func start() async {
        guard state == .idle else { return }
        state = .starting
        let current = settings()
        let startedAt = now()
        let parent = current.outputDirectoryURL(home: home)
        let fm = FileManager.default

        let folder: URL
        do {
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
            let name = SessionFolderName.make(pattern: current.fileNamePattern, startedAt: startedAt, timeZone: timeZone)
            folder = SessionFolderName.uniqueFolderURL(in: parent, name: name, fileManager: fm)
            try fm.createDirectory(at: folder, withIntermediateDirectories: false)
        } catch {
            diary.error(.recordingSession, "Could not create a Session folder in \(parent.path): \(error.localizedDescription)")
            state = .idle
            onFailure?("Not recording. Could not create a folder in \(parent.path).")
            return
        }

        do {
            try await capture.start(systemTrack: TrackFile.systemTrack.url(in: folder),
                                    micTrack: TrackFile.micTrack.url(in: folder),
                                    onInterrupted: { [weak self] reason in
                                        Task { @MainActor in await self?.captureInterrupted(reason) }
                                    })
        } catch {
            let reason = CaptureError(error)
            diary.error(.recordingSession, "Recording Session could not start (\(folder.lastPathComponent)): \(reason.plainWords)")
            removeIfEmpty(folder)
            state = .idle
            onFailure?("Not recording. \(reason.plainWords)")
            return
        }

        diary.notice(.recordingSession, "Recording Session started: \(folder.path)")
        state = .recording(folder: folder, startedAt: startedAt)
    }

    public func stop() async {
        guard case let .recording(folder, startedAt) = state else { return }
        state = .stopping
        do {
            try await capture.stop()
            diary.notice(.recordingSession, "Recording Session stopped after \(Self.duration(from: startedAt, to: now())): \(folder.path)")
        } catch {
            let reason = CaptureError(error)
            diary.error(.recordingSession, "Recording Session did not finish cleanly (\(folder.lastPathComponent)): \(reason.plainWords)")
            onFailure?("The recording did not finish cleanly. \(reason.plainWords)")
        }
        state = .idle
    }

    private func captureInterrupted(_ reason: CaptureError) async {
        guard case let .recording(folder, _) = state else { return }
        diary.error(.recordingSession, "Capture stopped by itself during the Recording Session (\(folder.lastPathComponent)): \(reason.plainWords)")
        onFailure?("Recording stopped by itself. \(reason.plainWords)")
        await stop()
    }

    private func removeIfEmpty(_ folder: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: folder.path), contents.isEmpty else {
            diary.warning(.recordingSession, "Left \(folder.path) in place because it is not empty")
            return
        }
        do {
            try fm.removeItem(at: folder)
        } catch {
            diary.warning(.recordingSession, "Could not remove the empty folder \(folder.path): \(error.localizedDescription)")
        }
    }

    /// `h:mm:ss`
    static func duration(from start: Date, to end: Date) -> String {
        let total = max(0, Int(end.timeIntervalSince(start).rounded()))
        return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }
}
```

- [ ] **Step 6: Run the tests to make sure they pass**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' -only-testing:SPRecorderCoreTests/RecordingSessionTests 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `✔ Test run with 11 tests in 1 suite passed` and `** TEST SUCCEEDED **`.

- [ ] **Step 7: Run the whole Core suite**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `✔ Test run with 53 tests in 8 suites passed` and `** TEST SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add SPRecorderCore/Session/AudioCapturing.swift SPRecorderCore/Session/RecordingSession.swift SPRecorderCoreTests/Support/FakeAudioCapture.swift SPRecorderCoreTests/RecordingSessionTests.swift
git commit -m "Run a whole Recording Session against a fake capture

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -- SPRecorderCore/Session/AudioCapturing.swift SPRecorderCore/Session/RecordingSession.swift SPRecorderCoreTests/Support/FakeAudioCapture.swift SPRecorderCoreTests/RecordingSessionTests.swift
```

---

### Task 9: Capture computer audio and the microphone with ScreenCaptureKit

The adapters touch hardware and permissions, which no automated test here can reach (`sprecorder-mac-0016`). This task's gate is a clean Swift 6 build; Task 11 is the hands-on proof.

**Files:**
- Create: `SPRecorderApp/Diary/OSLogSink.swift`
- Create: `SPRecorderApp/Capture/TrackWriter.swift`
- Create: `SPRecorderApp/Capture/ScreenCaptureAudioRecorder.swift`

**Interfaces:**
- Consumes: `DiarySink`, `DiaryEntry`, `DiaryCategory`, `Diary` (Task 3); `AudioCapturing`, `CaptureError` (Task 8).
- Produces:
  - `struct OSLogSink: DiarySink { init(subsystem: String = "com.sprecorder.mac") }`
  - `final class TrackWriter { init(url: URL, trackName: String, format: CMFormatDescription, bitrateKbps: Int, sessionStart: CMTime) throws; func append(_ buffer: CMSampleBuffer); func finish() async throws; appendedBuffers, droppedBuffers: Int; heardSound: Bool }`
  - `final class ScreenCaptureAudioRecorder: NSObject, AudioCapturing, SCStreamOutput, SCStreamDelegate { init(diary: Diary, bitrateKbps: @escaping @Sendable () -> Int) }` — throws `.microphoneNotAllowed` when `AVCaptureDevice.requestAccess(for: .audio)` returns false, `.computerAudioNotAllowed` for `SCStreamErrorDomain` code `-3801`.

- [ ] **Step 1: Write the os_log sink**

`SPRecorderApp/Diary/OSLogSink.swift`:

```swift
import os
import SPRecorderCore

/// The live-debugging sink: unified log, subsystem `com.sprecorder.mac`, one category per
/// glossary area (sprecorder-mac-0013). Message text stays private by default; the Diary file
/// is the support record, not this.
struct OSLogSink: DiarySink {
    private let loggers: [DiaryCategory: Logger]

    init(subsystem: String = "com.sprecorder.mac") {
        loggers = Dictionary(uniqueKeysWithValues: DiaryCategory.allCases.map { ($0, Logger(subsystem: subsystem, category: $0.rawValue)) })
    }

    func write(_ entry: DiaryEntry) {
        guard let logger = loggers[entry.category] else { return }
        switch entry.level {
        case .debug: logger.debug("\(entry.message, privacy: .private)")
        case .notice: logger.notice("\(entry.message, privacy: .private)")
        case .warning: logger.warning("\(entry.message, privacy: .private)")
        case .error: logger.error("\(entry.message, privacy: .private)")
        }
    }
}
```

- [ ] **Step 2: Write the track writer**

`SPRecorderApp/Capture/TrackWriter.swift`. `movieFragmentInterval` is set before `startWriting()`, so Plan 2's crash recovery needs no change here.

```swift
import AVFoundation
import CoreMedia
import SPRecorderCore

/// Writes one track as AAC in an `.m4a` (research #6), in 2-second pieces so a crash keeps all
/// but the last few seconds (sprecorder-mac-0034, sprecorder-mac-0038 rule 1).
/// Used only from the capture queue.
final class TrackWriter: @unchecked Sendable {
    let url: URL
    let trackName: String
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private(set) var appendedBuffers = 0
    private(set) var droppedBuffers = 0
    /// False while every sample so far is exactly zero — what a refused microphone delivers
    /// (measured, sprecorder-mac-0023 amendment).
    private(set) var heardSound = false

    init(url: URL, trackName: String, format: CMFormatDescription, bitrateKbps: Int, sessionStart: CMTime) throws {
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee else {
            throw CaptureError.failed("The \(trackName) delivered audio in a format SPRecorder cannot read.")
        }
        self.url = url
        self.trackName = trackName
        try? FileManager.default.removeItem(at: url)
        writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        writer.movieFragmentInterval = CMTime(seconds: 2, preferredTimescale: 600)
        input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: asbd.mSampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: bitrateKbps * 1000,
        ], sourceFormatHint: format)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else {
            throw CaptureError.failed("The \(trackName) could not be set up for writing.")
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw CaptureError.failed("The \(trackName) could not start writing: \(writer.error?.localizedDescription ?? "unknown error")")
        }
        // Every track starts its timeline at the first buffer of the whole stream, so the two
        // files stay in step for the Mixed file (Plan 2).
        writer.startSession(atSourceTime: sessionStart)
    }

    func append(_ buffer: CMSampleBuffer) {
        if !heardSound { heardSound = Self.containsSound(buffer) }
        if input.isReadyForMoreMediaData && input.append(buffer) {
            appendedBuffers += 1
        } else {
            droppedBuffers += 1
        }
    }

    func finish() async throws {
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw CaptureError.failed("The \(trackName) could not be finished: \(writer.error?.localizedDescription ?? "unknown error")")
        }
    }

    private static func containsSound(_ buffer: CMSampleBuffer) -> Bool {
        var found = false
        try? buffer.withAudioBufferList { list, _ in
            for audio in list {
                guard let data = audio.mData else { continue }
                let bytes = UnsafeRawBufferPointer(start: data, count: Int(audio.mDataByteSize))
                if bytes.contains(where: { $0 != 0 }) { found = true; return }
            }
        }
        return found
    }
}
```

- [ ] **Step 3: Write the recorder**

`SPRecorderApp/Capture/ScreenCaptureAudioRecorder.swift`. The stream configuration copies the one `tools/setup-check-probe/probe.swift` measured capturing audio (a 16×16 video output at 2 fps keeps the stream alive), with two changes: `excludesCurrentProcessAudio = true` (a recording must not contain the app's own sounds) and `captureMicrophone = true` (research #3).

```swift
import AVFoundation
import CoreMedia
import ScreenCaptureKit
import SPRecorderCore

/// Records the System track and the Mic track from one ScreenCaptureKit stream (research #3):
/// `capturesAudio` for computer audio, `captureMicrophone` for the microphone. The stream needs
/// a display to exist, so it is given the first display and a tiny, slow video output whose
/// frames are ignored — the same configuration that captured audio in
/// `tools/setup-check-probe`.
final class ScreenCaptureAudioRecorder: NSObject, AudioCapturing, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let diary: Diary
    private let bitrateKbps: @Sendable () -> Int
    private let queue = DispatchQueue(label: "com.sprecorder.mac.capture")

    // Touched only on `queue`.
    private var stream: SCStream?
    private var systemTrackURL: URL?
    private var micTrackURL: URL?
    private var system: TrackWriter?
    private var mic: TrackWriter?
    private var failedTracks: Set<String> = []
    private var sessionStart: CMTime?
    private var bitrate = 64
    private var onInterrupted: (@Sendable (CaptureError) -> Void)?

    init(diary: Diary, bitrateKbps: @escaping @Sendable () -> Int) {
        self.diary = diary
        self.bitrateKbps = bitrateKbps
    }

    func start(systemTrack: URL, micTrack: URL, onInterrupted: @escaping @Sendable (CaptureError) -> Void) async throws {
        // Asked lazily, when recording first starts (sprecorder-mac-0006). A refusal found here
        // is certain; a grant is not, so capture itself is still the proof.
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            diary.error(.permissions, "Microphone access is refused")
            throw CaptureError.microphoneNotAllowed
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            diary.error(.permissions, "ScreenCaptureKit would not list displays: \(Self.describe(error))")
            throw Self.translate(error)
        }
        guard let display = content.displays.first else {
            diary.error(.systemTrack, "ScreenCaptureKit listed no displays")
            throw CaptureError.failed("No display was found, and computer audio is captured through one.")
        }

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.captureMicrophone = true
        config.sampleRate = 48_000
        config.channelCount = 1
        config.width = 16
        config.height = 16
        config.minimumFrameInterval = CMTime(value: 1, timescale: 2)

        let newStream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []), configuration: config, delegate: self)
        do {
            try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
            try newStream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue)
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        } catch {
            diary.error(.systemTrack, "Could not attach to the capture stream: \(Self.describe(error))")
            throw Self.translate(error)
        }

        let kbps = bitrateKbps()
        queue.sync {
            systemTrackURL = systemTrack
            micTrackURL = micTrack
            system = nil
            mic = nil
            failedTracks = []
            sessionStart = nil
            bitrate = kbps
            self.onInterrupted = onInterrupted
        }

        do {
            try await newStream.startCapture()
        } catch {
            diary.error(.systemTrack, "Capture stream did not start: \(Self.describe(error))")
            queue.sync { self.onInterrupted = nil }
            throw Self.translate(error)
        }
        queue.sync { stream = newStream }
        diary.notice(.systemTrack, "Capture started on display \(display.displayID), AAC \(kbps) kbps")
    }

    func stop() async throws {
        let running = queue.sync { stream }
        if let running {
            do {
                try await running.stopCapture()
            } catch {
                diary.warning(.systemTrack, "Capture stream did not stop cleanly: \(Self.describe(error))")
            }
        }
        // stopCapture has returned, so no more buffers arrive; take the writers off the queue.
        let (systemWriter, micWriter) = queue.sync { () -> (TrackWriter?, TrackWriter?) in
            let writers = (system, mic)
            stream = nil
            system = nil
            mic = nil
            onInterrupted = nil
            return writers
        }

        var firstError: CaptureError?
        for (name, category, writer) in [("System track", DiaryCategory.systemTrack, systemWriter), ("Mic track", .micTrack, micWriter)] {
            guard let writer else {
                diary.warning(category, "\(name): no audio arrived, so no file was written")
                continue
            }
            do {
                try await writer.finish()
                diary.notice(category, "\(name) finished: \(writer.url.lastPathComponent), \(writer.appendedBuffers) buffers, \(writer.droppedBuffers) dropped")
                if writer.droppedBuffers > 0 {
                    diary.warning(category, "\(name) dropped \(writer.droppedBuffers) buffers; the file has short gaps")
                }
                if !writer.heardSound {
                    diary.warning(category, "\(name) is completely silent; if this is the Mic track, the microphone may not be allowed")
                }
            } catch {
                let reason = CaptureError(error)
                diary.error(category, reason.plainWords)
                if firstError == nil { firstError = reason }
            }
        }
        if let firstError { throw firstError }
    }

    // MARK: SCStreamOutput — called on `queue`

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid, type == .audio || type == .microphone else { return }
        if sessionStart == nil { sessionStart = sampleBuffer.presentationTimeStamp }
        if type == .audio {
            system = system ?? makeWriter(name: "System track", category: .systemTrack, url: systemTrackURL, first: sampleBuffer)
            system?.append(sampleBuffer)
        } else {
            mic = mic ?? makeWriter(name: "Mic track", category: .micTrack, url: micTrackURL, first: sampleBuffer)
            mic?.append(sampleBuffer)
        }
    }

    private func makeWriter(name: String, category: DiaryCategory, url: URL?, first: CMSampleBuffer) -> TrackWriter? {
        guard let url, let format = first.formatDescription, let sessionStart, !failedTracks.contains(name) else { return nil }
        if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee {
            diary.notice(category, "\(name) audio: \(Int(asbd.mSampleRate)) Hz, \(asbd.mChannelsPerFrame) channel(s), writing \(url.lastPathComponent)")
        }
        do {
            return try TrackWriter(url: url, trackName: name, format: format, bitrateKbps: bitrate, sessionStart: sessionStart)
        } catch {
            failedTracks.insert(name)
            let reason = CaptureError(error)
            diary.error(category, reason.plainWords)
            onInterrupted?(reason)
            onInterrupted = nil
            return nil
        }
    }

    // MARK: SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        diary.error(.systemTrack, "Capture stream stopped by itself: \(Self.describe(error))")
        queue.async {
            let callback = self.onInterrupted
            self.onInterrupted = nil
            callback?(Self.translate(error))
        }
    }

    // MARK: Errors

    /// `-3801` in `SCStreamErrorDomain` is the refusal measured by `tools/tcc-probe`:
    /// "The user declined TCCs for application, window, display capture".
    static func translate(_ error: any Error) -> CaptureError {
        let ns = error as NSError
        if ns.domain == SCStreamErrorDomain && ns.code == SCStreamError.Code.userDeclined.rawValue {
            return .computerAudioNotAllowed
        }
        return CaptureError(error)
    }

    static func describe(_ error: any Error) -> String {
        let ns = error as NSError
        return "\(ns.localizedDescription) (\(ns.domain) \(ns.code))"
    }
}
```

- [ ] **Step 4: Build the app**

Run: `xcodebuild build -scheme SPRecorderApp -destination 'platform=macOS' 2>&1 | grep -E ": error:|: warning:|\*\* BUILD"`

Expected: `** BUILD SUCCEEDED **` and no `warning:` lines. The Task 1 scaffold `AppDelegate` does not use the recorder yet; that is expected.

- [ ] **Step 5: Confirm the Core is still clean**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `✔ Test run with 53 tests in 8 suites passed` and `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add SPRecorderApp/Diary/OSLogSink.swift SPRecorderApp/Capture/TrackWriter.swift SPRecorderApp/Capture/ScreenCaptureAudioRecorder.swift
git commit -m "Capture computer audio and the microphone into two AAC tracks

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -- SPRecorderApp/Diary/OSLogSink.swift SPRecorderApp/Capture/TrackWriter.swift SPRecorderApp/Capture/ScreenCaptureAudioRecorder.swift
```

---

### Task 10: The start/stop hotkey, the menu-bar icon, and the app that wires them

**Files:**
- Create: `SPRecorderApp/Hotkey/CarbonHotkeyCenter.swift`
- Create: `SPRecorderApp/MenuBar/StatusItemController.swift`
- Modify: `SPRecorderApp/AppDelegate.swift` (replace the Task 1 scaffold entirely)

**Interfaces:**
- Consumes: `HotkeySpec` (Task 7); `RecordingSession` (Task 8); `SettingsStore` (Task 5); `Diary`, `DiaryFile` (Task 3); `OSLogSink`, `ScreenCaptureAudioRecorder` (Task 9).
- Produces:
  - `@MainActor final class CarbonHotkeyCenter { func register(_ spec: HotkeySpec, action: @escaping () -> Void) -> OSStatus; func unregisterAll() }`
  - `@MainActor final class StatusItemController: NSObject { var onToggle: () -> Void; var onOpenRecordingsFolder: () -> Void; func show(_ state: RecordingSession.State); func showHotkey(_ spec: HotkeySpec?, registered: Bool); func showFailure(_ message: String?) }`
  - The running app: Diary at `~/Library/Logs/SPRecorder`, settings at `~/Library/Application Support/SPRecorder/settings.json`, hotkey from `settings.current.hotkey`; quitting mid-recording stops the session first.

- [ ] **Step 1: Write the Carbon hotkey center**

`SPRecorderApp/Hotkey/CarbonHotkeyCenter.swift`:

```swift
import Carbon
import SPRecorderCore

/// Global hotkeys through Carbon's `RegisterEventHotKey`: the only macOS mechanism that is
/// exclusive, needs no permission, and works with no window (research #5). A combination
/// another app already owns fails to register — that is an Inactive hotkey.
@MainActor
final class CarbonHotkeyCenter {
    private var actions: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private var nextID: UInt32 = 1

    /// Returns `noErr` when registered; any other status means the hotkey is inactive.
    func register(_ spec: HotkeySpec, action: @escaping () -> Void) -> OSStatus {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x5350_5263), id: id)   // 'SPRc'
        let status = RegisterEventHotKey(spec.macVirtualKeyCode, spec.macModifierFlags, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            refs[id] = ref
            actions[id] = action
        }
        return status
    }

    func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs = [:]
        actions = [:]
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            let center = Unmanaged<CarbonHotkeyCenter>.fromOpaque(context).takeUnretainedValue()
            // The application event target delivers on the main thread.
            MainActor.assumeIsolated { center.actions[hotKeyID.id]?() }
            return noErr
        }, 1, &pressed, context, &handler)
    }
}
```

- [ ] **Step 2: Write the menu-bar icon and menu**

`SPRecorderApp/MenuBar/StatusItemController.swift`. Idle is a template ring, so macOS tints it for a light or dark menu bar; recording is a solid `#e0362c` fill (`sprecorder-mac-0010`).

```swift
import AppKit
import SPRecorderCore

/// The minimal menu-bar icon for Plan 1 (sprecorder-mac-0010): a template ring when idle, a red
/// fill while recording, and a menu to start or stop, see a failure, open the recordings
/// folder and quit. Plan 6 replaces it with the full twelve-row menu.
@MainActor
final class StatusItemController: NSObject {
    var onToggle: () -> Void = {}
    var onOpenRecordingsFolder: () -> Void = {}

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let toggleItem = NSMenuItem(title: "Start recording", action: #selector(toggle), keyEquivalent: "")
    private let hotkeyTakenItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let failureItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    static let recordingRed = NSColor(srgbRed: 0xE0 / 255.0, green: 0x36 / 255.0, blue: 0x2C / 255.0, alpha: 1)

    override init() {
        super.init()
        let menu = NSMenu()
        toggleItem.target = self
        menu.addItem(toggleItem)
        hotkeyTakenItem.isEnabled = false
        hotkeyTakenItem.isHidden = true
        menu.addItem(hotkeyTakenItem)
        failureItem.isEnabled = false
        failureItem.isHidden = true
        menu.addItem(failureItem)
        menu.addItem(.separator())
        let open = NSMenuItem(title: "Open recordings folder", action: #selector(openFolder), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SPRecorder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        show(.idle)
    }

    func show(_ state: RecordingSession.State) {
        switch state {
        case .idle:
            toggleItem.title = "Start recording"
            toggleItem.isEnabled = true
            setIcon(recording: false)
        case .starting:
            toggleItem.title = "Starting…"
            toggleItem.isEnabled = false
        case .recording:
            toggleItem.title = "Stop recording"
            toggleItem.isEnabled = true
            setIcon(recording: true)
        case .stopping:
            toggleItem.title = "Stopping…"
            toggleItem.isEnabled = false
        }
    }

    /// Shows the start/stop hotkey beside the menu row, or the Inactive hotkey warning.
    func showHotkey(_ spec: HotkeySpec?, registered: Bool) {
        if let spec, registered {
            toggleItem.keyEquivalent = Self.keyEquivalent(for: spec)
            toggleItem.keyEquivalentModifierMask = Self.modifierMask(for: spec)
            hotkeyTakenItem.isHidden = true
        } else {
            toggleItem.keyEquivalent = ""
            hotkeyTakenItem.title = spec.map { "⚠ Hotkey \($0.displayString) taken by another app" } ?? "⚠ Hotkey in settings.json is not valid"
            hotkeyTakenItem.isHidden = false
        }
    }

    /// A plain-words failure, or nil to clear it.
    func showFailure(_ message: String?) {
        failureItem.title = message ?? ""
        failureItem.isHidden = message == nil
    }

    private func setIcon(recording: Bool) {
        let image: NSImage?
        if recording {
            image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "SPRecorder — recording")?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [Self.recordingRed]))
            image?.isTemplate = false
        } else {
            image = NSImage(systemSymbolName: "circle", accessibilityDescription: "SPRecorder")
            image?.isTemplate = true
        }
        item.button?.image = image
    }

    @objc private func toggle() { onToggle() }
    @objc private func openFolder() { onOpenRecordingsFolder() }

    private static func keyEquivalent(for spec: HotkeySpec) -> String {
        if spec.key.hasPrefix("F"), let n = Int(spec.key.dropFirst()), let scalar = UnicodeScalar(NSF1FunctionKey + n - 1) {
            return String(Character(scalar))
        }
        return spec.key.lowercased()
    }

    private static func modifierMask(for spec: HotkeySpec) -> NSEvent.ModifierFlags {
        var mask: NSEvent.ModifierFlags = []
        if spec.modifiers.contains(.control) { mask.insert(.control) }
        if spec.modifiers.contains(.option) { mask.insert(.option) }
        if spec.modifiers.contains(.shift) { mask.insert(.shift) }
        if spec.modifiers.contains(.command) { mask.insert(.command) }
        return mask
    }
}
```

- [ ] **Step 3: Replace the scaffold entry point**

Replace the whole of `SPRecorderApp/AppDelegate.swift` with:

```swift
import AppKit
import Carbon
import SPRecorderCore

/// The entry point: a menu-bar app with no Dock icon (`LSUIElement`, sprecorder-mac-0010). It
/// wires the Core's Recording Session to the real adapters, and the start/stop hotkey and menu
/// to the session.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var diary: Diary!
    private var settings: SettingsStore!
    private var session: RecordingSession!
    private var statusItem: StatusItemController!
    private let hotkeys = CarbonHotkeyCenter()

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let fm = FileManager.default
        let library = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        diary = Diary(sinks: [DiaryFile(directory: library.appendingPathComponent("Logs/SPRecorder", isDirectory: true)), OSLogSink()])

        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        diary.notice(.app, "SPRecorder \(version) (\(build)) started on \(ProcessInfo.processInfo.operatingSystemVersionString)")

        let settingsURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SPRecorder/settings.json", isDirectory: false)
        let store = SettingsStore(fileURL: settingsURL, diary: diary)
        settings = store

        let recorder = ScreenCaptureAudioRecorder(diary: diary, bitrateKbps: { store.current.audioBitrateKbps })
        session = RecordingSession(settings: { store.current }, capture: recorder, diary: diary, home: fm.homeDirectoryForCurrentUser)

        statusItem = StatusItemController()
        statusItem.onToggle = { [weak self] in self?.toggleRecording() }
        statusItem.onOpenRecordingsFolder = { [weak self] in self?.openRecordingsFolder() }
        session.onStateChange = { [weak self] state in self?.statusItem.show(state) }
        session.onFailure = { [weak self] message in self?.statusItem.showFailure(message) }

        registerStartStopHotkey()
    }

    /// Quitting mid-recording finishes both files first.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard case .recording = session?.state else { return .terminateNow }
        diary.notice(.app, "Quit while recording; stopping the Recording Session first")
        Task {
            await session.stop()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeys.unregisterAll()
        diary?.notice(.app, "SPRecorder quit")
    }

    private func toggleRecording() {
        statusItem.showFailure(nil)
        Task { await session.toggle() }
    }

    private func registerStartStopHotkey() {
        let text = settings.current.hotkey
        let spec: HotkeySpec
        do {
            spec = try HotkeySpec.parse(text)
        } catch {
            let reason = (error as? HotkeySpec.ParseError)?.description ?? error.localizedDescription
            diary.warning(.hotkey, "Start/stop hotkey “\(text)” in settings.json is not valid: \(reason)")
            statusItem.showHotkey(nil, registered: false)
            return
        }
        let status = hotkeys.register(spec) { [weak self] in self?.toggleRecording() }
        if status == noErr {
            diary.notice(.hotkey, "Start/stop hotkey \(spec.displayString) registered")
            statusItem.showHotkey(spec, registered: true)
        } else {
            diary.warning(.hotkey, "Start/stop hotkey \(spec.displayString) is inactive: RegisterEventHotKey returned \(status); another app may own it")
            statusItem.showHotkey(spec, registered: false)
        }
    }

    private func openRecordingsFolder() {
        let folder = settings.current.outputDirectoryURL(home: FileManager.default.homeDirectoryForCurrentUser)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folder)
        } catch {
            diary.error(.app, "Could not open the recordings folder \(folder.path): \(error.localizedDescription)")
            statusItem.showFailure("Could not open \(folder.path).")
        }
    }
}
```

- [ ] **Step 4: Build the app**

Run: `xcodebuild build -scheme SPRecorderApp -destination 'platform=macOS' 2>&1 | grep -E ": error:|: warning:|\*\* BUILD"`

Expected: `** BUILD SUCCEEDED **` and no `warning:` lines.

- [ ] **Step 5: Run the whole Core suite and the guard once more**

Run: `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS' 2>&1 | grep -E "error: |✘|Test run with|\*\* TEST"`

Expected: `✔ Test run with 53 tests in 8 suites passed` and `** TEST SUCCEEDED **`.

Run: `grep -rlE '^import (AppKit|SwiftUI|ScreenCaptureKit|AVFoundation|Carbon|CoreAudio)' SPRecorderCore || echo "Core imports clean"`

Expected: `Core imports clean`

- [ ] **Step 6: Commit**

```bash
git add SPRecorderApp/Hotkey/CarbonHotkeyCenter.swift SPRecorderApp/MenuBar/StatusItemController.swift SPRecorderApp/AppDelegate.swift
git commit -m "Start and stop a Recording Session from a hotkey or the menu bar

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -- SPRecorderApp/Hotkey/CarbonHotkeyCenter.swift SPRecorderApp/MenuBar/StatusItemController.swift SPRecorderApp/AppDelegate.swift
```

---

### Task 11: First demo on the development Mac — measured, with a person at the keyboard

The steps marked **(person)** need the developer's hands: permission boxes, speaking, playing audio. An agent prints each step, waits for "done", then measures it read-only through a different channel from the one the person used: the file system, `afinfo`, the Diary and `log show`. Follow the `guide-and-verify` skill. One step at a time.

**Files:**
- Create: `tools/track-seconds/track-seconds.swift`
- Create: `docs/superpowers/plans/2026-09-10-plan-1-first-demo-results.md`
- Modify: `docs/adr/sprecorder-mac-0005-recordings-default-to-movies-no-bookmarks.md` (append amendment)
- Modify: `docs/superpowers/plans/2026-09-10-sprecorder-mac-roadmap.md` (Plan 1 row: done; the unverified line removed)

**Interfaces:**
- Consumes: the app from Task 10.
- Produces: measured answers to the four unverified items above, written down.

**Pass condition, fixed before anything is run:**

1. A Recording Session started and stopped with **⌃⌥R** leaves one folder in `~/Movies/SPRecorder` named `yyyy-MM-dd EEE HH.mm` for the start time.
2. It holds exactly `Computer audio.m4a` and `My microphone.m4a`, and `afinfo` reports each as `aac`, **1 ch**.
3. Each file's decodable length is within **2 seconds** of the time between the two presses.
4. Played back, `Computer audio.m4a` has the video's sound and not the voice alone; `My microphone.m4a` has the voice.
5. The Diary for today has `Recording Session started` and `Recording Session stopped after` lines, and a `System track finished` and a `Mic track finished` line, each with `0 dropped`, and no `completely silent` warning.
6. **Crash:** a session killed with `kill -9` after about 30 s leaves both files with at least **26 s** decodable (`sprecorder-mac-0034`: 2-second pieces lose about 2 s).

- [ ] **Step 1: Write the decodable-seconds tool**

`tools/track-seconds/track-seconds.swift`:

```swift
// Prints how many seconds of audio a player can decode from each file given — the same
// measure tools/crash-safety-probe used (sprecorder-mac-0034). Works on a file whose writer
// was killed before it finished.
//
// Usage: swift tools/track-seconds/track-seconds.swift <file.m4a> [more files...]
import AVFoundation

func decodableSeconds(_ url: URL) async -> String {
    let asset = AVURLAsset(url: url)
    guard let track = try? await asset.loadTracks(withMediaType: .audio).first else { return "no audio track" }
    guard let reader = try? AVAssetReader(asset: asset) else { return "unreadable" }
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
    reader.add(output)
    guard reader.startReading() else { return "unreadable: \(reader.error?.localizedDescription ?? "?")" }
    var frames = 0
    var rate = 0.0
    while let buffer = output.copyNextSampleBuffer() {
        frames += CMSampleBufferGetNumSamples(buffer)
        if rate == 0, let f = buffer.formatDescription, let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(f)?.pointee {
            rate = asbd.mSampleRate
        }
    }
    if reader.status == .failed { return "decode failed after \(frames) frames: \(reader.error?.localizedDescription ?? "?")" }
    return rate > 0 ? String(format: "%.2f s decodable", Double(frames) / rate) : "no samples"
}

for path in CommandLine.arguments.dropFirst() {
    print("\(path): \(await decodableSeconds(URL(fileURLWithPath: path)))")
}
```

Run: `say -o /tmp/sp-check.aiff "one two three" && afconvert -f m4af -d aac /tmp/sp-check.aiff /tmp/sp-check.m4a && swift tools/track-seconds/track-seconds.swift /tmp/sp-check.m4a`

Expected: `/tmp/sp-check.m4a: 1.… s decodable` (a length of about a second, not `unreadable`).

- [ ] **Step 2: Baseline — record what exists before the app first runs**

Run, and paste the output into the results file (Step 12):

```sh
ls -la ~/Movies/SPRecorder ~/Library/Logs/SPRecorder "$HOME/Library/Application Support/SPRecorder" 2>&1
/usr/bin/log show --last 1m --style compact --predicate 'subsystem == "com.apple.TCC" AND eventMessage CONTAINS "com.sprecorder.mac"' | tail -3
```

Expected: the three folders do not exist yet (or are listed as they are). Write down what is there — any existing Session folders are the blast radius that must not change.

- [ ] **Step 3: Build a copy to run, and put it where macOS registers it**

Run:

```sh
xcodebuild build -scheme SPRecorderApp -configuration Debug -destination 'platform=macOS' -derivedDataPath build 2>&1 | grep -E "\*\* BUILD"
rm -rf ~/Applications/SPRecorder.app
mkdir -p ~/Applications
cp -R build/Build/Products/Debug/SPRecorder.app ~/Applications/
open ~/Applications/SPRecorder.app
```

Expected: `** BUILD SUCCEEDED **`, and a hollow ring appears in the menu bar. It runs from `~/Applications` because an app run from `/tmp` never registered for permissions (`tools/setup-check-probe/README.md`).

Measure: `cat "$HOME/Library/Application Support/SPRecorder/settings.json"` shows 26 keys including `"Hotkey" : "Control+Option+R"`; `tail -3 ~/Library/Logs/SPRecorder/$(date +%F).log` shows `[notice] App: SPRecorder 0.1 (1) started on …`, `[notice] Settings: No settings file; created …` and `[notice] Hotkey: Start/stop hotkey ⌃⌥R registered`.

- [ ] **Step 4 (person): Start the first Recording Session and answer the permission boxes**

Tell the person:

```
Step 4 — let SPRecorder hear you and the computer

Do:
1. Click the ring in the menu bar.
2. Click "Start recording".
3. If macOS asks to use the microphone, press Allow.
4. Watch for a notification about Screen & System Audio Recording.
5. Open the menu again and read the grey line under "Start recording".

Do not:
- Press "Quit & Reopen" if any box offers it — press Later. Reopening voids the next measurement.

Then say "done" and read me the grey line.
```

Expected (measured for the setup-check probe, not yet for this app): a Microphone box; **no** Allow box for Screen & System Audio, only a notification; the grey line reads `Not recording. SPRecorder is not allowed to record computer audio.`

Measure: the Diary has `[error] Permissions: ScreenCaptureKit would not list displays: The user declined TCCs for application, window, display capture (com.apple.ScreenCaptureKit.SCStreamErrorDomain -3801)` and `[error] RecordingSession: Recording Session could not start (…)`; `ls ~/Movies/SPRecorder` shows **no** new folder (the empty one was removed). Record whether a *"SPRecorder would like to access files in your Movies folder"* box appeared at any point — that is `sprecorder-mac-0005`'s open question.

If the order differs (for example, no Microphone box, or the session starts), write down exactly what happened and continue — the pass condition is about the recording, not the prompt order.

- [ ] **Step 5 (person): Turn on Screen & System Audio Recording for SPRecorder**

Tell the person:

```
Step 5 — switch SPRecorder on

Go to: x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture
(paste into Safari's address bar, or: System Settings → Privacy & Security → Screen & System Audio Recording)

Do:
1. Find SPRecorder in the list.
2. Turn its switch on.
3. If a box offers "Quit & Reopen", press Later.

Do not:
- Search System Settings for it — search led to the wrong list last time (System Audio Recording Only).
- Press the + button unless SPRecorder is missing from the list — the one stuck permission ever seen followed a + add (sprecorder-mac-0041).

Then say "done".
```

Measure: `/usr/bin/log show --last 5m --style compact --predicate 'subsystem == "com.apple.TCC" AND eventMessage CONTAINS "com.sprecorder.mac"' | tail -5` shows an update for `kTCCServiceScreenCapture`; `pgrep -x SPRecorder` still prints one process id (it was not reopened).

- [ ] **Step 6 (person): Record 40 seconds with the hotkey**

Tell the person:

```
Step 6 — a real recording

Do:
1. Start a video with people talking (any YouTube video), sound on, headphones or speakers.
2. Look at a clock. Press ⌃⌥R (Control + Option + R).
3. Check the ring turned solid red.
4. Talk over the video for about 40 seconds — say "this is my microphone" a few times.
5. Press ⌃⌥R again. The ring goes hollow.
6. Note roughly how many seconds passed between the two presses.

Then say "done" and tell me the seconds.
```

Measure:

```sh
F="$(ls -td ~/Movies/SPRecorder/*/ | head -1)"; echo "$F"; ls "$F"
afinfo "$F/Computer audio.m4a" | grep -E "Data format|estimated duration"
afinfo "$F/My microphone.m4a"  | grep -E "Data format|estimated duration"
swift tools/track-seconds/track-seconds.swift "$F/Computer audio.m4a" "$F/My microphone.m4a"
grep -E "RecordingSession|SystemTrack|MicTrack" ~/Library/Logs/SPRecorder/$(date +%F).log | tail -10
```

Assert pass conditions 1, 2, 3 and 5. Write down the `… audio: N Hz, N channel(s)` lines for both tracks — the real formats research #3 could not confirm.

If `My microphone.m4a` is missing and the Diary says `Mic track: no audio arrived`, `captureMicrophone` did not deliver on macOS 26.6.2. **Stop and report** — the fallback is the separate `AVAudioEngine` input tap that `tools/setup-check-probe` measured working, and that is a change to `ScreenCaptureAudioRecorder` to plan with the user, not to improvise.

- [ ] **Step 7 (person): Listen to both files**

Tell the person:

```
Step 7 — listen

Do:
1. In Terminal: open "<the folder printed above>"
2. Play "Computer audio.m4a" in QuickTime Player. Is the video's sound there?
3. Play "My microphone.m4a". Is your voice there?

Then say "done" and answer both questions.
```

Assert pass condition 4. This is *reported by the operator*, not independently measured — write it down in those words.

- [ ] **Step 8 (person): Kill a recording mid-way**

Tell the person:

```
Step 8 — does a crash keep the recording?

Do:
1. Press ⌃⌥R to start. Let the video play for about 30 seconds.
2. Say "done" — I will kill SPRecorder myself. Do not press ⌃⌥R again.
```

Then the agent runs: `kill -9 "$(pgrep -x SPRecorder)"` and, after 2 seconds:

```sh
F="$(ls -td ~/Movies/SPRecorder/*/ | head -1)"; echo "$F"
swift tools/track-seconds/track-seconds.swift "$F/Computer audio.m4a" "$F/My microphone.m4a"
```

Assert pass condition 6: both at least 26 s. (Plan 2 finishes such a session at next launch; for now the file is only expected to be playable.)

- [ ] **Step 9: A second copy finds the hotkey taken**

Run:

```sh
open ~/Applications/SPRecorder.app
sleep 3
open -n ~/Applications/SPRecorder.app
sleep 3
grep "Hotkey" ~/Library/Logs/SPRecorder/$(date +%F).log | tail -2
```

Expected: the first copy logs `Start/stop hotkey ⌃⌥R registered`; the second logs `Start/stop hotkey ⌃⌥R is inactive: RegisterEventHotKey returned <status>; another app may own it`. Write down `<status>` — research #5 expected `-9878` (`eventHotKeyExistsErr`) and asked for it to be measured on macOS 26.

Then quit both copies from their menus (**Quit SPRecorder**) and confirm `pgrep -x SPRecorder` prints nothing.

If both copies log `registered`, Carbon does not refuse a combination held by another process on macOS 26, and the Inactive hotkey cannot be detected this way. Stop and report it — Plans 3 and 6 depend on it.

- [ ] **Step 10: Blast radius**

Run: `ls ~/Movies/SPRecorder` and compare with Step 2.

Expected: the only new folders are the ones from Steps 6 and 8. Any Session folder from before Step 2 is unchanged.

- [ ] **Step 11: Record `sprecorder-mac-0005`'s answer**

Append to the end of `docs/adr/sprecorder-mac-0005-recordings-default-to-movies-no-bookmarks.md`, writing the observed outcome from Step 4 in place of the bracketed choice:

```markdown

---

## Amendment — <date of the run>, measured

SPRecorder (`com.sprecorder.mac`, ad-hoc signed, macOS 26.6.2) created
`~/Movies/SPRecorder` and a Session folder inside it on its first Recording Session.
A "would like to access files in your Movies folder" box [did not appear / appeared].
Plan 1 first-demo results: `docs/superpowers/plans/2026-09-10-plan-1-first-demo-results.md`.
```

- [ ] **Step 12: Write the results file and update the roadmap**

Create `docs/superpowers/plans/2026-09-10-plan-1-first-demo-results.md` with: the date and macOS build (`sw_vers`); the Step 2 baseline output; a table of the six pass conditions with **PASS/FAIL** and the measured number for each; the two track formats from Step 6; the hotkey status code from Step 9; the permission prompts seen in Steps 4–5; and, for pass condition 4, the words *reported by the operator*.

In `docs/superpowers/plans/2026-09-10-sprecorder-mac-roadmap.md`, replace the line beginning `**Unverified, to confirm in Plan 1:**` with:

```markdown
**Confirmed in Plan 1:** `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS'` (see `sprecorder-mac-0007` amendment); first-demo results in `2026-09-10-plan-1-first-demo-results.md`.
```

- [ ] **Step 13: Commit**

```bash
git add tools/track-seconds/track-seconds.swift docs/superpowers/plans/2026-09-10-plan-1-first-demo-results.md docs/adr/sprecorder-mac-0005-recordings-default-to-movies-no-bookmarks.md docs/superpowers/plans/2026-09-10-sprecorder-mac-roadmap.md
git commit -m "Measure the first demo: two tracks, a crash, a taken hotkey

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -- tools/track-seconds/track-seconds.swift docs/superpowers/plans/2026-09-10-plan-1-first-demo-results.md docs/adr/sprecorder-mac-0005-recordings-default-to-movies-no-bookmarks.md docs/superpowers/plans/2026-09-10-sprecorder-mac-roadmap.md
```

---

## ADR coverage

| ADR | where |
|---|---|
| 0001 native Swift | the whole plan |
| 0002 Core / App, protocols | Tasks 1, 3, 8, 9 (`AudioCapturing`, `DiarySink`) |
| 0003 translate / rewrite / drop | Task 4 (`AppConfigStore` rewritten as `AppSettings` + `SettingsStore`), Task 6 (`FileNameBuilder` rewritten), Task 7 (`HotkeyParser` dropped, replaced) |
| 0004 settings JSON, validation | Tasks 4, 5 |
| 0005 `~/Movies`, plain path | Task 4 default, Task 8, Task 11 measurement |
| 0006 lazy permissions, attempt not preflight | Task 9 (request at first start; `-3801` read from the attempt), Task 11 |
| 0007 one project, guard script | Task 1 |
| 0009 macOS 26.0 arm64 | Task 1 build settings |
| 0010 menu-bar only, icon states | Task 1 (`LSUIElement`), Task 10 (ring, red fill; badge in Plan 6) |
| 0013 two sinks | Task 3 (`DiaryFile`, amendment), Task 9 (`OSLogSink`) |
| 0014 7 days, levels, no keystrokes | Task 3; Global Constraints |
| 0015 Swift Testing, faked session, failure lines | Tasks 3–8 |
| 0016 GitHub Actions | Task 2 |
| 0018 injected Diary directory | Task 3 (`DiaryFile(directory:)`); the leak test itself is Plan 4 |
| 0019 Session folder, names, locale, collisions | Tasks 1, 6, 8 |
| 0021 no monitor setting | Task 4 (`ScreenMonitorDeviceName` absent) |
| 0034 / 0038 2-second pieces | Task 9 (`movieFragmentInterval`), Task 11 crash check |
