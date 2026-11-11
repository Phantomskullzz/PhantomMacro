; GUI.ahk — visual interface, colour themes, panels and settings.
; Loaded by PhantomMacro.ahk. Do not run this file by itself.

; This file is included by PhantomMacro.ahk, not started separately.
; If someone opens this file directly, hand off to the launcher.
if (A_ScriptName = "GUI.ahk") {
    launcher := A_ScriptDir "\PhantomMacro.ahk"
    if FileExist(launcher)
        Run '"' A_AhkPath '" "' launcher '"'
    else
        MsgBox "PhantomMacro.ahk is missing. Keep all three .ahk files together.", "PhantomMacro"
    ExitApp
}


; A settings path derived from the launched folder rather than an uninitialised
; shared variable. This also lets a fresh install start without settings.ini.
SettingsFile() {
    return A_ScriptDir "\settings.ini"
}

ReadSetting(key, fallback := "") {
    try {
        return IniRead(SettingsFile(), "main", key, fallback)
    } catch {
        ; A missing / unreadable INI should not prevent the GUI from opening.
        ; Saving a setting reports errors through the existing catch handler.
        return fallback
    }
}

WriteSetting(key, value) {
    IniWrite value, SettingsFile(), "main", key
}


InitGuiState() {
    global Themes, ThemeOrder, CurTheme, Pal, CurPage, LogText
    ; Colours and themes used by the visual interface.
    ; Add your own by copying one of these blocks and changing the colours (hex RRGGBB).
    ;   BG/SIDE/NAVON/FIELD = surfaces     TEXT/MUTED = text
    ;   ACCENT = buttons/fills             ACCENT_T = accent used as text
    ;   ACCTXT = text on accent buttons    DANGER/DANGERTXT = stop button
    ;   DARK = "1" for dark themes, "0" for light ones (switches scrollbar style)
    Themes := Map()
    ThemeOrder := ["Crimson", "Ammo Lead", "Cherry Blossom", "Phantom"]

    ; Lead-grey surfaces with brass ammunition-inspired highlights.
    Themes["Ammo Lead"] := Map(
        "BG", "1B1F22", "SIDE", "111416", "NAVON", "30363A", "FIELD", "292F33",
        "TEXT", "E7E4DA", "MUTED", "A4A297",
        "ACCENT", "C6A05A", "ACCENT_T", "E0BD78", "ACCTXT", "191B1D",
        "DANGER", "754542", "DANGERTXT", "FFF4EE", "DARK", "1")

    Themes["Crimson"] := Map(
        "BG", "1A1013", "SIDE", "120A0C", "NAVON", "33171D", "FIELD", "2A1A1F",
        "TEXT", "F2DDE0", "MUTED", "9A7F85",
        "ACCENT", "DC143C", "ACCENT_T", "FF5C77", "ACCTXT", "FFFFFF",
        "DANGER", "5C2B34", "DANGERTXT", "FFFFFF", "DARK", "1")

    Themes["Cherry Blossom"] := Map(
        "BG", "2B1822", "SIDE", "201119", "NAVON", "5C2F45", "FIELD", "3A2230",
        "TEXT", "F8E8EE", "MUTED", "B38CA0",
        "ACCENT", "F4A6C0", "ACCENT_T", "F9B8D0", "ACCTXT", "3A1626",
        "DANGER", "6E3C52", "DANGERTXT", "F8E8EE", "DARK", "1")

    Themes["Phantom"] := Map(
        "BG", "0D0A14", "SIDE", "07050B", "NAVON", "1C1530", "FIELD", "17122A",
        "TEXT", "E8E2F7", "MUTED", "857D9E",
        "ACCENT", "8B5CF6", "ACCENT_T", "B79CFF", "ACCTXT", "FFFFFF",
        "DANGER", "3A2C5E", "DANGERTXT", "E8E2F7", "DARK", "1")

    ; Select Crimson on first launch, without saving a default setting.
    ; Restore a saved valid choice if the user changed themes previously.
    CurTheme := "Crimson"
    if FileExist(SettingsFile()) {
        savedTheme := ReadSetting("theme", "")
        if Themes.Has(savedTheme)
            CurTheme := savedTheme
    }
    Pal := Themes[CurTheme]
    CurPage := "Main"
    LogText := ""
}

