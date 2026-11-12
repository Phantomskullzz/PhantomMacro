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

; The .ico is loaded only once, then reused on every theme rebuild.
; WM_SETICON applies the branded icon to the actual GUI window and taskbar.
SetMacroWindowIcon(window) {
    global AppIconPath, AppIconLarge, AppIconSmall
    if !FileExist(AppIconPath)
        return
    try {
        if !AppIconLarge
            AppIconLarge := LoadPicture(AppIconPath, "Icon1 w32 h32", &imageType)
        if !AppIconSmall
            AppIconSmall := LoadPicture(AppIconPath, "Icon1 w16 h16", &imageType)
        if AppIconLarge
            DllCall("user32\SendMessageW", "ptr", window.Hwnd, "uint", 0x80,
                "uptr", 1, "ptr", AppIconLarge, "ptr")
        if AppIconSmall
            DllCall("user32\SendMessageW", "ptr", window.Hwnd, "uint", 0x80,
                "uptr", 0, "ptr", AppIconSmall, "ptr")
    } catch {
        ; A missing or invalid custom icon must never stop the macro GUI.
    }
}

ReleaseMacroIcons(exitReason, exitCode) {
    global AppIconLarge, AppIconSmall
    if AppIconLarge {
        DllCall("user32\DestroyIcon", "ptr", AppIconLarge)
        AppIconLarge := 0
    }
    if AppIconSmall {
        DllCall("user32\DestroyIcon", "ptr", AppIconSmall)
        AppIconSmall := 0
    }
}

