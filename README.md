# Split

Per-app audio focus for rooted Android, with a WebUI button in KernelSU.

```
Music keeps playing over a game.
Any app can be switched back to normal behaviour.
Turn the whole thing off and it is genuinely off.
```

No companion app, no Xposed, no hooks. One module, one app-op, and a button on
the module card in the KernelSU manager.

---

## What v2 fixes

v1 set `TAKE_AUDIO_FOCUS` to `ignore` on every installed package and reverted
with `default`. **On HyperOS `default` is not stock.** The platform rejects the
focus request and logs:

```
W/AS.HardeningEnforcer: AudioHardening focus request for req 1 ignored
                        for com.spotify.music (10302), level: partial
W/AS.AudioService:      Audio focus request blocked by hardening
```

With v1 installed, every app sat in that state. Measured effect:

- Focus stack permanently empty: no app could ever own audio.
- Blocked apps retried **every 5 seconds, indefinitely** — thousands of rejected
  binder calls into `system_server` per day.
- Disabling the module changed nothing, because `restore()` wrote `default`,
  which was the exact state that was already broken.

Verified on device: setting a package to `allow` stops the retry loop instantly
and puts it back in the focus stack with `gain=GAIN`.

So v2 never writes `default`. Only two values:

| Value | Meaning |
|---|---|
| `allow` | app takes focus normally and can pause others (stock behaviour) |
| `ignore` | app never takes focus, so it plays over others (overlay) |

---

## What v2.0.2 fixes

If every tap in the WebUI answers **Failed**, this is why, and this is what
changed.

The engine lived at `/data/adb/split/splitctl`, and only `customize.sh` ever put
it there — once, at install time. A hot reinstall runs the *old* `uninstall.sh`
first, and that script deletes `/data/adb/split` outright. The incoming module
then had `hotinstall.sh` guarding itself with:

```sh
[ -x "$DIR/splitctl" ] || exit 0
```

so it quietly did nothing. End state: module files present, engine gone, every
WebUI action exec'ing a binary that does not exist (`exit 127`), surfaced to the
user as the single word "Failed".

v2.0.2 removes the dependency instead of documenting it:

- `splitctl provision` redeploys the engine from the module directory. Idempotent.
- `customize.sh`, `service.sh`, `hotinstall.sh` and the WebUI all run it first.
- The WebUI prepends a bootstrap to every `ksu.exec`, so a wiped state directory
  heals on the next tap even before the boot service has run.
- Failures report the reason — `Failed: appops rejected ...` — instead of "Failed".
- `set` applies to the device *before* writing config, and returns a non-zero exit
  code when appops rejects it. Config can no longer claim a state the device refused.

---

## The WebUI

Tap **WebUI** on the Split card in the KernelSU manager. There is no IP to look
up and no port to remember: the page runs inside the manager and talks to the
module through KernelSU's own `ksu.exec` bridge.

- **Master switch**: on applies your rules, off returns every app to `allow`.
- **Per app**: `Normal` or `Overlay`, one tap, applied immediately.
- **Search**: filters 400+ packages by name or label.
- **Reset all**: clears every rule and restores normal focus everywhere.

A browser build is also served for desktop use, at
`http://<device-ip>:<port>`. The port is chosen at boot and stored in
`/data/adb/split/port`; **if 8080 is taken it walks up to 8092 automatically**
instead of failing. `splitctl serve` prints the port it settled on.

Config lives in `/data/adb/split/`, outside the module directory, so it survives
reboots, module updates and even disabling the module.

```
/data/adb/split/config.tsv    pkg<TAB>ignore, one per line
/data/adb/split/enabled       1 or 0
/data/adb/split/applied.txt   what is currently set to ignore
/data/adb/split/port          chosen automatically, or pin your own
/data/adb/split/bind          optional, default 0.0.0.0
```

---

## Install

1. Root with **KernelSU** or **Magisk**.
2. Flash `Split-Module-v2.0.2.zip`.
3. Reboot.
4. Tap **WebUI** on the module card.

The module touches no system files, so it also works as a hot install where the
manager supports it.

