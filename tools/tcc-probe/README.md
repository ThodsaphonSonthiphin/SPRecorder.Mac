# TCC probe

A throwaway macOS app used to measure real TCC (privacy permission) behaviour
instead of guessing at it. Built for `verify-screen-recording-restart` on the
decision map; kept because the same test is owed for Microphone and Input
Monitoring.

## Why a real .app bundle

A binary run from a terminal has its TCC decision attributed to **the terminal**,
not to itself, so it measures the wrong thing. The probe must be a signed `.app`
bundle launched with `open`.

## Build and run

```sh
swiftc -O probe.swift -o TCCProbe
mkdir -p TCCProbe.app/Contents/MacOS
cp TCCProbe TCCProbe.app/Contents/MacOS/TCCProbe
# write Contents/Info.plist with CFBundleIdentifier com.sprecorder.tccprobe,
# CFBundleExecutable TCCProbe, LSUIElement true
codesign -s - --force --timestamp=none TCCProbe.app
cp -R TCCProbe.app ~/Applications/          # NOT /tmp - see below
open ~/Applications/TCCProbe.app            # ONCE - each launch re-prompts
tail -f /tmp/tcc-probe.log
```

Reset between runs, **always scoped to the bundle id**:

```sh
tccutil reset ScreenCapture com.sprecorder.tccprobe
```

> Never run `tccutil reset ScreenCapture` unscoped — it wipes screen-recording
> permission for every app on the machine.

## Traps found the hard way

- An app under `/private/tmp` never registers in the privacy list at all.
- Even from `~/Applications` it did not self-register; it had to be added with the
  `+` button in System Settings.
- Clicking **Deny** writes a refusal that **overrides** the switch you turn on
  afterwards. Only a scoped `tccutil reset` clears it. A run contaminated this way
  looks exactly like a genuine failure.
- Ad-hoc signing is sufficient for TCC. This Mac has zero code-signing identities.

## What it measured, 2026-09-10, macOS 26.6.2 / arm64

No relaunch is required after granting Screen Recording: a process running since
before the grant captured 12 seconds after the toggle. See
`result-2026-09-10-screen-recording.log`.

`CGPreflightScreenCaptureAccess()` returned **false in the same log line as a
successful capture** — it is cached per process. Never gate on it alone.
