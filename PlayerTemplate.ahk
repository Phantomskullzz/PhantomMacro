#Requires AutoHotkey v2.0
#SingleInstance Force
; PhantomMacro exported EXE player. One file, offline, no writeable settings.
; The exporter inserts recording, fixed theme palette, EXE target and defaults.
; All user edits to loops/speed are IN-MEMORY ONLY.

;__PM_EXPORT_CONFIGURATION__

global Pal := PlayerPalette  ; The exact source theme is snapshotted at export.
global PlayerRunning := false, PlayerStopped := false
global PlayerHeldKeys := Map(), PlayerHeldButtons := Map()
global PlayerGui := "", PlayerPanels := Map(), PlayerNavItems := Map()
global PlayerPage := "Main", PlayerNavHovered := "", PlayerHoverButtons := Map()
global PlayerHoveredHwnd := 0
global PlayerLoopsEdit := "", PlayerSpeedEdit := ""
global PlayerStateText := "", PlayerProgressText := "", PlayerLogBox := ""
global PlayerLogText := "", PlayerSpeedValue := PlayerSpeedDefault

CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
SetMouseDelay -1
SetKeyDelay 0, 15
OnExit PlayerOnExit
OnMessage(0x200, PlayerMouseMove)
OnMessage(0x201, PlayerDragWindow)
BuildPlayer()
; Bind the same Start/Stop shortcuts that were active in the main app
; when this EXE was exported. No persistent settings are required.
try InitPlayerHotkeys()
catch as e {
    PlayerSetState("Hotkey registration failed — use the buttons", e.Message)
    MsgBox "The embedded shortcuts could not be registered:`n" e.Message
        . "`n`nYou can still use the Start and Stop buttons.", "PM Player — " PlayerTitle, "Icon!"
}
if PlayerAutoStart
    SetTimer StartPlayback, -700

InitPlayerHotkeys() {
    global PlayerStartHotkey, PlayerStopHotkey
    if PlayerStartHotkey = "" || PlayerStopHotkey = ""
        throw Error("Start/Stop shortcut missing from this export.")
    if StrLower(PlayerStartHotkey) = StrLower(PlayerStopHotkey)
        throw Error("Start and Stop shortcuts cannot be the same.")
    Hotkey PlayerStartHotkey, StartPlayback, "On"
    try Hotkey PlayerStopHotkey, StopPlayback, "On"
    catch as e {
        try Hotkey PlayerStartHotkey, "Off"
        throw Error("Could not register the Stop shortcut: " e.Message)
    }
}

PlayerHotkeyLabel(key) {
    label := (InStr(key, "^") ? "Ctrl+" : "")
    label .= (InStr(key, "!") ? "Alt+" : "")
    label .= (InStr(key, "+") ? "Shift+" : "")
    return label RegExReplace(key, "[\^!+]")
}

; Sidebar is only 76px wide: compact long key combinations for display.
; This never changes the actual exported Start/Stop hotkeys.
PlayerHotkeyCompact(key) {
    label := PlayerHotkeyLabel(key)
    if StrLen(label) > 9 {
        label := StrReplace(label, "Ctrl+", "C+")
        label := StrReplace(label, "Alt+", "A+")
        label := StrReplace(label, "Shift+", "S+")
    }
    return label
}

