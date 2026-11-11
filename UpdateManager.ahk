#Requires AutoHotkey v2.0
; UpdateManager.ahk - authenticated PRIVATE GitHub Releases updater.
; Only loads from the fixed repository below, through GitHub CLI (gh).
; No personal access tokens or GitHub passwords are stored in the AHK files.
;
; The user signs in ON THIS PC once using: gh auth login --web
; GitHub CLI manages the credential; PhantomMacro only runs gh commands.
; The released ZIP must be named PhantomMacro_Update.zip and include the
; five AHK application files, either at root or inside PhantomMacro/.


; Tie update dialogs to the main PhantomMacro window, not the desktop.
; Owner HWND keeps the prompt above the GUI and makes confirmation modal,
; including when called from the automatic startup update-check timer.
UpdateDialogMessage(message, options := "Icon!") {
    global g
    if IsObject(g) {
        g.Opt("+OwnDialogs")
        try {
            if WinGetMinMax("ahk_id " g.Hwnd) = -1
                WinRestore("ahk_id " g.Hwnd)
            WinActivate("ahk_id " g.Hwnd)
        } catch {
            ; The owner HWND still keeps the dialog above the GUI if activation fails.
        }
        return MsgBox(message, "PhantomMacro Update", options " Owner" g.Hwnd)
    }
    return MsgBox(message, "PhantomMacro Update", options)
}

SetUpdateMessage(message) {
    global updateStatusLabel
    if IsObject(updateStatusLabel)
        updateStatusLabel.Text := message
}

; Find GitHub CLI on typical Windows installs. Also support a normal PATH install.
GetGitHubCli() {
    candidates := [
        A_ProgramFiles "\GitHub CLI\gh.exe",
        A_ProgramFiles "\GitHub CLI\bin\gh.exe",
        EnvGet("LOCALAPPDATA") "\Programs\GitHub CLI\gh.exe",
        EnvGet("LOCALAPPDATA") "\Microsoft\WinGet\Links\gh.exe"
    ]
    for candidate in candidates {
        if FileExist(candidate)
            return candidate
    }
    return "gh.exe"
}

; Run GitHub CLI using WScript.Shell.Exec (no cmd.exe or shell expansion).
; Arguments below are either constants or tightly validated release tags.
; Do not print gh authentication tokens or pass them into command arguments.
RunGitHubCliCapture(arguments) {
    gh := GetGitHubCli()
    try {
        process := ComObject("WScript.Shell").Exec('"' gh '" ' arguments)
        output := process.StdOut.ReadAll()
        errors := process.StdErr.ReadAll()
        exitCode := process.ExitCode
    } catch as e {
        throw Error("GitHub CLI (gh) was not found or could not start.`n"
            . "Install it from https://cli.github.com/, then open PowerShell and run:`n"
            . "gh auth login --web`n`n" e.Message)
    }
    if exitCode != 0 {
        ; Limit output in dialogs, and never request/show gh auth tokens.
        reason := Trim(errors != "" ? errors : output, " `t`r`n")
        if StrLen(reason) > 500
            reason := SubStr(reason, 1, 500) "..."
        throw Error("GitHub CLI could not complete the request (exit " exitCode ")."
            . (reason != "" ? "`n" reason : ""))
    }
    return Trim(output, " `t`r`n")
}

EnsurePrivateGitHubLogin() {
    ; Check authentication WITHOUT retrieving or exposing an access token.
    try {
        RunGitHubCliCapture("auth status --hostname github.com")
    } catch as e {
        throw Error("Private releases need a GitHub login on THIS computer.`n"
            . "Open PowerShell and run:`n"
            . "gh auth login --web`n`n"
            . "Use the GitHub account with access to Phantomskullzz/PhantomMacro.`n`n"
            . e.Message)
    }
}

GetLatestPhantomRelease() {
    EnsurePrivateGitHubLogin()
    try {
        ; No explicit tag => latest published release, not a draft.
        tag := RunGitHubCliCapture('release view --repo "Phantomskullzz/PhantomMacro" --json tagName --jq .tagName')
    } catch as e {
        throw Error("Cannot read the latest PRIVATE GitHub Release.`n"
            . "Check that the account has repository access and a published Release exists.`n`n"
            . e.Message)
    }
    ; Never let release data inject arbitrary command-line arguments.
    if !RegExMatch(tag, '^v?([0-9]+\.[0-9]+\.[0-9]+)$', &version)
        throw Error("The release tag must be vX.Y.Z (for example v0.3.1). Got: " tag)
    return Map("version", version[1], "tag", tag)
}

