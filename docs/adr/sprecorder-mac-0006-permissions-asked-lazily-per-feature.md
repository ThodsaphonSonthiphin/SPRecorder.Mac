# Permissions are asked lazily, per feature, and refusal blocks only the core

```mermaid
flowchart TD
    Q{"When does the app ask<br/>for its TCC grants?"} -->|chosen| A["Lazily, when the feature<br/>that needs it is first used<br/>2 prompts to a first recording"]
    Q -->|rejected| B["All four up front<br/>shows the keylogger-shaped<br/>Input Monitoring prompt to<br/>every user before value is seen"]
    Q -->|rejected| C["Hybrid: core two up front,<br/>rest later<br/>calmer restart, but still a<br/>welcome wall before first use"]
    Q2{"What happens on refusal?"} -->|chosen| D["Core denied: refuse to record.<br/>Optional denied: degrade quietly"]
    Q2 -->|rejected| E["Always record what is possible<br/>silent half-capture of an<br/>unrepeatable meeting"]
    Q2 -->|rejected| F["Refuse until all four granted<br/>the Key caster becomes mandatory"]
```

## Which grants are actually required

Earlier decisions on this map removed more of these than the ticket assumed:

| grant | required for | when |
|---|---|---|
| **Microphone** | the Mic track | core |
| **Screen & System Audio Recording** | the System track, via ScreenCaptureKit | core |
| **Screen Recording** (video portion of the same grant) | the Screen recording | optional feature |
| **Input Monitoring** | the Key caster | optional feature |
| ~~Accessibility~~ | **nothing** | never asked |

**Accessibility is never requested.** `global-hotkey-mechanism` chose Carbon
`RegisterEventHotKey`, which needs no permission, so the port avoids the grant
entirely. `NSEvent` and `CGEventTap` would each have dragged it in.

On macOS 26 the Screen Recording panel is *"Screen & System Audio Recording"* and
carries an audio-only sub-toggle, so a user can grant system audio without
granting screen capture — which is exactly the split this ADR relies on.

## Why lazily

`ADR 0004` (Windows) makes the Screen recording an opt-in toggle, off by default,
and `ScreenRecordingEnabled` confirms it. So a new user who presses the hotkey
needs **two** grants, not four, and a user who never enables screen recording
never meets the Input Monitoring prompt — the one that reads as keylogging and is
most likely to end the install.

Asking up front was rejected because it puts the frightening prompt before any
demonstrated value. The hybrid was rejected for the same reason in weaker form.

> **Known cost of this choice.** Granting Screen Recording has historically
> required the app to be restarted before capture works, which is intrusive
> mid-recording. The mitigation is to preflight with
> `CGPreflightScreenCaptureAccess()` when the user *arms* recording rather than at
> the moment they press the hotkey, so any restart happens before a meeting is in
> progress. Verify the restart requirement on macOS 26 at first build.

## Why refusal blocks the core but not the extras

**A meeting happens once.** If system audio is denied and the app records anyway,
the user gets their own voice and none of the other participants — and finds out
after the meeting is over and unrepeatable. So a denied core grant refuses to
start a Recording Session, names the missing grant, and opens the correct System
Settings pane.

A denied **Input Monitoring** only disables the Key caster. The Recording Session
still runs, because losing the on-screen key display costs nothing that cannot be
recreated.

Refusing everything until all four are granted was rejected: it makes the Key
caster mandatory, and `ADR 0003` (Windows) already treats showing every keystroke
as a privacy trade-off a user should be able to decline.

## How a missing grant is shown

This reuses the existing visual language rather than inventing one:

- **`ADR 0017`** — a warning badge composited over the menu-bar icon, independent
  of the idle/recording base state, plus a menu item naming what is missing. A
  missing grant is exactly the ADR 0017 case: a capability that has silently
  failed and that the user must notice without already suspecting it.
- **`ADR 0016`** — at startup, **one consolidated alert** ("2 permissions
  missing"), never one per grant, and treated as a first alert only. The durable
  detail lives on the badge and in Settings.
- **`ADR 0018`** — resolved by the user acting, not by polling. The app re-checks
  when it next needs the capability, not on a timer.

Settings gains a Permissions view listing each grant, its state, and a button that
opens the matching System Settings pane.

## Consequences

Unblocks `signing-and-notarization` and contributes to `install-and-update-channel`.
`menu-bar-app-shape` inherits a requirement: the icon must support a badge overlay
and the menu must be able to name missing grants.
