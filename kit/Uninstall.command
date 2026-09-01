#!/bin/bash
# Uninstall.command — removes the scheduled jobs, the app and the local scripts.
# Your backups and your rekordbox library are NOT touched.
set -u
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$KIT_DIR/rbk-lib.sh"

rbk_load_config >/dev/null 2>&1 || true      # INSTALL_DIR / APP_DIR, if configured
EXTRA=""; [ "$(basename "${INSTALL_DIR:-}")" = "rekordbox-backup-kit" ] && [ -d "$INSTALL_DIR" ] && EXTRA=" and $INSTALL_DIR"
echo "rekordbox backup kit — uninstall"
echo "This removes: scheduled jobs, '$RBK_APP_NAME' (in $RBK_APP_DIR), $RBK_HOME$EXTRA"
echo "This keeps:   all backups, your rekordbox library, the log folder."
printf 'Continue? [y/N] '; read -r REPLY
case "$REPLY" in [Yy]*) ;; *) echo "Cancelled."; exit 0;; esac

if rbk_is_mac; then
    for L in "$RBK_LABEL_INTERVAL" "$RBK_LABEL_DAILY" $(rbk_legacy_labels); do
        [ -f "$RBK_LAUNCH_AGENTS/$L.plist" ] || continue
        launchctl bootout "gui/$(id -u)/$L" >/dev/null 2>&1 || launchctl unload "$RBK_LAUNCH_AGENTS/$L.plist" >/dev/null 2>&1 || true
        launchctl enable "gui/$(id -u)/$L" >/dev/null 2>&1 || true    # clear a "paused" (disabled) mark so a later reinstall starts clean
        rm -f "$RBK_LAUNCH_AGENTS/$L.plist" && echo "  removed job $L"
    done
    rm -rf "$RBK_APP_DIR/$RBK_APP_NAME" "$HOME/Applications/$RBK_APP_NAME" && echo "  removed app"
fi
[ -n "$EXTRA" ] && rm -rf "$INSTALL_DIR" && echo "  removed $INSTALL_DIR"
rm -rf "$RBK_HOME" && echo "  removed $RBK_HOME"
echo "  (the kit copy inside the backup folder is kept — it is part of the backup)"
echo "Done. To reinstall later: open the kit folder next to your backups (rekordbox-backup/kit) and double-click Install.command."
[ -t 0 ] && { printf 'Press Enter to close… '; read -r _; }
exit 0