CheckForUpdates(quiet := false) {
    global UpdatingNow, AppVersion, Running, Recording
    if UpdatingNow
        return
    if Running || Recording {
        if !quiet
            UpdateDialogMessage("Stop playback or recording before checking for updates.", "Icon!")
        return
    }
    UpdatingNow := true
    try {
        SetUpdateMessage("Checking private GitHub Releases...")
        latest := GetLatestPhantomRelease()
        if VerCompare(latest["version"], AppVersion) <= 0 {
            SetUpdateMessage("v" AppVersion " - up to date (private)")
            if !quiet
                UpdateDialogMessage("You're on the latest private release (v" AppVersion ").", "Iconi")
            return
        }
        SetUpdateMessage("Private update v" latest["version"] " available")
        Log("Private GitHub update available: v" latest["version"])
        answer := UpdateDialogMessage("PhantomMacro v" latest["version"] " is available in your private GitHub repository."
            . "`n`nInstall it now?`nYour settings.ini and presets will not be replaced.", "YesNo Iconi")
        if answer = "Yes"
            InstallPhantomRelease(latest)
    } catch as e {
        SetUpdateMessage("v" AppVersion " - private update check unavailable")
        if quiet
            Log("Private update check: " StrReplace(e.Message, "`n", " / "))
        else
            UpdateDialogMessage(e.Message, "Icon!")
    } finally {
        UpdatingNow := false
    }
}

InstallPhantomRelease(latest) {
    global Running, Recording
    if Running || Recording
        throw Error("Stop playback and recording before installing updates.")

    gh := GetGitHubCli()
    work := A_Temp "\PhantomMacro_PrivateUpdate_" A_TickCount
    unpack := work "\extracted"
    DirCreate unpack
    archive := work "\PhantomMacro_Update.zip"

    ; Authenticate again in case the user switched accounts since the check.
    EnsurePrivateGitHubLogin()
    SetUpdateMessage("Downloading private release v" latest["version"] "...")
    ; Tag was validated against ^v?NUMBER.NUMBER.NUMBER$.
    command := '"' gh '" release download "' latest["tag"] '" --repo "Phantomskullzz/PhantomMacro" --pattern "PhantomMacro_Update.zip" --dir "' work '" --clobber'
    try exitCode := RunWait(command, , "Hide")
    catch as e
        throw Error("Could not launch GitHub CLI to download the release: " e.Message)
    if exitCode != 0
        throw Error("GitHub CLI could not download the PRIVATE release (exit " exitCode ")."
            . "`nCheck repository access, the release tag, and that the release has a PhantomMacro_Update.zip asset.")
    if !FileExist(archive) || FileGetSize(archive) < 1024
        throw Error("The Release must contain a nonempty PhantomMacro_Update.zip asset.")

    zipped := FileOpen(archive, "r")
    signature := zipped.ReadUShort()
    zipped.Close()
    if signature != 0x4B50
        throw Error("The downloaded asset is not a ZIP archive.")

    tar := A_WinDir "\System32\tar.exe"
    if !FileExist(tar)
        throw Error("Windows tar.exe is required to unpack releases.")
    rc := RunWait('"' tar '" -xf "' archive '" -C "' unpack '"', , "Hide")
    if rc != 0
        throw Error("Could not extract the ZIP (tar exit " rc ").")

    root := FileExist(unpack "\PhantomMacro\PhantomMacro.ahk") ? unpack "\PhantomMacro" : unpack
    programFiles := ["PhantomMacro.ahk", "GUI.ahk", "Macro.ahk", "UpdateManager.ahk", "UpdateApply.ahk"]
    for filename in programFiles {
        if !FileExist(root "\" filename)
            throw Error("The update ZIP is missing " filename ".")
    }
    launcherText := FileRead(root "\PhantomMacro.ahk", "UTF-8")
    if !RegExMatch(launcherText, 'global AppVersion\s*:=\s*"([0-9]+\.[0-9]+\.[0-9]+)"', &embeddedVersion)
        throw Error("The downloaded launcher has no AppVersion.")
    if embeddedVersion[1] != latest["version"]
        throw Error("The release version and downloaded launcher version do not match.")

    ; Hand off replacement to a separate temporary AHK process, after exiting.
    helper := work "\UpdateApply.ahk"
    FileCopy A_ScriptDir "\UpdateApply.ahk", helper, 1
    PersistSettings()
    SetUpdateMessage("Applying update and restarting...")
    currentPid := DllCall("GetCurrentProcessId", "UInt")
    Run '"' A_AhkPath '" "' helper '" "' root '" "' A_ScriptDir '" "' currentPid '"'
    ExitApp
}
