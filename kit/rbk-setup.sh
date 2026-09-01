#!/bin/bash
# rbk-setup.sh — the folder-selection wizard used by Install.command (first launch) and by
# the app's "Settings…" button. Sourced, not run. Sets:
#   LIBRARY_DIR  SETTINGS_DIR  BACKUP_DIR  MUSIC_DIR  DRIVE_ROOT  INSTALL_DIR  APP_DIR
# Graphical (macOS dialogs with a ⌘⇧G tip) when possible, typed prompts otherwise.

SETUP_TITLE="rekordbox Backup — setup"
GOTO_TIP="Tip: press ⌘⇧G (Command-Shift-G) in this window, paste the path and press Enter."

setup_gui_available() {
    rbk_is_mac || return 1
    [ "${RBK_NO_GUI:-0}" != "1" ] || return 1
    command -v osascript >/dev/null 2>&1 || return 1
    [ -t 0 ] || [ -n "${SETUP_FROM_APP:-}" ]      # a Terminal window (double-click) or the app
}

# ---- osascript helpers (return "" when the user cancels) --------------------------------------
gui_dialog() {   # text  buttons-as-applescript-list  default-button-name  [icon]
    local text; text=$(rbk_as_escape "$1")
    osascript 2>/dev/null <<EOS
try
    set r to display dialog "$text" with title "$SETUP_TITLE" buttons $2 default button "$3" with icon ${4:-note}
    return button returned of r
on error
    return ""
end try
EOS
}
gui_choose_folder() {   # prompt  default-folder
    local prompt def; prompt=$(rbk_as_escape "$1"); def="$2"; [ -d "$def" ] || def="$HOME"
    def=$(rbk_as_escape "$def")
    osascript 2>/dev/null <<EOS | sed 's#/$##'
try
    set f to choose folder with prompt "$prompt" default location (POSIX file "$def") with invisibles
    return POSIX path of f
on error
    return ""
end try
EOS
}
gui_choose_list() {   # prompt  items(one per line)  [default item]  -> chosen line or ""
    local prompt list="" line def=""; prompt=$(rbk_as_escape "$1")
    while IFS= read -r line; do [ -n "$line" ] || continue; list="$list${list:+, }\"$(rbk_as_escape "$line")\""; done <<EOS
$2
EOS
    [ -n "${3:-}" ] && def="default items {\"$(rbk_as_escape "$3")\"}"
    osascript 2>/dev/null <<EOS
try
    set pick to choose from list {$list} with prompt "$prompt" with title "$SETUP_TITLE" $def OK button name "Choose" cancel button name "Cancel"
    if pick is false then return ""
    return item 1 of pick
on error
    return ""
end try
EOS
}

# ---- shared logic -----------------------------------------------------------------------------
setup_master_db_in() { find "$1" -maxdepth 3 -name master.db -print 2>/dev/null | head -n 1; }