; ============================================================
;  GUI construction (rebuilt whenever the theme changes)
; ============================================================
BuildGui(px := "", py := "") {
    global g, panels, navItems, ddl, edLoops, edSpeed, edUp, edSell, edWin
    global chkTop, statusTxt, recBtn, logBox
    global hkStart, hkStop, hkRecord, keybindStatus, ActionHotkeys
    global headerKeybindPic
    global updateStatusLabel, AppVersion
    global Pal, CurPage, ThemeOrder, Themes, CurTheme, WinTitle, PresetDir, LogText

    panels := Map("Main", [], "Settings", [], "Themes", [])
    navItems := Map()

    g := Gui("-MaximizeBox -Caption", "TD Macro")
    g.BackColor := Pal["BG"]
    g.MarginX := 0
    g.MarginY := 0
    g.SetFont("s10 c" Pal["TEXT"], "Segoe UI")

    ; ----- Sidebar (icon above label, glowing tile on the active page) -----
    g.Add("Text", "x0 y0 w96 h470 Background" Pal["SIDE"])
    g.SetFont("s13 Bold c" Pal["ACCENT_T"], "Segoe UI")
    g.Add("Text", "x0 y21 w96 h25 Center BackgroundTrans", "TD")
    ; The installed version stays visible in every GUI tab.
    g.SetFont("s8 Norm c" Pal["MUTED"], "Segoe UI")
    g.Add("Text", "x0 y46 w96 h15 Center BackgroundTrans", "v" AppVersion)
    navDefs := [["Main", "RUN", 0xE768], ["Settings", "SETTINGS", 0xE713], ["Themes", "THEMES", 0xE790]]
    for i, d in navDefs {
        ny := 70 + (i - 1) * 76
        bgOn := g.Add("Text", "x10 y" ny " w76 h64 Background" Pal["NAVON"])
        RoundCtrl(bgOn, 30)
        g.SetFont("s16 Norm c" Pal["MUTED"], "Segoe MDL2 Assets")
        icOff := g.Add("Text", "x10 y" (ny + 8) " w76 h28 Center BackgroundTrans", Chr(d[3]))
        g.SetFont("s7 Bold c" Pal["MUTED"], "Segoe UI")
        lbOff := g.Add("Text", "x10 y" (ny + 40) " w76 h16 Center BackgroundTrans", d[2])
        g.SetFont("s16 Norm c" Pal["ACCENT_T"], "Segoe MDL2 Assets")
        icOn := g.Add("Text", "x10 y" (ny + 8) " w76 h28 Center BackgroundTrans", Chr(d[3]))
        g.SetFont("s7 Bold c" Pal["ACCENT_T"], "Segoe UI")
        lbOn := g.Add("Text", "x10 y" (ny + 40) " w76 h16 Center BackgroundTrans", d[2])
        for ctl in [bgOn, icOff, lbOff, icOn, lbOn]
            ctl.OnEvent("Click", ShowPanel.Bind(d[1]))
        navItems[d[1]] := [bgOn, icOff, lbOff, icOn, lbOn]
    }
    g.SetFont("s10 Norm c" Pal["TEXT"], "Segoe UI")

    ; Header uses a single bitmap with curved pill backgrounds and labels.
    g.SetFont("s8 Bold c" Pal["ACCENT_T"], "Segoe UI")
    try {
        headerBitmap := RenderHotkeyHeader()
        headerKeybindPic := g.Add("Picture", "x96 y0 w365 h24", "HBITMAP:" headerBitmap)
    } catch {
        headerKeybindPic := g.Add("Text", "x96 y0 w365 h24 Center +0x200 Background" Pal["SIDE"], "")
        RefreshHeaderHotkeys()
    }
    g.SetFont("s10 Norm c" Pal["TEXT"], "Segoe UI")

    ; ----- Main: preset, controls, status, log -----
    ddl := Reg("Main", g.Add("DropDownList", "x120 y24 w300 -Theme Background" Pal["FIELD"] " c" Pal["TEXT"]))
    Btn("Main", "x430 y24 w70 h24", "Reload", Pal["FIELD"], Pal["TEXT"], LoadList)
    g.SetFont("s10 Bold")
    Btn("Main", "x120 y76 w120 h40", "START", Pal["ACCENT"], Pal["ACCTXT"], StartMacro)
    Btn("Main", "x250 y76 w120 h40", "STOP", Pal["DANGER"], Pal["DANGERTXT"], StopMacro)
    recBtn := Btn("Main", "x380 y76 w120 h40", "RECORD", Pal["FIELD"], Pal["TEXT"], ToggleRecord)
    g.SetFont("s10 Norm c" Pal["TEXT"])
    Label("Main", "x120 y132", "LOOPS  (0 = forever)")
    edLoops := AddInputField("Main", "x120 y154 w100 h26 Number", ReadSetting("loops", "0"))
    Label("Main", "x265 y132", "SPEED (1.0 = normal)")
    edSpeed := AddInputField("Main", "x265 y154 w100 h26", ReadSetting("speed", "1.0"))
    Label("Main", "x265 y183", "2.0 = faster, 0.5 = slower")
    statusTxt := Reg("Main", g.Add("Text", "x120 y200 w380 h22 BackgroundTrans c" Pal["ACCENT_T"], "Idle"))
    g.SetFont("s9 c" Pal["ACCENT_T"], "Consolas")
    logBox := Reg("Main", g.Add("Edit", "x120 y232 w380 h218 ReadOnly Multi +VScroll -Theme -E0x200 Background" Pal["SIDE"] " c" Pal["ACCENT_T"], LogText))
    SendMessage(0xD3, 3, 10 | (10 << 16), logBox)   ; inner padding left/right
    SendMessage(0x115, 7, 0, logBox)                 ; scroll to bottom
    g.SetFont("s10 Norm c" Pal["TEXT"], "Segoe UI")

    ; ----- Settings (keys, window, tools) -----
    Label("Settings", "x120 y44", "UPGRADE KEY")
    edUp := AddInputField("Settings", "x120 y66 w70 h26 Limit1", ReadSetting("upkey", "t"))
    Label("Settings", "x220 y44", "SELL KEY")
    edSell := AddInputField("Settings", "x220 y66 w70 h26 Limit1", ReadSetting("sellkey", "x"))
    Label("Settings", "x120 y110", "ROBLOX WINDOW TARGET")
    edWin := AddInputField("Settings", "x120 y132 w380 h26", WinTitle)
    onTop := ReadSetting("ontop", "0") = "1"
    chkTop := Reg("Settings", g.Add("CheckBox", "x120 y178 -Theme c" Pal["TEXT"] (onTop ? " Checked" : ""), "Keep this window on top"))
    chkTop.OnEvent("Click", (*) => g.Opt(chkTop.Value ? "+AlwaysOnTop" : "-AlwaysOnTop"))
    if onTop
        g.Opt("+AlwaysOnTop")
    ; Hotkey controls display key names and support Ctrl / Alt / Shift combinations.
    Label("Settings", "x120 y213", "MACRO KEYBINDS  (click a box, then press a key)")
    Label("Settings", "x120 y241", "START")
    Label("Settings", "x250 y241", "STOP")
    Label("Settings", "x380 y241", "RECORD")
    hkStart := Reg("Settings", g.Add("Hotkey", "x120 y263 w120 h28 -Theme", ActionHotkeys["start"]))
    hkStop := Reg("Settings", g.Add("Hotkey", "x250 y263 w120 h28 -Theme", ActionHotkeys["stop"]))
    hkRecord := Reg("Settings", g.Add("Hotkey", "x380 y263 w120 h28 -Theme", ActionHotkeys["record"]))
    ; Save a complete, valid combination as soon as it is entered.
    ; OnEvent automatically handles Ctrl/Alt/Shift + key combinations.
    for bindAction, hotkeyControl in Map("start", hkStart, "stop", hkStop, "record", hkRecord)
        hotkeyControl.OnEvent("Change", HotkeyFieldChanged.Bind(bindAction))
    ; A real Button receives keyboard focus. The old text-only Save surface left
    ; focus in the Hotkey editor, effectively disabling the in-app shortcuts.
    bSave := Reg("Settings", g.Add("Button", "x120 y309 w134 h32 -Theme", "Save settings"))
    bSave.OnEvent("Click", SaveSettings)
    bReset := Reg("Settings", g.Add("Button", "x264 y309 w144 h32 -Theme", "Reset keybinds"))
    bReset.OnEvent("Click", ResetKeybindFields)
    keybindStatus := Reg("Settings", g.Add("Text", "x120 y348 w380 h22 BackgroundTrans c" Pal["ACCENT_T"], "Hotkeys active. Changes save automatically."))
    Label("Settings", "x120 y371", "TOOLS")
    Btn("Settings", "x120 y393 w120 h30", "Open folder", Pal["FIELD"], Pal["TEXT"], (*) => Run(PresetDir))
    Btn("Settings", "x250 y393 w120 h30", "Edit preset", Pal["FIELD"], Pal["TEXT"], EditPreset)
    Btn("Settings", "x380 y393 w120 h30", "Pick pixel", Pal["FIELD"], Pal["TEXT"], PickPixel)
    updateStatusLabel := Reg("Settings", g.Add("Text", "x120 y436 w255 h22 BackgroundTrans c" Pal["MUTED"], "Version v" AppVersion " - private releases"))
    Btn("Settings", "x380 y430 w120 h30", "Check updates", Pal["FIELD"], Pal["TEXT"], (*) => CheckForUpdates(false))

    ; ----- Themes -----
    for i, tname in ThemeOrder {
        th := Themes[tname]
        cy := 24 + (i - 1) * 46
        Btn("Themes", "x120 y" cy " w380 h38", "", Pal["FIELD"], Pal["TEXT"], ApplyTheme.Bind(tname))
        Reg("Themes", g.Add("Text", "x138 y" (cy + 9) " w150 BackgroundTrans c" (tname = CurTheme ? Pal["ACCENT_T"] : Pal["TEXT"]), tname))
        if tname = CurTheme
            Reg("Themes", g.Add("Text", "x305 y" (cy + 10) " w120 BackgroundTrans c" Pal["MUTED"], "active"))
        for j, key in ["ACCENT", "BG"] {
            sw := Reg("Themes", g.Add("Text", "x" (445 + (j - 1) * 28) " y" (cy + 9) " w20 h20 Background" th[key]))
            RoundCtrl(sw, 8)
        }
    }

    ; ----- Custom window buttons (the title bar is removed) -----
    g.SetFont("s10 Bold c" Pal["MUTED"])
    btnMin := g.Add("Text", "x461 y0 w32 h26 +0x200 Center Background" Pal["BG"], "-")
    btnMin.OnEvent("Click", (*) => g.Minimize())
    btnClose := g.Add("Text", "x493 y0 w32 h26 +0x200 Center Background" Pal["BG"], "X")
    btnClose.OnEvent("Click", (*) => (PersistSettings(), ExitApp()))
    g.SetFont("s10 Norm c" Pal["TEXT"], "Segoe UI")

    g.OnEvent("Close", (*) => (PersistSettings(), ExitApp()))

    ; Set everything up while the window is still hidden, so nothing flashes on screen
    ShowPanel(CurPage)
    LoadList()
    DarkTheme(logBox)
    DarkTheme(ddl, "combo")
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "int", 34, "uint*", 0xFFFFFFFE, "int", 4)  ; border colour: none
    win11 := VerCompare(A_OSVersion, "10.0.22000") >= 0
    if win11
        DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "int", 33, "int*", 2, "int", 4)       ; round corners

    g.Show("w524 h470" (px != "" ? " x" px " y" py : ""))
    ; Header pill shapes are already painted into the bitmap.
    for _, navControls in navItems
        RoundCtrl(navControls[1], 30)
    logBox.Focus()   ; keeps the dropdown from showing a bright selection

    if !win11 {
        WinGetPos(, , &ww, &wh, "ahk_id " g.Hwnd)
        rgn := DllCall("gdi32\CreateRoundRectRgn", "int", 0, "int", 0, "int", ww + 1, "int", wh + 1, "int", 24, "int", 24, "ptr")
        DllCall("user32\SetWindowRgn", "ptr", g.Hwnd, "ptr", rgn, "int", true)
    }
    if px = ""
        Log("Ready. Window target: " WinTitle)
}