; ============================================================
;  GUI construction (rebuilt whenever the theme changes)
; ============================================================
BuildGui(px := "", py := "") {
    global g, panels, navItems, NavHovered, ddl, edLoops, edSpeed, edWin
    global chkTop, statusTxt, recBtn, logBox, exePickerStatus
    global hkStart, hkStop, hkRecord, keybindStatus, ActionHotkeys
    global headerKeybindPic, UiHoverButtons, UiHoveredHwnd
    global AppVersion, AppIconPath
    global Pal, CurPage, ThemeOrder, Themes, CurTheme, WinTitle, PresetDir, LogText

    panels := Map("Main", [], "Settings", [], "Themes", [])
    navItems := Map()
    ; The hover tracker is only active while the pointer is on a navigation tile.
    SetTimer NavHoverTick, 0
    SetTimer UiHoverTick, 0
    NavHovered := ""
    UiHoverButtons := Map()
    UiHoveredHwnd := 0

    g := Gui("-MaximizeBox -Caption", "PM Macro")
    SetMacroWindowIcon(g)
    g.BackColor := Pal["BG"]
    g.MarginX := 0
    g.MarginY := 0
    g.SetFont("s10 c" Pal["TEXT"], "Segoe UI")

    ; ----- Sidebar (icon above label, glowing tile on the active page) -----
    g.Add("Text", "x0 y0 w96 h470 Background" Pal["SIDE"])
    if FileExist(AppIconPath) {
        try g.Add("Picture", "x30 y7 w36 h36", AppIconPath)
        catch {
            g.SetFont("s13 Bold c" Pal["ACCENT_T"], "Segoe UI")
            g.Add("Text", "x0 y21 w96 h25 Center BackgroundTrans", "PM")
        }
    } else {
        g.SetFont("s13 Bold c" Pal["ACCENT_T"], "Segoe UI")
        g.Add("Text", "x0 y21 w96 h25 Center BackgroundTrans", "PM")
    }
    ; The installed version stays visible in every GUI tab.
    g.SetFont("s8 Norm c" Pal["MUTED"], "Segoe UI")
    g.Add("Text", "x0 y46 w96 h15 Center BackgroundTrans", "v" AppVersion)
    navDefs := [["Main", "RUN", 0xE768], ["Settings", "SETTINGS", 0xE713], ["Themes", "THEMES", 0xE790]]
    for i, d in navDefs {
        ny := 70 + (i - 1) * 76
        tile := g.Add("Picture", "x10 y" ny " w76 h64",
            "HBITMAP:" RenderNavTile(d[2], d[3], d[1] = CurPage, false))
        tile.OnEvent("Click", ShowPanel.Bind(d[1]))
        navItems[d[1]] := {ctrl: tile, label: d[2], glyph: d[3], mode: d[1] = CurPage ? "active" : "idle"}
    }
    g.SetFont("s10 Norm c" Pal["TEXT"], "Segoe UI")

    ; Header uses a slim bitmap, leaving a 45+ px gap to the window controls.
    ; Pills are contained within x104..416, below the titlebar's 24px height.
    ; Continuous top bar matching the sidebar, including the window controls.
    g.Add("Text", "x96 y0 w428 h24 Background" Pal["SIDE"])
    g.SetFont("s8 Bold c" Pal["ACCENT_T"], "Segoe UI")
    try {
        headerBitmap := RenderHotkeyHeader()
        headerKeybindPic := g.Add("Picture", "x106 y2 w300 h20", "HBITMAP:" headerBitmap)
    } catch {
        headerKeybindPic := g.Add("Text", "x106 y2 w300 h20 Center +0x200 Background" Pal["SIDE"], "")
        RefreshHeaderHotkeys()
    }
    g.SetFont("s10 Norm c" Pal["TEXT"], "Segoe UI")

    ; ----- Main: preset, controls, status, log -----
    ddl := Reg("Main", g.Add("DropDownList", "x120 y36 w300 -Theme Background" Pal["FIELD"] " c" Pal["TEXT"]))
    Btn("Main", "x430 y36 w70 h24", "Reload", Pal["FIELD"], Pal["TEXT"], LoadList)
    g.SetFont("s10 Bold")
    Btn("Main", "x120 y88 w120 h40", "START", Pal["ACCENT"], Pal["ACCTXT"], StartMacro)
    Btn("Main", "x250 y88 w120 h40", "STOP", Pal["DANGER"], Pal["DANGERTXT"], StopMacro)
    recBtn := Btn("Main", "x380 y88 w120 h40", "RECORD", Pal["FIELD"], Pal["TEXT"], ToggleRecord)
    g.SetFont("s10 Norm c" Pal["TEXT"])
    Label("Main", "x120 y144", "LOOPS  (0 = forever)")
    edLoops := AddInputField("Main", "x120 y166 w100 h26 Number", ReadSetting("loops", "1"))
    Label("Main", "x265 y144", "SPEED (1.0 = normal)")
    edSpeed := AddInputField("Main", "x265 y166 w100 h26", ReadSetting("speed", "1.0"))
    Label("Main", "x265 y195", "2.0 = faster, 0.5 = slower")
    Btn("Main", "x380 y166 w120 h28", "EXPORT EXE", Pal["FIELD"], Pal["TEXT"], OpenExportDialog)
    statusTxt := Reg("Main", g.Add("Text", "x120 y212 w380 h22 BackgroundTrans c" Pal["ACCENT_T"], "Idle"))
    g.SetFont("s9 c" Pal["ACCENT_T"], "Consolas")
    logBox := Reg("Main", g.Add("Edit", "x120 y244 w380 h206 ReadOnly Multi +VScroll -Theme -E0x200 Background" Pal["SIDE"] " c" Pal["ACCENT_T"], LogText))
    SendMessage(0xD3, 3, 10 | (10 << 16), logBox)   ; inner padding left/right
    SendMessage(0x115, 7, 0, logBox)                 ; scroll to bottom
    g.SetFont("s10 Norm c" Pal["TEXT"], "Segoe UI")

    ; ----- Settings (keys, window, tools) -----
    ; Keep Settings focused on actual user-facing controls. Legacy upgrade/sell
    ; preset commands still read their last saved INI keys (defaults t/x), but
    ; the unused per-action editors no longer occupy this screen.
    Label("Settings", "x120 y44", "TARGET APPLICATION (.EXE)")
    edWin := AddInputField("Settings", "x120 y66 w268 h26", WinTitle)
    Btn("Settings", "x398 y66 w102 h26", "Pick EXE", Pal["FIELD"], Pal["TEXT"], StartExePicker)
    exePickerStatus := Reg("Settings", g.Add("Text", "x120 y94 w380 h18 BackgroundTrans c" Pal["MUTED"],
        "Press Pick EXE, then right-click the app window."))
    onTop := ReadSetting("ontop", "0") = "1"
    chkTop := Reg("Settings", g.Add("CheckBox", "x120 y122 -Theme c" Pal["TEXT"] (onTop ? " Checked" : ""), "Keep this window on top"))
    chkTop.OnEvent("Click", (*) => g.Opt(chkTop.Value ? "+AlwaysOnTop" : "-AlwaysOnTop"))
    if onTop
        g.Opt("+AlwaysOnTop")
    ; Hotkey controls display key names and support Ctrl / Alt / Shift combinations.
    Label("Settings", "x120 y166", "MACRO KEYBINDS  (click a box, then press a key)")
    Label("Settings", "x120 y194", "START")
    Label("Settings", "x250 y194", "STOP")
    Label("Settings", "x380 y194", "RECORD")
    hkStart := Reg("Settings", g.Add("Hotkey", "x120 y216 w120 h28 -Theme", ActionHotkeys["start"]))
    hkStop := Reg("Settings", g.Add("Hotkey", "x250 y216 w120 h28 -Theme", ActionHotkeys["stop"]))
    hkRecord := Reg("Settings", g.Add("Hotkey", "x380 y216 w120 h28 -Theme", ActionHotkeys["record"]))
    ; Save a complete, valid combination as soon as it is entered.
    ; OnEvent automatically handles Ctrl/Alt/Shift + key combinations.
    for bindAction, hotkeyControl in Map("start", hkStart, "stop", hkStop, "record", hkRecord)
        hotkeyControl.OnEvent("Change", HotkeyFieldChanged.Bind(bindAction))
    ; A real Button receives keyboard focus. The old text-only Save surface left
    ; focus in the Hotkey editor, effectively disabling the in-app shortcuts.
    bSave := Btn("Settings", "x120 y270 w134 h32", "Save settings", Pal["FIELD"], Pal["TEXT"], SaveSettings)
    bReset := Btn("Settings", "x264 y270 w144 h32", "Reset keybinds", Pal["FIELD"], Pal["TEXT"], ResetKeybindFields)
    keybindStatus := Reg("Settings", g.Add("Text", "x120 y310 w380 h22 BackgroundTrans c" Pal["ACCENT_T"], "Hotkeys active. Changes save automatically."))
    Label("Settings", "x120 y371", "TOOLS")
    Btn("Settings", "x120 y393 w120 h30", "Open folder", Pal["FIELD"], Pal["TEXT"], (*) => Run(PresetDir))
    Btn("Settings", "x250 y393 w120 h30", "Edit preset", Pal["FIELD"], Pal["TEXT"], EditPreset)
    Btn("Settings", "x380 y393 w120 h30", "Pick pixel", Pal["FIELD"], Pal["TEXT"], PickPixel)
    Reg("Settings", g.Add("Text", "x120 y436 w380 h22 BackgroundTrans c" Pal["MUTED"],
        "PhantomMacro v" AppVersion "  |  Offline edition - manual ZIP updates"))

    ; ----- Themes -----
    for i, tname in ThemeOrder {
        th := Themes[tname]
        cy := 24 + (i - 1) * 46
        themeTitle := tname (tname = CurTheme ? "     • ACTIVE" : "")
        Btn("Themes", "x120 y" cy " w380 h38", themeTitle, Pal["FIELD"],
            tname = CurTheme ? Pal["ACCENT_T"] : Pal["TEXT"], ApplyTheme.Bind(tname))
        for j, key in ["ACCENT", "BG"] {
            sw := Reg("Themes", g.Add("Text", "x" (445 + (j - 1) * 28) " y" (cy + 9) " w20 h20 Background" th[key]))
            RoundCtrl(sw, 8)
            sw.OnEvent("Click", ApplyTheme.Bind(tname))
            UiRegisterHover(sw, th[key], Pal["TEXT"], Pal["ACCENT_T"], Pal["ACCTXT"])
        }
    }

    ; ----- Custom window buttons (the title bar is removed) -----
    ; Both window controls share the shortcut-chip row (y2..22). The old
    ; y0/h26 layout made their glyphs visibly lower than the pill labels.
    g.SetFont("s9 Bold c" Pal["MUTED"], "Segoe UI")
    btnMin := g.Add("Text", "x460 y2 w32 h20 +0x200 Center Background" Pal["SIDE"], "−")
    btnMin.OnEvent("Click", (*) => g.Minimize())
    UiRegisterHover(btnMin, Pal["SIDE"], Pal["MUTED"], Pal["NAVON"], Pal["ACCENT_T"])
    btnClose := g.Add("Text", "x492 y2 w32 h20 +0x200 Center Background" Pal["SIDE"], "×")
    btnClose.OnEvent("Click", (*) => (PersistSettings(), ExitApp()))
    UiRegisterHover(btnClose, Pal["SIDE"], Pal["MUTED"], Pal["DANGER"], Pal["DANGERTXT"])
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
    ; Sidebar buttons are single bitmaps, not layered clipping regions.
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
    return ("0x" SubStr(rgb, 5, 2) SubStr(rgb, 3, 2) SubStr(rgb, 1, 2)) + 0
}

