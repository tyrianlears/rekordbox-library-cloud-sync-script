#!/bin/bash
# rbk-launch.sh — the small local launcher used by the two launchd jobs.
#
# The kit's scripts can be installed on this Mac (default), inside the backup folder (cloud folder or disk)
# or anywhere else — INSTALL_DIR in config.sh says where. launchd always calls THIS file, which lives on the
# Mac, so a missing scripts folder (cloud app not running, disk unplugged) is logged and announced with a
# notification (at most once every 12 hours) instead of failing silently inside launchd.
#
#   rbk-launch.sh --auto            run the scheduled backup from wherever the scripts are installed
#   rbk-launch.sh --auto --daily    same, with the daily housekeeping
# Standalone on purpose: it must work even when rbk-lib.sh is not reachable.
set -u
HOME_DIR="${RBK_HOME:-$HOME/Library/Application Support/rekordbox-backup}"
LOG_DIR="${RBK_LOG_DIR:-$HOME/Library/Logs/rekordbox-backup}"
LOG="$LOG_DIR/rekordbox-backup.log"
STATE="$HOME_DIR/state"
INSTALL_DIR=""
# shellcheck disable=SC1090
[ -f "$HOME_DIR/config.sh" ] && . "$HOME_DIR/config.sh" 2>/dev/null
INSTALL_DIR="${INSTALL_DIR:-$HOME_DIR/bin}"

if [ -f "$INSTALL_DIR/rbk-backup.sh" ]; then
    exec /bin/bash "$INSTALL_DIR/rbk-backup.sh" "$@"
fi

# ---- scripts folder not available ---------------------------------------------------------------
mkdir -p "$LOG_DIR" "$STATE" 2>/dev/null
printf '%s [launch] SKIP: scripts folder not available: %s (cloud app not running / disk not connected?)\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$INSTALL_DIR" >> "$LOG" 2>/dev/null
NOW=$(date '+%s'); LAST=$(cat "$STATE/launch-miss-notified" 2>/dev/null); LAST=${LAST:-0}
if [ $((NOW - LAST)) -ge 43200 ]; then
    printf '%s\n' "$NOW" > "$STATE/launch-miss-notified" 2>/dev/null
    MSG="Automatic backup skipped: the scripts folder is not available ($INSTALL_DIR). Start the cloud app or connect the disk."
    [ -n "${RBK_TEST_NOTIFY_LOG:-}" ] && printf '%s | %s\n' "rekordbox Backup — attention" "$MSG" >> "$RBK_TEST_NOTIFY_LOG"
    if [ "$(uname -s)" = "Darwin" ] && command -v osascript >/dev/null 2>&1; then
        M=$(printf '%s' "$MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')
        osascript -e "display notification \"$M\" with title \"rekordbox Backup — attention\"" >/dev/null 2>&1 || true
    fi
fi
exit 4
