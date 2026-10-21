# Split

Per-app audio focus for rooted Android, with a local web UI.

```
Music keeps playing over a game.
Any app can be switched back to normal behaviour.
Turn the whole thing off and it is genuinely off.
```

No companion app, no Xposed, no hooks. One module, one app-op, and a page at
`http://<device-ip>:8080` that writes the rules.

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

With v1 installed, every app on the device sat in that state. Measured effect:

- Focus stack permanently empty — no app could ever own audio.
- Blocked apps retried **every 5 seconds, indefinitely** — thousands of rejected
  binder calls into `system_server` per day.
- Disabling the module changed nothing, because `restore()` wrote `default`,
  which is the exact state that was already broken.

Verified on device: setting a package to `allow` stops the retry loop instantly
and puts it back in the focus stack with `gain=GAIN`.

So v2 never writes `default`. Only:

| Value | Meaning |
|---|---|
| `allow` | app takes focus normally and can pause others — **stock behaviour** |
| `ignore` | app never takes focus, so it plays over others — **overlay** |

---

## The web UI

Open `http://<device-ip>:8080` from the tablet or any machine on the same
network.

- **Master switch** — on applies your rules, off returns every app to `allow`.
- **Per app** — `Normal` or `Overlay`, one tap, applied immediately.
- **Search** — filters 400+ packages instantly.
- **Reset all** — clears every rule and restores normal focus everywhere.

Config lives in `/data/adb/split/`, outside the module directory, so it
survives reboots, module updates and even disabling the module.

```
/data/adb/split/config.tsv    pkg<TAB>ignore, one per line
/data/adb/split/enabled       1 or 0
/data/adb/split/applied.txt   what is currently set to ignore
/data/adb/split/port          optional, default 8080
/data/adb/split/bind          optional, default 0.0.0.0
```

The server is BusyBox `httpd`, started at boot by `service.sh`. It runs whether
or not Split is enabled — otherwise there would be no way to switch it back on.

---

## Install

1. Root with **KernelSU** or **Magisk**.
2. Flash `Split-Module-v2.0.0.zip`.
3. Reboot.
4. Open `http://<device-ip>:8080`.

BusyBox is required for the web UI. KernelSU and Magisk both ship one; the
service checks `/data/adb/ksu/bin/busybox`, `/data/adb/magisk/busybox` and
`$PATH`.

---

## Command line

```sh
su -c /data/adb/split/splitctl status
su -c '/data/adb/split/splitctl set com.spotify.music ignore'
su -c '/data/adb/split/splitctl set com.spotify.music allow'
su -c /data/adb/split/splitctl disable     # everything back to allow
su -c /data/adb/split/splitctl enable      # re-apply saved rules
su -c /data/adb/split/splitctl restore-all # nuclear: allow on every package
```

`restore-all` is slow by nature — one appops write per installed package,
roughly a minute for ~450 packages. `restore` only touches packages Split has
changed, so it is near instant.

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
```

Reading the result:

| Symptom | Meaning |
|---|---|
| `ignore`, app plays over others | working as configured |
| `allow`, app pauses when another starts | stock behaviour, working |
| `default` | broken state — run `splitctl apply` |
| `AudioHardening ... ignored` repeating | that package is not at `allow`; either set it to `allow` or accept it is in overlay mode |
| Web page does not load | BusyBox missing, or `service.sh` did not run; check `ps -A \| grep httpd` |

---

## Compatibility

Tested on:

- Xiaomi Pad 8 Pro (HyperOS, Android 16) — where the `default` behaviour above
  was measured
- Xiaomi Pad 7 Ultra, Xiaomi Pad 7
- Poco X7 Pro, Redmi 10 Pro Max

The `default`-is-not-stock quirk is HyperOS-specific. On other ROMs `default`
may well behave like stock; v2 avoids it either way, so behaviour is the same
everywhere.

Requires KernelSU or Magisk. No per-app configuration app is needed or provided
beyond the web page.

---

## Building

No compiler step.

**Linux / macOS / Termux**
```sh
cd module && zip -r ../Split-Module-v2.0.0.zip . -x '.*'
```

**Windows**
```powershell
./build.ps1
```

Requirements:

- LF line endings on every script (`customize.sh`, `service.sh`, `bin/splitctl`,
  `www/cgi-bin/api`, `update-binary`). CRLF silently breaks the shebang.
- Forward slashes in zip entry names. `Compress-Archive` writes backslashes and
  produces a zip Android cannot extract; `build.ps1` builds entries by hand.
- `META-INF/com/google/android/update-binary` must stay in the archive.
- `www/cgi-bin/api` must be executable after install — `customize.sh` sets it.

## Layout

```
module/
  module.prop                 identity and version
  customize.sh                install-time setup + watchdog install
  service.sh                  boot: apply rules, start the web UI
  uninstall.sh                restore, stop server, clean up
  bin/splitctl                apply | restore | restore-all | set | enable | disable | status
  www/index.html              the UI
  www/cgi-bin/api             JSON API behind it
  META-INF/…/update-binary    KernelSU/Magisk installer
```

## License

MIT.
