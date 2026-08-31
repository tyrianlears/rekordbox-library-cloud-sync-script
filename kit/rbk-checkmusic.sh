#!/bin/bash
# rbk-checkmusic.sh [folder] — is the music really on this Mac?
# Counts "online-only" placeholder files (Google Drive Stream mode, iCloud, OneDrive Files On-Demand) that rekordbox cannot play.
# STRICTLY READ-ONLY: this script only reads file metadata; it never writes, moves or deletes anything.
# Default folder: the Music folder from config.sh. Use --backup to check the backup folder instead.
set -u
RBK_TAG="checkmusic"
# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/rbk-lib.sh"

TARGET=""
case "${1:-}" in
    --backup) rbk_load_config || exit 2; TARGET="$BACKUP_DIR" ;;
    "")       rbk_load_config || exit 2; TARGET="$MUSIC_DIR"
              [ -n "$TARGET" ] || { echo "No music folder set. Open the app › More… › Settings… and choose it (or run: rbk-checkmusic.sh /path/to/Music)."; exit 1; } ;;
    *)        TARGET="$1" ;;
esac
[ -d "$TARGET" ] || { echo "Folder not found: $TARGET"; exit 1; }

echo "Checking: $TARGET"
echo "(read-only scan — nothing is modified)"
echo

# A placeholder has a size but no data blocks allocated on disk.
if rbk_is_mac; then FMT='%z %b %N'; STAT=(stat -f "$FMT"); else FMT='%s %b %n'; STAT=(stat -c "$FMT"); fi
RESULT=$(find "$TARGET" -type f ! -name .DS_Store -print0 2>/dev/null | xargs -0 "${STAT[@]}" 2>/dev/null | awk '
    { size=$1; blocks=$2; $1=""; $2=""; name=substr($0,3); total++; bytes+=size
      if (size>0 && blocks==0) { ph++; phbytes+=size; if (ph<=15) list=list "   " name "\n" } }
    END { printf "%d\t%d\t%d\t%d\n%s", total, bytes, ph+0, phbytes+0, list }')

SUMMARY=$(printf '%s\n' "$RESULT" | head -n 1)
LIST=$(printf '%s\n' "$RESULT" | tail -n +2)
TOTAL=$(echo "$SUMMARY" | cut -f1); BYTES=$(echo "$SUMMARY" | cut -f2); PH=$(echo "$SUMMARY" | cut -f3); PHB=$(echo "$SUMMARY" | cut -f4)

echo "Files:                 $TOTAL  ($(rbk_human "$BYTES"))"
echo "Online-only (missing): $PH  ($(rbk_human "$PHB") still to download)"
if [ "$PH" -eq 0 ]; then
    echo
    echo "✅ Everything is available offline — rekordbox can use every file."
    rbk_log "checkmusic: $TARGET — $TOTAL files, all offline"
else
    echo
    echo "⚠️  $PH file(s) are online-only placeholders. rekordbox will show them as missing or fail to load them."
    echo "   Fix: in Finder, right-click the folder and choose the 'keep on this Mac' option of your cloud app"
    echo "   (Google Drive / Dropbox: 'Make available offline' · iCloud: 'Download Now' / 'Keep Downloaded' ·"
    echo "   OneDrive: 'Always Keep on This Device' · Box: 'Make Available Offline'), wait for the download to"
    echo "   finish (the cloud app's menu-bar icon shows progress), then run this check again."
    [ -n "$LIST" ] && { echo "   First examples:"; printf '%s\n' "$LIST"; }
    rbk_log "checkmusic: $TARGET — $PH of $TOTAL files are online-only"
fi

# Second opinion where the OS supports the 'dataless' flag (macOS File Provider placeholders)
if rbk_is_mac; then
    DL=$(find "$TARGET" -type f -flags +dataless -print 2>/dev/null | wc -l | tr -d ' ')
    [ -n "$DL" ] && echo "   (macOS 'dataless' flag count: $DL)"
fi
