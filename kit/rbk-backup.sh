#!/bin/bash
# rbk-backup.sh — back up the rekordbox library to the backup folder (cloud folder or disk chosen in setup).
#
#   --auto      scheduled run (launchd): silent, skips if nothing changed or rekordbox is open
#   --force     "Back up now": always mirrors, always makes a manual_ snapshot, always notifies
#   --daily     also run the daily housekeeping (snapshot check, retention, stale alert, log copy)
#   --dry-run   show what would happen, change nothing
#   --verbose   print log lines even when not in a terminal
#
# Exit codes: 0 done/nothing to do · 1 failure · 2 config problem · 3 rekordbox open · 4 Drive unavailable
set -u
RBK_TAG="backup"
# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/rbk-lib.sh"

MODE="auto"; DAILY=0; DRYRUN=0
for a in "$@"; do
    case "$a" in
        --auto) MODE="auto" ;;
        --force) MODE="force" ;;
        --daily) DAILY=1 ;;
        --dry-run) DRYRUN=1 ;;
        --verbose) RBK_VERBOSE=1 ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "Unknown option: $a"; exit 2 ;;
    esac
done
export RBK_VERBOSE="${RBK_VERBOSE:-0}"

rbk_load_config || exit 2
[ $MODE = auto ] && rbk_state_set last-run-epoch "$(rbk_epoch)"
RSYNC="$(rbk_rsync_bin)"
[ -n "$RSYNC" ] || { rbk_fail "rsync not found on this Mac"; exit 1; }

STAMP="$RBK_STATE/last-backup.stamp"
START=$(rbk_epoch)

# ---- excludes for rsync (same names as the find() prune list) ----
EXCL=(--exclude=.DS_Store --exclude='*.log')
for n in $RBK_EXCLUDE_DIRS; do EXCL[${#EXCL[@]}]="--exclude=$n/"; done

# ---- helpers -------------------------------------------------------------
stale_check() {
    local last; last=$(rbk_last_success_epoch); [ -n "$last" ] || return 0
    local age=$(( ($(rbk_epoch) - last) / 86400 ))
    if [ "$age" -ge "$STALE_DAYS" ]; then
        rbk_log "WARNING: last successful backup was $age days ago"
        rbk_notify "rekordbox Backup — attention" "No successful backup for $age days. Open the app and press Back up now."
    fi
}

write_info() {   # BACKUP-INFO.txt in latest/
    local out="$LATEST_DIR/BACKUP-INFO.txt"
    {
        echo "rekordbox backup kit $RBK_VERSION"
        echo "Backed up:        $(rbk_now)"
        echo "Mode:             $MODE"
        echo "Computer:         $(hostname 2>/dev/null)"
        echo "macOS user:       ${USER:-$(id -un)}  (home: $HOME)"
        rbk_is_mac && echo "macOS:            $(sw_vers -productVersion 2>/dev/null)"
        echo "rekordbox:        $(rbk_rekordbox_version)"
        echo "Source 1:         $PIONEER_DIR  -> latest/Pioneer/"
        echo "Source 2:         $APPSUPPORT_DIR  -> latest/ApplicationSupport-Pioneer/"
        echo "master.db:        $(rbk_find_master_db)"
        echo "Files:            $SRC_COUNT  ($(rbk_human "$SRC_BYTES"))"
        echo "DB fingerprint:   $FP"
        echo
        echo "Restore: open 'rekordbox Backup.app' > Restore…  (or run kit/rbk-restore.sh in Terminal)."
        echo "New Mac: follow README.md section 'Moving to a new laptop'."
    } > "$out" 2>/dev/null
}

mirror_one() {   # src dst label
    local src="$1" dst="$2" label="$3" rc
    [ -d "$src" ] || { rbk_log "Skip $label: $src not found"; return 0; }
    mkdir -p "$dst"
    if [ $DRYRUN = 1 ]; then
        rbk_say "--- dry run: $label ---"
        "$RSYNC" -a -n -v --delete "${EXCL[@]}" "$src/" "$dst/" | grep -v '^\./\?$' | head -n 40
        return 0
    fi
    "$RSYNC" -a --delete "${EXCL[@]}" "$src/" "$dst/" 2>>"$RBK_LOG"; rc=$?
    case $rc in
        0) return 0 ;;
        23|24) rbk_log "rsync reported partial transfer for $label (code $rc) — usually a file that changed during copy; will retry next run"; return 0 ;;
        *) rbk_fail "rsync failed for $label (code $rc). See $RBK_LOG"; return 1 ;;
    esac
}