RenderHotkeyHeader() {
    global ActionHotkeys, Pal
    width := 300, height := 20
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
            "uint", 0, "uint", 0, "uint", 0, "uint", 0, "str", "Segoe UI", "ptr")
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
            x := 4 + (i - 1) * 98
            pillWidth := i = 3 ? 96 : 88
            rgn := DllCall("gdi32\CreateRoundRectRgn", "int", x, "int", 1,
                "int", x + pillWidth, "int", 19, "int", 18, "int", 18, "ptr")
            if !rgn
                throw Error("Failed to create pill region")
            try DllCall("gdi32\FillRgn", "ptr", mem, "ptr", rgn, "ptr", fg)
            finally DllCall("gdi32\DeleteObject", "ptr", rgn)
            textRect := Buffer(16, 0)
            NumPut("int", x + 3, "int", 1, "int", x + pillWidth - 3, "int", 19, textRect)
            DllCall("user32\DrawTextW", "ptr", mem, "wstr", label, "int", -1,
                "ptr", textRect, "uint", 0x8825, "int")
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
    global g, Pal
    b := g.Add("Text", opts " +0x200 Center Background" bg " c" fg, text)
    b.OnEvent("Click", fn)
    RoundCtrl(b, 20)
    ; Accent buttons brighten; secondary buttons get an accent text/fill hover.
    UiRegisterHover(b, bg, fg,
        bg = Pal["ACCENT"] ? Pal["ACCENT_T"] : Pal["NAVON"],
        bg = Pal["ACCENT"] ? Pal["ACCTXT"] : Pal["ACCENT_T"])
    return Reg(p, b)
}


