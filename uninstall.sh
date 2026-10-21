#!/system/bin/sh

/data/adb/split/splitctl restore
rm -f /data/adb/service.d/split-watchdog.sh
rm -rf /data/adb/split
