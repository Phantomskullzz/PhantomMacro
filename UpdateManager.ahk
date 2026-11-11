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


UpdateNotesPreview(notes) {
    nl := Chr(13) Chr(10)
    out := "", count := 0
    for rawLine in StrSplit(StrReplace(notes, Chr(13)), Chr(10)) {
        line := Trim(RegExReplace(Trim(rawLine), "^[#*>-]+\s*"))
        if line = ""
            continue
        out .= (count ? nl : "") "• " SubStr(line, 1, 110)
        count += 1
        if count >= 5
            break
    }
    return count ? out : "• Private update available." nl "• Existing settings and presets will be preserved."
}

ShowUpdateAvailableDialog(release) {
    global g, Pal, AppVersion
    choice := {install: false}
    dlg := Gui("+Owner" g.Hwnd " -Caption +Border", "PhantomMacro Update")
    dlg.BackColor := Pal["BG"]
    dlg.MarginX := 0
    dlg.MarginY := 0
    dlg.SetFont("s10 c" Pal["TEXT"], "Segoe UI")
    dlg.Add("Text", "x0 y0 w500 h394 Background" Pal["BG"])
    dlg.Add("Text", "x0 y0 w500 h4 Background" Pal["ACCENT"])
    dlg.SetFont("s14 Bold c" Pal["ACCENT_T"], "Segoe UI")
    dlg.Add("Text", "x24 y24 w44 h44 Center +0x200 Background" Pal["NAVON"], "↑")
    dlg.SetFont("s12 Bold c" Pal["TEXT"], "Segoe UI")
    dlg.Add("Text", "x82 y24 w365 h30 BackgroundTrans", "Update Available")
    dlg.SetFont("s8 c" Pal["MUTED"], "Segoe UI")
    dlg.Add("Text", "x82 y53 w374 h23 BackgroundTrans", "New private PhantomMacro release ready to install")
    dlg.Add("Text", "x0 y92 w500 h1 Background" Pal["NAVON"])
    dlg.Add("Text", "x24 y110 w212 h75 Background" Pal["FIELD"])
    dlg.Add("Text", "x264 y110 w212 h75 Background" Pal["NAVON"])
    dlg.SetFont("s8 Bold c" Pal["MUTED"], "Segoe UI")
    dlg.Add("Text", "x38 y119 w150 h18 BackgroundTrans", "CURRENT")
    dlg.Add("Text", "x278 y119 w150 h18 BackgroundTrans", "NEW")
    dlg.SetFont("s15 Bold c" Pal["TEXT"], "Segoe UI")
    dlg.Add("Text", "x38 y141 w172 h29 BackgroundTrans", "v" AppVersion)
    dlg.SetFont("s15 Bold c" Pal["ACCENT_T"], "Segoe UI")
    dlg.Add("Text", "x278 y141 w172 h29 BackgroundTrans", "v" release["version"])
    dlg.SetFont("s11 c" Pal["MUTED"], "Segoe UI")
    dlg.Add("Text", "x237 y138 w24 h26 Center BackgroundTrans", "→")
    dlg.SetFont("s8 Bold c" Pal["MUTED"], "Segoe UI")
    dlg.Add("Text", "x24 y201 w125 h20 BackgroundTrans", "WHAT'S NEW")
    dlg.Add("Text", "x124 y212 w352 h1 Background" Pal["NAVON"])
    dlg.SetFont("s9 c" Pal["TEXT"], "Segoe UI")
    notesBox := dlg.Add("Edit", "x24 y226 w452 h108 ReadOnly Multi -Theme -WantReturn -E0x200 Background" Pal["FIELD"] " c" Pal["TEXT"], UpdateNotesPreview(release["notes"]))
    DarkTheme(notesBox)
    dlg.SetFont("s8 c" Pal["MUTED"], "Segoe UI")
    dlg.Add("Text", "x24 y353 w272 h22 BackgroundTrans", "App restarts automatically after updating.")
    dlg.SetFont("s9 c" Pal["TEXT"], "Segoe UI")
    later := dlg.Add("Text", "x298 y346 w80 h34 Center +0x200 Background" Pal["FIELD"] " c" Pal["TEXT"], "Later")
    install := dlg.Add("Text", "x385 y346 w91 h34 Center +0x200 Background" Pal["ACCENT"] " c" Pal["ACCTXT"], "Install")
    later.OnEvent("Click", (*) => dlg.Destroy())
    install.OnEvent("Click", (*) => (choice.install := true, dlg.Destroy()))
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.OnEvent("Escape", (*) => dlg.Destroy())
    g.Opt("+Disabled")
    try {
        WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " g.Hwnd)
        dlg.Show("w500 h394 x" (gx + Round((gw - 500)/2)) " y" (gy + Round((gh - 394)/2)))
        RoundCtrl(later, 16)
        RoundCtrl(install, 16)
        WinActivate("ahk_id " dlg.Hwnd)
        WinWaitClose("ahk_id " dlg.Hwnd)
    } finally {
        try dlg.Destroy()
        g.Opt("-Disabled")
        try WinActivate("ahk_id " g.Hwnd)
    }
    return choice.install
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

; Run GitHub CLI hidden and poll a completion marker, never blocking the GUI
; with StdOut.ReadAll() or exposing a command window.
StartGitHubCommandAsync(arguments, callback, timeoutMs := 60000) {
    gh := GetGitHubCli()
    work := A_Temp "\PhantomMacro_Gh_" A_TickCount "_" Random(1000, 9999)
    DirCreate work
    batch := work "\run.cmd"
    outFile := work "\stdout.txt"
    errorFile := work "\stderr.txt"
    doneFile := work "\exitcode.txt"

    ; This temporary batch file never includes authentication tokens.
    ; The caller provides fixed arguments or a strictly validated tag.
    script := "@echo off" "`r`n"
        . "chcp 65001 >nul" "`r`n"
        . '"' gh '" ' arguments ' 1>"' outFile '" 2>"' errorFile '"' "`r`n"
        . 'set "PM_GH_EXIT=%errorlevel%"' "`r`n"
        . '> "' doneFile '" echo %PM_GH_EXIT%' "`r`n"
    FileAppend script, batch, "UTF-8-RAW"
    request := {work: work, stdout: outFile, stderr: errorFile,
        done: doneFile, callback: callback, start: A_TickCount,
        timeout: timeoutMs}
    try {
        ; cmd.exe and gh.exe are launched with a hidden window.
        Run('"' A_ComSpec '" /D /C "' batch '"', , "Hide")
        request.poll := PollGitHubCommand.Bind(request)
        SetTimer request.poll, 125
    } catch as e {
        try DirDelete work, true
        throw Error("Unable to launch GitHub CLI silently. " e.Message)
    }
}

; Decode a cmd.exe exit-code file defensively. UTF-8 BOM or control
; characters have appeared on some PCs, and the timer must not crash.
ParseGitHubExitCode(raw) {
    raw := StrReplace(raw, Chr(0xFEFF))
    raw := Trim(raw, " `t`r`n")
    if !RegExMatch(raw, "^-?[0-9]+$")
        throw Error("Unexpected GitHub CLI exit status: " SubStr(raw, 1, 40))
    return raw + 0  ; Arithmetic conversion yields a real AHK number.
}

PollGitHubCommand(request) {
    if !FileExist(request.done) && A_TickCount - request.start < request.timeout
        return
    SetTimer request.poll, 0
    code := -1, output := "", errors := ""
    try {
        if FileExist(request.done) {
            rawCode := FileRead(request.done, "UTF-8")
            code := ParseGitHubExitCode(rawCode)
        } else
            errors := "The private GitHub request timed out."
        if FileExist(request.stdout)
            output := FileRead(request.stdout, "UTF-8")
        if FileExist(request.stderr)
            errors .= FileRead(request.stderr, "UTF-8")
    } catch as e {
        code := -1
        errors .= "Cannot read GitHub command result: " e.Message
    }
    try {
        request.callback.Call(code, output, errors)
    } catch as e {
        ; This function executes on a timer; no exception may escape the timer.
        try {
            SetUpdateMessage("Private update error")
            UpdateDialogMessage("An unexpected updater error occurred:`n" e.Message, "Icon!")
        }
        try {
            global UpdatingNow
            UpdatingNow := false
        }
    } finally {
        try DirDelete request.work, true
    }
}

; Decode common JSON escapes from gh release view --json tagName,body.
UnescapeReleaseJson(value) {
    out := "", i := 1
    while i <= StrLen(value) {
        c := SubStr(value, i, 1)
        if c = "\" && i < StrLen(value) {
            n := SubStr(value, i + 1, 1)
            switch n {
                case "n": out .= "`n"
                case "r": out .= "`r"
                case "t": out .= "`t"
                case '"': out .= '"'
                case "u":
                    hex := SubStr(value, i + 2, 4)
                    if RegExMatch(hex, "^[0-9A-Fa-f]{4}$") {
                        out .= Chr(("0x" hex) + 0)
                        i += 6
                        continue
                    }
                    out .= n
                default: out .= n
            }
            i += 2
        } else {
            out .= c
            i += 1
        }
    }
    return out
}

