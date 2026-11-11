; Macro.ahk — macro engine, playback, recording and hotkeys.
; Loaded by PhantomMacro.ahk. Do not run this file by itself.

; This file is included by PhantomMacro.ahk, not started separately.
; If someone opens this file directly, hand off to the launcher.
if (A_ScriptName = "Macro.ahk") {
    launcher := A_ScriptDir "\PhantomMacro.ahk"
    if FileExist(launcher)
        Run '"' A_AhkPath '" "' launcher '"'
    else
        MsgBox "PhantomMacro.ahk is missing. Keep all three .ahk files together.", "PhantomMacro"
    ExitApp
}


InitRecorderHotkeys() {
    global Recording, WinTitle
    ; Mouse hooks pass the real event through (~); capture only in Roblox.
    HotIf (*) => Recording && WinActive(WinTitle)
    for buttonName in ["LButton", "RButton", "MButton", "XButton1", "XButton2"] {
        Hotkey "~*" buttonName, RecorderMouseButton.Bind(buttonName, "down")
        Hotkey "~*" buttonName " Up", RecorderMouseButton.Bind(buttonName, "up")
    }
    for wheelName in ["WheelUp", "WheelDown", "WheelLeft", "WheelRight"]
        Hotkey "~*" wheelName, RecorderMouseWheel.Bind(wheelName)
    HotIf
}

; ============================================================
;  Engine
; ============================================================
Speed() {
    global edSpeed
    try
        return Max(0.1, Float(edSpeed.Value))
    return 1.0
}

GetRect() {
    global WinTitle
    if !WinExist(WinTitle)
        throw Error("Roblox window not found")
    WinGetClientPos(&x, &y, &w, &h, WinTitle)
    return {x: x, y: y, w: w, h: h}
}

ToScreen(fx, fy) {
    r := GetRect()
    return {x: Round(r.x + fx * r.w), y: Round(r.y + fy * r.h)}
}

; Playback speed is a multiplier: 1.0 = recorded timing, 2.0 = twice
; as fast, 0.5 = half speed. Higher values MUST mean shorter delays.
; Only timed steps are scaled; waitpixel continues waiting for game state.
Nap(ms) {
    global Running
    duration := Max(0, Round(ms / Speed()))
    endTick := A_TickCount + duration
    while Running && A_TickCount < endTick
        Sleep Min(50, endTick - A_TickCount)
}

ClickAt(fx, fy) {
    p := ToScreen(fx, fy)
    MouseMove p.x, p.y, 0
    Nap(60)
    Click
    Nap(80)
}

ColorNear(a, b, tol) {
    return Abs(((a >> 16) & 255) - ((b >> 16) & 255)) <= tol
        && Abs(((a >> 8) & 255) - ((b >> 8) & 255)) <= tol
        && Abs((a & 255) - (b & 255)) <= tol
}

Join(arr) {
    s := ""
    for v in arr
        s .= (A_Index > 1 ? " " : "") v
    return s
}

LoadPreset(path) {
    steps := []
    text := FileRead(path)
    Loop Parse text, "`n", "`r" {
        line := Trim(A_LoopField)
        if line = "" || SubStr(line, 1, 1) = ";"
            continue
        line := RegExReplace(line, "\s+", " ")
        steps.Push(StrSplit(line, " "))
    }
    return steps
}