; ---------------- GUI helpers ----------------
; Keep the always-on-top-of-panels shortcut labels in sync with the actual
; active bindings. Called when the GUI opens, when a hotkey changes, and
; after the GUI is rebuilt for a different colour theme.
RefreshHeaderHotkeys() {
    global headerKeybindPic, ActionHotkeys
    if !IsObject(headerKeybindPic)
        return
    if headerKeybindPic.Type = "Pic" {
        try headerKeybindPic.Value := "HBITMAP:" RenderHotkeyHeader()
    } else {
        headerKeybindPic.Text := HeaderShortcut(ActionHotkeys["start"]) "  START   "
            . HeaderShortcut(ActionHotkeys["stop"]) "  STOP   "
            . HeaderShortcut(ActionHotkeys["record"]) "  RECORD"
    }
}

HeaderWinColor(rgb) {
    return Integer("0x" SubStr(rgb, 5, 2) SubStr(rgb, 3, 2) SubStr(rgb, 1, 2))
}

RenderHotkeyHeader() {
    global ActionHotkeys, Pal
    width := 365, height := 24
    screen := DllCall("user32\GetDC", "ptr", 0, "ptr")
    if !screen
        throw Error("Unable to get a screen device context")
    mem := 0, bmp := 0, oldBmp := 0
    bg := 0, fg := 0, font := 0, oldFont := 0
    complete := false
    try {
        mem := DllCall("gdi32\CreateCompatibleDC", "ptr", screen, "ptr")
        bmp := DllCall("gdi32\CreateCompatibleBitmap", "ptr", screen, "int", width, "int", height, "ptr")
        if !mem || !bmp
            throw Error("Failed to allocate header bitmap")
        oldBmp := DllCall("gdi32\SelectObject", "ptr", mem, "ptr", bmp, "ptr")
        bg := DllCall("gdi32\CreateSolidBrush", "uint", HeaderWinColor(Pal["SIDE"]), "ptr")
        fg := DllCall("gdi32\CreateSolidBrush", "uint", HeaderWinColor(Pal["NAVON"]), "ptr")
        font := DllCall("gdi32\CreateFontW", "int", -13, "int", 0, "int", 0, "int", 0,
            "int", 700, "uint", 0, "uint", 0, "uint", 0, "uint", 1,
            "uint", 0, "uint", 0, "uint", 0, "str", "Segoe UI", "ptr")
        if !bg || !fg || !font
            throw Error("Failed to create header brushes/font")
        oldFont := DllCall("gdi32\SelectObject", "ptr", mem, "ptr", font, "ptr")
        DllCall("gdi32\SetBkMode", "ptr", mem, "int", 1)
        DllCall("gdi32\SetTextColor", "ptr", mem, "uint", HeaderWinColor(Pal["ACCENT_T"]))
        whole := Buffer(16, 0)
        NumPut("int", 0, "int", 0, "int", width, "int", height, whole)
        DllCall("user32\FillRect", "ptr", mem, "ptr", whole, "ptr", bg)
        labels := [HeaderShortcut(ActionHotkeys["start"]) "  START",
            HeaderShortcut(ActionHotkeys["stop"]) "  STOP",
            HeaderShortcut(ActionHotkeys["record"]) "  RECORD"]
        for i, label in labels {
            x := 24 + (i - 1) * 111
            rgn := DllCall("gdi32\CreateRoundRectRgn", "int", x, "int", 1,
                "int", x + 100, "int", 23, "int", 22, "int", 22, "ptr")
            if !rgn
                throw Error("Failed to create pill region")
            try DllCall("gdi32\FillRgn", "ptr", mem, "ptr", rgn, "ptr", fg)
            finally DllCall("gdi32\DeleteObject", "ptr", rgn)
            textRect := Buffer(16, 0)
            NumPut("int", x + 3, "int", 1, "int", x + 97, "int", 23, textRect)
            DllCall("user32\DrawTextW", "ptr", mem, "wstr", label, "int", -1,
                "ptr", textRect, "uint", 0x25, "int")
        }
        complete := true
        return bmp
    } finally {
        if oldFont
            DllCall("gdi32\SelectObject", "ptr", mem, "ptr", oldFont)
        if font
            DllCall("gdi32\DeleteObject", "ptr", font)
        if fg
            DllCall("gdi32\DeleteObject", "ptr", fg)
        if bg
            DllCall("gdi32\DeleteObject", "ptr", bg)
        if oldBmp
            DllCall("gdi32\SelectObject", "ptr", mem, "ptr", oldBmp)
        if mem
            DllCall("gdi32\DeleteDC", "ptr", mem)
        DllCall("user32\ReleaseDC", "ptr", 0, "ptr", screen)
        if !complete && bmp
            DllCall("gdi32\DeleteObject", "ptr", bmp)
    }
}