The browser UI needs BusyBox; KernelSU and Magisk both ship one and the service
checks `/data/adb/ksu/bin/busybox`, `/data/adb/magisk/busybox` and `$PATH`. The
KernelSU WebUI needs nothing extra.

---

## Command line

```sh
su -c /data/adb/split/splitctl status
su -c /data/adb/split/splitctl provision  # redeploy the engine, idempotent
su -c '/data/adb/split/splitctl set com.spotify.music ignore'
su -c '/data/adb/split/splitctl set com.spotify.music allow'
su -c /data/adb/split/splitctl disable      # everything back to allow
su -c /data/adb/split/splitctl enable       # re-apply saved rules
su -c /data/adb/split/splitctl serve        # start the browser UI, prints port
su -c /data/adb/split/splitctl restore-all  # nuclear: allow on every package
```

`restore-all` is slow by nature: one appops write per installed package, roughly
a minute for ~450 packages. `restore` only touches packages Split has changed,
so it is near instant.

---

## Revert

Disable the module and reboot. The watchdog at
`/data/adb/service.d/split-watchdog.sh` sees the module disabled or removed and
runs `splitctl restore`, which sets every changed package back to `allow`.

By hand, any time:

```sh
su -c /data/adb/split/splitctl disable
```

Uninstalling does the same, then deletes `/data/adb/split` and the watchdog.

---

## Debugging

```sh
# what does the op actually say?
su -c 'cmd appops get com.spotify.music TAKE_AUDIO_FOCUS'

# who owns audio right now?
su -c 'dumpsys audio | grep -A6 "Audio Focus stack"'

# is anything still being blocked? these lines should stop appearing
su -c 'dumpsys audio | grep AudioHardening | tail'

# which port did the browser UI end up on?
su -c 'cat /data/adb/split/port'
```

Reading the result:

| Symptom | Meaning |
|---|---|
| `ignore`, app plays over others | working as configured |
| `allow`, app pauses when another starts | stock behaviour, working |
| `default` | broken state: run `splitctl apply` |
| `AudioHardening ... ignored` repeating | that package is not at `allow` |
| WebUI says `Failed` | engine missing from `/data/adb/split` (run `splitctl provision`), or appops rejected the package; the toast now names the reason |
| WebUI button missing | module not enabled, or `webroot/` missing from the module dir |
| Browser UI does not load | BusyBox missing, or `ps -A \| grep httpd` is empty |

---

## Compatibility

Tested on:

- Xiaomi Pad 8 Pro (HyperOS, Android 16), where the `default` behaviour above was
  measured
- Xiaomi Pad 7 Ultra, Xiaomi Pad 7
- Poco X7 Pro, Redmi 10 Pro Max

The `default`-is-not-stock quirk is HyperOS-specific. On other ROMs `default` may
well behave like stock; v2 avoids it either way, so behaviour is the same
everywhere.

Requires KernelSU or Magisk.

---

## Building

No compiler step.

**Linux / macOS / Termux**
```sh
cd module && zip -r ../Split-Module-v2.0.2.zip . -x '.*'
```

**Windows**
```powershell
./build.ps1
```

Requirements:

- LF line endings on every script (`customize.sh`, `service.sh`,
  `bin/splitctl`, `www/cgi-bin/api`, `hotinstall.sh`, `update-binary`). CRLF
  silently breaks the shebang.
- Forward slashes in zip entry names. `Compress-Archive` writes backslashes and
  produces a zip Android cannot extract; `build.ps1` builds entries by hand.
- `META-INF/com/google/android/update-binary` must stay in the archive.
- `webroot/` must be named exactly that and contain `index.html`. Do not set
  permissions on it: KernelSU applies its own ownership and SELinux context.

## Layout

```
module/
  module.prop                 identity and version
  customize.sh                install-time setup, watchdog, hot install
  service.sh                  boot: apply rules, start the browser UI
  hotinstall.sh               run right after a hot install
  uninstall.sh                restore, stop server, clean up
  bin/splitctl                provision | apply | restore | restore-all | set |
                              enable | disable | serve | status
  webroot/index.html          the KernelSU WebUI
  www/index.html              same page, served over HTTP
  www/cgi-bin/api             JSON API behind it
  META-INF/.../update-binary  KernelSU/Magisk installer
```

## License

MIT.
