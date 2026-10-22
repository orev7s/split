#!/system/bin/sh
# Runs after a hot install. Applies the current rules and refreshes the
# optional browser UI without waiting for a reboot.
#
# This must NOT bail out when $DIR/splitctl is missing: customize.sh is what
# creates it, and a hot reinstall deletes $DIR first via the old uninstall.sh.
# Provision from the module directory, then continue.

MODDIR=${0%/*}
DIR=/data/adb/split

CTL="$MODDIR/bin/splitctl"
[ -x "$CTL" ] || CTL="$DIR/splitctl"
[ -x "$CTL" ] || exit 0

"$CTL" provision >/dev/null 2>&1
[ -x "$DIR/splitctl" ] && CTL="$DIR/splitctl"

"$CTL" apply
"$CTL" serve