ReadLatestReleaseJson(output) {
    if !RegExMatch(output, '"tagName"\s*:\s*"([^"]+)"', &tagMatch)
        throw Error("GitHub CLI did not return a release tag.")
    tag := tagMatch[1]
    if !RegExMatch(tag, "^v?([0-9]+\.[0-9]+\.[0-9]+)$", &version)
        throw Error("Unexpected release tag: " tag)
    notes := ""
    if RegExMatch(output, '"body"\s*:\s*"((?:\\.|[^"\\])*)"', &bodyMatch)
        notes := UnescapeReleaseJson(bodyMatch[1])
    return Map("version", version[1], "tag", tag, "notes", notes)
}

GitHubRequestError(code, errors) {
    reason := Trim(errors, " `t`r`n")
    if StrLen(reason) > 500
        reason := SubStr(reason, 1, 500) "..."
    if code = -1
        return "Private GitHub request timed out." (reason != "" ? "`n" reason : "")
    return "GitHub CLI request failed (exit " code ")."
        . (reason != "" ? "`n" reason : "`nCheck GitHub CLI login and access to Phantomskullzz/PhantomMacro.")
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
    SetUpdateMessage("Checking private GitHub Releases...")
    try {
        ; One hidden, nonblocking gh process checks credentials and release data.
        StartGitHubCommandAsync(
            'release view --repo "Phantomskullzz/PhantomMacro" --json tagName,body',
            OnPrivateReleaseCheck.Bind(quiet), 35000)
    } catch as e {
        UpdatingNow := false
        SetUpdateMessage("Private update check unavailable")
        if quiet
            Log("Private update check: " e.Message)
        else
            UpdateDialogMessage(e.Message, "Icon!")
    }
}

