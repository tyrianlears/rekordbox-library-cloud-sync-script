#!/bin/bash
# rbk-selftest.sh — check that everything the backup needs is in place. Safe to run any time.
set -u
RBK_TAG="selftest"
# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/rbk-lib.sh"
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"

PASS=0; WARN=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✅ $*"; }
warn() { WARN=$((WARN+1)); echo "  ⚠️  $*"; }
bad()  { FAIL=$((FAIL+1)); echo "  ❌ $*"; }

echo "rekordbox backup kit $RBK_VERSION — self-test $(rbk_now)"
echo "------------------------------------------------------------"

# 1. platform & tools
if rbk_is_mac; then ok "macOS $(sw_vers -productVersion 2>/dev/null)"; else warn "not macOS ($(uname -s)) — launchd/app checks skipped"; fi
RS=$(rbk_rsync_bin); if [ -n "$RS" ]; then ok "rsync: $RS ($("$RS" --version 2>/dev/null | head -n 1 | cut -c1-40))"; else bad "rsync not found"; fi
command -v python3 >/dev/null 2>&1 && ok "python3: $(python3 --version 2>&1)" || warn "python3 not found (only needed by Fix paths on a new Mac with a different user name)"

# 2. config
if rbk_load_config >/dev/null 2>&1; then ok "config: $RBK_CONFIG"; else bad "config missing — run Install.command"; echo; echo "Result: $PASS ok, $WARN warnings, $FAIL failed"; exit 1; fi

# 3. sources
if [ -d "$PIONEER_DIR" ]; then ok "library folder: $PIONEER_DIR ($(rbk_count_files "$PIONEER_DIR") files, $(rbk_human "$(rbk_sum_bytes "$PIONEER_DIR")"))"; else bad "library folder not found: $PIONEER_DIR"; fi
MDB=$(rbk_find_master_db)
if [ -n "$MDB" ] && [ -s "$MDB" ]; then ok "master.db: $(rbk_human "$(rbk_file_size "$MDB")") — $MDB"; else bad "master.db not found under $PIONEER_DIR"; fi
[ -d "$APPSUPPORT_DIR" ] && ok "settings folder: $APPSUPPORT_DIR" || warn "settings folder not found: $APPSUPPORT_DIR (rekordbox not opened yet on this Mac?)"

# 4. backup destination
if [ -n "$DRIVE_ROOT" ]; then if [ -d "$DRIVE_ROOT" ]; then ok "cloud/disk root: $DRIVE_ROOT"; else bad "cloud/disk root missing: $DRIVE_ROOT (cloud app not running / disk not connected?)"; fi; fi
if [ -z "$MUSIC_DIR" ]; then warn "music folder not set (optional — only used by Check music; set it in the app › Settings…)"
elif [ -d "$MUSIC_DIR" ]; then ok "music folder: $MUSIC_DIR (read-only for this kit)"; else warn "music folder not found: $MUSIC_DIR"; fi
if [ -d "$BACKUP_DIR" ]; then
    ok "backup folder: $BACKUP_DIR"
    T="$BACKUP_DIR/logs/.selftest-$$"
    if mkdir -p "$BACKUP_DIR/logs" 2>/dev/null && echo test > "$T" 2>/dev/null && rm -f "$T"; then ok "backup folder is writable"; else bad "cannot write into the backup folder (permission? see README › Troubleshooting)"; fi
else
    bad "backup folder missing: $BACKUP_DIR"
fi

# 5. installed pieces
[ -f "$RBK_LOCAL_BIN/rbk-launch.sh" ] && ok "launcher on this Mac: $RBK_LOCAL_BIN/rbk-launch.sh" || bad "launcher missing: $RBK_LOCAL_BIN/rbk-launch.sh (re-run Install.command)"
if rbk_install_available; then ok "scripts: $(rbk_install_text)"; else bad "scripts not available at $INSTALL_DIR — cloud app not running / disk not connected? (or re-run Install.command)"; fi
if rbk_is_mac; then
    for L in "$RBK_LABEL_INTERVAL" "$RBK_LABEL_DAILY"; do
        if launchctl print "gui/$(id -u)/$L" >/dev/null 2>&1; then ok "scheduled job loaded: $L"; else bad "scheduled job NOT loaded: $L (re-run Install.command)"; fi
    done
    [ -d "$RBK_APP_DIR/$RBK_APP_NAME" ] && ok "app: $RBK_APP_DIR/$RBK_APP_NAME" || warn "app not found in $RBK_APP_DIR (re-run Install.command)"
fi

# 6. state
LE=$(rbk_last_success_epoch)
if [ -n "$LE" ]; then ok "last successful backup: $(rbk_age_text "$LE")"; else warn "no backup has run yet"; fi
rbk_rekordbox_running && warn "rekordbox is open right now (backups wait until it is closed)" || ok "rekordbox is closed"

# 7. dry run
echo
echo "Dry-run backup (nothing is written):"
if "$RBK_BIN/rbk-backup.sh" --force --dry-run >/dev/null 2>&1 || "$KIT_DIR/rbk-backup.sh" --force --dry-run >/dev/null 2>&1; then ok "dry-run backup works"; else bad "dry-run backup failed — see $RBK_LOG"; fi

echo "------------------------------------------------------------"
echo "Result: $PASS ok, $WARN warnings, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ Ready." || echo "❌ Fix the items marked ❌ (README › Troubleshooting), then run the self-test again."
[ $FAIL -eq 0 ]
