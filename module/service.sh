#!/system/bin/sh

MODDIR=${0%/*}
DIR=/data/adb/split

sleep 20

# wait until the package manager can answer
i=0
while [ $i -lt 30 ]; do
  pm list packages >/dev/null 2>&1 && break
  sleep 2
  i=$((i+1))
done

# Self-heal before anything else. If $DIR was wiped (a hot reinstall runs the
# old uninstall.sh, which deletes it) the engine may only exist inside the
# module directory. Redeploy it from there instead of failing forever.
CTL="$MODDIR/bin/splitctl"
[ -x "$CTL" ] || CTL="$DIR/splitctl"
[ -x "$CTL" ] && "$CTL" provision >/dev/null 2>&1

[ -x "$DIR/splitctl" ] && CTL="$DIR/splitctl"

[ -f "$DIR/no_focus" ] || "$CTL" apply

# Optional browser UI. The KernelSU WebUI button does not need this.
"$CTL" serve
