#!/bin/bash
# Settings — re-run the wizard (library / backup destination / music folder / where the scripts and the app are installed). Same as the app's Settings… button.
RBK_CFG="$HOME/Library/Application Support/rekordbox-backup/config.sh"; INSTALL_DIR=""
# shellcheck disable=SC1090
[ -f "$RBK_CFG" ] && . "$RBK_CFG" 2>/dev/null
KIT_BIN="${INSTALL_DIR:-$HOME/Library/Application Support/rekordbox-backup/bin}"   # this Mac, the backup folder, or wherever Settings put the scripts
HERE="$(cd "$(dirname "$0")/.." && pwd)"
if [ -x "$KIT_BIN/install.sh" ]; then S="$KIT_BIN/install.sh"; else S="$HERE/Install.command"; fi
clear; echo "▶ Settings — change folders"; echo
/bin/bash "$S" --reconfigure; RC=$?
exit $RC
