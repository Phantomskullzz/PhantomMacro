; ExportManager.ahk — build a single-file standalone player with Ahk2Exe.
; No GitHub, network, or player-side settings file is used.

OpenExportDialog(*) {
    global g, ddl, edLoops, edSpeed, edWin, PresetDir, Pal, CurTheme, ActionHotkeys, chkTop
    global Running, Recording, PickingTarget, ExportDialogHwnd, AppIconPath
    if Running || Recording || PickingTarget {
        MsgBox "Stop playback, recording or Pick EXE before exporting.", "Export EXE", "Icon!"
        return
    }
    if ddl.Text = "" {
        MsgBox "Choose or record a preset first.", "Export EXE", "Icon!"
        return
    }
    presetFile := PresetDir "\" ddl.Text ".txt"
    if !FileExist(presetFile) {
        MsgBox "Preset file was not found:`n" presetFile, "Export EXE", "Icon!"
        return
    }
    if Trim(edWin.Value) = "" {
        MsgBox "Pick a target EXE in Settings before exporting.", "Export EXE", "Icon!"
        return
    }
    name := RegExReplace(ddl.Text, "[^a-zA-Z0-9 _-]", "_")
    if name = ""
        name := "MyMacro"

    ; Same captionless theme treatment as the main PhantomMacro window.
    ; This removes the system's black title bar on Windows 10/11.
    dlg := Gui("+Owner" g.Hwnd " -MaximizeBox -Caption", "Export Standalone Macro")
    SetMacroWindowIcon(dlg)
    dlg.BackColor := Pal["BG"]
    dlg.MarginX := 0
    dlg.MarginY := 0
    dlg.SetFont("s9 Bold c" Pal["TEXT"], "Segoe UI")
    dlg.Add("Text", "x0 y0 w414 h28 Background" Pal["SIDE"])
    if FileExist(AppIconPath) {
        try dlg.Add("Picture", "x9 y4 w20 h20", AppIconPath)
    }
    dlg.Add("Text", "x37 y4 w326 h20 +0x200 BackgroundTrans c" Pal["TEXT"], "Export Standalone Macro")
    dlg.SetFont("s9 Bold c" Pal["MUTED"], "Segoe UI")
    closeBtn := dlg.Add("Text", "x382 y3 w28 h22 +0x200 Center Background" Pal["SIDE"] " c" Pal["MUTED"], "×")
    closeBtn.OnEvent("Click", (*) => CloseExportDialog(dlg))
    UiRegisterHover(closeBtn, Pal["SIDE"], Pal["MUTED"], Pal["DANGER"], Pal["DANGERTXT"])
    dlg.SetFont("s10 c" Pal["TEXT"], "Segoe UI")
    dlg.Add("Text", "x18 y46 w390 BackgroundTrans c" Pal["ACCENT_T"], "Export recording as EXE")
    dlg.SetFont("s9 c" Pal["MUTED"])
    dlg.Add("Text", "x18 y71 w395", "Recording: " ddl.Text)
    dlg.Add("Text", "x18 y100 w175", "EXE name")
    nameEdit := dlg.Add("Edit", "x18 y119 w375 h26", name)
    dlg.Add("Text", "x18 y157 w155", "Loops (0 = unlimited)")
    dlg.Add("Text", "x211 y157 w170", "Speed (1.0 = normal)")
    loopEdit := dlg.Add("Edit", "x18 y177 w165 h26 Number", Trim(edLoops.Value) = "" ? "1" : edLoops.Value)
    speedEdit := dlg.Add("Edit", "x211 y177 w182 h26", edSpeed.Value)
    autoCheck := dlg.Add("CheckBox", "x18 y218 w380 h24 c" Pal["TEXT"], "Start playback when the EXE opens")
    ; Default to the current in-app setting, but allow an export-specific choice.
    stayTopCheck := dlg.Add("CheckBox", "x18 y247 w380 h24 c" Pal["TEXT"], "Keep exported EXE above other windows")
    stayTopCheck.Value := chkTop.Value ? 1 : 0
    dlg.SetFont("s8 c" Pal["MUTED"])
    dlg.Add("Text", "x18 y282 w375 h38", "Exported hotkeys: " ShowHotkey(ActionHotkeys["start"]) " starts, "
        . ShowHotkey(ActionHotkeys["stop"]) " stops. Loops and speed are editable while stopped.")
    dlg.Add("Text", "x18 y332 w375 h35", "Changes made in the exported EXE are temporary and won't be saved when you close it.")
    dlg.SetFont("s9 c" Pal["TEXT"])
    cancel := dlg.Add("Text", "x193 y389 w92 h32 +0x200 Center Background" Pal["FIELD"] " c" Pal["TEXT"], "Cancel")
    cancel.OnEvent("Click", (*) => CloseExportDialog(dlg))
    UiRegisterHover(cancel, Pal["FIELD"], Pal["TEXT"], Pal["NAVON"], Pal["ACCENT_T"])
    exportBtn := dlg.Add("Text", "x293 y389 w100 h32 +0x200 Center Background" Pal["ACCENT"] " c" Pal["ACCTXT"], "Build EXE")
    UiRegisterHover(exportBtn, Pal["ACCENT"], Pal["ACCTXT"], Pal["ACCENT_T"], Pal["ACCTXT"])
    exportBtn.OnEvent("Click", BuildExportedMacro.Bind(dlg, nameEdit, loopEdit, speedEdit,
        autoCheck, stayTopCheck, presetFile, Trim(edWin.Value),
        LegacyPresetKey("upkey", "t"), LegacyPresetKey("sellkey", "x")))
    dlg.OnEvent("Close", (*) => CloseExportDialog(dlg))
    dlg.OnEvent("Escape", (*) => CloseExportDialog(dlg))
    ExportDialogHwnd := dlg.Hwnd
    OnMessage(0x201, ExportDialogDrag)
    dlg.Show("w414 h440")
    ; No +Border: Windows' 1px light frame looked grey around the dark dialog.
    ; Enforce rounded corners on older Windows; use DWM's native rounded
    ; corners on Win11 while explicitly disabling the grey accent border.
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", dlg.Hwnd,
        "int", 34, "uint*", 0xFFFFFFFE, "int", 4)
    if VerCompare(A_OSVersion, "10.0.22000") >= 0 {
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", dlg.Hwnd,
            "int", 33, "int*", 2, "int", 4)
    } else {
        WinGetPos(, , &ww, &wh, "ahk_id " dlg.Hwnd)
        region := DllCall("gdi32\CreateRoundRectRgn", "int", 0, "int", 0,
            "int", ww + 1, "int", wh + 1, "int", 20, "int", 20, "ptr")
        if region && !DllCall("user32\SetWindowRgn", "ptr", dlg.Hwnd,
            "ptr", region, "int", true, "int")
            DllCall("gdi32\DeleteObject", "ptr", region)
    }
    ; Keep Cancel and Build EXE rectangular in both idle and hovered states.
    ; Do not clip with RoundCtrl: changing the background on hover can cause
    ; clipping artefacts on some versions of Windows.
}