; Returns false to abort the current run (stop pressed or a wait timed out)
ExecStep(p) {
    global Running, edUp, edSell, PlaybackHeldKeys, PlaybackHeldButtons
    cmd := StrLower(p[1])
    switch cmd {
        case "click":                       ; click fx fy
            ClickAt(Float(p[2]), Float(p[3]))
        case "move":                        ; move fx fy — recorded pointer path
            pnt := ToScreen(Float(p[2]), Float(p[3]))
            MouseMove pnt.x, pnt.y, 0
        case "mousedown":                   ; mousedown LButton / RButton / ...
            buttonName := p[2]
            SendEvent "{" buttonName " Down}"
            PlaybackHeldButtons[buttonName] := true
        case "mouseup":                     ; mouseup LButton / RButton / ...
            buttonName := p[2]
            SendEvent "{" buttonName " Up}"
            if PlaybackHeldButtons.Has(buttonName)
                PlaybackHeldButtons.Delete(buttonName)
        case "wheel":                       ; wheel WheelUp / WheelDown / ...
            SendEvent "{" p[2] "}"
        case "keydown":                     ; keydown W (also supports modifier keys)
            keyName := p[2]
            SendEvent "{" keyName " Down}"
            PlaybackHeldKeys[keyName] := true
        case "keyup":                       ; keyup W
            keyName := p[2]
            SendEvent "{" keyName " Up}"
            if PlaybackHeldKeys.Has(keyName)
                PlaybackHeldKeys.Delete(keyName)
        case "place":                       ; place slot fx fy
            Send "{" p[2] "}"
            Nap(150)
            ClickAt(Float(p[3]), Float(p[4]))
        case "upgrade":                     ; upgrade fx fy [times]
            ClickAt(Float(p[2]), Float(p[3]))
            Loop (p.Length >= 4 ? Integer(p[4]) : 1) {
                if !Running
                    return false
                Send "{" edUp.Value "}"
                Nap(200)
            }
        case "sell":                        ; sell fx fy
            ClickAt(Float(p[2]), Float(p[3]))
            Send "{" edSell.Value "}"
            Nap(200)
        case "key":                         ; key k
            Send "{" p[2] "}"
            Nap(100)
        case "wait":                        ; wait ms
            Nap(Integer(p[2]))
        case "waitpixel":                   ; waitpixel fx fy 0xRRGGBB [timeoutMs] [tolerance]
            timeout := p.Length >= 5 ? Integer(p[5]) : 60000
            tol := p.Length >= 6 ? Integer(p[6]) : 20
            want := Integer(p[4])
            deadline := A_TickCount + timeout
            while Running {
                pos := ToScreen(Float(p[2]), Float(p[3]))
                if ColorNear(PixelGetColor(pos.x, pos.y), want, tol)
                    return true
                if A_TickCount > deadline {
                    SetStatus("waitpixel timed out - restarting run")
                    return false
                }
                Sleep 100
            }
            return false
        default:
            throw Error("Unknown command: " cmd)
    }
    return Running
}

RunSteps(steps) {
    global Running, WinTitle
    for step in steps {
        if !Running
            return false
        ; Never send recorded keyboard/mouse input into another application.
        if !WinActive(WinTitle) {
            Running := false
            SetStatus("Stopped: Roblox lost focus")
            return false
        }
        ; High-frequency move/wait pairs should not flood the GUI log.
        verb := StrLower(step[1])
        if verb != "move" && (verb != "wait" || Integer(step[2]) >= 250)
            Log(Join(step))
        if !ExecStep(step)
            return false
    }
    return true
}

