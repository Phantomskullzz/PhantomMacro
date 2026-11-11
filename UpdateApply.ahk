#Requires AutoHotkey v2.0
#SingleInstance Off
; UpdateApply.ahk runs from a TEMPORARY copy after the main app exits.
; Replaces ONLY the 5 application .ahk files. Never touches settings.ini,
; presets/, or update_backups/. Creates a backup before modifying files.

if A_Args.Length != 3 {
    MsgBox "Updater arguments are missing.", "PhantomMacro Update", "Icon!"
    ExitApp 1
}
sourceDir := A_Args[1]
installDir := A_Args[2]
if !RegExMatch(A_Args[3], "^[0-9]+$") {
    MsgBox "Updater received an invalid process ID.", "PhantomMacro Update", "Icon!"
    ExitApp 1
}
oldPid := A_Args[3] + 0
filesToUpdate := ["PhantomMacro.ahk", "GUI.ahk", "Macro.ahk", "UpdateManager.ahk", "UpdateApply.ahk"]
backupDir := installDir "\update_backups\before_" FormatTime(, "yyyyMMdd_HHmmss") "_" A_TickCount
replaced := []
try {
    ; Wait until the AHK process has released its script files.
    Loop 100 {
        if !ProcessExist(oldPid)
            break
        Sleep 200
    }
    if ProcessExist(oldPid)
        throw Error("PhantomMacro did not close within 20 seconds.")
    if !FileExist(installDir "\PhantomMacro.ahk")
        throw Error("The original PhantomMacro installation was not found.")
    for name in filesToUpdate {
        if !FileExist(sourceDir "\" name)
            throw Error("Missing update file: " name)
    }
    DirCreate backupDir
    ; Keep original files intact until the backup phase is complete.
    for name in filesToUpdate {
        if FileExist(installDir "\" name)
            FileCopy installDir "\" name, backupDir "\" name, 1
    }
    for name in filesToUpdate {
        ; Record the target before copying so a partially written file is
        ; rolled back even if FileCopy itself throws an exception.
        replaced.Push(name)
        FileCopy sourceDir "\" name, installDir "\" name, 1
    }
    Run '"' A_AhkPath '" "' installDir '\PhantomMacro.ahk"'
} catch as e {
    ; Restore the earlier version on any copy/launch error.
    rollbackErrors := ""
    for name in replaced {
        try {
            if FileExist(backupDir "\" name)
                FileCopy backupDir "\" name, installDir "\" name, 1
            else if FileExist(installDir "\" name)
                FileDelete installDir "\" name
        } catch as restoreError {
            rollbackErrors .= "`n" name ": " restoreError.Message
        }
    }
    MsgBox "Update failed: " e.Message "`n`nBackups: " backupDir (rollbackErrors != "" ? "`nRollback errors:" rollbackErrors : ""), "PhantomMacro Update", "Icon!"
    if replaced.Length && rollbackErrors = "" {
        try Run '"' A_AhkPath '" "' installDir '\PhantomMacro.ahk"'
    }
    ExitApp 1
}