; Abbreviate long combinations in the compact bar. The Settings fields
; retain and show the full shortcut, and are not changed by this display.
HeaderShortcut(key) {
    pretty := ShowHotkey(key)
    if StrLen(pretty) > 9 {
        pretty := StrReplace(pretty, "Ctrl+", "C+")
        pretty := StrReplace(pretty, "Alt+", "A+")
        pretty := StrReplace(pretty, "Shift+", "S+")
    }
    return pretty
}

Reg(p, ctrl) {
    global panels
    panels[p].Push(ctrl)
    return ctrl
}

Label(p, opts, text) {
    global g, Pal
    return Reg(p, g.Add("Text", opts " BackgroundTrans c" Pal["MUTED"], text))
}

Btn(p, opts, text, bg, fg, fn) {
    global g
    b := g.Add("Text", opts " +0x200 Center Background" bg " c" fg, text)
    b.OnEvent("Click", fn)
    RoundCtrl(b, 20)
    return Reg(p, b)
}

AddInputField(p, opts, text := "") {
    global g, Pal
    return Reg(p, g.Add("Edit", opts " -Theme -E0x200 +Border Background" Pal["FIELD"] " c" Pal["TEXT"], text))
}

; Apply true rounded regions using a shown control's client dimensions.
; r = 0 means a full pill; other values are DPI-scaled logical pixels.
RoundCtrl(ctrl, r := 12) {
    rect := Buffer(16, 0)
    if !DllCall("user32\GetClientRect", "ptr", ctrl.Hwnd, "ptr", rect, "int")
        return false
    w := NumGet(rect, 8, "int")
    h := NumGet(rect, 12, "int")
    if w < 2 || h < 2
        return false
    diameter := r = 0 ? h : Min(h, Max(2, Round(r * A_ScreenDPI / 96)))
    region := DllCall("gdi32\CreateRoundRectRgn", "int", 0, "int", 0, "int", w, "int", h, "int", diameter, "int", diameter, "ptr")
    if !region
        return false
    if !DllCall("user32\SetWindowRgn", "ptr", ctrl.Hwnd, "ptr", region, "int", true, "int") {
        DllCall("gdi32\DeleteObject", "ptr", region)
        return false
    }
    return true
}