StartMacro(*) {
    global Running, WinTitle, Recording, ddl, PresetDir, edWin, edLoops
    global PlaybackHeldKeys, PlaybackHeldButtons
    if Running || Recording
        return
    if ddl.Text = "" {
        SetStatus("Choose or record a preset before starting")
        return
    }
    WinTitle := edWin.Value
    try {
        steps := LoadPreset(PresetDir "\" ddl.Text ".txt")
        if !steps.Length {
            SetStatus("Preset is empty")
            return
        }
        if !WinExist(WinTitle)
            throw Error("Roblox window not found: " WinTitle)
        ; Launching playback with the START GUI button otherwise sends keys
        ; to PhantomMacro itself rather than the game.
        WinActivate WinTitle
        if !WinWaitActive(WinTitle, , 2)
            throw Error("Could not focus Roblox. Activate the game and retry.")
        loops := edLoops.Value = "" ? 0 : Integer(edLoops.Value)
        PlaybackHeldKeys := Map()
        PlaybackHeldButtons := Map()
        Running := true
        n := 0
        while Running {
            n++
            SetStatus("Running '" ddl.Text "' - run " n)
            if !RunSteps(steps)
                break
            if loops > 0 && n >= loops
                break
        }
    } catch as e {
        Log("ERROR: " e.Message)
        MsgBox "Macro error: " e.Message, "PhantomMacro", "Icon!"
    } finally {
        Running := false
        ReleasePlaybackInputs()
        SetStatus("Idle")
    }
}

StopMacro(*) {
    global Running
    Running := false
    SetStatus("Stopped")
}

ReleasePlaybackInputs() {
    global PlaybackHeldKeys, PlaybackHeldButtons
    ; A stopped preset must never leave a key or mouse button held down.
    for buttonName in PlaybackHeldButtons {
        try SendEvent "{" buttonName " Up}"
    }
    for keyName in PlaybackHeldKeys {
        try SendEvent "{" keyName " Up}"
    }
    PlaybackHeldButtons := Map()
    PlaybackHeldKeys := Map()
}

; ---------------- Full recorder ----------------
; New presets contain: move, mousedown/up, wheel, keydown/up and wait.
; Old click/place/key/wait/pixel preset commands remain supported.
; All cursor coordinates are saved relative to the Roblox client area.

AddRecord(line, showInLog := true) {
    global LastTick, RecordLines
    now := A_TickCount
    elapsed := Max(0, now - LastTick)
    ; Record timing for each movement/key/button event, not only long pauses.
    if elapsed >= 10 && RecordLines.Length
        RecordLines.Push("wait " elapsed)
    RecordLines.Push(line)
    LastTick := now
    ; Mouse movement is high-frequency. Logging each position would make the
    ; GUI extremely slow and drown out useful messages.
    if showInLog
        Log("rec: " line)
}

RecorderTargetActive() {
    global Recording, WinTitle
    return Recording && WinActive(WinTitle)
}

RecorderSampleMouse(force := false) {
    global RecorderMouseX, RecorderMouseY
    if !RecorderTargetActive()
        return false
    try {
        MouseGetPos &mx, &my
        rect := GetRect()
        if rect.w <= 0 || rect.h <= 0
            return false
        ; Ignore the cursor outside the actual game client area.
        if mx < rect.x || mx >= rect.x + rect.w || my < rect.y || my >= rect.y + rect.h
            return false
        if !force && RecorderMouseX != "" {
            ; 3-pixel threshold filters jitter while keeping smooth motion.
            if Abs(mx - RecorderMouseX) < 3 && Abs(my - RecorderMouseY) < 3
                return false
        }
        if !force && RecorderMouseX = mx && RecorderMouseY = my
            return false
        fx := Round((mx - rect.x) / rect.w, 5)
        fy := Round((my - rect.y) / rect.h, 5)
        AddRecord("move " fx " " fy, false)
        RecorderMouseX := mx
        RecorderMouseY := my
        return true
    } catch {
        return false
    }
}

RecorderMouseButton(buttonName, direction, *) {
    global RecorderHeldButtons, Recording
    if !RecorderTargetActive()
        return
    ; Save the exact position before every press/release. Combined with the
    ; movement timer, this reproduces click locations and right/left drags.
    RecorderSampleMouse(true)
    if direction = "down" {
        if RecorderHeldButtons.Has(buttonName)
            return
        RecorderHeldButtons[buttonName] := true
    } else {
        if !RecorderHeldButtons.Has(buttonName)
            return
        RecorderHeldButtons.Delete(buttonName)
    }
    AddRecord("mouse" direction " " buttonName)
}

RecorderMouseWheel(wheelName, *) {
    if !RecorderTargetActive()
        return
    RecorderSampleMouse(true)
    AddRecord("wheel " wheelName)
}

RecorderKeyId(vk, sc) {
    return Format("{:02X}:{:03X}", vk, sc)
}

IsMacroControlKey(vk) {
    global ActionHotkeys
    ; Don't accidentally replay Start/Stop/Record or the reserved F9 tool.
    if vk = GetKeyVK("F9")
        return true
    for action, binding in ActionHotkeys {
        name := RegExReplace(binding, "[\^!+]", "")
        if name = "" || vk != GetKeyVK(name)
            continue
        if (InStr(binding, "^") != 0) != !!GetKeyState("Ctrl", "P")
            continue
        if (InStr(binding, "!") != 0) != !!GetKeyState("Alt", "P")
            continue
        if (InStr(binding, "+") != 0) != !!GetKeyState("Shift", "P")
            continue
        return true
    }
    return false
}

RecorderOnKeyDown(ih, vk, sc) {
    global RecorderHeldKeys
    if !RecorderTargetActive() || IsMacroControlKey(vk)
        return
    id := RecorderKeyId(vk, sc)
    if RecorderHeldKeys.Has(id)
        return  ; Ignore Windows key auto-repeat while physically held.
    keyName := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
    if keyName = ""
        keyName := Format("vk{:02X}sc{:03X}", vk, sc)
    RecorderHeldKeys[id] := keyName
    AddRecord("keydown " keyName)
}

RecorderOnKeyUp(ih, vk, sc) {
    global RecorderHeldKeys, Recording
    if !Recording
        return
    id := RecorderKeyId(vk, sc)
    if !RecorderHeldKeys.Has(id)
        return
    keyName := RecorderHeldKeys[id]
    RecorderHeldKeys.Delete(id)
    ; Always release any key pressed in Roblox, even if focus just changed.
    AddRecord("keyup " keyName)
}

RecorderStartCapture() {
    global RecorderInput, RecorderMouseX, RecorderMouseY
    global RecorderHeldKeys, RecorderHeldButtons
    RecorderMouseX := ""
    RecorderMouseY := ""
    RecorderHeldKeys := Map()
    RecorderHeldButtons := Map()
    ih := InputHook("L0 V")   ; No text buffer / 1023-character limit.
    ih.VisibleText := true
    ih.VisibleNonText := true
    ih.KeyOpt("{All}", "N")
    ih.OnKeyDown := RecorderOnKeyDown
    ih.OnKeyUp := RecorderOnKeyUp
    ih.Start()
    RecorderInput := ih
    ; Sample the cursor 40 times per second. Dragging is recorded via
    ; distinct button-down/movement/button-up events.
    SetTimer RecorderSampleMouse, 25
}

RecorderStopCapture() {
    global RecorderInput, RecorderHeldKeys, RecorderHeldButtons
    SetTimer RecorderSampleMouse, 0
    if IsObject(RecorderInput) {
        RecorderInput.Stop()
        RecorderInput := ""
    }
    ; Close any outstanding holds so replay never leaves a key/button down.
    for id, keyName in RecorderHeldKeys
        AddRecord("keyup " keyName)
    for buttonName in RecorderHeldButtons
        AddRecord("mouseup " buttonName)
    RecorderHeldKeys := Map()
    RecorderHeldButtons := Map()
}

ToggleRecord(*) {
    global Recording, RecordLines, LastTick, PendingSlot, WinTitle
    global Running, edWin, recBtn, Pal, PresetDir, ActionHotkeys, ddl
    if Running
        return
    if !Recording {
        WinTitle := edWin.Value
        if !WinExist(WinTitle) {
            SetStatus("Roblox not found. Check Settings > window target.")
            return
        }
        RecordLines := []
        LastTick := A_TickCount
        PendingSlot := ""
        Recording := true
        try {
            RecorderStartCapture()
        } catch as e {
            Recording := false
            try RecorderStopCapture()
            SetStatus("Recorder error: " e.Message)
            MsgBox "Could not start recording: " e.Message, "PhantomMacro", "Icon!"
            return
        }
        recBtn.Text := "STOP REC"
        recBtn.Opt("+Background" Pal["DANGER"])
        recBtn.Redraw()
        SetStatus("Recording mouse + keys in Roblox. Press " ShowHotkey(ActionHotkeys["record"]) " to stop.")
    } else {
        Recording := false
        RecorderStopCapture()
        recBtn.Text := "RECORD"
        recBtn.Opt("+Background" Pal["FIELD"])
        recBtn.Redraw()
        if RecordLines.Length {
            filename := "recorded_" FormatTime(, "yyyyMMdd_HHmmss")
            filepath := PresetDir "\" filename ".txt"
            output := "; PhantomMacro recording — mouse movement, mouse buttons, keyboard and timing`n"
            for eventLine in RecordLines
                output .= eventLine "`n"
            try {
                FileAppend output, filepath, "UTF-8"
                LoadList()
                try ddl.Choose(filename)
                SetStatus("Saved " filename ".txt (" RecordLines.Length " steps)")
            } catch as e {
                SetStatus("Could not save recording: " e.Message)
                MsgBox "Could not save preset:`n" e.Message, "PhantomMacro", "Icon!"
            }
        } else {
            SetStatus("No input recorded. Focus Roblox while recording.")
        }
    }
}

; F9: copy a ready-to-paste waitpixel line for whatever is under the cursor
PickPixel(*) {
    try {
        MouseGetPos &mx, &my
        r := GetRect()
        fx := Round((mx - r.x) / r.w, 4)
        fy := Round((my - r.y) / r.h, 4)
        A_Clipboard := "waitpixel " fx " " fy " " PixelGetColor(mx, my) " 30000 20"
        SetStatus("Copied: " A_Clipboard)
    }
}

; ---------------- Rebindable global hotkeys ----------------
; These three shortcuts are created dynamically rather than with F5:: etc.
; They are loaded at startup and saved through the Settings page.
DefaultActionHotkeys() {
    return Map("start", "F5", "stop", "F8", "record", "F7")
}

ShowHotkey(key) {
    label := (InStr(key, "^") ? "Ctrl+" : "")
    label .= (InStr(key, "!") ? "Alt+" : "")
    label .= (InStr(key, "+") ? "Shift+" : "")
    return label RegExReplace(key, "[\^!+]")
}

HotkeyId(key) {
    ; Normalize modifier order and case for duplicate checking.
    mods := (InStr(key, "^") ? "^" : "")
    mods .= (InStr(key, "!") ? "!" : "")
    mods .= (InStr(key, "+") ? "+" : "")
    return StrLower(mods RegExReplace(key, "[\^!+]"))
}

ValidateActionHotkeys(candidate) {
    seen := Map()
    for action in ["start", "stop", "record"] {
        key := candidate[action]
        ; The Hotkey GUI control may temporarily contain only a modifier.
        if key = "" || RegExReplace(key, "[\^!+]") = ""
            return "Choose a complete key for " action "."
        identity := HotkeyId(key)
        if identity = "f9"
            return "F9 is reserved for Pick Pixel. Choose another key."
        if seen.Has(identity)
            return "Start, Stop and Record must each have a different keybind."
        seen[identity] := true
    }
    return ""
}

ActionHotkeyCallback(action) {
    ; In AHK v2, named functions ARE function objects. Calling Func("Name")
    ; treats Func as a class constructor and throws "Invalid base.".
    ; Pass the function itself to Hotkey() instead.
    switch action {
        case "start":  return StartMacro
        case "stop":   return StopMacro
        case "record": return ToggleRecord
    }
    throw Error("Unknown action: " action)
}

LoadActionHotkeySettings() {
    global ActionHotkeys
    candidate := DefaultActionHotkeys()
    candidate["start"] := ReadSetting("hk_start", "F5")
    candidate["stop"] := ReadSetting("hk_stop", "F8")
    candidate["record"] := ReadSetting("hk_record", "F7")
    if ValidateActionHotkeys(candidate) = ""
        ActionHotkeys := candidate
}

; Global shortcuts work everywhere EXCEPT while editing a hotkey field.
; This allows an existing binding (e.g. F5) to be pressed into the editor.
ActionHotkeyContext(*) {
    global g, CurPage, hkStart, hkStop, hkRecord
    ; Disable these keys ONLY while actually typing in a visible hotkey field.
    ; When switching to Main/Themes, the shortcuts always work again.
    if CurPage != "Settings" || !IsObject(g) || !WinActive("ahk_id " g.Hwnd)
        return true
    try {
        focused := g.FocusedCtrl
        if IsObject(focused)
            return focused.Hwnd != hkStart.Hwnd && focused.Hwnd != hkStop.Hwnd && focused.Hwnd != hkRecord.Hwnd
    }
    return true
}

; Registers a new set as a unit, restores the old set on failure.
; Returns blank for success, error text for failure.
InstallActionHotkeys(candidate) {
    global ActionHotkeys, InstalledActionHotkeys
    old := InstalledActionHotkeys.Clone()
    touched := []
    errorText := ""
    ; The same stable HotIf callback is used when disabling and adding keys.
    HotIf ActionHotkeyContext
    try {
        for action, key in old
            Hotkey key, "Off"
        for action in ["start", "stop", "record"] {
            key := candidate[action]
            Hotkey key, ActionHotkeyCallback(action), "On"
            touched.Push(key)
        }
    } catch as e {
        for key in touched {
            try Hotkey key, "Off"
        }
        for action, key in old {
            try Hotkey key, ActionHotkeyCallback(action), "On"
        }
        errorText := e.Message
    } finally {
        HotIf
    }
    if errorText != ""
        return errorText
    InstalledActionHotkeys := candidate.Clone()
    ActionHotkeys := candidate.Clone()
    ; Show the newly installed shortcuts in the compact header immediately.
    RefreshHeaderHotkeys()
    return ""
}

InitActionHotkeys() {
    global ActionHotkeys, hkStart, hkStop, hkRecord, UpdatingHotkeyFields
    problem := InstallActionHotkeys(ActionHotkeys)
    if problem != "" {
        defaults := DefaultActionHotkeys()
        fallbackProblem := InstallActionHotkeys(defaults)
        if fallbackProblem != "" {
            SetKeybindStatus("Hotkeys unavailable: " fallbackProblem)
            MsgBox "Cannot register macro hotkeys: " fallbackProblem, "PhantomMacro", "Icon!"
            return
        }
        ; Changing GUI controls programmatically must not trigger auto-save.
        UpdatingHotkeyFields := true
        try {
            hkStart.Value := defaults["start"]
            hkStop.Value := defaults["stop"]
            hkRecord.Value := defaults["record"]
        } finally {
            UpdatingHotkeyFields := false
        }
        SetKeybindStatus("Saved binding unavailable. F5 / F8 / F7 active; reset to save.")
        Log("Saved keybind unavailable; using F5 / F8 / F7 temporarily")
        return
    }
    SetKeybindStatus("Active: Start " ShowHotkey(ActionHotkeys["start"])
        " | Stop " ShowHotkey(ActionHotkeys["stop"])
        " | Record " ShowHotkey(ActionHotkeys["record"]))
}

; F9 is deliberately not rebindable because the pixel picker uses it.
; Like other shortcuts it must not intercept key presses in hotkey editors.
#HotIf ActionHotkeyContext()
F9:: PickPixel()
#HotIf