# Absolute, symlink-resolved path (for a folder that does not exist yet, its parent is resolved)
setup_realpath() {
    local p="${1%/}" par
    if [ -d "$p" ]; then (cd "$p" && pwd -P); return; fi
    par=$(dirname "$p")
    if [ -d "$par" ]; then printf '%s/%s\n' "$(cd "$par" && pwd -P)" "$(basename "$p")"; else printf '%s\n' "$p"; fi
}
setup_is_inside() {   # child parent → true when child == parent or child lives inside parent
    local c p; c=$(setup_realpath "$1"); p=$(setup_realpath "$2")
    [ "$c" = "$p" ] && return 0
    case "$c/" in "$p"/*) return 0 ;; esac
    return 1
}
# Safety rules for the chosen folders. Sets SETUP_ERROR and returns 1 when a rule is broken.
setup_validate_folders() {
    SETUP_ERROR=""
    [ -n "${BACKUP_DIR:-}" ] || { SETUP_ERROR="No backup folder chosen."; return 1; }
    [ -n "${LIBRARY_DIR:-}" ] || { SETUP_ERROR="No rekordbox library folder chosen."; return 1; }
    if [ -n "${MUSIC_DIR:-}" ] && setup_is_inside "$BACKUP_DIR" "$MUSIC_DIR"; then
        SETUP_ERROR="The backup folder cannot be inside the Music folder ($MUSIC_DIR). The kit never writes there — pick another place for the backups."; return 1; fi
    if setup_is_inside "$BACKUP_DIR" "$LIBRARY_DIR"; then
        SETUP_ERROR="The backup folder cannot be inside the rekordbox library folder ($LIBRARY_DIR) — it would back up itself."; return 1; fi
    if [ -n "${SETTINGS_DIR:-}" ] && setup_is_inside "$BACKUP_DIR" "$SETTINGS_DIR"; then
        SETUP_ERROR="The backup folder cannot be inside the rekordbox settings folder ($SETTINGS_DIR)."; return 1; fi
    if setup_is_inside "$LIBRARY_DIR" "$BACKUP_DIR"; then
        SETUP_ERROR="The rekordbox library folder cannot be inside the backup folder."; return 1; fi
    case "$(setup_realpath "$BACKUP_DIR")" in
        "/"|"$(setup_realpath "$HOME")") SETUP_ERROR="Choose a folder for the backups, not the home folder itself."; return 1 ;;
    esac
    # install location (scripts) and app folder
    if [ -n "${INSTALL_DIR:-}" ]; then
        if [ -n "${MUSIC_DIR:-}" ] && setup_is_inside "$INSTALL_DIR" "$MUSIC_DIR"; then
            SETUP_ERROR="The scripts cannot be installed inside the Music folder ($MUSIC_DIR) — the kit never writes there."; return 1; fi
        if setup_is_inside "$INSTALL_DIR" "$LIBRARY_DIR" || { [ -n "${SETTINGS_DIR:-}" ] && setup_is_inside "$INSTALL_DIR" "$SETTINGS_DIR"; }; then
            SETUP_ERROR="The scripts cannot be installed inside the rekordbox library or settings folder."; return 1; fi
        if setup_is_inside "$INSTALL_DIR" "$BACKUP_DIR" && [ "$(setup_realpath "$INSTALL_DIR")" != "$(setup_realpath "$BACKUP_DIR/kit")" ]; then
            SETUP_ERROR="Inside the backup folder the scripts can only live in its 'kit' folder ($BACKUP_DIR/kit) — everything else there is managed by the backups."; return 1; fi
        case "$(setup_realpath "$INSTALL_DIR")" in
            "/"|"$(setup_realpath "$HOME")") SETUP_ERROR="Choose a folder for the scripts, not the home folder itself."; return 1 ;;
        esac
    fi
    if [ -n "${APP_DIR:-}" ] && [ -n "${MUSIC_DIR:-}" ] && setup_is_inside "$APP_DIR" "$MUSIC_DIR"; then
        SETUP_ERROR="The app cannot be placed inside the Music folder."; return 1; fi
    return 0
}

# Install-location helpers. INSTALL_DIR = where the scripts run from:
#   local  → $DEFAULT_INSTALL_DIR (this Mac)      backup → $BACKUP_DIR/kit      other → <folder>/rekordbox-backup-kit
setup_install_from_choice() {   # local | backup | <path>
    case "$1" in
        local)  INSTALL_DIR="$DEFAULT_INSTALL_DIR" ;;
        backup) INSTALL_DIR="$BACKUP_DIR/kit" ;;
        *)      local p="${1%/}"
                if [ "$(basename "$p")" = "rekordbox-backup-kit" ] || [ "$(setup_realpath "$p")" = "$(setup_realpath "$BACKUP_DIR/kit")" ] || [ "$(setup_realpath "$p")" = "$(setup_realpath "$DEFAULT_INSTALL_DIR")" ]; then INSTALL_DIR="$p"; else INSTALL_DIR="$p/rekordbox-backup-kit"; fi ;;
    esac
}
setup_install_label() {   # human label for the summary
    case "$(setup_realpath "${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}")" in
        "$(setup_realpath "$DEFAULT_INSTALL_DIR")") printf 'on this Mac (%s)' "$INSTALL_DIR" ;;
        "$(setup_realpath "$BACKUP_DIR/kit")")      printf 'inside the backup folder (%s)' "$INSTALL_DIR" ;;
        *)                                           printf '%s' "$INSTALL_DIR" ;;
    esac
}

# "<label><TAB><path>" candidates + a manual option; sets BACKUP_DIR and DRIVE_ROOT from a picked root
setup_dest_from_root() {   # root
    local root="${1%/}"
    DRIVE_ROOT="$root"
    case "$(basename "$root")" in rekordbox-backup) BACKUP_DIR="$root"; DRIVE_ROOT="$(dirname "$root")";; *) BACKUP_DIR="$root/rekordbox-backup";; esac
}

# ---- the GUI wizard ---------------------------------------------------------------------------
setup_gui() {
    local first="$1" ans lib mdb size dests labels pick path music_default
    if [ "$first" = 1 ]; then
        ans=$(gui_dialog "Welcome! Before the first backup you choose three things:

1. Your rekordbox LIBRARY folder — normally ~/Library/Pioneer (it is detected for you).
2. WHERE the backups go — Google Drive, Dropbox, iCloud, OneDrive, an external disk… any folder.
3. Optionally, your MUSIC folder — only ever read, never written to.

When a folder window opens you can press ⌘⇧G and paste a path. You can change all of this later with the app's Settings… button.

⚠️ Use this kit at your own risk — it comes with no warranty and the author accepts no responsibility for lost data. Always keep rekordbox's own backups too: File › Library › Backup Library, answer No to including the music files, save the zip (see DISCLAIMER.md)." '{"Cancel", "Continue"}' "Continue") 
        [ "$ans" = "Continue" ] || return 1
    fi
    while :; do
        # 1. library ---------------------------------------------------------------------------
        lib="${LIBRARY_DIR:-$DEFAULT_LIBRARY_DIR}"
        while :; do
            mdb=$(setup_master_db_in "$lib")
            if [ -n "$mdb" ]; then
                size=$(rbk_human "$(rbk_file_size "$mdb")")
                ans=$(gui_dialog "rekordbox library folder:

$lib

✅ master.db found ($size) — this looks right.

Use this folder?" '{"Cancel", "Choose another…", "Use this folder"}' "Use this folder")
            else
                ans=$(gui_dialog "rekordbox library folder:

$lib

⚠️ No master.db found inside this folder. If rekordbox has never been opened on this Mac that is normal (the folder will be filled by a Restore). Otherwise choose the right folder.

$GOTO_TIP" '{"Cancel", "Choose another…", "Use anyway"}' "Choose another…" caution)
            fi
            case "$ans" in
                "Use this folder"|"Use anyway") break ;;
                "Choose another…")
                    path=$(gui_choose_folder "Select the rekordbox LIBRARY folder — the one that contains rekordbox7/master.db (normally ~/Library/Pioneer).   $GOTO_TIP" "$HOME/Library")
                    [ -n "$path" ] && lib="$path" ;;
                *) return 1 ;;
            esac
        done
        LIBRARY_DIR="$lib"
        SETTINGS_DIR="${SETTINGS_DIR:-$DEFAULT_SETTINGS_DIR}"

        # 2. destination -----------------------------------------------------------------------
        dests=$(rbk_detect_destinations)
        labels=""
        while IFS=$'\t' read -r l p; do [ -n "$p" ] && labels="$labels$l  —  $p"$'\n'; done <<EOS
$dests
EOS
        [ -n "${BACKUP_DIR:-}" ] && labels="Keep current  —  $BACKUP_DIR"$'\n'"$labels"
        labels="$labels"'Other folder…  —  pick any folder yourself (⌘⇧G works there)'
        pick=$(gui_choose_list "WHERE should the backups be kept? A folder named 'rekordbox-backup' is created inside the place you pick. Cloud folders found on this Mac are listed first." "$labels")
        [ -n "$pick" ] || return 1
        case "$pick" in
            "Keep current"*) : ;;
            "Other folder"*)
                path=$(gui_choose_folder "Select the folder that will hold the backups (a 'rekordbox-backup' folder is created inside it).   $GOTO_TIP" "$HOME")
                [ -n "$path" ] || continue
                setup_dest_from_root "$path"; DRIVE_ROOT="" ;;
            *) setup_dest_from_root "${pick##*  —  }" ;;
        esac

        # 3. music (optional) ------------------------------------------------------------------
        music_default="${MUSIC_DIR:-}"
        [ -n "$music_default" ] || { [ -n "$DRIVE_ROOT" ] && [ -d "$DRIVE_ROOT/Music" ] && music_default="$DRIVE_ROOT/Music"; }
        if [ -n "$music_default" ]; then
            ans=$(gui_dialog "Optional — your MUSIC folder.

Detected: $music_default

The kit never writes there; it is only used by 'Check music folder' to tell you if files are still online-only." '{"Skip", "Choose…", "Use detected"}' "Use detected")
        else
            ans=$(gui_dialog "Optional — your MUSIC folder.

The kit never writes there; it is only used by 'Check music folder' to tell you if files are still online-only. You can skip this." '{"Skip", "Choose…"}' "Skip")
        fi
        case "$ans" in
            "Use detected") MUSIC_DIR="$music_default" ;;
            "Choose…") path=$(gui_choose_folder "Select your MUSIC folder (read-only for the kit).   $GOTO_TIP" "${DRIVE_ROOT:-$HOME}"); MUSIC_DIR="${path:-$MUSIC_DIR}" ;;
            "Skip") MUSIC_DIR="" ;;
            *) return 1 ;;
        esac

        # 4. where the scripts and the app are installed --------------------------------------
        local cur_label="" items def
        items="On this Mac (recommended)  —  $DEFAULT_INSTALL_DIR"$'\n'"Inside the backup folder  —  $BACKUP_DIR/kit   (backups run only while it is available)"
        if [ -n "${INSTALL_DIR:-}" ] && [ "$(setup_realpath "$INSTALL_DIR")" != "$(setup_realpath "$DEFAULT_INSTALL_DIR")" ] && [ "$(setup_realpath "$INSTALL_DIR")" != "$(setup_realpath "$BACKUP_DIR/kit")" ]; then
            cur_label="Keep current  —  $INSTALL_DIR"; items="$items"$'\n'"$cur_label"
        fi
        items="$items"$'\n'"Other folder…  —  pick any folder (a 'rekordbox-backup-kit' folder is created inside it)"
        case "$(setup_realpath "${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}")" in
            "$(setup_realpath "$BACKUP_DIR/kit")") def="Inside the backup folder  —  $BACKUP_DIR/kit   (backups run only while it is available)" ;;
            "$(setup_realpath "$DEFAULT_INSTALL_DIR")") def="On this Mac (recommended)  —  $DEFAULT_INSTALL_DIR" ;;
            *) def="$cur_label" ;;
        esac
        pick=$(gui_choose_list "WHERE should the app's scripts be installed? 'On this Mac' is the safe default. Choosing the backup folder (cloud or disk) means the very same scripts are already in place on your next Mac — but automatic backups can only run while that folder is available; a small launcher stays on this Mac and warns you when it is not." "$items" "$def")
        [ -n "$pick" ] || return 1
        case "$pick" in
            "On this Mac"*)   setup_install_from_choice local ;;
            "Inside the backup"*) setup_install_from_choice backup ;;
            "Keep current"*)  : ;;
            *)  path=$(gui_choose_folder "Select the folder for the scripts (a 'rekordbox-backup-kit' folder is created inside it).   $GOTO_TIP" "$HOME")
                [ -n "$path" ] || continue
                setup_install_from_choice "$path" ;;
        esac
        ans=$(gui_dialog "Where should the app 'rekordbox Backup.app' go?

~/Applications is your personal Applications folder (recommended). /Applications is the shared one for all users of this Mac." '{"Cancel", "/Applications", "~/Applications"}' "~/Applications")
        case "$ans" in
            "~/Applications") APP_DIR="$HOME/Applications" ;;
            "/Applications")  APP_DIR="/Applications" ;;
            *) return 1 ;;
        esac

        # 5. safety rules ----------------------------------------------------------------------
        if ! setup_validate_folders; then
            ans=$(gui_dialog "⚠️ $SETUP_ERROR" '{"Cancel", "Start over"}' "Start over" caution)
            [ "$ans" = "Start over" ] && continue
            return 1
        fi

        # 6. summary ---------------------------------------------------------------------------
        ans=$(gui_dialog "Please confirm:

Library:   $LIBRARY_DIR
Settings:  $SETTINGS_DIR
Backups:   $BACKUP_DIR
Music:     ${MUSIC_DIR:-(not set)}
Scripts:   $(setup_install_label)
App:       $APP_DIR/rekordbox Backup.app

Nothing in the Music folder is ever modified. Backups run automatically after each rekordbox session and daily at 03:00." '{"Cancel", "Start over", "Install"}' "Install")
        case "$ans" in Install) return 0;; "Start over") continue;; *) return 1;; esac
    done
}

# ---- typed-prompt fallback (Terminal without dialogs, or --no-gui) ----------------------------
setup_text() {
    local d line n i p
    echo "Folder setup (press Enter to accept the value in brackets)."
    echo "⚠️  Use this kit at your own risk (no warranty, no liability for lost data). Keep rekordbox's own backups too:"
    echo "    File › Library › Backup Library — answer No to including the music files — save the zip. See DISCLAIMER.md."
    while :; do
    d="${LIBRARY_DIR:-$DEFAULT_LIBRARY_DIR}"
    while :; do
        ask "rekordbox library folder [$d]: " "$d"; LIBRARY_DIR="${REPLY%/}"
        [ -d "$LIBRARY_DIR" ] || { echo "  folder not found: $LIBRARY_DIR"; continue; }
        [ -n "$(setup_master_db_in "$LIBRARY_DIR")" ] || echo "  ⚠️  no master.db under $LIBRARY_DIR (fine on a brand-new Mac)"
        break
    done
    SETTINGS_DIR="${SETTINGS_DIR:-$DEFAULT_SETTINGS_DIR}"
    echo "Where should the backups go? Folders found on this Mac:"
    i=0; DESTS=""
    while IFS=$'\t' read -r l p; do [ -n "$p" ] || continue; i=$((i+1)); DESTS="$DESTS$p"$'\n'; echo "  [$i] $l — $p"; done <<EOS
$(rbk_detect_destinations)
EOS
    [ -n "${BACKUP_DIR:-}" ] && echo "  [Enter] keep current: $BACKUP_DIR"
    echo "  or type any folder path (a 'rekordbox-backup' folder is created inside it)"
    while :; do
        ask "Backup destination [${BACKUP_DIR:-1}]: " "${BACKUP_DIR:-1}"
        case "$REPLY" in
            "${BACKUP_DIR:-__none__}") break ;;
            ''|*[!0-9]*) [ -d "${REPLY%/}" ] || { echo "  folder not found: $REPLY"; continue; }; setup_dest_from_root "$REPLY"; DRIVE_ROOT=""; break ;;
            *) p=$(printf '%s' "$DESTS" | sed -n "${REPLY}p"); [ -n "$p" ] || { echo "  invalid choice"; continue; }; setup_dest_from_root "$p"; break ;;
        esac
    done
    d="${MUSIC_DIR:-}"; [ -n "$d" ] || { [ -n "$DRIVE_ROOT" ] && [ -d "$DRIVE_ROOT/Music" ] && d="$DRIVE_ROOT/Music"; }
    while :; do
        ask "Music folder, optional, read-only for the kit [${d:-none}]: " "$d"; MUSIC_DIR="${REPLY%/}"
        [ "$MUSIC_DIR" = "none" ] && MUSIC_DIR=""
        [ -z "$MUSIC_DIR" ] || [ -d "$MUSIC_DIR" ] && break
        echo "  folder not found: $MUSIC_DIR (type 'none' to leave it unset)"
    done
    echo "Where should the scripts be installed?"
    echo "  [1] On this Mac (recommended) — $DEFAULT_INSTALL_DIR"
    echo "  [2] Inside the backup folder — $BACKUP_DIR/kit   (backups run only while it is available)"
    echo "  or type a folder path (a 'rekordbox-backup-kit' folder is created inside it)"
    d=1; case "$(setup_realpath "${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}")" in "$(setup_realpath "$BACKUP_DIR/kit")") d=2;; "$(setup_realpath "$DEFAULT_INSTALL_DIR")") d=1;; *) d="$INSTALL_DIR";; esac
    while :; do
        ask "Scripts location [$d]: " "$d"
        case "$REPLY" in
            1) setup_install_from_choice local; break ;;
            2) setup_install_from_choice backup; break ;;
            *) [ -d "${REPLY%/}" ] || [ "$(basename "${REPLY%/}")" = "rekordbox-backup-kit" ] && [ -d "$(dirname "${REPLY%/}")" ] || { echo "  folder not found: $REPLY"; continue; }; setup_install_from_choice "$REPLY"; break ;;
        esac
    done
    d="${APP_DIR:-$DEFAULT_APP_DIR}"
    ask "App folder — ~/Applications or /Applications [$d]: " "$d"; APP_DIR="${REPLY/#\~/$HOME}"
    if ! setup_validate_folders; then echo; echo "  ❌ $SETUP_ERROR"; echo "  Let's choose again."; echo; BACKUP_DIR=""; INSTALL_DIR=""; continue; fi
    echo
    echo "  Library:  $LIBRARY_DIR"; echo "  Settings: $SETTINGS_DIR"; echo "  Backups:  $BACKUP_DIR"; echo "  Music:    ${MUSIC_DIR:-(not set)}"
    echo "  Scripts:  $(setup_install_label)"; echo "  App:      $APP_DIR/rekordbox Backup.app"
    ask "Install with these folders? [Y/n] " "Y"; case "$REPLY" in [Nn]*) return 1;; esac
    return 0
    done
}

run_setup_wizard() {   # first(1/0)
    if setup_gui_available; then setup_gui "$1"; else setup_text; fi
}