; Scrollbar / dropdown styling that matches the theme (dark or light)
DarkTheme(ctrl, kind := "scroll") {
    global Pal
    dark := Pal["DARK"] = "1"
    if kind = "combo"
        name := dark ? "DarkMode_CFD" : "CFD"
    else
        name := dark ? "DarkMode_Explorer" : "Explorer"
    DllCall("uxtheme\SetWindowTheme", "ptr", ctrl.Hwnd, "str", name, "ptr", 0)
}

DragWindow(wParam, lParam, msg, hwnd) {
    global g
    if IsObject(g) && hwnd = g.Hwnd
        PostMessage 0xA1, 2, , g   ; WM_NCLBUTTONDOWN, HTCAPTION
}

ShowPanel(name, *) {
    global CurPage, panels, navItems, g, logBox, hkStart, hkStop, hkRecord
    ; Text-based sidebar items do not take keyboard focus. Move focus away
    ; from the hotkey input if that panel is being hidden.
    if name != "Settings" && IsObject(g) {
        try {
            focused := g.FocusedCtrl
            if IsObject(focused) && (focused.Hwnd = hkStart.Hwnd || focused.Hwnd = hkStop.Hwnd || focused.Hwnd = hkRecord.Hwnd)
                logBox.Focus()
        }
    }
    CurPage := name
    for pname, list in panels {
        for ctrl in list
            ctrl.Visible := (pname = name)
    }
    for nname, it in navItems {
        on := (nname = name)
        it[1].Visible := on     ; glowing tile
        it[2].Visible := !on    ; muted icon + label
        it[3].Visible := !on
        it[4].Visible := on     ; accent icon + label
        it[5].Visible := on
    }
    ; Hidden rounded buttons can leave stray corner pixels behind - repaint everything
    DllCall("user32\RedrawWindow", "ptr", g.Hwnd, "ptr", 0, "ptr", 0, "uint", 0x85)
}