; Drag only from the custom 28px header, never the close button or fields.
ExportDialogDrag(wParam, lParam, msg, hwnd) {
    global ExportDialogHwnd
    if !ExportDialogHwnd
        return
    if hwnd != ExportDialogHwnd
        if DllCall("user32\GetAncestor", "ptr", hwnd, "uint", 2, "ptr") != ExportDialogHwnd
            return
    MouseGetPos(&mx, &my, &topWindow)
    if topWindow != ExportDialogHwnd
        return
    WinGetPos(&wx, &wy, , , "ahk_id " ExportDialogHwnd)
    if my >= wy && my < wy + Round(28 * A_ScreenDPI / 96)
        && mx >= wx && mx < wx + Round(374 * A_ScreenDPI / 96)
        PostMessage 0xA1, 2, , , "ahk_id " ExportDialogHwnd
}

CloseExportDialog(dlg) {
    global UiHoverButtons, ExportDialogHwnd
    if ExportDialogHwnd = dlg.Hwnd {
        OnMessage(0x201, ExportDialogDrag, 0)
        ExportDialogHwnd := 0
    }
    for id, entry in UiHoverButtons.Clone() {
        try {
            if DllCall("user32\GetAncestor", "ptr", id, "uint", 2, "ptr") = dlg.Hwnd
                UiForgetHover(entry.ctrl)
        }
    }
    dlg.Destroy()
}