; Register every clickable action surface for clear colour-on-hover feedback.
; Timer runs only while the pointer is on a button and stops on exit.
UiRegisterHover(ctrl, bg, fg, hoverBg, hoverFg) {
    global UiHoverButtons
    UiHoverButtons[ctrl.Hwnd] := {ctrl:ctrl, normalBg:bg, normalFg:fg,
        hoverBg:hoverBg, hoverFg:hoverFg, hovered:false}
    return ctrl
}

UiHoverMouseMove(wParam, lParam, msg, hwnd) {
    UiUpdateHover()
}

UiHoverTick() {
    UiUpdateHover()
}

UiUpdateHover() {
    global UiHoverButtons, UiHoveredHwnd
    if !IsObject(UiHoverButtons) || UiHoverButtons.Count = 0
        return
    ; Direct HWND hit-testing avoids repeated GetWindowRect calls on mouse moves.
    MouseGetPos(&mx, &my, &hoverWindow, &hoverControl, 2)
    target := 0
    if UiHoverButtons.Has(hoverControl) {
        item := UiHoverButtons[hoverControl]
        try {
            if item.ctrl.Visible
                target := hoverControl
        }
    }
    if target = UiHoveredHwnd
        return
    if UiHoveredHwnd && UiHoverButtons.Has(UiHoveredHwnd)
        UiPaintHover(UiHoverButtons[UiHoveredHwnd], false)
    UiHoveredHwnd := target
    if target && UiHoverButtons.Has(target)
        UiPaintHover(UiHoverButtons[target], true)
    SetTimer UiHoverTick, target ? 85 : 0
}