BuildPlayer() {
    global Pal, PlayerTitle, PlayerTarget, PlayerThemeName, PlayerStartHotkey, PlayerStopHotkey, PlayerAlwaysOnTop
    global PlayerLoopsDefault, PlayerSpeedDefault, PlayerGui, PlayerPanels
    global PlayerNavItems, PlayerPage, PlayerNavHovered, PlayerHoverButtons
    global PlayerHoveredHwnd, PlayerLoopsEdit, PlayerSpeedEdit
    global PlayerStateText, PlayerProgressText, PlayerLogBox, PlayerLogText

    PlayerPanels := Map("Main", [])
    PlayerNavItems := Map()
    PlayerHoverButtons := Map()
    PlayerNavHovered := "", PlayerHoveredHwnd := 0
    win := Gui((PlayerAlwaysOnTop ? "+AlwaysOnTop " : "") "-MaximizeBox -Caption", "PM Player — " PlayerTitle)
    win.BackColor := Pal["BG"]
    win.MarginX := 0, win.MarginY := 0
    win.SetFont("s10 c" Pal["TEXT"], "Segoe UI")
    PlayerGui := win
    win.Add("Text", "x0 y0 w96 h470 Background" Pal["SIDE"])
    ; The icon has been embedded in the EXE by Ahk2Exe; no sidecar .ico file.
    try win.Add("Picture", "x30 y7 w36 h36 Icon1", A_ScriptFullPath)
    catch {
        win.SetFont("s13 Bold c" Pal["ACCENT_T"], "Segoe UI")
        win.Add("Text", "x0 y21 w96 h25 Center BackgroundTrans", "PM")
    }
    win.SetFont("s8 c" Pal["MUTED"], "Segoe UI")
    win.Add("Text", "x0 y46 w96 h15 Center BackgroundTrans", "Player")

    navDefs := [["Main", "Run", 0xE768]]
    for i, d in navDefs {
        y := 70 + (i - 1) * 76
        tile := win.Add("Picture", "x10 y" y " w76 h64",
            "HBITMAP:" RenderNavTile(d[2], d[3], i = 1, false))
        tile.OnEvent("Click", PlayerShowPanel.Bind(d[1]))
        PlayerNavItems[d[1]] := {ctrl:tile, label:d[2], glyph:d[3], mode:i = 1 ? "active" : "idle"}
    }
    ; The top bar is intentionally empty of shortcuts, so it can be
    ; grabbed anywhere to the left of the minimise/close controls.
    win.Add("Text", "x96 y0 w428 h24 Background" Pal["SIDE"])
    win.SetFont("s8 Bold c" Pal["MUTED"], "Segoe UI")
    win.Add("Text", "x117 y3 w324 h18 BackgroundTrans", "PM Player — " PlayerTitle)
    win.SetFont("s10 c" Pal["TEXT"], "Segoe UI")

    ; Primary actions live in the sidebar, padded below RUN. The embedded
    ; shortcuts are printed on the actions, not in the draggable header.
    PlayerAddButton("Main", "x10 y160 w76 h46", "Start", "ACCENT", "ACCTXT", StartPlayback)
    win.SetFont("s8 Norm c" Pal["MUTED"], "Segoe UI")
    PlayerAddLabel("Main", "x10 y208 w76 h16 Center", PlayerHotkeyCompact(PlayerStartHotkey), "MUTED")
    win.SetFont("s10 Norm c" Pal["TEXT"], "Segoe UI")
    PlayerAddButton("Main", "x10 y233 w76 h46", "Stop", "DANGER", "DANGERTXT", StopPlayback)
    win.SetFont("s8 Norm c" Pal["MUTED"], "Segoe UI")
    PlayerAddLabel("Main", "x10 y281 w76 h16 Center", PlayerHotkeyCompact(PlayerStopHotkey), "MUTED")
    win.SetFont("s10 Norm c" Pal["TEXT"], "Segoe UI")

    ; The RUN workspace has more breathing room with one wide focus action.
    PlayerAddLabel("Main", "x120 y44 w380 h25", "Standalone recording")
    PlayerAddLabel("Main", "x120 y65 w380 h19", PlayerTitle, "TEXT")
    PlayerAddButton("Main", "x120 y95 w380 h38", "Focus target application", "FIELD", "TEXT", PlayerFocusTarget)
    PlayerAddLabel("Main", "x120 y144 w140 h18", "Loops  (0 = forever)")
    PlayerAddLabel("Main", "x265 y144 w220 h18", "Speed (1.0 = normal)")
    PlayerLoopsEdit := PlayerAdd("Main", win.Add("Edit", "x120 y166 w100 h26 Number -Theme -E0x200 Background" Pal["FIELD"] " c" Pal["TEXT"], PlayerLoopsDefault))
    PlayerSpeedEdit := PlayerAdd("Main", win.Add("Edit", "x265 y166 w100 h26 -Theme -E0x200 Background" Pal["FIELD"] " c" Pal["TEXT"], PlayerSpeedDefault))
    ; Keep the no-save warning immediately under the editable settings.
    PlayerAddLabel("Main", "x120 y195 w380 h17", "Playback loops/speed will NOT be saved.")
    PlayerStateText := PlayerAdd("Main", win.Add("Text", "x120 y216 w380 h22 BackgroundTrans c" Pal["ACCENT_T"], "Ready — press " PlayerHotkeyLabel(PlayerStartHotkey)))
    PlayerProgressText := PlayerAdd("Main", win.Add("Text", "x120 y241 w380 h18 BackgroundTrans c" Pal["MUTED"], "Loop 0"))
    win.SetFont("s9 c" Pal["ACCENT_T"], "Consolas")
    PlayerLogBox := PlayerAdd("Main", win.Add("Edit", "x120 y263 w380 h150 ReadOnly Multi +VScroll -Theme -E0x200 Background" Pal["SIDE"] " c" Pal["ACCENT_T"], ""))
    win.SetFont("s8 c" Pal["MUTED"], "Segoe UI")
    ; The temporary-settings warning is displayed above the run status.
    ; Avoid repeating the same warning at the bottom of the player.
    win.SetFont("s10 c" Pal["TEXT"], "Segoe UI")

    ; This standalone player intentionally contains only the RUN page.
    ; The chosen target and export theme remain embedded but read-only.

    ; Controls align with the plain draggable top bar at y2..22.
    win.SetFont("s9 Bold c" Pal["MUTED"], "Segoe UI")
    minBtn := win.Add("Text", "x460 y2 w32 h20 +0x200 Center Background" Pal["SIDE"], "−")
    minBtn.OnEvent("Click", (*) => PlayerGui.Minimize())
    PlayerRegisterHover(minBtn, "SIDE", "MUTED", "NAVON", "ACCENT_T")
    exitBtn := win.Add("Text", "x492 y2 w32 h20 +0x200 Center Background" Pal["SIDE"], "×")
    exitBtn.OnEvent("Click", PlayerExit)
    PlayerRegisterHover(exitBtn, "SIDE", "MUTED", "DANGER", "DANGERTXT")
    win.OnEvent("Close", PlayerExit)
    PlayerShowPanel("Main")
    win.Show("w524 h470")
    ; Avoid the OS-drawn light/grey frame seen against dark themes.
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", win.Hwnd,
        "int", 34, "uint*", 0xFFFFFFFE, "int", 4)
    if VerCompare(A_OSVersion, "10.0.22000") >= 0 {
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", win.Hwnd, "int", 33,
            "int*", 2, "int", 4)
    } else {
        WinGetPos(, , &ww, &wh, "ahk_id " win.Hwnd)
        rg := DllCall("gdi32\CreateRoundRectRgn", "int", 0, "int", 0,
            "int", ww + 1, "int", wh + 1, "int", 24, "int", 24, "ptr")
        if rg && !DllCall("user32\SetWindowRgn", "ptr", win.Hwnd, "ptr", rg,
            "int", true, "int")
            DllCall("gdi32\DeleteObject", "ptr", rg)
    }
    ; Player action buttons deliberately stay rectangular, including on hover.
    A_TrayMenu.Add("Show Player", (*) => PlayerGui.Show())
    A_TrayMenu.Add("Exit Player", PlayerExit)
    PlayerLog("Ready: " PlayerTitle " | " PlayerThemeName " theme")
}

