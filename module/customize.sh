#!/system/bin/sh

ui_print "- Split 2.0.2"
ui_print "- Per-app audio focus with a KernelSU WebUI button"
ui_print "- Reverts to normal focus when disabled, for real this time"
ui_print "- Recovers itself if /data/adb/split gets wiped"

# Nothing here touches system files, so the module can go live immediately
# instead of waiting for a reboot.
export MODULE_HOT_INSTALL_REQUEST=true
export MODULE_HOT_RUN_SCRIPT=hotinstall.sh

DIR=/data/adb/split

# Permissions first: provision executes this binary.
set_perm "$MODPATH/bin/splitctl" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/hotinstall.sh" 0 0 0755
set_perm "$MODPATH/module.prop" 0 0 0644

mkdir -p "$DIR"

# Deployment lives in splitctl itself (`provision`) so install, boot and the
# WebUI share one code path. Do not duplicate the copy logic here: doing that
# is exactly what let a hot reinstall leave the module with no engine at all.
"$MODPATH/bin/splitctl" provision \
  || ui_print "! engine not deployed; WebUI will self-heal on first tap"

# The browser build is optional distinct content, so it is staged here only.
rm -rf "$DIR/www"
cp -a "$MODPATH/www" "$DIR/www" 2>/dev/null
chmod 0755 "$DIR/www" 2>/dev/null
chmod 0755 "$DIR/www/cgi-bin" 2>/dev/null
chmod 0644 "$DIR/www/index.html" 2>/dev/null
chmod 0755 "$DIR/www/cgi-bin/api" 2>/dev/null

[ -f "$DIR/config.tsv" ]  || : > "$DIR/config.tsv"
[ -f "$DIR/enabled" ]     || echo 1 > "$DIR/enabled"
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
CTL=/data/adb/split/splitctl
[ -x "$CTL" ] || CTL=/data/adb/modules/split/bin/splitctl
[ -x "$CTL" ] && "$CTL" restore
EOF
chmod 0755 /data/adb/service.d/split-watchdog.sh

# Per-file permissions only. KernelSU sets ownership/SELinux for webroot/
# itself and warns against touching it, so it is left alone here.
set_perm "$MODPATH/bin/splitctl" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/hotinstall.sh" 0 0 0755
set_perm "$MODPATH/module.prop" 0 0 0644