make_snapshot() {   # name  -> copies database-level files (everything except share/ analysis trees)
    local name="$1" dst="$HISTORY_DIR/$1"
    [ $DRYRUN = 1 ] && { rbk_say "dry run: would create snapshot $name"; return 0; }
    mkdir -p "$dst"
    "$RSYNC" -a --exclude='share/' --exclude='USBANLZ/' "${EXCL[@]}" "$PIONEER_DIR/" "$dst/Pioneer/" 2>>"$RBK_LOG" || { rbk_fail "snapshot $name failed"; rm -rf "$dst"; return 1; }
    if [ -d "$APPSUPPORT_DIR" ]; then
        "$RSYNC" -a "${EXCL[@]}" "$APPSUPPORT_DIR/" "$dst/ApplicationSupport-Pioneer/" 2>>"$RBK_LOG" || true
    fi
    printf 'snapshot=%s\ncreated=%s\nfingerprint=%s\nrekordbox=%s\n' "$name" "$(rbk_now)" "$FP" "$(rbk_rekordbox_version)" > "$dst/SNAPSHOT-INFO.txt"
    rbk_state_set snapshot-fingerprint "$FP"
    rbk_log "Snapshot created: $name ($(rbk_human "$(rbk_sum_bytes "$dst")"))"
}

# ---- 0. lock -------------------------------------------------------------
if ! rbk_lock; then rbk_log "Another backup/restore is running — skipping"; exit 0; fi
trap 'rbk_unlock' EXIT

# ---- 1. preconditions ----------------------------------------------------
if ! rbk_drive_available; then
    rbk_log "SKIP: backup folder not available ($BACKUP_DIR). Cloud app not running / disk not connected?"
    [ $MODE = force ] && rbk_notify "rekordbox Backup" "Backup folder not available. Is the cloud app running (or the disk connected)?"
    [ $DAILY = 1 ] && stale_check
    exit 4
fi
if [ ! -d "$PIONEER_DIR" ]; then rbk_fail "rekordbox library folder not found: $PIONEER_DIR"; exit 1; fi
if rbk_rekordbox_running; then
    if [ $MODE = force ] && [ -t 0 ]; then
        printf 'rekordbox is open. Quit it now and continue with the backup? [Y/n] '; read -r REPLY
        case "$REPLY" in [Nn]*) rbk_say "A safe backup needs rekordbox closed. Nothing was done."; exit 3;; esac
        rbk_say "Quitting rekordbox…"
        rbk_quit_rekordbox || { rbk_say "❌ rekordbox did not quit. Quit it manually (⌘Q) and run Back up now again."; exit 3; }
    else
        rbk_log "SKIP: rekordbox is open — will try again later"
        [ $MODE = force ] && rbk_notify "rekordbox Backup" "rekordbox is open. Quit it, then press Back up now."
        [ $DAILY = 1 ] && stale_check
        exit 3
    fi
fi

# ---- 2. change detection (auto only) -------------------------------------
if [ $MODE = auto ] && [ $DRYRUN = 0 ] && [ -f "$STAMP" ] && ! rbk_sources_changed_since "$STAMP"; then
    rbk_log "No changes since last backup ($(rbk_age_text "$(rbk_last_success_epoch)")) — nothing to do"
    if [ $DAILY = 1 ]; then rbk_prune_history; stale_check; fi
    exit 0
fi

# ---- 3. mirror ----------------------------------------------------------
CHANGED=""   # files changed since the last backup (for the notification)
if [ -f "$STAMP" ]; then CHANGED=$(rbk_count_changed_since "$STAMP"); fi
FP=$(rbk_db_fingerprint)
SRC_COUNT=$(( $(rbk_count_files "$PIONEER_DIR") + $(rbk_count_files "$APPSUPPORT_DIR") ))
SRC_BYTES=$(( $(rbk_sum_bytes "$PIONEER_DIR") + $(rbk_sum_bytes "$APPSUPPORT_DIR") ))
rbk_log "Backup starting ($MODE): $SRC_COUNT files, $(rbk_human "$SRC_BYTES") — rekordbox $(rbk_rekordbox_version)"
[ $MODE = force ] && rbk_say "Mirroring the library to $BACKUP_DIR … (the first run can take several minutes)"