PlayerAdd(page, ctrl) {
    global PlayerPanels
    PlayerPanels[page].Push(ctrl)
    return ctrl
}

PlayerAddLabel(page, opts, label, color := "MUTED") {
    global PlayerGui, Pal
    return PlayerAdd(page, PlayerGui.Add("Text", opts " BackgroundTrans c" Pal[color], label))
}

PlayerAddButton(page, opts, title, bgKey, fgKey, callback) {
    global PlayerGui, Pal
    ; Rectangular surfaces keep their shape when hover colors are repainted.
    b := PlayerAdd(page, PlayerGui.Add("Text", opts " Center +0x200 Background" Pal[bgKey]
        " c" Pal[fgKey], title))
    b.OnEvent("Click", callback)
    PlayerRegisterHover(b, bgKey, fgKey,
        bgKey = "ACCENT" ? "ACCENT_T" : "NAVON",
        bgKey = "ACCENT" ? "ACCTXT" : "ACCENT_T")
    return b
}

PlayerRegisterHover(ctrl, bg, fg, hoverBg, hoverFg) {
    global PlayerHoverButtons
    PlayerHoverButtons[ctrl.Hwnd] := {ctrl:ctrl, bg:bg, fg:fg,
        hoverBg:hoverBg, hoverFg:hoverFg}
}