ExportAhkLiteral(text) {
    ; Single-quoted strings are easy to embed safely; doubled apostrophes and
    ; escaped backticks keep presets as DATA, never interpreted as AHK source.
    return "'" StrReplace(StrReplace(text, "``", "````"), "'", "''") "'"
}

ExportNumber(value, key, allowZero := false) {
    value := Trim(value)
    if !RegExMatch(value, "^[0-9]+(?:\.[0-9]+)?$")
        throw Error(key " must be a nonnegative number.")
    converted := value + 0
    if !allowZero && converted <= 0
        throw Error(key " must be greater than zero.")
    return converted
}

FindAhkCompiler() {
    dirs := []
    SplitPath A_AhkPath, , &ahkDir
    dirs.Push(ahkDir "\Compiler\Ahk2Exe.exe")
    dirs.Push(ahkDir "\..\Compiler\Ahk2Exe.exe")
    dirs.Push(A_ProgramFiles "\AutoHotkey\Compiler\Ahk2Exe.exe")
    dirs.Push(A_ProgramFiles "\AutoHotkey\v2\Compiler\Ahk2Exe.exe")
    ; AutoHotkey also supports per-user installation (no admin required).
    dirs.Push(EnvGet("LOCALAPPDATA") "\Programs\AutoHotkey\Compiler\Ahk2Exe.exe")
    dirs.Push(A_ScriptDir "\Compiler\Ahk2Exe.exe")
    for candidate in dirs {
        if FileExist(candidate)
            return candidate
    }
    response := MsgBox("Export EXE requires Ahk2Exe.exe and AutoHotkey v2.`n`n"
        . "Get AutoHotkey v2 from the official site:`n"
        . "https://www.autohotkey.com/`n`n"
        . "After installing, open AutoHotkey Dash > Compile to install Ahk2Exe if needed.`n`n"
        . "Already installed? Locate Ahk2Exe.exe on this PC?", "Compiler required", "YesNo Icon?")
    if response != "Yes"
        return ""
    selected := FileSelect(1, A_ProgramFiles, "Select Ahk2Exe.exe", "Programs (*.exe)")
    if selected = ""
        return ""
    SplitPath selected, &selectedName
    if StrLower(selectedName) != "ahk2exe.exe"
        throw Error("Please select a valid Ahk2Exe.exe compiler.")
    return selected
}

; Ahk2Exe needs a v2 interpreter as its base. After compiling the main app,
; A_AhkPath may refer to PhantomMacro.exe, which is NOT a valid v2 base.
FindAhkBase() {
    if !A_IsCompiled && FileExist(A_AhkPath)
        return A_AhkPath

    candidates := [
        A_ProgramFiles "\AutoHotkey\v2\AutoHotkey64.exe",
        A_ProgramFiles "\AutoHotkey\v2\AutoHotkey32.exe",
        EnvGet("LOCALAPPDATA") "\Programs\AutoHotkey\v2\AutoHotkey64.exe"
    ]
    for candidate in candidates {
        if !FileExist(candidate)
            continue
        version := ""
        try version := FileGetVersion(candidate)
        if RegExMatch(version, "^2\.")
            return candidate
    }
    MsgBox("An AutoHotkey v2 interpreter is required to export macros from compiled PhantomMacro."
        . "`n`nInstall AutoHotkey v2 from https://www.autohotkey.com/"
        . "`nThen select AutoHotkey64.exe (v2) on your PC.", "AutoHotkey v2 required", "Iconi")
    selected := FileSelect(1, A_ProgramFiles, "Select an AutoHotkey v2 interpreter", "Programs (*.exe)")
    if selected = ""
        return ""
    try {
        if !RegExMatch(FileGetVersion(selected), "^2\.")
            throw Error("The selected program is not an AutoHotkey v2 interpreter.")
    } catch as err {
        throw Error("Could not verify the AutoHotkey v2 interpreter: " err.Message)
    }
    return selected
}

