# Split v2.0.2

Fixes the WebUI reporting **Failed** on every tap, and removes the class of bug
that caused it.

## Root cause

The engine (`splitctl`) was deployed to `/data/adb/split/splitctl` by
`customize.sh` **once, at install time**. Nothing ever re-created it.

A hot reinstall runs the previous module's `uninstall.sh`, which does:

```sh
rm -f /data/adb/service.d/split-watchdog.sh
rm -rf /data/adb/split
```

The incoming module then ran `hotinstall.sh`, which started with:

```sh
[ -x "$DIR/splitctl" ] || exit 0
```

So it provisioned nothing, applied nothing and started no server — silently.

Observed on a Xiaomi Pad 8 Pro (HyperOS, Android 16):

```
/data/adb/split: No such file or directory
/data/adb/service.d: (empty)
$ adb shell /data/adb/split/splitctl set com.spotify.music ignore
/system/bin/sh: /data/adb/split/splitctl: inaccessible or not found
exit=127
```

The WebUI turns any non-zero `ksu.exec` errno into the toast `Failed`, so a
missing binary and a rejected app-op were indistinguishable to the user.

The engine itself was never the problem:

```sh
$ cmd appops set com.android.settings TAKE_AUDIO_FOCUS ignore   # rc=0
$ cmd appops get com.android.settings TAKE_AUDIO_FOCUS
TAKE_AUDIO_FOCUS: ignore
```

## Changes

- **`splitctl provision`** — new subcommand. Idempotently recreates the state
  directory and redeploys the engine from wherever the script itself lives.
  `customize.sh`, `service.sh`, `hotinstall.sh` and the WebUI all call it first.
- **WebUI self-heal** — every `ksu.exec` is prefixed with a bootstrap that
  redeploys the engine if `/data/adb/split/splitctl` is missing, so a tap works
  even before `service.sh` has run (it sleeps 20 s at boot).
- **`hotinstall.sh` no longer bails** when the state directory is gone.
- **Honest failures** — `set` applies to the device before writing config and
  returns non-zero when appops rejects the package. The toast now reads
  `Failed: appops rejected <pkg> -> ignore (is the package installed?)`.
- **`config.tsv` can no longer claim a state the device refused**, because the
  write now happens after a successful app-op change.
- **`apply` counts failures** — `applied: N ignore, M allow, K failed`.
- **`build.sh` derives the version from `module.prop`** instead of the hardcoded
  `v1.0.0` that it had been shipping under.

## Verified

On device, against a sandboxed state directory:

| Case | Result |
|---|---|
| `provision` with state dir deleted | recreates dir + engine, `rc=0` |
| WebUI bootstrap, state dir deleted | self-heals, command runs, `rc=0` |
| `set <pkg> ignore` | app-op becomes `ignore`, config written |
| `set <pkg> allow` | app-op back to `allow` |
| `set <nonexistent-pkg> ignore` | `rc=1` with a named reason |

## Upgrade

Flash over the top; no reboot needed. If the WebUI is already open, reload it.
