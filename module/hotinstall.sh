#!/system/bin/sh
# Runs after a hot install. Applies the current rules and refreshes the
# optional browser UI without waiting for a reboot.

DIR=/data/adb/split

[ -x "$DIR/splitctl" ] || exit 0

"$DIR/splitctl" apply
"$DIR/splitctl" serve