PlayerMouseMove(wParam, lParam, msg, hwnd) {
    PlayerNavUpdate()
    PlayerButtonHoverUpdate()
}

; Captionless window supports dragging from the dark header bar.
PlayerDragWindow(wParam, lParam, msg, hwnd) {
    global PlayerGui
    if !IsObject(PlayerGui)
        return
    MouseGetPos(&mx, &my, &hoverWindow)
    if hoverWindow != PlayerGui.Hwnd
        return
    WinGetPos(&wx, &wy, , , "ahk_id " PlayerGui.Hwnd)
    if mx >= wx + 96 && mx < wx + 460 && my >= wy && my < wy + 24
        PostMessage 0xA1, 2, , PlayerGui
}

PlayerHoverTick() {
    PlayerNavUpdate()
    PlayerButtonHoverUpdate()
}

PlayerNavUpdate() {
    global PlayerNavItems, PlayerNavHovered
    MouseGetPos(&mx, &my, &window, &hoverControl, 2)
    hovered := ""
    for name, tile in PlayerNavItems {
        if tile.ctrl.Hwnd = hoverControl {
            hovered := name
            break
        }
    }
    if PlayerNavHovered = hovered
        return
    PlayerNavHovered := hovered
    PlayerPaintNav()
    PlayerRefreshHoverTimer()
}

PlayerPaintNav() {
    global PlayerNavItems, PlayerNavHovered, PlayerPage
    for name, tile in PlayerNavItems {
        active := name = PlayerPage
        hovered := name = PlayerNavHovered
        mode := active ? (hovered ? "active-hover" : "active") : (hovered ? "hover" : "idle")
        if mode = tile.mode
            continue
        try tile.ctrl.Value := "HBITMAP:" RenderNavTile(tile.label, tile.glyph,
            active, hovered)
        tile.mode := mode
    }
}

PlayerButtonHoverUpdate() {
    global PlayerHoverButtons, PlayerHoveredHwnd
    ; O(1) native control hit-test, no hot-loop window rectangle scanning.
    MouseGetPos(&mx, &my, &window, &hoverControl, 2)
    found := PlayerHoverButtons.Has(hoverControl) ? hoverControl : 0
    if found = PlayerHoveredHwnd
        return
    if PlayerHoveredHwnd && PlayerHoverButtons.Has(PlayerHoveredHwnd)
        PlayerPaintButton(PlayerHoverButtons[PlayerHoveredHwnd], false)
    PlayerHoveredHwnd := found
    if found && PlayerHoverButtons.Has(found)
        PlayerPaintButton(PlayerHoverButtons[found], true)
    PlayerRefreshHoverTimer()
}

PlayerPaintButton(item, active) {
    global Pal
    try {
        item.ctrl.Opt("Background" Pal[active ? item.hoverBg : item.bg]
            " c" Pal[active ? item.hoverFg : item.fg])
        item.ctrl.Redraw()
    }
}

