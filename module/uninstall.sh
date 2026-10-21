#!/system/bin/sh

pkill -f "httpd.*split/www" 2>/dev/null

# full revert: every package back to working focus
[ -x /data/adb/split/splitctl ] && /data/adb/split/splitctl restore-all
[ -x /data/adb/split/splitctl ] && /data/adb/split/splitctl restore

rm -f /data/adb/service.d/split-watchdog.sh
rm -rf /data/adb/split
