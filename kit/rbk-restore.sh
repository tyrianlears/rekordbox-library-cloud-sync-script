#!/bin/bash
# rbk-restore.sh — restore the rekordbox library from the backup folder.
#
#   (no option)   interactive restore: pick latest or a dated snapshot, confirm, restore, verify
#   --list        show what is available to restore
#   --drill       SAFE TEST: restore into a scratch folder and verify; the live library is not touched
#   --rollback    undo the most recent restore (puts the pre-restore copy back)
#   --from NAME   restore this snapshot non-interactively (still asks for the final confirmation)
#   --yes         skip the typed confirmation (for use by people who know what they are doing)
#
# Every real restore first moves your current library aside as
#   ~/Library/Pioneer.pre-restore_<timestamp>   (and the same for Application Support/Pioneer)
# so a restore can always be undone with --rollback.
set -u
RBK_TAG="restore"
# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/rbk-lib.sh"

ACTION="interactive"; FROM=""; YES=0
while [ $# -gt 0 ]; do
    case "$1" in
        --list) ACTION="list" ;;
        --drill) ACTION="drill" ;;
        --rollback) ACTION="rollback" ;;
        --from) FROM="$2"; shift ;;
        --yes) YES=1 ;;
        -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1"; exit 2 ;;
    esac
    shift
done

rbk_load_config || exit 2
RSYNC="$(rbk_rsync_bin)"
TS=$(rbk_now_id)
# safety copies live next to the folders they came from: <library>.pre-restore_<ts>
# (a suffix is added if a copy with the same timestamp already exists — never move INTO an existing folder)
unique_ts() { local i=1 t="$TS"; while [ -e "$PIONEER_DIR.pre-restore_$t" ] || [ -e "$PIONEER_DIR.undone-restore_$t" ]; do i=$((i+1)); t="${TS}_$i"; done; printf '%s' "$t"; }
TS=$(unique_ts)
PRE_LIB="$PIONEER_DIR.pre-restore_$TS";   PRE_SET="$APPSUPPORT_DIR.pre-restore_$TS"
UNDONE_LIB="$PIONEER_DIR.undone-restore_$TS"; UNDONE_SET="$APPSUPPORT_DIR.undone-restore_$TS"

hr() { printf '%s\n' "------------------------------------------------------------"; }
ask() {   # prompt default -> REPLY
    local p="$1" d="${2:-}"
    printf '%s' "$p"; read -r REPLY; [ -n "$REPLY" ] || REPLY="$d"
}

need_drive() {
    rbk_dest_available || { rbk_say "❌ Backup folder not available: $BACKUP_DIR"; rbk_say "   Make sure the cloud app is running and signed in (or the disk is connected), then try again."; exit 4; }
    [ -d "$LATEST_DIR/Pioneer" ] || { rbk_say "❌ No backup found in $LATEST_DIR"; exit 1; }
    [ -n "$(find "$LATEST_DIR/Pioneer" -maxdepth 3 -name master.db 2>/dev/null | head -n 1)" ] || { rbk_say "❌ The backup in $LATEST_DIR is empty (no master.db) — nothing to restore from. Run 'Back up now' first, or check the backup folder in Settings…"; exit 1; }
}

list_sources() {
    need_drive
    hr; rbk_say "Available restore points in $BACKUP_DIR"; hr
    local info="$LATEST_DIR/BACKUP-INFO.txt" when="(unknown date)"
    [ -f "$info" ] && when=$(grep '^Backed up:' "$info" | sed 's/^Backed up: *//')
    rbk_say "  [0] latest    — full library incl. analysis data, backed up $when"
    local i=0 p
    SNAPS=""
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        i=$((i+1)); SNAPS="$SNAPS$p"$'\n'
        rbk_say "  [$i] $(basename "$p")  — database as of that date ($(rbk_human "$(rbk_sum_bytes "$p")"))"
    done < <(ls -1dt "$HISTORY_DIR"/daily_* "$HISTORY_DIR"/manual_* 2>/dev/null)
    [ $i -eq 0 ] && rbk_say "  (no dated snapshots yet)"
    hr
    rbk_say "A dated snapshot = full library from 'latest' + the database (playlists, cues, tags) as of that date."
}

