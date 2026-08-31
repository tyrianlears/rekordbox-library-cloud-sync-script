#!/bin/bash
# Restore drill — safe rehearsal, live library untouched — double-click to run. Same action as the button in "rekordbox Backup.app".
# Uses the installed kit (~/Library/Application Support/rekordbox-backup/bin); falls back to the scripts next to this file.
KIT_BIN="$HOME/Library/Application Support/rekordbox-backup/bin"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
if [ -x "$KIT_BIN/rbk-restore.sh" ]; then S="$KIT_BIN/rbk-restore.sh"; else S="$HERE/rbk-restore.sh"; fi
clear; echo "▶ Restore drill — safe rehearsal, live library untouched"; echo
/bin/bash "$S" --drill; RC=$?
echo; [ $RC -eq 0 ] && echo "Done. You can close this window." || echo "Finished with a problem (code $RC) — see the messages above or README › Troubleshooting."
[ -t 0 ] && { printf 'Press Enter to close… '; read -r _; }
exit $RC