PlayerRefreshHoverTimer() {
    global PlayerNavHovered, PlayerHoveredHwnd
    SetTimer PlayerHoverTick, PlayerNavHovered != "" || PlayerHoveredHwnd ? 85 : 0
}

PlayerShowPanel(name, *) {
    global PlayerPanels, PlayerPage
    PlayerPage := name
    for page, controls in PlayerPanels {
        for ctl in controls
            ctl.Visible := page = name
    }
    PlayerPaintNav()
    PlayerButtonHoverUpdate()
}

PlayerFocusTarget(*) {
    global PlayerTarget
    try {
        if !WinExist(PlayerTarget)
            throw Error("The target application is not open: " PlayerTarget)
        WinActivate PlayerTarget
        PlayerSetState("Target focused")
    } catch as e
        PlayerSetState("Could not focus target", e.Message)
}

PlayerLog(message) {
    global PlayerLogText, PlayerLogBox
    PlayerLogText .= FormatTime(, "HH:mm:ss") "  " message "`r`n"
    if StrLen(PlayerLogText) > 18000
        PlayerLogText := SubStr(PlayerLogText, -9000)
    if IsObject(PlayerLogBox) {
        PlayerLogBox.Value := PlayerLogText
        SendMessage(0x115, 7, 0, PlayerLogBox)
    }
}

PlayerSetState(status, progress := "") {
    global PlayerStateText, PlayerProgressText
    if IsObject(PlayerStateText)
        PlayerStateText.Text := status
    if progress != "" && IsObject(PlayerProgressText)
        PlayerProgressText.Text := progress
    PlayerLog(status (progress != "" ? " — " progress : ""))
}

ReadPlayerControls() {
    global PlayerLoopsEdit, PlayerSpeedEdit
    loopsText := Trim(PlayerLoopsEdit.Value), speedText := Trim(PlayerSpeedEdit.Value)
    if !RegExMatch(loopsText, "^[0-9]+$")
        throw Error("Loops must be a whole number (0 = unlimited).")
    if !RegExMatch(speedText, "^[0-9]+(?:\.[0-9]+)?$")
        throw Error("Speed must be a positive number, such as 1.0.")
    loops := loopsText + 0, speed := speedText + 0
    if loops > 10000000
        throw Error("Please use a smaller loop count.")
    if speed < 0.1 || speed > 10
        throw Error("Speed must be between 0.1 and 10.0.")
    return {loops:loops, speed:speed}
}

StartPlayback(*) {
    global PlayerRunning, PlayerStopped, PlayerSpeedValue
    global PlayerLoopsEdit, PlayerSpeedEdit, PlayerHeldKeys, PlayerHeldButtons
    global PlayerPreset, PlayerTarget, PlayerStartHotkey
    if PlayerRunning
        return
    try {
        opts := ReadPlayerControls()
        if PlayerTarget = "" || !WinExist(PlayerTarget)
            throw Error("The exported target app isn't open: " PlayerTarget)
        WinActivate PlayerTarget
        if !WinWaitActive(PlayerTarget, , 2)
            throw Error("Couldn't focus the target application.")
        if !PlayerPreset.Length
            throw Error("This EXE contains no recorded steps.")
        PlayerSpeedValue := opts.speed
        PlayerHeldKeys := Map(), PlayerHeldButtons := Map()
        PlayerRunning := true, PlayerStopped := false
        PlayerLoopsEdit.Opt("+Disabled"), PlayerSpeedEdit.Opt("+Disabled")
        number := 0
        while PlayerRunning {
            number++
            PlayerSetState("Running", "Loop " number (opts.loops ? " / " opts.loops : " / unlimited"))
            if !PlayerRunSteps()
                break
            if opts.loops > 0 && number >= opts.loops
                break
        }
        if PlayerStopped
            PlayerSetState("Stopped - press " PlayerHotkeyLabel(PlayerStartHotkey) " to restart", "Stopped during loop " number)
        else if PlayerRunning
            PlayerSetState("Completed - press " PlayerHotkeyLabel(PlayerStartHotkey) " to restart", "Finished " number " loop(s)")
        else
            PlayerSetState("Stopped", "Loop " number)
    } catch as e {
        PlayerSetState("Error - press " PlayerHotkeyLabel(PlayerStartHotkey) " to retry", e.Message)
        MsgBox "Playback error:`n" e.Message, "PM Player — " PlayerTitle, "Icon!"
    } finally {
        PlayerRunning := false
        PlayerReleaseInputs()
        PlayerLoopsEdit.Opt("-Disabled"), PlayerSpeedEdit.Opt("-Disabled")
    }
}