# Copy latest (+ optional snapshot overlay) into the given target roots
restore_into() {   # pioneer_target appsupport_target snapshot_path_or_empty
    local pt="$1" at="$2" snap="$3"
    mkdir -p "$pt" "$at"
    rbk_say "Copying library…  (several GB: this takes a few minutes; on a new Mac it also downloads from the cloud)"
    "$RSYNC" -a --delete "$LATEST_DIR/Pioneer/" "$pt/" 2>>"$RBK_LOG" || return 1
    if [ -d "$LATEST_DIR/ApplicationSupport-Pioneer" ]; then
        "$RSYNC" -a --delete "$LATEST_DIR/ApplicationSupport-Pioneer/" "$at/" 2>>"$RBK_LOG" || return 1
    fi
    if [ -n "$snap" ]; then
        rbk_say "Applying database snapshot $(basename "$snap")…"
        "$RSYNC" -a "$snap/Pioneer/" "$pt/" 2>>"$RBK_LOG" || return 1
        [ -d "$snap/ApplicationSupport-Pioneer" ] && "$RSYNC" -a "$snap/ApplicationSupport-Pioneer/" "$at/" 2>>"$RBK_LOG"
    fi
    rm -f "$pt/BACKUP-INFO.txt" "$pt/SNAPSHOT-INFO.txt" 2>/dev/null
    return 0
}

verify_target() {   # pioneer_target -> prints result, returns 0/1
    local pt="$1" sc dc sb db mdb
    sc=$(rbk_count_files "$LATEST_DIR/Pioneer"); dc=$(rbk_count_files "$pt")
    sb=$(rbk_sum_bytes "$LATEST_DIR/Pioneer"); db=$(rbk_sum_bytes "$pt")
    # master.db must exist at the SAME relative place as in the backup, and must not be empty
    local rel; rel=$(cd "$LATEST_DIR/Pioneer" 2>/dev/null && find . -maxdepth 3 -name master.db 2>/dev/null | head -n 1)
    mdb="$pt/${rel#./}"
    rbk_say "Verification: backup $sc files / $(rbk_human "$sb")  →  restored $dc files / $(rbk_human "$db")"
    if [ -z "$rel" ] || [ ! -s "$mdb" ]; then rbk_say "❌ master.db missing or empty in the restored library"; return 1; fi
    rbk_say "master.db: $(rbk_human "$(rbk_file_size "$mdb")")  ($mdb)"
    [ "$dc" -ge "$sc" ] || { rbk_say "❌ fewer files than the backup — restore incomplete"; return 1; }
    return 0
}

confirm_typed() {
    [ $YES = 1 ] && return 0
    ask "Type RESTORE (in capitals) to continue, anything else to abort: "
    [ "$REPLY" = "RESTORE" ] || { rbk_say "Aborted — nothing was changed."; exit 0; }
}

# ---------------------------------------------------------------------------
case "$ACTION" in
list)
    list_sources; exit 0 ;;

drill)
    need_drive
    DRILL="$HOME/rekordbox-restore-drill"
    hr; rbk_say "RESTORE DRILL — a safe rehearsal. Your live library will NOT be touched."; hr
    rbk_say "Target: $DRILL"
    rm -rf "$DRILL"
    if restore_into "$DRILL/Pioneer" "$DRILL/ApplicationSupport-Pioneer" "" && verify_target "$DRILL/Pioneer"; then
        rbk_say "✅ DRILL PASSED — the backup restores cleanly."
        rbk_log "Restore drill passed"
    else
        rbk_say "❌ DRILL FAILED — do not rely on this backup until fixed. See $RBK_LOG"; rbk_log "Restore drill FAILED"
        exit 1
    fi
    ask "Delete the drill folder now? [Y/n] " "Y"
    case "$REPLY" in [Nn]*) rbk_say "Kept: $DRILL (delete it yourself later)";; *) rm -rf "$DRILL"; rbk_say "Drill folder deleted.";; esac
    exit 0 ;;