mkdir -p "$LATEST_DIR" "$HISTORY_DIR" "$OFFICIAL_DIR" "$DRIVE_LOG_DIR" 2>/dev/null
mirror_one "$PIONEER_DIR" "$LATEST_DIR/Pioneer" "library" || exit 1
mirror_one "$APPSUPPORT_DIR" "$LATEST_DIR/ApplicationSupport-Pioneer" "settings" || exit 1
[ $DRYRUN = 1 ] && { rbk_say "dry run complete — nothing was changed."; exit 0; }

# ---- 4. verify the mirror -------------------------------------------------
DST_COUNT=$(( $(rbk_count_files "$LATEST_DIR/Pioneer") + $(rbk_count_files "$LATEST_DIR/ApplicationSupport-Pioneer") ))
DST_BYTES=$(( $(rbk_sum_bytes "$LATEST_DIR/Pioneer") + $(rbk_sum_bytes "$LATEST_DIR/ApplicationSupport-Pioneer") ))
MDB=$(rbk_find_master_db)
if [ -n "$MDB" ] && [ ! -s "$LATEST_DIR/Pioneer/${MDB#$PIONEER_DIR/}" ]; then
    rbk_fail "master.db is missing from the mirror — backup NOT trusted"; exit 1
fi
if [ "$SRC_COUNT" != "$DST_COUNT" ] || [ "$SRC_BYTES" != "$DST_BYTES" ]; then
    rbk_log "WARNING: mirror differs from source (source $SRC_COUNT files/$SRC_BYTES B, mirror $DST_COUNT files/$DST_BYTES B). A file may have changed during the copy; will re-check next run."
fi

# ---- 5. snapshots ----------------------------------------------------------
LAST_FP=$(rbk_state_get snapshot-fingerprint)
TODAY_DAILY="$HISTORY_DIR/daily_$(rbk_today)"
SNAPSHOT_MADE=""
if [ $MODE = force ]; then
    make_snapshot "manual_$(rbk_now_id)" && SNAPSHOT_MADE="manual"
elif [ ! -d "$TODAY_DAILY" ] && { [ -z "$LAST_FP" ] || [ "$FP" != "$LAST_FP" ]; }; then
    make_snapshot "daily_$(rbk_today)" && SNAPSHOT_MADE="daily"
else
    rbk_log "Database unchanged since last snapshot — no new snapshot"
fi

# ---- 6. state, info, housekeeping ----------------------------------------
touch "$STAMP"
rbk_state_set last-success-epoch "$(rbk_epoch)"
rbk_state_set last-success "$(rbk_now) ($MODE) — $SRC_COUNT files, $(rbk_human "$SRC_BYTES")"
write_info
ELAPSED=$(( $(rbk_epoch) - START ))
rbk_log "Backup complete: $SRC_COUNT files, $(rbk_human "$SRC_BYTES")${CHANGED:+, $CHANGED changed} in ${ELAPSED}s -> $LATEST_DIR"
if [ $DAILY = 1 ] || [ $MODE = force ]; then
    rbk_prune_history
    [ $MODE = force ] || stale_check
    tail -n 300 "$RBK_LOG" > "$DRIVE_LOG_DIR/rekordbox-backup.log" 2>/dev/null
fi

if [ -z "$CHANGED" ]; then WHAT="first full backup: $SRC_COUNT files, $(rbk_human "$SRC_BYTES")"
elif [ "$CHANGED" = "0" ]; then WHAT="no changes — library re-verified"
elif [ "$CHANGED" = "1" ]; then WHAT="1 file updated"
else WHAT="$CHANGED files updated"; fi
[ -n "$SNAPSHOT_MADE" ] && WHAT="$WHAT + $SNAPSHOT_MADE snapshot"
if [ $MODE = force ] || [ "$NOTIFY_SUCCESS" = "1" ]; then
    rbk_notify "rekordbox backup ✓" "$(date '+%H:%M') · $WHAT · ${ELAPSED}s"
fi
[ $MODE = force ] && rbk_say "✅ Backup complete — $WHAT ($SRC_COUNT files, $(rbk_human "$SRC_BYTES") in ${ELAPSED}s). You can close this window."
exit 0
