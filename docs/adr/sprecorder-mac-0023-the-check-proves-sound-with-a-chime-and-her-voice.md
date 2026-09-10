# Check my setup proves sound by hearing it: a chime and her voice

```mermaid
flowchart TD
    Q{"How does the check prove the<br/>Mic track and System track<br/>really hear something?"} -->|chosen| A["Chime + speak<br/>the Mac plays a short chime,<br/>she is asked to say something;<br/>both lines mean 'it heard it'"]
    Q -->|rejected| B["Speak only<br/>catches a wrong or muted microphone,<br/>but computer audio only proves<br/>it opened - silence is expected"]
    Q -->|rejected| C["Silent, as sprecorder-mac-0017 first wrote it<br/>'recorded 2 seconds, N kB' -<br/>two seconds of silence makes<br/>a file too"]
```

When she presses **Check my setup**, the Mac plays a short chime and the window asks
her to **say something**. The microphone line passes only if it heard her voice; the
computer audio line passes only if it caught the chime.

## Why a file size proves nothing

`sprecorder-mac-0017` wrote the report line as *"recorded 2 seconds, N kB"*. A file of
silence has a size too, so that line passes in exactly the cases most likely to reach
the developer as *"the recording has no sound"*:

- the wrong microphone is chosen — a USB headset left in a drawer, a phone offered as a
  microphone;
- the input volume is at zero;
- computer audio opens without error and hears nothing.

Worked through: she plugs in a headset and leaves it in the drawer. The silent check
reports everything working, and her next meeting's *My microphone* file is silent. This
check instead says the microphone *heard only silence* — before any meeting.

## What each audio line can say

| line | passes when | otherwise |
|---|---|---|
| Microphone | her voice lifts the level clearly above the room during the listening window | *heard only silence* — with a hint to check which microphone is chosen — or *could not record*, naming the fix |
| Computer audio | the chime is found in the captured computer audio | *heard nothing* or *could not record*, naming the fix |

Three outcomes, not two: *heard only silence* is not the same fault as *could not
record*, and the fix differs — one is a permission, the other is a device or a volume.

## The rejected options

- **Speak only** catches the microphone faults but leaves computer audio proving only
  that it opened, because nothing is playing during a check. The chime is what turns
  that line into evidence.
- **Silent** is `sprecorder-mac-0017`'s original wording. It proves the pipe opened and
  writes a file, which the fakes in `sprecorder-mac-0015` already prove without hardware.

## Costs, accepted

- **The check makes a sound and asks her to talk.** She is in Settings on purpose, not
  in a meeting, so the intrusion lands at the one moment it costs nothing.
- **The prompt comes before the listening window, not inside it**, so she is not asked
  to speak into a window that has already half closed. The window itself stays about the
  two seconds `sprecorder-mac-0017` chose.

## To verify at build time

- **SPRecorder must be able to record its own chime.** A real Recording Session never
  needs to hear SPRecorder, and the computer-audio capture may be set to leave the app's
  own sound out. The check needs that sound included. `sprecorder-mac-0021` moves
  computer audio to its own capture path, independent of the screen, so this is a
  property of that path — measure it there.
- **Whether the chime is still caught with the output muted, or with headphones in.** If
  a muted Mac hides the chime from capture, the line must say *turn the volume up and
  check again*, not blame a permission.

## Consequences

- `sprecorder-mac-0017`'s report table no longer decides pass or fail by size. The byte
  count may still appear where the developer reads it; the words she sees are decided
  with the rest of the report under `setup-self-check`.
- The "heard it" judgement is a level threshold on a short buffer and a match against a
  known chime — logic that belongs in the Core behind a protocol
  (`sprecorder-mac-0002`), so the fakes can feed it a voice, a chime and silence.
