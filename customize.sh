#!/system/bin/sh

ui_print "- Split"
ui_print "- Audio focus relaxed at boot for every installed app"
ui_print "- Browsers, speech services and IMEs exempted so they still play"
ui_print "- Reverts automatically when the module is disabled"

mkdir -p /data/adb/split
cp -f "$MODPATH/bin/splitctl" /data/adb/split/splitctl
chmod 0755 /data/adb/split/splitctl

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
