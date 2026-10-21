# Split

Global audio concurrency for rooted Android. Stop apps from pausing each other.

```
Music keeps playing over a video.
Two calls run at once.
Your keyboard's voice typing still works.
```

No companion app. No per-app configuration. No hooks. One module: enable it and audio stops being a zero-sum game, disable it and you are back to stock.

---

## The problem

Android's audio focus stack is a single-winner system. When one app starts playing, it asks for focus, and every other app is told to shut up. That is fine on a phone that plays one thing at a time. It is miserable on a tablet:

- You are listening to Spotify. You open a video. Spotify pauses.
- You are on a Discord call. Instagram calls you back. One of them silently gets nothing.
- You press the microphone key on your keyboard. It says *"microphone already in use"*, even though nothing is recording.

All three come from the same place: `AudioManager.requestAudioFocus()` and the policy that answers it.

## How it works

Split does not touch audio itself. It touches one app-op:

```
TAKE_AUDIO_FOCUS
```

Every app's request to own the audio output passes through this op. Split runs a sweep at boot and sets it to one of two values:

| Mode | Applied to | Effect |
|---|---|---|
| `ignore` | everything | the request is refused, so the app **cannot pause anyone** — but most apps keep playing anyway |
| `allow` | browsers, speech services, keyboards | the request succeeds, because these apps refuse to play without it |

That split is the whole design. Deny focus to a video app and it plays alongside your music. Deny focus to Chrome and it stops dead; deny it to a speech recogniser and it reports a phantom microphone conflict. Allow those, and everything works at once.

### The detail that matters most

On HyperOS, `TAKE_AUDIO_FOCUS: default` does **not** mean "stock behaviour". The platform resolves `default` through a restrictive default mode, so an app marked `default` still gets rejected. Exempt apps must be set to `allow` explicitly. If you fork this and wonder why your exemption does nothing, that is why. You can watch it happen: `rejectTime` keeps advancing on a package whose mode reads `default`.

### What is *not* in this module

- No Xposed, no LSPosed, no Zygisk module. Nothing is injected into any app's process.
- No vendor audio-policy overlay. An earlier build raised `maxOpenCount` on the capture ports to allow concurrent recording; it caused speech recognition to fail with a real "microphone in use" because the HAL ended up holding several parallel input streams. It was removed. Stock Android already multiplexes capture clients onto one stream, which is why voice messages work next to each other without help.
- No `aaudio.*` property changes. Tested and reverted: Chrome never used the MMAP path anyway.

## Install

1. Root with **KernelSU** or **Magisk**.
2. Flash `Split-Module-v1.0.0.zip`.
3. Reboot.

The sweep runs about 25 seconds after boot, once the package manager is up.

## Revert

**Disable the module → reboot.** The vendor overlay is gone with the module, and a watchdog at `/data/adb/service.d/split-watchdog.sh` runs on every boot; when it sees the module disabled or removed, it restores every package's op to `default`.

By hand, any time:

```sh
su -c /data/adb/split/splitctl restore
```

Uninstalling does the same and deletes the state directory.

## Allowing another app

Any app that goes **silent** instead of degrading gracefully needs to be on the allow list — it is refusing to play without focus. One line, no rebuild:

```sh
su -c 'echo com.example.app >> /data/adb/split/focus_allow'
su -c /data/adb/split/splitctl apply
```

The list survives reboots. Browsers (Chrome, Chrome Beta/Dev, Brave, Firefox, Edge, Opera, Samsung Internet, Vivaldi, DuckDuckGo), Google's speech service and Gboard are already on it.

Trade-off, stated plainly: allowed apps can pause other apps again. There is no mode where two apps both *own* focus — only modes where neither can enforce it.

## Compatibility

Tested working on:

- Xiaomi Pad 8 Pro
- Xiaomi Pad 7 Ultra
- Xiaomi Pad 7
- Poco X7 Pro
- Redmi 10 Pro Max

Reported working across Xiaomi / HyperOS devices generally. Other manufacturers are untested — the mechanism is plain AOSP, but the `default`-mode quirk above is HyperOS-specific, so behaviour elsewhere may differ. If you run it on something else, open an issue with the output of the debug commands below.

## Debugging

This module is a thin wrapper over two inspectable systems. Do not guess; read them.

### 1. Is the app-op actually applied?

```sh
su -c 'cmd appops get <package> TAKE_AUDIO_FOCUS'
```

You want `ignore` (normal apps) or `allow` (exempt apps). Watch `rejectTime` — if it is recent while the mode reads `default`, you have hit the HyperOS default-mode trap.

### 2. Who holds focus, and who asked?

```sh
su -c dumpsys audio | grep -A 40 "Audio Focus stack"
```

The `Events log: focus commands as seen by MediaFocusControl` section lists every request and abandon with package names. If your app requests and then loses, the stack tells you who beat it.

### 3. Is Xiaomi refusing on its own?

```sh
adb logcat -d -b all | grep -i hardening
```

On HyperOS you will see:

```
W AS.HardeningEnforcer: AudioHardening focus request for req 1 ignored for com.android.chrome (10174)
```

That single line is what proved the app-op path was the cause and not the audio hardware.

### 4. Did the audio stream actually open?

```sh
adb logcat -d -b all | grep -iE "AudioStreamBuilder|AudioTrack|MediaSessionService"
```

- `build() uid=... clientName=com.android.chrome` then `playbackState=PAUSED` within a second → **focus** problem, the app gave up after being refused.
- `AudioStreamBuilder` missing or followed by an open failure → **stream** problem, the HAL refused the device.
- `mStreamsIn size N` from the Xiaomi HAL → how many input streams are open at once. More than one is unusual and worth investigating.

### Reading the result

| Symptom | Layer | Fix |
|---|---|---|
| App plays then instantly pauses/stops | focus | add to `focus_allow` |
| "Microphone already in use" with nothing recording | focus on the recogniser's host app | add that host app to `focus_allow` |
| No audio but video runs | stream | check `dumpsys media.audio_flinger` |
| Everything pauses normally | sweep didn't run | `splitctl status`, check `service.sh` |

## Building it yourself

The module is just files and a zip — there is no compiler step.

**Linux / macOS / Termux:**

```sh
cd module
zip -r ../Split-Module-v1.0.0.zip . -x '.*'
```

**Windows:**

```powershell
./build.ps1
```

Requirements, in both cases:

- LF line endings on every script (`customize.sh`, `service.sh`, `bin/splitctl`, `update-binary`). CRLF silently breaks the shebang and the module installs but does nothing.
- Forward slashes in zip entry names. `Compress-Archive` writes backslashes and produces a zip Android cannot extract — `build.ps1` builds entries by hand for this reason.
- The `META-INF/com/google/android/update-binary` installer must stay in the archive.

After flashing, confirm it ran:

```sh
su -c /data/adb/split/splitctl status
su -c /data/adb/split/splitctl apply
```

## Layout

```
module/
  module.prop                 identity and version
  customize.sh                install-time setup + watchdog install
  service.sh                  boot-time sweep
  uninstall.sh                restore and clean up
  bin/splitctl                apply | restore | status
  META-INF/…/update-binary    KernelSU/Magisk installer
```

`splitctl` is the whole engine: it enumerates packages, sets the op, and logs counts to `/data/adb/split/split.log`.

## License

MIT. Fork it, break it, fix it.
