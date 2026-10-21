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

# Web UI. Started whether or not Split is enabled, because it is the only way
# to switch it back on. Bind address can be pinned in $DIR/bind, port in $DIR/port.
BB=""
for c in /data/adb/ksu/bin/busybox /data/adb/magisk/busybox /system/bin/busybox; do
  [ -x "$c" ] && { BB="$c"; break; }
done
[ -n "$BB" ] || BB=$(command -v busybox 2>/dev/null)

if [ -n "$BB" ]; then
  PORT=$(cat "$DIR/port" 2>/dev/null)
  [ -n "$PORT" ] || PORT=8080
  BIND=$(cat "$DIR/bind" 2>/dev/null)
  [ -n "$BIND" ] || BIND=0.0.0.0

  pkill -f "httpd.*split/www" 2>/dev/null
  sleep 1
  $BB httpd -p "$BIND:$PORT" -h "$DIR/www" >/dev/null 2>&1
fi