ApplyTheme(name, *) {
    global CurTheme, Running, Recording
    if name = CurTheme
        return
    if Running || Recording {
        Log("Stop the macro / recording before switching themes")
        return
    }
    SetTimer(() => RebuildWithTheme(name), -10)   ; defer so we don't destroy the GUI inside its own click handler
}

RebuildWithTheme(name) {
    global Pal, CurTheme, g, Themes
    PersistSettings()
    WinGetPos(&px, &py, , , "ahk_id " g.Hwnd)
    old := g
    CurTheme := name
    Pal := Themes[name]
    WriteSetting("theme", name)
    BuildGui(px, py)    ; new window appears exactly on top of the old one...
    old.Destroy()       ; ...then the old one disappears, so there is no blank flash
    Log("Theme: " name)
}

Log(msg) {
    global LogText, logBox
    LogText .= FormatTime(, "HH:mm:ss") "  " msg "`r`n"
    if StrLen(LogText) > 30000
        LogText := SubStr(LogText, -15000)
    logBox.Value := LogText
    SendMessage(0x115, 7, 0, logBox)   ; scroll to bottom
}

SetStatus(msg) {
    global statusTxt
    statusTxt.Text := msg
    Log(msg)
}

LoadList(*) {
    global ddl, PresetDir
    ddl.Delete()
    names := []
    Loop Files PresetDir "\*.txt"
        names.Push(RegExReplace(A_LoopFileName, "\.txt$"))
    if names.Length {
        ddl.Add(names)
        try
            ddl.Choose(ReadSetting("preset", ""))
        if ddl.Value = 0
            ddl.Choose(1)
    }
}