StopPlayback(*) {
    global PlayerRunning, PlayerStopped, PlayerStartHotkey
    PlayerStopped := true, PlayerRunning := false
    PlayerReleaseInputs()
    PlayerSetState("Stopped - press " PlayerHotkeyLabel(PlayerStartHotkey) " to restart")
}

PlayerExit(*) {
    global PlayerRunning
    PlayerRunning := false
    PlayerReleaseInputs()
    ExitApp
}

PlayerOnExit(reason, code) {
    PlayerReleaseInputs()
}

PlayerReleaseInputs() {
    global PlayerHeldKeys, PlayerHeldButtons
    for name in PlayerHeldButtons {
        try SendEvent "{" name " Up}"
    }
    for name in PlayerHeldKeys {
        try SendEvent "{" name " Up}"
    }
    PlayerHeldButtons := Map(), PlayerHeldKeys := Map()
}

PlayerStepNumber(text) {
    text := Trim(text)
    if !RegExMatch(text, "i)^[-+]?(?:0x[0-9a-f]+|(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:e[-+]?[0-9]+)?)$")
        throw Error("Invalid recording number: " text)
    return text + 0
}

PlayerClientPoint(fx, fy) {
    global PlayerTarget
    WinGetClientPos(&x, &y, &w, &h, PlayerTarget)
    if w < 1 || h < 1
        throw Error("Target application has no usable client area.")
    return {x:Round(x + fx * w), y:Round(y + fy * h)}
}

PlayerNap(ms) {
    global PlayerRunning, PlayerSpeedValue
    duration := Max(0, Round(ms / PlayerSpeedValue))
    ends := A_TickCount + duration
    while PlayerRunning && A_TickCount < ends
        Sleep Min(40, ends - A_TickCount)
}

PlayerClick(fx, fy) {
    global PlayerRunning, PlayerTarget
    point := PlayerClientPoint(fx, fy)
    MouseMove point.x, point.y, 0
    PlayerNap(60)
    if !PlayerRunning || !WinActive(PlayerTarget)
        return false
    Click
    PlayerNap(80)
    return PlayerRunning
}

PlayerNearColor(a, b, tolerance) {
    return Abs(((a >> 16) & 255) - ((b >> 16) & 255)) <= tolerance
        && Abs(((a >> 8) & 255) - ((b >> 8) & 255)) <= tolerance
        && Abs((a & 255) - (b & 255)) <= tolerance
}

PlayerRunSteps() {
    global PlayerRunning, PlayerTarget, PlayerPreset
    for line in PlayerPreset {
        if !PlayerRunning
            return false
        if !WinActive(PlayerTarget) {
            PlayerRunning := false
            PlayerSetState("Stopped - target lost focus")
            return false
        }
        p := StrSplit(line, " ")
        if !PlayerExecStep(p)
            return false
    }
    return true
}