UiPaintHover(entry, hovered) {
    try {
        entry.ctrl.Opt("Background" (hovered ? entry.hoverBg : entry.normalBg)
            " c" (hovered ? entry.hoverFg : entry.normalFg))
        entry.ctrl.Redraw()
        entry.hovered := hovered
    }
}

; When RECORD switches to STOP REC, keep the active state and hover colours in sync.
UiSetButtonBase(ctrl, bg, fg) {
    global UiHoverButtons, UiHoveredHwnd, Pal
    id := ctrl.Hwnd
    if !UiHoverButtons.Has(id)
        return
    item := UiHoverButtons[id]
    item.normalBg := bg, item.normalFg := fg
    isStrong := (bg = Pal["ACCENT"] || bg = Pal["DANGER"])
    item.hoverBg := isStrong ? Pal["ACCENT_T"] : Pal["NAVON"]
    item.hoverFg := isStrong ? Pal["ACCTXT"] : Pal["ACCENT_T"]
    UiPaintHover(item, UiHoveredHwnd = id)
}

UiForgetHover(ctrl) {
    global UiHoverButtons, UiHoveredHwnd
    id := ctrl.Hwnd
    if UiHoverButtons.Has(id)
        UiHoverButtons.Delete(id)
    if UiHoveredHwnd = id {
        UiHoveredHwnd := 0
        SetTimer UiHoverTick, 0
    }
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

; One-shot application picker: press Pick EXE, then right-click any running app.
; During picking, the right-click is consumed so no context menu is opened.
; Esc, the Pick EXE button, a tab change, or the timeout cancels selection.
StartExePicker(*) {
    global PickingTarget, Running, Recording, exePickerStatus
    if PickingTarget {
        StopExePicker("Selection cancelled.")
        return
    }
    if Running || Recording {
        exePickerStatus.Text := "Stop playback or recording before choosing an app."
        return
    }
    PickingTarget := true
    try {
        Hotkey "*RButton", CaptureExeRightClick, "On"
        Hotkey "*Esc", CancelExePicker, "On"
        SetTimer ExePickerTimedOut, -30000
        exePickerStatus.Text := "Right-click your app window now. Esc cancels (30s)."
    } catch as e {
        StopExePicker("Picker unavailable: " e.Message)
    }
}

CaptureExeRightClick(*) {
    global PickingTarget, g, edWin, WinTitle, exePickerStatus
    if !PickingTarget
        return
    MouseGetPos(, , &hwnd)
    if !hwnd {
        exePickerStatus.Text := "No window found. Right-click an open app window."
        return
    }
    ; MouseGetPos can return a child control. Normalize to the top-level app.
    root := DllCall("user32\GetAncestor", "ptr", hwnd, "uint", 2, "ptr")
    if root
        hwnd := root
    if hwnd = g.Hwnd {
        exePickerStatus.Text := "Right-click the OTHER application's window."
        return
    }
    try {
        cls := WinGetClass("ahk_id " hwnd)
        if cls = "Progman" || cls = "WorkerW" || cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd"
            throw Error("Choose a running app window, not the desktop/taskbar.")
        exe := WinGetProcessName("ahk_id " hwnd)
        if !RegExMatch(exe, "i)\.exe$")
            throw Error("Windows did not return an EXE for that window.")
        selected := "ahk_exe " exe
        ; Save before changing the active target so an inaccessible INI cannot
        ; silently create a target that will be lost after restart.
        WriteSetting("window", selected)
        edWin.Value := selected
        WinTitle := selected
        StopExePicker()
        exePickerStatus.Text := "Selected: " exe "  (saved)"
        Log("Application target set to " exe)
    } catch as e {
        exePickerStatus.Text := "Not selected: " SubStr(e.Message, 1, 70)
    }
}

StopExePicker(message := "") {
    global PickingTarget, exePickerStatus
    PickingTarget := false
    SetTimer ExePickerTimedOut, 0
    try Hotkey "*RButton", "Off"
    try Hotkey "*Esc", "Off"
    if message != "" && IsObject(exePickerStatus)
        exePickerStatus.Text := message
}

CancelExePicker(*) {
    StopExePicker("Selection cancelled. Press Pick EXE to retry.")
}

ExePickerTimedOut(*) {
    if PickingTarget
        StopExePicker("Selection timed out. Press Pick EXE to retry.")
}

; Sidebar hover is driven by WM_MOUSEMOVE, not a permanent mouse poll.
; Only while a tile is hovered do we use a brief timer to detect leaving it.
NavMouseMove(wParam, lParam, msg, hwnd) {
    global g
    if !IsObject(g)
        return
    if hwnd != g.Hwnd && DllCall("user32\GetAncestor", "ptr", hwnd, "uint", 2, "ptr") != g.Hwnd
        return
    UpdateNavHover()
}

NavHoverTick() {
    UpdateNavHover()
}

NavHitTest() {
    global navItems
    MouseGetPos(&mx, &my)
    bounds := Buffer(16, 0)
    for name, tile in navItems {
        if !DllCall("user32\GetWindowRect", "ptr", tile.ctrl.Hwnd, "ptr", bounds, "int")
            continue
        x1 := NumGet(bounds, 0, "int")
        y1 := NumGet(bounds, 4, "int")
        x2 := NumGet(bounds, 8, "int")
        y2 := NumGet(bounds, 12, "int")
        if mx >= x1 && mx < x2 && my >= y1 && my < y2
            return name
    }
    return ""
}

UpdateNavHover() {
    global NavHovered
    try hovered := NavHitTest()
    catch
        return
    if hovered = NavHovered
        return
    NavHovered := hovered
    SetTimer NavHoverTick, hovered = "" ? 0 : 85
    PaintNavTiles()
}

PaintNavTiles() {
    global navItems, NavHovered, CurPage
    for name, tile in navItems {
        active := name = CurPage
        hovered := name = NavHovered
        mode := active ? (hovered ? "active-hover" : "active") : (hovered ? "hover" : "idle")
        if mode = tile.mode
            continue
        ; A single picture replaces layered, clipped text windows that left
        ; dark triangles in the rounded sidebar buttons after hover changes.
        try tile.ctrl.Value := "HBITMAP:" RenderNavTile(tile.label, tile.glyph,
            active, hovered)
        tile.mode := mode
    }
}

; Draw a complete tile into one opaque bitmap. No overlapping controls,
; transparent regions or corner-pixel remnants when switching hover state.
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

ShowPanel(name, *) {
    global CurPage, panels, navItems, g, logBox, hkStart, hkStop, hkRecord, PickingTarget
    if name != "Settings" && PickingTarget
        StopExePicker("Selection cancelled.")
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
    PaintNavTiles()
    UiUpdateHover()
    ; Repaint after switching pages; hover updates only toggle the affected tiles.
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
    global WinTitle, edWin, edLoops, edSpeed, ddl, chkTop, ActionHotkeys
    WinTitle := edWin.Value
    WriteSetting("loops", edLoops.Value)
    WriteSetting("speed", edSpeed.Value)
    ; Keep existing upkey/sellkey INI entries untouched so older presets
    ; retain their original behaviour even without visible key editors.
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
