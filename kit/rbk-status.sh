#!/bin/bash
# rbk-status.sh — show the state of the rekordbox backup.   --short = 5-line version for the app dialog
set -u
RBK_TAG="status"
# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/rbk-lib.sh"

SHORT=0; [ "${1:-}" = "--short" ] && SHORT=1

if ! rbk_load_config >/dev/null 2>&1; then
    echo "Not installed yet — run Install.command from the kit folder."; exit 0
fi

LAST_E=$(rbk_last_success_epoch)
LAST=$(rbk_state_get last-success); [ -n "$LAST" ] || LAST="never"
AGE=$(rbk_age_text "$LAST_E")
if rbk_dest_available; then DRIVE="✅ available"; else DRIVE="❌ NOT available (cloud app not running / disk not connected?)"; fi
if rbk_rekordbox_running; then RB="open (backups wait until it is closed)"; else RB="closed"; fi
SNAPS=$(ls -1d "$HISTORY_DIR"/daily_* "$HISTORY_DIR"/manual_* 2>/dev/null | wc -l | tr -d ' ')
AUTO_STATE=$(rbk_auto_state); AUTO_TEXT=$(rbk_auto_state_text)
if rbk_install_available; then SCRIPTS="$(rbk_install_text)"; else SCRIPTS="❌ NOT available: $INSTALL_DIR (cloud app not running / disk not connected?)"; fi
HEALTH="✅ OK"
if [ -z "$LAST_E" ]; then HEALTH="⚠️ no backup yet"
elif [ $(( ($(rbk_epoch) - LAST_E) / 86400 )) -ge "$STALE_DAYS" ]; then HEALTH="⚠️ last backup is $AGE"; fi
case "$AUTO_STATE" in paused) HEALTH="$HEALTH · ⏸ automatic backups PAUSED";; off) HEALTH="$HEALTH · ❌ schedule not loaded";; esac
rbk_install_available || HEALTH="$HEALTH · ❌ scripts folder not available"

if [ $SHORT = 1 ]; then
    printf '%s\n' "Status: $HEALTH" \
                  "Last backup: $LAST" \
                  "Automatic backups: $AUTO_TEXT" \
                  "Backup folder: $DRIVE" \
                  "rekordbox: $RB" \
                  "Snapshots kept: $SNAPS"
    [ "$(rbk_install_kind)" = local ] && rbk_install_available || printf '%s\n' "Scripts: $SCRIPTS"
    exit 0
fi

echo "rekordbox backup kit $RBK_VERSION — status $(rbk_now)"
echo "------------------------------------------------------------"
echo "Health:            $HEALTH"
echo "Last backup:       $LAST"
echo "Automatic backups: $AUTO_TEXT"
echo "Backup folder:     $BACKUP_DIR  — $DRIVE"
echo "rekordbox:         $RB  (version $(rbk_rekordbox_version))"
echo "Library:           $PIONEER_DIR"
echo "Scripts:           $SCRIPTS"
echo "App:               $RBK_APP_DIR/$RBK_APP_NAME"
MDB=$(rbk_find_master_db); [ -n "$MDB" ] && echo "master.db:         $(rbk_human "$(rbk_file_size "$MDB")")  $MDB"
if rbk_dest_available; then
    echo "Mirror (latest):   $(rbk_count_files "$LATEST_DIR/Pioneer") files, $(rbk_human "$(rbk_sum_bytes "$LATEST_DIR/Pioneer")")"
    echo "Snapshots kept:    $SNAPS   (newest: $(ls -1dt "$HISTORY_DIR"/daily_* "$HISTORY_DIR"/manual_* 2>/dev/null | head -n 1 | xargs -I{} basename {} 2>/dev/null))"
    OFF=$(ls -1t "$OFFICIAL_DIR"/*.zip 2>/dev/null | head -n 1)
    if [ -n "$OFF" ]; then echo "Official zip:      $(basename "$OFF")"; else echo "Official zip:      none yet — rekordbox: File › Library › Backup Library → save into $OFFICIAL_DIR"; fi
fi
if rbk_is_mac; then
    for L in "$RBK_LABEL_INTERVAL" "$RBK_LABEL_DAILY"; do
        if launchctl print "gui/$(id -u)/$L" >/dev/null 2>&1; then echo "Scheduled job:     ✅ $L"; else echo "Scheduled job:     ❌ $L not loaded (re-run Install.command)"; fi
    done
fi
echo "Log:               $RBK_LOG"
echo "------------------------------------------------------------"
echo "Recent log lines:"
tail -n 8 "$RBK_LOG" 2>/dev/null | sed 's/^/  /'