PersistSettings() {
    global WinTitle, edWin, edLoops, edSpeed, edUp, edSell, ddl, chkTop, ActionHotkeys
    WinTitle := edWin.Value
    WriteSetting("loops", edLoops.Value)
    WriteSetting("speed", edSpeed.Value)
    WriteSetting("upkey", edUp.Value)
    WriteSetting("sellkey", edSell.Value)
    WriteSetting("window", WinTitle)
    WriteSetting("preset", ddl.Text)
    WriteSetting("ontop", chkTop.Value)
    ; Persist only the active bindings, never unfinished input edits.
    WriteSetting("hk_start", ActionHotkeys["start"])
    WriteSetting("hk_stop", ActionHotkeys["stop"])
    WriteSetting("hk_record", ActionHotkeys["record"])
}

; Updates the visible feedback next to the editable bindings.
SetKeybindStatus(message) {
    global keybindStatus
    if IsObject(keybindStatus)
        keybindStatus.Text := message
}

; Assemble all 3 fields so that changes are committed together.
GetActionHotkeyFields() {
    global hkStart, hkStop, hkRecord
    return Map("start", hkStart.Value, "stop", hkStop.Value, "record", hkRecord.Value)
}

HotkeyFieldChanged(action, *) {
    global UpdatingHotkeyFields
    if UpdatingHotkeyFields
        return
    candidate := GetActionHotkeyFields()
    problem := ValidateActionHotkeys(candidate)
    if problem != "" {
        SetKeybindStatus("Not saved: " problem)
        return
    }
    ; Applying immediately also prevents accidental loss on closing the GUI.
    ApplyAndSaveActionHotkeys(candidate)
}

