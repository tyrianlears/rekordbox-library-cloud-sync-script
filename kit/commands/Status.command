#!/bin/bash
# Backup status — double-click to run. Same action as the button in "rekordbox Backup.app".
# Uses the installed kit (~/Library/Application Support/rekordbox-backup/bin); falls back to the scripts next to this file.
KIT_BIN="$HOME/Library/Application Support/rekordbox-backup/bin"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
if [ -x "$KIT_BIN/rbk-status.sh" ]; then S="$KIT_BIN/rbk-status.sh"; else S="$HERE/rbk-status.sh"; fi
clear; echo "▶ Backup status"; echo
/bin/bash "$S" ; RC=$?
echo; [ $RC -eq 0 ] && echo "Done. You can close this window." || echo "Finished with a problem (code $RC) — see the messages above or README › Troubleshooting."
[ -t 0 ] && { printf 'Press Enter to close… '; read -r _; }
exit $RC
