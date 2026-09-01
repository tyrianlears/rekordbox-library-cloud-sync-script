-- rekordbox Backup.app — the buttons for the rekordbox backup kit.
-- Compiled by Install.command with:  osacompile -o "~/Applications/rekordbox Backup.app" rekordbox-backup.applescript
-- Main window: status text + three buttons  [More…] [Pause/Resume automatic backups] [Back up now]
-- More… holds Restore…, Settings… (change folders / install location — the wizard also runs at the very first launch), and the tools.
-- Long-running actions open in a Terminal window so you can see progress; short ones show a dialog.

property appTitle : "rekordbox Backup"

on homeDir()
	return (POSIX path of (path to home folder)) & "Library/Application Support/rekordbox-backup/"
end homeDir

on binDir()
	-- where the scripts are installed: INSTALL_DIR in config.sh (this Mac by default, or the backup folder / any folder)
	try
		set p to do shell script "INSTALL_DIR=''; . " & quoted form of (homeDir() & "config.sh") & " 2>/dev/null; printf '%s' \"${INSTALL_DIR:-" & homeDir() & "bin}\""
		if p is not "" then
			if p does not end with "/" then set p to p & "/"
			return p
		end if
	end try
	return homeDir() & "bin/"
end binDir

on scriptsAvailable()
	try
		do shell script "test -f " & quoted form of (binDir() & "rbk-backup.sh")
		return true
	on error
		return false
	end try
end scriptsAvailable

on unavailableText()
	return "The scripts folder is not available right now:" & return & binDir() & return & return & "Start the cloud app or connect the disk, then open this app again. To move the scripts back to this Mac, run Install.command from the kit folder."
end unavailableText

on runScript(scriptName, args)
	-- run a kit script quietly and return its output (short actions only)
	return do shell script "/bin/bash " & quoted form of (binDir() & scriptName) & " " & args
end runScript

on shortStatus()
	if not scriptsAvailable() then return unavailableText()
	try
		return runScript("rbk-status.sh", "--short")
	on error errMsg
		return "Status unavailable — is the kit installed? (run Install.command)" & return & errMsg
	end try
end shortStatus

on autoState()
	-- "on" | "paused" | "off"
	try
		return runScript("rbk-toggle.sh", "state")
	on error
		return "off"
	end try
end autoState

on runInTerminal(scriptName, args)
	if not scriptsAvailable() then
		display dialog unavailableText() with title appTitle buttons {"OK"} default button 1 with icon caution
		return
	end if
	set cmd to "clear; /bin/bash " & quoted form of (binDir() & scriptName) & " " & args
	tell application "Terminal"
		activate
		do script cmd
	end tell
end runInTerminal

on rekordboxRunning()
	try
		do shell script "/usr/bin/pgrep -x rekordbox"
		return true
	on error
		return false
	end try
end rekordboxRunning

on quitRekordbox()
	-- resolved at run time so the app also compiles on a Mac where rekordbox is not installed yet
	do shell script "/usr/bin/osascript -e 'tell application \"rekordbox\" to quit'"
	repeat 60 times
		delay 1
		if not rekordboxRunning() then return true
	end repeat
	return false
end quitRekordbox

on backupNow()
	if rekordboxRunning() then
		try
			display dialog "rekordbox is open. It must be closed for a safe backup." & return & return & "Quit rekordbox and back up now?" with title appTitle buttons {"Cancel", "Quit rekordbox & back up"} default button 2 with icon caution
		on error number -128
			return
		end try
		if not quitRekordbox() then
			display dialog "rekordbox did not quit. Please quit it manually (⌘Q) and press Back up now again." with title appTitle buttons {"OK"} default button 1 with icon stop
			return
		end if
	end if
	runInTerminal("rbk-backup.sh", "--force")
end backupNow

on togglePause()
	set st to autoState()
	if st is "on" then
		try
			display dialog "Pause the automatic backups?" & return & return & "They stay paused — even after a restart — until you press Resume. Back up now and Restore keep working." with title appTitle buttons {"Cancel", "Pause"} default button "Pause" with icon caution
		on error number -128
			return
		end try
		set outText to runScript("rbk-toggle.sh", "pause")
	else
		set outText to runScript("rbk-toggle.sh", "resume")
	end if
	display dialog outText with title appTitle buttons {"OK"} default button 1 with icon note
end togglePause

