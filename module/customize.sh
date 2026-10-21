#!/system/bin/sh

ui_print "- Split 2.0"
ui_print "- Per-app audio focus, managed from a local web page"
ui_print "- Reverts to normal focus when disabled, for real this time"

DIR=/data/adb/split

mkdir -p "$DIR" "$DIR/www"
cp -f "$MODPATH/bin/splitctl" "$DIR/splitctl"
chmod 0755 "$DIR/splitctl"
rm -rf "$DIR/www"
cp -a "$MODPATH/www" "$DIR/www"
chmod -R 0755 "$DIR/www"
find "$DIR/www" -type f -exec chmod 0644 {} \;
chmod 0755 "$DIR/www/cgi-bin/api"

[ -f "$DIR/config.tsv" ] || : > "$DIR/config.tsv"
[ -f "$DIR/enabled" ]    || echo 1 > "$DIR/enabled"
[ -f "$DIR/applied.txt" ] || : > "$DIR/applied.txt"

# boot watchdog: if the module is disabled or removed, undo the rules
mkdir -p /data/adb/service.d
cat > /data/adb/service.d/split-watchdog.sh <<'EOF'
#!/system/bin/sh
sleep 30
M=/data/adb/modules/split
if [ -d "$M" ] && [ ! -f "$M/disable" ] && [ ! -f "$M/remove" ]; then
  exit 0
fi
[ -x /data/adb/split/splitctl ] && /data/adb/split/splitctl restore
EOF
chmod 0755 /data/adb/service.d/split-watchdog.sh

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/bin/splitctl" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
