#!/bin/bash
# Settings — re-run the folder wizard (rekordbox library / backup destination / music folder). Same as the app's Settings… button.
KIT_BIN="$HOME/Library/Application Support/rekordbox-backup/bin"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
if [ -x "$KIT_BIN/install.sh" ]; then S="$KIT_BIN/install.sh"; else S="$HERE/Install.command"; fi
clear; echo "▶ Settings — change folders"; echo
/bin/bash "$S" --reconfigure; RC=$?
exit $RC
