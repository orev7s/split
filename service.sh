#!/system/bin/sh

MODDIR=${0%/*}

sleep 25

[ -f /data/adb/split/no_focus ] && exit 0

/data/adb/split/splitctl apply