BuildExportedMacro(dlg, nameEdit, loopEdit, speedEdit, autoCheck, stayTopCheck,
    presetFile, target, upgradeKey, sellKey, *) {
    global AppIconPath, PlayerTemplatePath, PresetDir, CurTheme, Pal, ActionHotkeys
    work := ""
    exportedPath := ""
    successNotice := ""
    try {
        baseName := Trim(nameEdit.Value)
        if !RegExMatch(baseName, "^[a-zA-Z0-9][a-zA-Z0-9 _.-]{0,80}$")
            throw Error("Use a simple EXE name containing letters, numbers, spaces, dots, '-' or '_'.")
        if StrLower(SubStr(baseName, -4)) = ".exe"
            baseName := SubStr(baseName, 1, -4)
        loops := ExportNumber(loopEdit.Value, "Loops", true)
        if loops != Floor(loops) || loops > 10000000
            throw Error("Loops must be a whole number between 0 and 10,000,000 (0 = unlimited).")
        speed := ExportNumber(speedEdit.Value, "Playback speed")
        ; Save while the dialog still exists. Never read its controls after closing.
        stayOnTop := stayTopCheck.Value ? true : false
        autoStart := autoCheck.Value ? true : false
        if speed < 0.1 || speed > 10
            throw Error("Speed must be between 0.1 and 10.0.")
        if !FileExist(AppIconPath)
            throw Error("PhantomMacro.ico is missing. Keep it in your macro folder.")
        compiler := FindAhkCompiler()
        if compiler = ""
            return
        baseExe := FindAhkBase()
        if baseExe = ""
            return
        steps := LoadPreset(presetFile)
        if !steps.Length
            throw Error("The selected recording is empty.")
        ; Verify the recorded commands before handing them to a compiled player.
        allowed := Map("click", 3, "move", 3, "mousedown", 2,
            "mouseup", 2, "wheel", 2, "keydown", 2, "keyup", 2,
            "place", 4, "upgrade", 3, "sell", 3, "key", 2,
            "wait", 2, "waitpixel", 4)
        for i, step in steps {
            cmd := StrLower(step[1])
            if !allowed.Has(cmd) || step.Length < allowed[cmd]
                throw Error("Invalid recording command on step " i ": " Join(step))
        }
        requestedPath := FileSelect("S", A_ScriptDir "\" baseName ".exe",
            "Save standalone macro EXE", "EXE applications (*.exe)")
        if requestedPath = ""
            return
        if StrLower(SubStr(requestedPath, -4)) != ".exe"
            requestedPath .= ".exe"
        if FileExist(requestedPath) {
            if MsgBox("Replace the existing EXE?`n" requestedPath,
                "Confirm overwrite", "YesNo Icon?") != "Yes"
                return
        }
        ; Capture the currently active shortcuts at the moment Build EXE is clicked,
        ; not the factory F5/F8 defaults or unfinished text in a hotkey editor.
        startBind := ActionHotkeys["start"]
        stopBind := ActionHotkeys["stop"]
        if startBind = "" || stopBind = "" || HotkeyId(startBind) = HotkeyId(stopBind)
            throw Error("Start and Stop hotkeys must be different, complete bindings.")
        template := FileRead(PlayerTemplatePath, "UTF-8")
        marker := ";__PM_EXPORT_CONFIGURATION__"
        if !InStr(template, marker)
            throw Error("PlayerTemplate.ahk is missing or incompatible.")
        SplitPath presetFile, &presetName, , , &stem
        paletteKeys := ["BG", "SIDE", "NAVON", "FIELD", "TEXT", "MUTED",
            "ACCENT", "ACCENT_T", "ACCTXT", "DANGER", "DANGERTXT", "DARK"]
        paletteSource := "global PlayerPalette := Map(" 
        for index, colorKey in paletteKeys
            paletteSource .= (index > 1 ? ", " : "") ExportAhkLiteral(colorKey) ", " ExportAhkLiteral(Pal[colorKey])
        paletteSource .= ")`r`n"
        config := "global PlayerTitle := " ExportAhkLiteral(baseName) "`r`n"
            . "global PlayerThemeName := " ExportAhkLiteral(CurTheme) "`r`n"
            . paletteSource
            . "global PlayerTarget := " ExportAhkLiteral(target) "`r`n"
            . "global PlayerLoopsDefault := " loops "`r`n"
            . "global PlayerSpeedDefault := " speed "`r`n"
            . "global PlayerAutoStart := " (autoStart ? "true" : "false") "`r`n"
            . "global PlayerAlwaysOnTop := " (stayOnTop ? "true" : "false") "`r`n"
            . "global PlayerStartHotkey := " ExportAhkLiteral(startBind) "`r`n"
            . "global PlayerStopHotkey := " ExportAhkLiteral(stopBind) "`r`n"
            . "global PlayerUpgradeKey := " ExportAhkLiteral(upgradeKey) "`r`n"
            . "global PlayerSellKey := " ExportAhkLiteral(sellKey) "`r`n"
            . "global PlayerPreset := [`r`n"
        for index, step in steps {
            line := Join(step)
            config .= "    " ExportAhkLiteral(line)
                . (index < steps.Length ? "," : "") "`r`n"
        }
        config .= "]`r`n"
        outputSource := StrReplace(template, marker, config)
        work := A_Temp "\PM_Export_" A_TickCount "_" Random(1000, 9999)
        DirCreate work
        scriptFile := work "\ExportedMacro.ahk"
        tempExe := work "\ExportedMacro.exe"
        FileAppend outputSource, scriptFile, "UTF-8"
        ; The compiler bundles the program, recording and icon into one file.
        command := '"' compiler '" /in "' scriptFile '" /out "' tempExe
            . '" /icon "' AppIconPath '" /base "' baseExe '"'
        code := RunWait(command, work, "Hide")
        if code != 0 || !FileExist(tempExe) || FileGetSize(tempExe) < 50000
            throw Error("Ahk2Exe failed (exit " code "). Ensure the AutoHotkey v2 compiler is installed.")
        ; Build confirmation while the dialog still exists. The filesystem move
        ; is the final build operation and is what defines export success.
        successNotice := "Standalone EXE created:`n" requestedPath "`n`n"
            . ShowHotkey(startBind) " Start | " ShowHotkey(stopBind)
            . " Stop. On top: " (stayOnTop ? "Yes" : "No") "."
        ; Move only after successful compilation; preserve any older EXE on error.
        FileMove tempExe, requestedPath, 1
        exportedPath := requestedPath
    } catch as e {
        MsgBox "Could not export the EXE:`n" e.Message, "Export failed", "Icon!"
    } finally {
        if work != ""
            try DirDelete work, true
    }
    ; Close the export dialog only AFTER leaving the compile/error handler.
    ; Cleanup problems must never falsely report failure after a valid EXE exists.
    if exportedPath != "" {
        try CloseExportDialog(dlg)
        catch {
            ; Export already succeeded. The owner GUI will clean itself up.
        }
        MsgBox successNotice, "Export complete", "Iconi"
    }
}