PlayerExecStep(p) {
    global PlayerRunning, PlayerStopped, PlayerHeldKeys, PlayerHeldButtons
    global PlayerUpgradeKey, PlayerSellKey, PlayerTarget
    op := StrLower(p[1])
    switch op {
        case "click":
            return PlayerClick(PlayerStepNumber(p[2]), PlayerStepNumber(p[3]))
        case "move":
            point := PlayerClientPoint(PlayerStepNumber(p[2]), PlayerStepNumber(p[3]))
            MouseMove point.x, point.y, 0
        case "mousedown":
            PlayerHeldButtons[p[2]] := true
            SendEvent "{" p[2] " Down}"
        case "mouseup":
            SendEvent "{" p[2] " Up}"
            if PlayerHeldButtons.Has(p[2])
                PlayerHeldButtons.Delete(p[2])
        case "wheel":
            SendEvent "{" p[2] "}"
        case "keydown":
            PlayerHeldKeys[p[2]] := true
            SendEvent "{" p[2] " Down}"
        case "keyup":
            SendEvent "{" p[2] " Up}"
            if PlayerHeldKeys.Has(p[2])
                PlayerHeldKeys.Delete(p[2])
        case "place":
            Send "{" p[2] "}"
            PlayerNap(150)
            if !PlayerRunning
                return false
            return PlayerClick(PlayerStepNumber(p[3]), PlayerStepNumber(p[4]))
        case "upgrade":
            if !PlayerClick(PlayerStepNumber(p[2]), PlayerStepNumber(p[3]))
                return false
            Loop (p.Length >= 4 ? Round(PlayerStepNumber(p[4])) : 1) {
                if !PlayerRunning
                    return false
                Send "{" PlayerUpgradeKey "}"
                PlayerNap(200)
            }
        case "sell":
            if !PlayerClick(PlayerStepNumber(p[2]), PlayerStepNumber(p[3]))
                return false
            Send "{" PlayerSellKey "}"
            PlayerNap(200)
        case "key":
            Send "{" p[2] "}"
            PlayerNap(100)
        case "wait":
            PlayerNap(PlayerStepNumber(p[2]))
        case "waitpixel":
            wanted := PlayerStepNumber(p[4])
            timeout := p.Length >= 5 ? PlayerStepNumber(p[5]) : 60000
            tolerance := p.Length >= 6 ? PlayerStepNumber(p[6]) : 20
            deadline := A_TickCount + timeout
            while PlayerRunning {
                if !WinActive(PlayerTarget) {
                    PlayerRunning := false
                    return false
                }
                point := PlayerClientPoint(PlayerStepNumber(p[2]), PlayerStepNumber(p[3]))
                if PlayerNearColor(PixelGetColor(point.x, point.y), wanted, tolerance)
                    return true
                if A_TickCount >= deadline {
                    PlayerRunning := false
                    PlayerStopped := true
                    PlayerSetState("Stopped - pixel check timed out")
                    return false
                }
                Sleep 75
            }
            return false
        default:
            throw Error("Unsupported recorded command: " op)
    }
    return PlayerRunning
}

HeaderWinColor(rgb) {
    return ("0x" SubStr(rgb, 5, 2) SubStr(rgb, 3, 2) SubStr(rgb, 1, 2)) + 0
}

