# One Xcode project with two targets

```mermaid
flowchart TD
    Q{"How are SPRecorderCore and<br/>SPRecorderApp actually built?"} -->|chosen| A["One .xcodeproj<br/>Core framework target<br/>+ App target"]
    Q -->|rejected| B["Swift Package for Core<br/>+ thin Xcode app<br/>7s CLI tests, but code<br/>lives in two places"]
    Q -->|rejected| C["Generated project<br/>XcodeGen / Tuist<br/>solves a multi-author merge<br/>problem a solo dev does not have"]
```

`SPRecorderCore` and `SPRecorderApp` (`sprecorder-mac-0002`) are two **targets in a
single Xcode project**. Both remain real, separate Swift modules, so the module
boundary the earlier ADR describes is unchanged — only its build container is
decided here.

## Structure

| target | kind | holds |
|---|---|---|
| `SPRecorderCore` | framework | domain types, the Recording Session orchestrator, the platform protocols |
| `SPRecorderApp` | application | adapters, SwiftUI/AppKit, entry point |
| `SPRecorderCoreTests` | unit test | the translated tests from `sprecorder-mac-0003` |

`Info.plist` and the entitlements file belong to the **App** target only. The Core
is a framework and has no need of either — it never asks for a permission, because
`sprecorder-mac-0002` puts every platform call in an adapter. This keeps the TCC
usage strings and hardened-runtime settings in exactly one place, which is what
`signing-and-notarization` will need.

## Why this, and what it costs

The user chose one place over two. The trade was made explicitly, against a
measured alternative: a Swift Package Core builds and tests from the command line
in **7.4 seconds** with no Xcode involved. That speed is now given up.

**The costs, recorded so they are not rediscovered as surprises:**

- Testing the Core requires a scheme and `xcodebuild`, not `swift test`. The
  command is expected to be
  `xcodebuild test -scheme SPRecorderCore -destination 'platform=macOS'`.
  **This has not been verified — confirm it when the project is first created.**
- Any machine that builds this project needs a **full Xcode install**, not just the
  command-line tools. That matters if a build machine is ever added.
- The `.xcodeproj` file is awkward to diff. Harmless while one person works on it;
  the reason to revisit this ADR is a second contributor, not a change of taste.

## Enforcing the Core boundary — the compiler does NOT do it

`sprecorder-mac-0002` claimed the compiler makes `import ScreenCaptureKit` inside
the Core a build error. **That claim is false and is corrected in that ADR.**
Measured 2026-09-10: a library target importing `ScreenCaptureKit` and `AppKit`
compiled cleanly in 4.5 seconds. A Swift module boundary stops the Core using the
App's *own* types; it does nothing about system frameworks, which are available to
any macOS target.

The boundary is therefore enforced by a **Run Script build phase on the
`SPRecorderCore` target** that fails the build when a forbidden import appears:

```sh
if grep -rlE '^import (AppKit|SwiftUI|ScreenCaptureKit|AVFoundation|Carbon|CoreAudio)' "$SRCROOT/SPRecorderCore"; then
  echo "error: SPRecorderCore must not import a platform framework (sprecorder-mac-0002)"
  exit 1
fi
```

A Linux compilation would enforce it properly, since `import AppKit` genuinely
fails there — but no container runtime is installed on this machine (`docker` and
`podman` both absent), so that route would add infrastructure to buy a stricter
version of a check the script already performs.

## Consequences

Unblocks `signing-and-notarization`, which needs to know where the entitlements
file lives.

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

---

## Amendment — 2026-09-11, measured. The import guard is an allowlist.

The denylist `grep` above let four imports through: `@preconcurrency import AVFoundation`,
`public import AppKit`, `import CoreMedia` and `import os` each passed it, and Swift 6 compiled
them. `@preconcurrency import` is the usual Swift 6 way to import AVFoundation or
ScreenCaptureKit, so the gap was the likely one. `scripts/forbid-core-platform-imports.sh` now
finds every `import` line in `SPRecorderCore/`, whatever attribute or access level comes before
it, and fails the build unless the imported module is Foundation. Each of the four lines fails
it; `import struct Foundation.Date`, comments, string literals and the Core as it stands pass.
