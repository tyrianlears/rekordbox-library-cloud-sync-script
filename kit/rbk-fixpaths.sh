#!/bin/bash
# rbk-fixpaths.sh — after restoring on a Mac with a DIFFERENT user name, rewrite the paths
# inside the restored library from /Users/<old>/... to /Users/<new>/...
#
#   rbk-fixpaths.sh                 dry run: detect old/new user names and count what would change
#   rbk-fixpaths.sh --apply         actually rewrite (settings files + master.db), safety copies first
#   --old NAME / --new NAME         override the detected user names
#
# Not needed at all if the new Mac uses the same user name as the old one (recommended).
# Part 1 (settings files) needs nothing extra. Part 2 (master.db) needs Python 3 + pyrekordbox:
#     python3 -m pip install --user pyrekordbox
set -u
RBK_TAG="fixpaths"
# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/rbk-lib.sh"
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"

APPLY=0; OLD=""; NEW=""
while [ $# -gt 0 ]; do
    case "$1" in
        --apply) APPLY=1 ;;
        --old) OLD="$2"; shift ;;
        --new) NEW="$2"; shift ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1"; exit 2 ;;
    esac; shift
done

[ -n "$NEW" ] || NEW=$(basename "$HOME")
if [ -z "$OLD" ]; then
    # first /Users/<name>/ mentioned in the restored settings files
    OLD=$(grep -rhoE '/Users/[^/"<>]+/' "$APPSUPPORT_DIR" 2>/dev/null | grep -v "^/Users/$NEW/" | head -n 1 | cut -d/ -f3)
fi
[ -n "$OLD" ] || { echo "Could not detect an old user name in $APPSUPPORT_DIR — pass --old NAME."; exit 1; }
[ "$OLD" != "$NEW" ] || { echo "Old and new user names are both '$NEW' — nothing to fix."; exit 0; }

echo "Rewrite  /Users/$OLD/  →  /Users/$NEW/"
[ $APPLY = 1 ] || echo "(dry run — add --apply to make changes)"
echo

if rbk_rekordbox_running; then echo "❌ rekordbox is open. Quit it first."; exit 3; fi
rbk_stop_agent

# ---- Part 1: settings files -------------------------------------------------
echo "Part 1 — settings files in $APPSUPPORT_DIR"
COUNT=0
while IFS= read -r -d '' f; do
    n=$(grep -c "/Users/$OLD/" "$f" 2>/dev/null || true)
    [ "${n:-0}" -gt 0 ] || continue
    COUNT=$((COUNT+n))
    echo "   $n occurrence(s): ${f#$APPSUPPORT_DIR/}"
    if [ $APPLY = 1 ]; then
        cp -p "$f" "$f.pre-fixpaths_$(rbk_now_id)"
        if rbk_is_mac; then sed -i '' "s#/Users/$OLD/#/Users/$NEW/#g" "$f"; else sed -i "s#/Users/$OLD/#/Users/$NEW/#g" "$f"; fi
    fi
done < <(find "$APPSUPPORT_DIR" -type f \( -name '*.settings' -o -name '*.xml' -o -name '*.json' -o -name '*.ini' -o -name '*.txt' \) -print0 2>/dev/null)
[ $COUNT -eq 0 ] && echo "   nothing to change"
[ $APPLY = 1 ] && [ $COUNT -gt 0 ] && rbk_log "fixpaths: rewrote $COUNT settings entries /Users/$OLD/ -> /Users/$NEW/"
echo

# ---- Part 2: master.db track paths -------------------------------------------
echo "Part 2 — track locations inside master.db"
MDB=$(rbk_find_master_db)
[ -n "$MDB" ] || { echo "   master.db not found under $PIONEER_DIR"; exit 1; }
if ! command -v python3 >/dev/null 2>&1; then
    echo "   python3 not found. Install Xcode Command Line Tools (xcode-select --install) or Python from python.org, then re-run."
    exit 1
fi
ARGS=(--db "$MDB" --old "/Users/$OLD/" --new "/Users/$NEW/")
[ $APPLY = 1 ] && ARGS[${#ARGS[@]}]="--apply"
python3 "$KIT_DIR/rbk_fixpaths.py" "${ARGS[@]}"
RC=$?
if [ $RC -eq 2 ]; then
    echo
    echo "   Alternative without Python: open rekordbox, right-click a track marked '!' → Relocate, pick the file"
    echo "   in the Music folder; rekordbox then offers to relocate the rest automatically."
fi
[ $APPLY = 1 ] && [ $RC -eq 0 ] && rbk_log "fixpaths: master.db paths rewritten /Users/$OLD/ -> /Users/$NEW/"
exit $RC