; Applies the hotkeys, persists them, and rolls back if writing fails.
ApplyAndSaveActionHotkeys(candidate) {
    global ActionHotkeys
    problem := ValidateActionHotkeys(candidate)
    if problem != "" {
        SetKeybindStatus("Not saved: " problem)
        return false
    }
    previous := ActionHotkeys.Clone()
    problem := InstallActionHotkeys(candidate)
    if problem != "" {
        SetKeybindStatus("Hotkey error: " problem)
        MsgBox "Unable to register shortcut: " problem, "PhantomMacro", "Icon!"
        return false
    }
    try {
        WriteSetting("hk_start", candidate["start"])
        WriteSetting("hk_stop", candidate["stop"])
        WriteSetting("hk_record", candidate["record"])
        ; Read back to catch an inaccessible or protected INI location.
        if ReadSetting("hk_start", "") != candidate["start"]
            || ReadSetting("hk_stop", "") != candidate["stop"]
            || ReadSetting("hk_record", "") != candidate["record"]
            throw Error("Could not verify settings.ini after saving")
    } catch as e {
        InstallActionHotkeys(previous)
        SetKeybindStatus("Save failed. See error message.")
        MsgBox "Hotkeys were not saved to:`n" SettingsFile() "`n`n" e.Message, "PhantomMacro", "Icon!"
        return false
    }
    SetKeybindStatus("Saved! Start: " ShowHotkey(candidate["start"]) " | Stop: " ShowHotkey(candidate["stop"]) " | Record: " ShowHotkey(candidate["record"]))
    Log("Saved keybinds: " candidate["start"] " / " candidate["stop"] " / " candidate["record"])
    return true
}

SaveSettings(*) {
    candidate := GetActionHotkeyFields()
    if !ApplyAndSaveActionHotkeys(candidate)
        return
    try {
        PersistSettings()
        Log("Settings saved")
    } catch as e {
        MsgBox "Unable to save other settings:`n" e.Message, "PhantomMacro", "Icon!"
    }
}

ResetKeybindFields(*) {
    global hkStart, hkStop, hkRecord, UpdatingHotkeyFields
    candidate := DefaultActionHotkeys()
    UpdatingHotkeyFields := true
    try {
        hkStart.Value := candidate["start"]
        hkStop.Value := candidate["stop"]
        hkRecord.Value := candidate["record"]
    } finally {
        UpdatingHotkeyFields := false
    }
    ; Reset takes effect and saves right away, no second click required.
    ApplyAndSaveActionHotkeys(candidate)
}

EditPreset(*) {
    global ddl, PresetDir
    if ddl.Text != ""
        Run 'notepad.exe "' PresetDir "\" ddl.Text '.txt"'
}
