#!/bin/bash
# Install.command — double-click to install (or update / repair / reconfigure) the rekordbox backup kit.
#
# First launch: a short wizard lets you pick the rekordbox library folder, where backups go
# (Google Drive, Dropbox, iCloud, OneDrive, an external disk… any folder), optionally the music
# folder, and where the scripts and the app are installed (this Mac by default, or inside the
# backup folder so they travel with it). In every folder window you can press ⌘⇧G and paste a path.
# Safe to run again at any time. Nothing in the music folder is ever touched.
#
# Options (all optional):
#   --library PATH   --settings PATH   --backup PATH   --music PATH     use these folders, no questions
#   --install-dir local|backup|PATH   where the scripts go (default local = this Mac)
#   --app-dir PATH   where "rekordbox Backup.app" is built (default ~/Applications)
#   --yes            accept defaults, no questions (with the paths above → fully unattended)
#   --no-gui         typed prompts instead of dialogs
#   --reconfigure    change folders only (used by the app's Settings… button)
set -u
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$KIT_DIR/rbk-lib.sh"
# shellcheck disable=SC1091
. "$KIT_DIR/rbk-setup.sh"
RBK_TAG="install"

hr()   { printf '%s\n' "------------------------------------------------------------"; }
step() { echo; echo "▶ $*"; }
ask()  { local p="$1" d="${2:-}"; printf '%s' "$p"; { read -r REPLY </dev/tty; } 2>/dev/null || read -r REPLY; [ -n "$REPLY" ] || REPLY="$d"; }
done_msg() { echo; hr; echo "$*"; hr; echo; [ -t 0 ] && { printf 'Press Enter to close this window… '; read -r _; }; }

# ---- options ---------------------------------------------------------------------------------
OPT_LIB=""; OPT_SET=""; OPT_BAK=""; OPT_MUS=""; OPT_INSTALL=""; OPT_APP=""; YES=0; RECONF=0
while [ $# -gt 0 ]; do
    case "$1" in
        --library) OPT_LIB="${2%/}"; shift ;;
        --settings) OPT_SET="${2%/}"; shift ;;
        --backup) OPT_BAK="${2%/}"; shift ;;
        --music) OPT_MUS="${2%/}"; shift ;;
        --install-dir) OPT_INSTALL="${2%/}"; shift ;;
        --app-dir) OPT_APP="${2%/}"; shift ;;
        --yes) YES=1 ;;
        --no-gui) RBK_NO_GUI=1 ;;
        --reconfigure) RECONF=1 ;;
        -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1"; exit 2 ;;
    esac; shift
done

hr; echo "rekordbox backup kit $RBK_VERSION — installer"; hr
if ! rbk_is_mac && [ "${RBK_ALLOW_NON_MAC:-0}" != "1" ]; then echo "This installer is for macOS."; exit 1; fi

# Where is the full kit (README, commands…)? Running from the kit folder, or from the installed copy.
if [ -f "$KIT_DIR/../README.md" ] && [ -d "$KIT_DIR/commands" ]; then KIT_ROOT="$(cd "$KIT_DIR/.." && pwd)"
elif [ -f "$RBK_KIT_COPY/README.md" ]; then KIT_ROOT="$RBK_KIT_COPY"
else KIT_ROOT=""; fi

# ---- 1. folders (wizard) ---------------------------------------------------------------------
step "1/7  Folders"
FIRST=1
if [ -f "$RBK_CONFIG" ]; then
    # shellcheck disable=SC1090
    . "$RBK_CONFIG" 2>/dev/null; FIRST=0
    echo "Existing installation found — current folders are offered as defaults."
fi
LIBRARY_DIR="${LIBRARY_DIR:-}"; SETTINGS_DIR="${SETTINGS_DIR:-}"; BACKUP_DIR="${BACKUP_DIR:-}"; MUSIC_DIR="${MUSIC_DIR:-}"; DRIVE_ROOT="${DRIVE_ROOT:-}"
INSTALL_DIR="${INSTALL_DIR:-}"; APP_DIR="${APP_DIR:-}"
OLD_LIB="$LIBRARY_DIR"; OLD_BAK="$BACKUP_DIR"; OLD_INSTALL="$INSTALL_DIR"; OLD_APP="$APP_DIR"
[ -n "$OPT_LIB" ] && LIBRARY_DIR="$OPT_LIB"
[ -n "$OPT_SET" ] && SETTINGS_DIR="$OPT_SET"
[ -n "$OPT_MUS" ] && MUSIC_DIR="$OPT_MUS"
if [ -n "$OPT_BAK" ]; then setup_dest_from_root "$OPT_BAK"; DRIVE_ROOT=""; fi
if [ $YES = 1 ]; then
    LIBRARY_DIR="${LIBRARY_DIR:-$DEFAULT_LIBRARY_DIR}"; SETTINGS_DIR="${SETTINGS_DIR:-$DEFAULT_SETTINGS_DIR}"
    if [ -z "$BACKUP_DIR" ]; then
        D=$(rbk_detect_drive_root); [ -n "$D" ] || D=$(rbk_detect_destinations | head -n 1 | cut -f2)
        [ -n "$D" ] || { done_msg "❌ No backup destination found. Run without --yes to pick a folder."; exit 1; }
        setup_dest_from_root "$D"
    fi
    [ -n "$MUSIC_DIR" ] || { [ -n "$DRIVE_ROOT" ] && [ -d "$DRIVE_ROOT/Music" ] && MUSIC_DIR="$DRIVE_ROOT/Music"; }
