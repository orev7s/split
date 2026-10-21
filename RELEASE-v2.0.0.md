## Split 2.0.0

Per-app audio focus, with a web UI, and a revert that actually reverts.

### The bug in 1.0.0

v1 set `TAKE_AUDIO_FOCUS=ignore` on every installed package and restored with
`TAKE_AUDIO_FOCUS=default`.

On HyperOS `default` is **not** stock. The platform rejects the focus request:

```
W/AS.HardeningEnforcer: AudioHardening focus request for req 1 ignored
                        for com.spotify.music (10302), level: partial
W/AS.AudioService:      Audio focus request blocked by hardening
```

So `restore` was a no-op. Disabling or uninstalling the module changed nothing:
every app stayed rejected, the focus stack stayed empty, and blocked apps
retried **every 5 seconds indefinitely** — thousands of rejected binder calls
into `system_server` per day.

Verified on device: setting a package to `allow` stops the loop immediately and
returns it to the focus stack with `gain=GAIN`.

### What 2.0 does

Never writes `default`. Two values only:

| Value | Effect |
|---|---|
| `allow` | app takes focus normally, can pause others — stock behaviour |
| `ignore` | app never takes focus, plays over others — overlay |

- **Web UI** at `http://<device-ip>:8080` — master switch, search, per-app
  `Normal`/`Overlay`, applied instantly, plus a one-tap Reset all.
- **Per-app rules** in `/data/adb/split/config.tsv`, outside the module
  directory, so they survive reboots and module updates.
- **Exact revert** — only packages Split actually changed are touched, so
  disabling is instant and complete.
- **Boot watchdog** restores normal focus when the module is disabled or removed.
- **No global sweep** — about 20 app-ops writes at boot instead of ~447, and
  `service.sh` waits for the package manager before applying.

### Install

1. Root with KernelSU or Magisk.
2. Flash `Split-Module-v2.0.0.zip`.
3. Reboot.
4. Open `http://<device-ip>:8080`.

If you are coming from 1.0.0, uninstall it and reboot first, or run
`splitctl restore-all` once — that clears the 447 `default` leftovers.

### Verified

Tested on Xiaomi Pad 8 Pro (HyperOS, Android 16): rules apply and revert
correctly, `disable` returns all 447 packages to `allow`, web UI reachable over
LAN, `cmd appops get` matches the UI for every change.
