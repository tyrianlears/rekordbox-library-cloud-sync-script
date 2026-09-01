#!/bin/bash
# Restore drill — safe rehearsal, live library untouched — double-click to run. Same action as the button in "rekordbox Backup.app".
# Uses the installed scripts (location from config.sh); falls back to the scripts next to this file.
RBK_CFG="$HOME/Library/Application Support/rekordbox-backup/config.sh"; INSTALL_DIR=""
# shellcheck disable=SC1090
[ -f "$RBK_CFG" ] && . "$RBK_CFG" 2>/dev/null
KIT_BIN="${INSTALL_DIR:-$HOME/Library/Application Support/rekordbox-backup/bin}"   # this Mac, the backup folder, or wherever Settings put the scripts
HERE="$(cd "$(dirname "$0")/.." && pwd)"
if [ -x "$KIT_BIN/rbk-restore.sh" ]; then S="$KIT_BIN/rbk-restore.sh"; else S="$HERE/rbk-restore.sh"; fi
clear; echo "▶ Restore drill — safe rehearsal, live library untouched"; echo
/bin/bash "$S" --drill; RC=$?
echo; [ $RC -eq 0 ] && echo "Done. You can close this window." || echo "Finished with a problem (code $RC) — see the messages above or README › Troubleshooting."
[ -t 0 ] && { printf 'Press Enter to close… '; read -r _; }
exit $RC
