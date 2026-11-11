#Requires AutoHotkey v2.0
#SingleInstance Force

; PhantomMacro.ahk — the ONLY file you need to launch.
; Keep GUI.ahk and Macro.ahk alongside this file.
; F5 start / F8 stop / F7 record initially; change these in Settings. F9 picks a pixel.

CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
SetMouseDelay -1   ; No artificial delay between recorded pointer positions.
SetKeyDelay 0, 15  ; Let short legacy key steps register in games.

; Shared configuration and state used by both modules.
global AppVersion := "0.3.4"
global UpdatingNow := false
global updateStatusLabel := ""
global IniFile := A_ScriptDir "\settings.ini"
global PresetDir := A_ScriptDir "\presets"
global WinTitle := ReadSetting("window", "ahk_exe RobloxPlayerBeta.exe")

global Running := false
global Recording := false
global RecordLines := []
global LastTick := 0
global PendingSlot := ""    ; Kept for compatibility with existing presets.
; Recorder state (captured only while the configured Roblox window is active).
global RecorderInput := ""
global RecorderHeldKeys := Map(), RecorderHeldButtons := Map()
global RecorderMouseX := "", RecorderMouseY := ""
; Playback-held inputs must always be released when stopped/aborted.
global PlaybackHeldKeys := Map(), PlaybackHeldButtons := Map()

; GUI globals are declared here so that all included functions can share them.
global Themes := Map(), ThemeOrder := []
global CurTheme := "", Pal := Map(), CurPage := "Main", LogText := ""
global g := "", panels := Map(), navItems := Map()
global ddl := "", edLoops := "", edSpeed := "", edUp := "", edSell := "", edWin := ""
global chkTop := "", statusTxt := "", recBtn := "", logBox := ""
global hkStart := "", hkStop := "", hkRecord := "", keybindStatus := ""
; Read-only shortcut chips shown in the title/header area on every page.
global headerKeybindPic := ""
; Prevent programmatic resets of hotkey fields from causing a save callback.
global UpdatingHotkeyFields := false
; Live hotkeys and the previously registered shortcuts (both held by the macro module).
global ActionHotkeys := Map("start", "F5", "stop", "F8", "record", "F7")
global InstalledActionHotkeys := Map()

DirCreate PresetDir
InitGuiState()
LoadActionHotkeySettings()
BuildGui()
OnMessage(0x201, DragWindow)   ; Drag the window using empty space.
InitRecorderHotkeys()
InitActionHotkeys()
SetTimer (*) => CheckForUpdates(true), -3500

; Include implementation of GUI and macro in this SAME AutoHotkey process.
; Use this entrypoint, not GUI.ahk or Macro.ahk.
#Include %A_ScriptDir%\GUI.ahk
#Include %A_ScriptDir%\Macro.ahk
#Include %A_ScriptDir%\UpdateManager.ahk