on emergencyRestore()
	try
		display dialog "Emergency restore replaces the rekordbox library on this Mac with the backup kept in your backup folder." & return & return & "Your current library is kept aside first, so this can be undone (More… › Restore rollback)." & return & return & "A Terminal window will guide you through it." with title appTitle buttons {"Cancel", "Continue"} default button "Cancel" with icon caution
	on error number -128
		return
	end try
	runInTerminal("rbk-restore.sh", "")
end emergencyRestore

on openBackupFolder()
	set cfg to homeDir() & "config.sh"
	set p to do shell script ". " & quoted form of cfg & "; printf '%s' \"$BACKUP_DIR\""
	do shell script "/usr/bin/open " & quoted form of p
end openBackupFolder

on settingsWizard()
	-- re-runs the folder wizard (library / backup destination / music) and re-installs with the new folders
	runInTerminal("install.sh", "--reconfigure")
end settingsWizard

on firstRunSetup()
	-- the app was opened before the kit was installed (or the config was deleted)
	try
		display dialog "rekordbox Backup is not set up on this Mac yet." & return & return & "Press Set up… and select the kit folder (the one that contains Install.command — usually rekordbox-backup › kit)." & return & return & "Tip: in the folder window you can press ⌘⇧G and paste a path." with title appTitle buttons {"Quit", "Set up…"} default button "Set up…" with icon note
	on error number -128
		return
	end try
	try
		set kitFolder to POSIX path of (choose folder with prompt "Select the kit folder that contains Install.command   (⌘⇧G lets you paste a path)" with invisibles)
	on error number -128
		return
	end try
	set installer to kitFolder & "Install.command"
	try
		do shell script "test -f " & quoted form of installer
	on error
		display dialog "Install.command was not found in:" & return & kitFolder & return & return & "Choose the folder that contains it (rekordbox-backup › kit)." with title appTitle buttons {"OK"} default button 1 with icon stop
		return
	end try
	tell application "Terminal"
		activate
		do script "clear; /bin/bash " & quoted form of installer
	end tell
end firstRunSetup

on isInstalled()
	try
		do shell script "test -f " & quoted form of (homeDir() & "config.sh")
		return true
	on error
		return false
	end try
end isInstalled

on moreMenu()
	set menuItems to {"Restore… — EMERGENCY: put the library back from the backup", "Settings… — change the library, backup, music folder or where the scripts live", "Status (full report)", "Check music folder — is everything offline?", "Restore drill — safe rehearsal of a restore", "Restore rollback — undo the last restore", "Fix paths — after moving to a Mac with a different user name", "Run self-test", "Open backup folder in Finder", "View log", "Close"}
	set pick to choose from list menuItems with prompt "rekordbox Backup — more tools" with title appTitle default items {"Status (full report)"} OK button name "Open" cancel button name "Close"
	if pick is false then return
	set choice to item 1 of pick
	if choice starts with "Restore…" then
		emergencyRestore()
	else if choice starts with "Settings…" then
		settingsWizard()
	else if choice starts with "Status" then
		runInTerminal("rbk-status.sh", "")
	else if choice starts with "Check music" then
		runInTerminal("rbk-checkmusic.sh", "")
	else if choice starts with "Restore drill" then
		runInTerminal("rbk-restore.sh", "--drill")
	else if choice starts with "Restore rollback" then
		runInTerminal("rbk-restore.sh", "--rollback")
	else if choice starts with "Fix paths" then
		runInTerminal("rbk-fixpaths.sh", "")
	else if choice starts with "Run self-test" then
		runInTerminal("rbk-selftest.sh", "")
	else if choice starts with "Open backup" then
		openBackupFolder()
	else if choice starts with "View log" then
		do shell script "/usr/bin/open -a Console " & quoted form of ((POSIX path of (path to home folder)) & "Library/Logs/rekordbox-backup/rekordbox-backup.log")
	end if
end moreMenu

on run
	if not isInstalled() then
		firstRunSetup()
		return
	end if
	set statusText to shortStatus()
	if autoState() is "on" then
		set pauseLabel to "Pause automatic backups"
	else
		set pauseLabel to "Resume automatic backups"
	end if
	try
		set answer to button returned of (display dialog statusText with title appTitle buttons {"More…", pauseLabel, "Back up now"} default button "Back up now" cancel button "More…" with icon note)
	on error number -128
		-- "More…" is the cancel button so that Esc also opens the tools menu
		moreMenu()
		return
	end try
	if answer is "Back up now" then
		backupNow()
	else if answer is pauseLabel then
		togglePause()
	end if
end run
