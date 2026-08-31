#!/bin/bash
# rbk-toggle.sh — Pause / Resume the automatic backups (the two launchd jobs).
#
#   rbk-toggle.sh pause     stop the schedule; stays stopped across reboots until you resume
#   rbk-toggle.sh resume    start the schedule again
#   rbk-toggle.sh toggle    pause if running, resume if paused (used by the app button)
#   rbk-toggle.sh state     print: on | paused | off
#
# Pausing never affects "Back up now", Restore or any other manual tool.
set -u
RBK_TAG="toggle"
# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/rbk-lib.sh"

ACTION="${1:-toggle}"
case "$ACTION" in pause|resume|toggle|state|-h|--help) ;; *) echo "Usage: rbk-toggle.sh pause|resume|toggle|state"; exit 2 ;; esac
[ "$ACTION" = "-h" ] || [ "$ACTION" = "--help" ] && { sed -n '2,10p' "$0"; exit 0; }
rbk_load_config || exit 2

UID_="$(id -u)"
plist_of() { printf '%s\n' "$RBK_LAUNCH_AGENTS/$1.plist"; }

do_pause() {
    local L
    for L in "$RBK_LABEL_INTERVAL" "$RBK_LABEL_DAILY"; do
        if rbk_is_mac; then
            launchctl bootout "gui/$UID_/$L" >/dev/null 2>&1 || launchctl unload "$(plist_of "$L")" >/dev/null 2>&1 || true
            launchctl disable "gui/$UID_/$L" >/dev/null 2>&1 || true      # survives reboots and logins
        else
            rm -f "$RBK_STATE/test-auto-loaded"                              # Linux test stand-in
        fi
    done
    rbk_state_set paused-since "$(date '+%a %d %b %H:%M')"
    rbk_log "Automatic backups PAUSED by user"
    rbk_notify "rekordbox backup ⏸" "Automatic backups paused. Press Resume in the app when you want them back."
    rbk_say "⏸  Automatic backups are now PAUSED (they stay paused until you resume — even after a restart)."
    rbk_say "   Manual 'Back up now' and Restore keep working."
}

do_resume() {
    local L ok=1 p
    for L in "$RBK_LABEL_INTERVAL" "$RBK_LABEL_DAILY"; do
        if rbk_is_mac; then
            p="$(plist_of "$L")"
            [ -f "$p" ] || { rbk_say "❌ schedule file missing: $p — re-run Install.command"; ok=0; continue; }
            launchctl enable "gui/$UID_/$L" >/dev/null 2>&1 || true
            launchctl bootout "gui/$UID_/$L" >/dev/null 2>&1 || true
            if ! launchctl bootstrap "gui/$UID_" "$p" 2>/dev/null && ! launchctl load -w "$p" 2>/dev/null; then
                rbk_say "❌ could not load $L (see README › Troubleshooting)"; ok=0
            fi
        else
            touch "$RBK_STATE/test-auto-loaded"
        fi
    done
    [ $ok = 1 ] || { rbk_log "Resume FAILED"; exit 1; }
    rm -f "$RBK_STATE/paused-since"
    rbk_log "Automatic backups RESUMED by user"
    rbk_notify "rekordbox backup ▶" "Automatic backups resumed — next check $(rbk_next_check_text)."
    rbk_say "▶  Automatic backups are ON again (every 30 min after a session + daily 03:00)."
}

case "$ACTION" in
    state)  rbk_auto_state ;;
    pause)  do_pause ;;
    resume) do_resume ;;
    toggle)
        case "$(rbk_auto_state)" in
            on) do_pause ;;
            *)  do_resume ;;
        esac ;;
esac
exit 0