else
    run_setup_wizard "$FIRST" || { done_msg "Setup cancelled — nothing was changed."; exit 0; }
fi
[ -n "$OPT_INSTALL" ] && setup_install_from_choice "$OPT_INSTALL"
[ -n "$OPT_APP" ] && APP_DIR="$OPT_APP"
INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"; APP_DIR="${APP_DIR:-$DEFAULT_APP_DIR}"
setup_validate_folders || { done_msg "❌ $SETUP_ERROR
   Nothing was changed. Run the installer again and choose different folders."; exit 1; }
[ -d "$LIBRARY_DIR" ] || echo "⚠️  Library folder does not exist yet: $LIBRARY_DIR (fine on a brand-new Mac — it appears when rekordbox is opened once)"
D=$(dirname "$BACKUP_DIR"); [ -d "$D" ] || { done_msg "❌ The chosen backup location is not available right now: $D — is the cloud app running / the disk connected?"; exit 1; }
echo "Library:  $LIBRARY_DIR"; echo "Settings: $SETTINGS_DIR"; echo "Backups:  $BACKUP_DIR"; echo "Music:    ${MUSIC_DIR:-(not set)}"
echo "Scripts:  $(setup_install_label)"; echo "App:      $APP_DIR/$RBK_APP_NAME"

# ---- 2. install the scripts (INSTALL_DIR) + the launcher that always stays on this Mac --------------
step "2/7  Installing scripts to $INSTALL_DIR"
mkdir -p "$RBK_LOCAL_BIN" "$RBK_STATE" "$RBK_LOG_DIR" "$INSTALL_DIR/launchd" || { done_msg "❌ Cannot create $INSTALL_DIR — is that location available and writable?"; exit 1; }
cp "$KIT_DIR/rbk-launch.sh" "$RBK_LOCAL_BIN/"                      # launchd calls this; it finds the scripts wherever they are
if [ "$(setup_realpath "$KIT_DIR")" != "$(setup_realpath "$INSTALL_DIR")" ]; then
    cp "$KIT_DIR"/rbk-*.sh "$KIT_DIR"/rbk_*.py "$KIT_DIR"/*.applescript "$INSTALL_DIR/" && cp "$KIT_DIR"/launchd/*.plist "$INSTALL_DIR/launchd/"
fi
SELF="$KIT_DIR/$(basename "$0")"                                    # this installer (Install.command, or install.sh when run from Settings…)
[ "$(setup_realpath "$SELF")" != "$(setup_realpath "$INSTALL_DIR/install.sh")" ] && cp "$SELF" "$INSTALL_DIR/install.sh"   # lets the app's Settings… button re-run this wizard
if [ -n "$KIT_ROOT" ] && [ "$KIT_ROOT" != "$RBK_KIT_COPY" ]; then rm -rf "$RBK_KIT_COPY"; mkdir -p "$RBK_KIT_COPY"; cp -R "$KIT_ROOT"/. "$RBK_KIT_COPY/"; fi
if [ -n "$OLD_INSTALL" ] && [ "$(setup_realpath "$OLD_INSTALL")" != "$(setup_realpath "$INSTALL_DIR")" ]; then
    # the scripts moved: tidy the old location (the launcher and the backup folder's own kit/ copy always stay)
    if [ "$(setup_realpath "$OLD_INSTALL")" = "$(setup_realpath "$RBK_LOCAL_BIN")" ]; then
        for f in "$RBK_LOCAL_BIN"/rbk-*.sh "$RBK_LOCAL_BIN"/rbk_*.py "$RBK_LOCAL_BIN"/*.applescript "$RBK_LOCAL_BIN"/install.sh; do
            [ -e "$f" ] && [ "$(basename "$f")" != "rbk-launch.sh" ] && rm -f "$f"
        done; rm -rf "$RBK_LOCAL_BIN/launchd"
    elif [ "$(basename "$OLD_INSTALL")" = "rekordbox-backup-kit" ] && [ -d "$OLD_INSTALL" ]; then rm -rf "$OLD_INSTALL"; fi
    echo "  scripts moved: $OLD_INSTALL → $INSTALL_DIR"
fi
chmod +x "$INSTALL_DIR"/*.sh "$RBK_LOCAL_BIN"/*.sh "$RBK_KIT_COPY"/kit/*.command "$RBK_KIT_COPY"/kit/commands/*.command "$KIT_DIR"/*.command "$KIT_DIR"/commands/*.command 2>/dev/null
rbk_is_mac && xattr -dr com.apple.quarantine "$KIT_ROOT" "$RBK_HOME" "$INSTALL_DIR" 2>/dev/null
rbk_write_config
echo "Config written: $RBK_CONFIG"
if [ "$OLD_LIB" != "$LIBRARY_DIR" ] || [ "$OLD_BAK" != "$BACKUP_DIR" ]; then
    rm -f "$RBK_STATE/last-backup.stamp" "$RBK_STATE/snapshot-fingerprint"    # folders changed → next run does a full mirror + snapshot
fi
rbk_load_config >/dev/null || { done_msg "❌ Config could not be loaded."; exit 1; }

# ---- 3. backup folder + a copy of the kit inside it ------------------------------------------------
step "3/7  Preparing $BACKUP_DIR"
mkdir -p "$LATEST_DIR" "$HISTORY_DIR" "$OFFICIAL_DIR" "$DRIVE_LOG_DIR" "$BACKUP_DIR/kit" || { done_msg "❌ Cannot create folders inside $BACKUP_DIR (permission? see README › Troubleshooting)."; exit 1; }
if [ -n "$KIT_ROOT" ] && [ "$KIT_ROOT" != "$BACKUP_DIR" ]; then
    for f in README.md README.pdf DISCLAIMER.md LICENSE NOTES.md CHANGELOG.md; do [ -f "$KIT_ROOT/$f" ] && cp "$KIT_ROOT/$f" "$BACKUP_DIR/"; done
    cp -R "$KIT_ROOT/kit"/. "$BACKUP_DIR/kit/" && echo "Kit copied next to the backups (so it is there on a new Mac): $BACKUP_DIR/kit"
else
    echo "Installer is running from the backup folder's own copy — nothing to copy."
fi
[ -f "$OFFICIAL_DIR/README.txt" ] || printf 'Save rekordbox'"'"'s own library backups here.\n\n1. In rekordbox: File > Library > Backup Library\n2. Click OK on the "this may take a while" message\n3. Answer NO when asked whether to also back up the music files (library only)\n4. Save the zip in this folder\n\nDo this at least monthly, before installing/updating the kit, before any restore and before moving to a new Mac.\nRestore with File > Library > Restore Library. Use the kit at your own risk - see DISCLAIMER.md.\n' > "$OFFICIAL_DIR/README.txt"

# ---- 4. scheduled jobs (launchd) ---------------------------------------------------------------
step "4/7  Scheduling automatic backups (every 30 min + daily 03:00)"
[ -f "$RBK_STATE/paused-since" ] && echo "  (automatic backups were paused — installing turns them back ON; press Pause in the app if you want them off)"
rm -f "$RBK_STATE/paused-since"
if rbk_is_mac; then
    mkdir -p "$RBK_LAUNCH_AGENTS"
    for L in $(rbk_legacy_labels); do    # remove jobs left by pre-release kits
        [ -f "$RBK_LAUNCH_AGENTS/$L.plist" ] || continue
        launchctl bootout "gui/$(id -u)/$L" >/dev/null 2>&1 || true; launchctl enable "gui/$(id -u)/$L" >/dev/null 2>&1 || true
        rm -f "$RBK_LAUNCH_AGENTS/$L.plist"; echo "  removed old job $L"
    done
    for L in "$RBK_LABEL_INTERVAL" "$RBK_LABEL_DAILY"; do
        DST="$RBK_LAUNCH_AGENTS/$L.plist"
        sed -e "s#__BIN__#$RBK_LOCAL_BIN#g" -e "s#__LOG__#$RBK_LOG_DIR#g" -e "s#__HOME__#$HOME#g" "$KIT_DIR/launchd/$L.plist" > "$DST"
        launchctl enable "gui/$(id -u)/$L" >/dev/null 2>&1 || true      # in case it was paused (disabled) before
        launchctl bootout "gui/$(id -u)/$L" >/dev/null 2>&1 || true
        if launchctl bootstrap "gui/$(id -u)" "$DST" 2>/dev/null || launchctl load -w "$DST" 2>/dev/null; then echo "  ✅ $L"; else echo "  ❌ could not load $L (see README › Troubleshooting)"; fi
    done
else
    echo "  (skipped — not macOS)"; touch "$RBK_STATE/test-auto-loaded"
fi

# ---- 5. the app --------------------------------------------------------------------------------
step "5/7  Building '$RBK_APP_NAME' in $RBK_APP_DIR"
if ! mkdir -p "$RBK_APP_DIR" 2>/dev/null || [ ! -w "$RBK_APP_DIR" ]; then
    echo "  ⚠️  $RBK_APP_DIR is not writable — building the app in $HOME/Applications instead"
    APP_DIR="$HOME/Applications"; RBK_APP_DIR="$APP_DIR"; mkdir -p "$RBK_APP_DIR"; rbk_write_config
fi
[ -n "$OLD_APP" ] && [ "$OLD_APP" != "$RBK_APP_DIR" ] && rm -rf "$OLD_APP/$RBK_APP_NAME" 2>/dev/null   # the app moved
if rbk_is_mac && command -v osacompile >/dev/null 2>&1; then
    rm -rf "$RBK_APP_DIR/$RBK_APP_NAME"
    if osacompile -o "$RBK_APP_DIR/$RBK_APP_NAME" "$INSTALL_DIR/rekordbox-backup.applescript" 2>&1; then
        echo "  ✅ $RBK_APP_DIR/$RBK_APP_NAME   (drag it to the Dock if you like)"
    else
        echo "  ❌ app could not be built — you can still use the files in kit/commands or the scripts in $INSTALL_DIR"
    fi
    echo "  Sending a test notification (if macOS asks, allow notifications for Script Editor)…"
    rbk_notify "rekordbox backup ✓" "Notifications are working. You will get one like this after every backup."
else
    echo "  (skipped — osacompile not available)"
fi

# ---- 6. self-test ------------------------------------------------------------------------------
step "6/7  Self-test"
"$INSTALL_DIR/rbk-selftest.sh" || true

# ---- 7. first backup ---------------------------------------------------------------------------
step "7/7  First backup"
if [ $RECONF = 1 ] && [ -n "$(rbk_last_success_epoch)" ]; then
    if [ "$OLD_LIB" != "$LIBRARY_DIR" ] || [ "$OLD_BAK" != "$BACKUP_DIR" ]; then
        echo "Folders updated. The next automatic run mirrors the library to the new location — or press Back up now."
    elif [ "$OLD_INSTALL" != "$INSTALL_DIR" ] || [ "$OLD_APP" != "$APP_DIR" ]; then
        echo "Scripts/app location updated. Backups continue as before."
    else
        echo "Folders unchanged. Settings saved."
    fi
elif [ ! -d "$PIONEER_DIR" ]; then
    echo "No rekordbox library on this Mac yet ($PIONEER_DIR)."
    echo "New Mac? → open the app → More… › Restore… (see README › Moving to a new laptop). Skipping the first backup."
elif rbk_rekordbox_running; then
    echo "rekordbox is open — quit it, then open the app and press 'Back up now' for the first backup."
else
    if [ $YES = 1 ]; then REPLY=Y; else ask "Run the first backup now? It can take several minutes. [Y/n] " "Y"; fi
    case "$REPLY" in
        [Nn]*) echo "Skipped. Open the app and press 'Back up now' when ready." ;;
        *) "$INSTALL_DIR/rbk-backup.sh" --force --verbose || echo "⚠️  The first backup reported a problem — see $RBK_LOG" ;;
    esac
fi

rbk_log "Installed/updated kit $RBK_VERSION (library=$LIBRARY_DIR backup=$BACKUP_DIR scripts=$INSTALL_DIR app=$RBK_APP_DIR)"
if rbk_is_mac && [ -d "$RBK_APP_DIR/$RBK_APP_NAME" ] && [ $RECONF = 0 ]; then open "$RBK_APP_DIR/$RBK_APP_NAME" 2>/dev/null || true; fi
done_msg "✅ Installed. From now on backups run by themselves — you get a notification after each one.
   • App:      $RBK_APP_DIR/$RBK_APP_NAME  → Back up now / Pause·Resume / More… (Restore, Settings…, tools)
   • Buttons as files:  ${KIT_ROOT:-$RBK_KIT_COPY}/kit/commands/  (double-click any .command)
   • Backups:  $BACKUP_DIR
   • Scripts:  $(rbk_install_text)
   • Guide:    $BACKUP_DIR/README.md$( [ -f "$BACKUP_DIR/README.pdf" ] && printf "  (PDF: README.pdf)")
   Tip: once a month run rekordbox › File › Library › Backup Library and save the zip into
        $OFFICIAL_DIR"