OnPrivateReleaseCheck(quiet, code, output, errors) {
    global UpdatingNow, AppVersion
    downloading := false
    try {
        if code != 0
            throw Error(GitHubRequestError(code, errors))
        latest := ReadLatestReleaseJson(output)
        if VerCompare(latest["version"], AppVersion) <= 0 {
            SetUpdateMessage("v" AppVersion " - up to date (private)")
            if !quiet
                UpdateDialogMessage("You're on the latest private release (v" AppVersion ").", "Iconi")
            return
        }
        SetUpdateMessage("Private update v" latest["version"] " available")
        Log("Private GitHub update available: v" latest["version"])
        if ShowUpdateAvailableDialog(latest) {
            InstallPhantomRelease(latest)
            downloading := true
        } else
            SetUpdateMessage("Update postponed: v" latest["version"])
    } catch as e {
        SetUpdateMessage("v" AppVersion " - private update check unavailable")
        if quiet
            Log("Private update check: " StrReplace(e.Message, "`n", " / "))
        else
            UpdateDialogMessage(e.Message, "Icon!")
    } finally {
        if !downloading
            UpdatingNow := false
    }
}

InstallPhantomRelease(latest) {
    global Running, Recording
    if Running || Recording
        throw Error("Stop playback and recording before installing updates.")
    work := A_Temp "\PhantomMacro_PrivateUpdate_" A_TickCount
    DirCreate work
    SetUpdateMessage("Downloading private release v" latest["version"] "...")
    ; The release tag passed a strict vX.Y.Z validator before reaching the shell.
    args := 'release download "' latest["tag"] '" --repo "Phantomskullzz/PhantomMacro"'
        . ' --pattern "PhantomMacro_Update.zip" --dir "' work '" --clobber'
    try StartGitHubCommandAsync(args, FinishPrivateReleaseDownload.Bind(latest, work), 120000)
    catch as e {
        try DirDelete work, true
        throw Error("Could not start the private release download: " e.Message)
    }
}

FinishPrivateReleaseDownload(latest, work, code, output, errors) {
    global UpdatingNow
    try {
        if code != 0
            throw Error("Could not download v" latest["version"] ".`n" GitHubRequestError(code, errors))
        unpack := work "\extracted"
        archive := work "\PhantomMacro_Update.zip"
        if !FileExist(archive) || FileGetSize(archive) < 1024
            throw Error("The GitHub release is missing PhantomMacro_Update.zip.")
        zipped := FileOpen(archive, "r")
        signature := zipped.ReadUShort()
        zipped.Close()
        if signature != 0x4B50
            throw Error("The downloaded asset is not a ZIP archive.")
        tar := A_WinDir "\System32\tar.exe"
        if !FileExist(tar)
            throw Error("Windows tar.exe is required to unpack releases.")
        DirCreate unpack
        if RunWait('"' tar '" -xf "' archive '" -C "' unpack '"', , "Hide") != 0
            throw Error("Could not extract the downloaded ZIP.")

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
            throw Error("Release tag and downloaded launcher version do not match.")

        helper := work "\UpdateApply.ahk"
        FileCopy A_ScriptDir "\UpdateApply.ahk", helper, 1
        PersistSettings()
        SetUpdateMessage("Applying update and restarting...")
        currentPid := DllCall("GetCurrentProcessId", "UInt")
        Run '"' A_AhkPath '" "' helper '" "' root '" "' A_ScriptDir '" "' currentPid '"', , "Hide"
        ExitApp
    } catch as e {
        SetUpdateMessage("Private update failed - please retry")
        UpdateDialogMessage(e.Message, "Icon!")
        try DirDelete work, true
    } finally {
        UpdatingNow := false
    }
}
