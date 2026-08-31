# Changelog — rekordbox backup kit

## 1.2.1 — 31 Aug 2026 — cloud-agnostic pass
- Nothing depends on Google Drive any more: unattended-install default = first detected cloud folder (any service), neutral wording in the app, Check music and the scripts.
- More cloud folders detected by the wizard: Box, Proton Drive, pCloud, MEGA, Nextcloud, Sync.com (in addition to Google Drive, Dropbox, iCloud Drive, OneDrive and external disks); anything else via "Other folder…".
- README: "Supported destinations" table with each service's keep-offline wording; new-Mac guide rewritten for any cloud app; Windows explicitly unsupported.

## 1.2.0 — 31 Aug 2026 — universal
- Folder safety rules in the wizard, the installer and the command-line options: the backup folder is refused if it is inside the Music folder, inside the rekordbox library/settings folders, or is the home folder itself; the library folder cannot sit inside the backup folder.
- First-launch folder wizard (rekordbox library, backup destination, optional music folder) with detected defaults, a list of cloud folders/external disks found on the Mac, and a ⌘⇧G tip in every folder window.
- Settings… in the app (More…) and `Settings (change folders).command` re-run the wizard; changing the destination triggers a full mirror on the next run.
- App shows a Set up… button when opened before installation.
- Backups to any folder (Google Drive, Dropbox, iCloud Drive, OneDrive, external disk, NAS…); library folder can be anywhere.
- launchd labels renamed to `com.rekordbox-backup-kit.*` (old jobs removed automatically).
- Restore: refuses an empty backup, undoes itself if verification fails, safety copies next to the library folder with unique names.
- `Install.command --library … --backup … --music … --yes` for unattended installs.

## 1.1.0 — 31 Aug 2026
- Notification after every completed backup (time · files updated · snapshot · duration); skipped runs stay silent.
- Pause / Resume automatic backups: app button with live label, `rbk-toggle.sh`, `Pause auto-backup.command` / `Resume auto-backup.command`; a pause survives reboots.
- Status shows automatic-backup state and the next check time.
- One double-click `.command` file per action in `kit/commands/`.
- Restore… moved under More… in the app (three-button limit); `Back up now` from Terminal offers to quit rekordbox.
- Installer: test notification, `launchctl enable` before loading, clears a previous pause.
- Snapshots exclude `USBANLZ/` as well as `share/`.

## 1.0.0 — 31 Aug 2026
- First version: automatic mirror + dated snapshots to Google Drive, Back up now, emergency Restore with rollback, restore drill, self-test, Check music, Fix paths, README + PDF, new-laptop guide.