RenderNavTile(label, glyph, active, hovered) {
    global Pal
    w := 76, h := 64
    screen := DllCall("user32\GetDC", "ptr", 0, "ptr")
    if !screen
        throw Error("Cannot create sidebar bitmap")
    mem := 0, bmp := 0, oldBmp := 0, brush := 0
    font := 0, oldFont := 0, rgn := 0
    success := false
    try {
        mem := DllCall("gdi32\CreateCompatibleDC", "ptr", screen, "ptr")
        bmp := DllCall("gdi32\CreateCompatibleBitmap", "ptr", screen, "int", w, "int", h, "ptr")
        if !mem || !bmp
            throw Error("Cannot allocate sidebar tile")
        oldBmp := DllCall("gdi32\SelectObject", "ptr", mem, "ptr", bmp, "ptr")
        brush := DllCall("gdi32\CreateSolidBrush", "uint", HeaderWinColor(Pal["SIDE"]), "ptr")
        bounds := Buffer(16, 0)
        NumPut("int", 0, "int", 0, "int", w, "int", h, bounds)
        DllCall("user32\FillRect", "ptr", mem, "ptr", bounds, "ptr", brush)
        DllCall("gdi32\DeleteObject", "ptr", brush)
        brush := 0
        if active || hovered {
            brush := DllCall("gdi32\CreateSolidBrush", "uint", HeaderWinColor(Pal[active ? "NAVON" : "FIELD"]), "ptr")
            rgn := DllCall("gdi32\CreateRoundRectRgn", "int", 1, "int", 1,
                "int", 75, "int", 63, "int", 14, "int", 14, "ptr")
            DllCall("gdi32\FillRgn", "ptr", mem, "ptr", rgn, "ptr", brush)
            DllCall("gdi32\DeleteObject", "ptr", rgn)
            rgn := 0
            DllCall("gdi32\DeleteObject", "ptr", brush)
            brush := 0
            if hovered {
                brush := DllCall("gdi32\CreateSolidBrush", "uint", HeaderWinColor(Pal["ACCENT_T"]), "ptr")
                NumPut("int", 4, "int", 17, "int", 7, "int", 47, bounds)
                DllCall("user32\FillRect", "ptr", mem, "ptr", bounds, "ptr", brush)
                DllCall("gdi32\DeleteObject", "ptr", brush)
                brush := 0
            }
        }
        DllCall("gdi32\SetBkMode", "ptr", mem, "int", 1)
        DllCall("gdi32\SetTextColor", "ptr", mem, "uint",
            HeaderWinColor(Pal[active || hovered ? "ACCENT_T" : "MUTED"]))
        font := DllCall("gdi32\CreateFontW", "int", -24, "int", 0, "int", 0, "int", 0,
            "int", 400, "uint", 0, "uint", 0, "uint", 0, "uint", 1,
            "uint", 0, "uint", 0, "uint", 0, "uint", 0, "str", "Segoe MDL2 Assets", "ptr")
        if !font
            throw Error("Cannot draw sidebar icon")
        oldFont := DllCall("gdi32\SelectObject", "ptr", mem, "ptr", font, "ptr")
        NumPut("int", 4, "int", 7, "int", 72, "int", 37, bounds)
        DllCall("user32\DrawTextW", "ptr", mem, "wstr", Chr(glyph), "int", -1,
            "ptr", bounds, "uint", 0x25)
        DllCall("gdi32\SelectObject", "ptr", mem, "ptr", oldFont)
        oldFont := 0
        DllCall("gdi32\DeleteObject", "ptr", font)
        font := 0
        font := DllCall("gdi32\CreateFontW", "int", -11, "int", 0, "int", 0, "int", 0,
            "int", 700, "uint", 0, "uint", 0, "uint", 0, "uint", 1,
            "uint", 0, "uint", 0, "uint", 0, "uint", 0, "str", "Segoe UI", "ptr")
        oldFont := DllCall("gdi32\SelectObject", "ptr", mem, "ptr", font, "ptr")
        NumPut("int", 4, "int", 41, "int", 72, "int", 59, bounds)
        DllCall("user32\DrawTextW", "ptr", mem, "wstr", label, "int", -1,
            "ptr", bounds, "uint", 0x25)
        success := true
        return bmp
    } finally {
        if oldFont
            DllCall("gdi32\SelectObject", "ptr", mem, "ptr", oldFont)
        if font
            DllCall("gdi32\DeleteObject", "ptr", font)
        if brush
            DllCall("gdi32\DeleteObject", "ptr", brush)
        if rgn
            DllCall("gdi32\DeleteObject", "ptr", rgn)
        if oldBmp
            DllCall("gdi32\SelectObject", "ptr", mem, "ptr", oldBmp)
        if mem
            DllCall("gdi32\DeleteDC", "ptr", mem)
        DllCall("user32\ReleaseDC", "ptr", 0, "ptr", screen)
        if !success && bmp
            DllCall("gdi32\DeleteObject", "ptr", bmp)
    }
}
