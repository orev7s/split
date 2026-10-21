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

[ -f "$DIR/no_focus" ] || "$DIR/splitctl" apply

# Optional browser UI. The KernelSU WebUI button does not need this.
"$DIR/splitctl" serve