rollback)
    hr; rbk_say "ROLLBACK — put the library from before the last restore back in place."; hr
    PRE=$(ls -1d "$PIONEER_DIR".pre-restore_* 2>/dev/null | sort -r | head -n 1)
    [ -n "$PRE" ] || { rbk_say "No pre-restore copy found — nothing to roll back."; exit 1; }
    STAMP=${PRE##*.pre-restore_}
    PRE_AS="$APPSUPPORT_DIR.pre-restore_$STAMP"
    rbk_say "Will restore: $PRE"
    if rbk_rekordbox_running; then rbk_say "rekordbox is open — quitting it…"; rbk_quit_rekordbox || { rbk_say "Could not quit rekordbox. Quit it manually and retry."; exit 3; }; fi
    rbk_stop_agent
    confirm_typed
    [ -d "$PIONEER_DIR" ] && mv "$PIONEER_DIR" "$UNDONE_LIB"
    mv "$PRE" "$PIONEER_DIR" || { rbk_say "❌ move failed"; exit 1; }
    if [ -d "$PRE_AS" ]; then
        [ -d "$APPSUPPORT_DIR" ] && mv "$APPSUPPORT_DIR" "$UNDONE_SET"
        mv "$PRE_AS" "$APPSUPPORT_DIR"
    fi
    rbk_log "Rollback done: $PRE -> $PIONEER_DIR"
    rbk_say "✅ Rolled back. The restored library was kept as $UNDONE_LIB (delete it when happy)."
    exit 0 ;;

interactive)
    need_drive
    hr; rbk_say "EMERGENCY RESTORE of the rekordbox library"; hr
    if rbk_rekordbox_running; then
        ask "rekordbox is open. Quit it now? [Y/n] " "Y"
        case "$REPLY" in [Nn]*) rbk_say "Restore needs rekordbox closed. Aborting."; exit 3;; esac
        rbk_quit_rekordbox || { rbk_say "❌ rekordbox did not quit. Quit it manually (Cmd-Q) and run Restore again."; exit 3; }
    fi
    rbk_stop_agent
    SNAP=""
    if [ -n "$FROM" ]; then
        [ "$FROM" = latest ] || { SNAP="$HISTORY_DIR/$FROM"; [ -d "$SNAP" ] || { rbk_say "Snapshot not found: $FROM"; exit 1; }; }
    else
        list_sources
        ask "Which restore point? [0] " "0"
        if [ "$REPLY" != "0" ]; then
            case "$REPLY" in ''|*[!0-9]*) rbk_say "Invalid choice."; exit 1;; esac
            SNAP=$(printf '%s' "$SNAPS" | sed -n "${REPLY}p")
            [ -n "$SNAP" ] && [ -d "$SNAP" ] || { rbk_say "Invalid choice."; exit 1; }
        fi
    fi
    hr
    rbk_say "About to replace:"
    rbk_say "   $PIONEER_DIR"
    rbk_say "   $APPSUPPORT_DIR"
    rbk_say "with the backup in $BACKUP_DIR${SNAP:+ + snapshot $(basename "$SNAP")}."
    rbk_say "Your current library will first be moved to $PRE_LIB (undo: Restore rollback)."
    hr
    confirm_typed
    if ! rbk_lock; then rbk_say "A backup is running right now — wait a minute and retry."; exit 1; fi
    trap 'rbk_unlock' EXIT

    # 1. safety copy (instant rename, no extra disk space)
    if [ -d "$PIONEER_DIR" ]; then mv "$PIONEER_DIR" "$PRE_LIB" || { rbk_say "❌ could not move the current library aside"; exit 1; }; fi
    if [ -d "$APPSUPPORT_DIR" ]; then mv "$APPSUPPORT_DIR" "$PRE_SET" 2>/dev/null; fi
    rbk_log "Restore started: pre-restore copy = $PRE_LIB; source = latest${SNAP:+ + $(basename "$SNAP")}"

    # 2. restore
    if ! restore_into "$PIONEER_DIR" "$APPSUPPORT_DIR" "$SNAP"; then
        rbk_say "❌ Restore copy failed. Putting your previous library back…"
        rm -rf "$PIONEER_DIR"; mv "$PRE_LIB" "$PIONEER_DIR"
        [ -d "$PRE_SET" ] && { rm -rf "$APPSUPPORT_DIR"; mv "$PRE_SET" "$APPSUPPORT_DIR"; }
        rbk_log "Restore FAILED and was undone"; exit 1
    fi

    # 3. verify
    if verify_target "$PIONEER_DIR"; then
        rbk_log "Restore complete and verified"
        rbk_prune_prerestore
        hr
        rbk_say "✅ RESTORE COMPLETE"
        rbk_say "Next: open rekordbox and check your playlists, a few tracks and their waveforms."
        rbk_say "   • Tracks with an orange '!' → the music paths differ (new Mac / new user name): run Fix paths from the app."
        rbk_say "   • Something wrong? Undo with: app → More… → Restore rollback  (or rbk-restore.sh --rollback)."
        rbk_say "Your previous library is kept for safety at $PRE_LIB"
        rbk_notify "rekordbox Backup" "Restore complete. Open rekordbox to check your library."
    else
        rbk_say "❌ Verification failed — putting your previous library back…"
        rm -rf "$PIONEER_DIR"; mv "$PRE_LIB" "$PIONEER_DIR"
        [ -d "$PRE_SET" ] && { rm -rf "$APPSUPPORT_DIR"; mv "$PRE_SET" "$APPSUPPORT_DIR"; }
        rbk_say "   Your previous library is back in place. Nothing was lost. See $RBK_LOG"
        rbk_log "Restore verification FAILED and was undone"; exit 1
    fi
    exit 0 ;;
esac
