#Requires AutoHotkey v2.0
#SingleInstance Force

; PhantomMacro.ahk — the ONLY file you need to launch.
; Keep GUI.ahk and Macro.ahk alongside this file.
; F5 start / F8 stop / F7 record initially; change these in Settings. F9 picks a pixel.

CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
SetMouseDelay -1   ; No artificial delay between recorded pointer positions.
SetKeyDelay 0, 15  ; Let short key steps register in target applications.

; Shared configuration and state used by both modules.
global AppVersion := "1.0.0"
global AppSupportDir := A_IsCompiled ? A_Temp "\PhantomMacro_v1_Resources" : A_ScriptDir
global AppIconPath := AppSupportDir "\PhantomMacro.ico"
global PlayerTemplatePath := AppSupportDir "\PlayerTemplate.ahk"
global AppIconLarge := 0, AppIconSmall := 0
global IniFile := A_ScriptDir "\settings.ini"
global PresetDir := A_ScriptDir "\presets"
global WinTitle := ReadSetting("window", "")
global PickingTarget := false

global Running := false
global Recording := false
global RecordLines := []
global LastTick := 0
global PendingSlot := ""    ; Kept for compatibility with existing presets.
; Recorder state (captured only while the selected application window is active).
global RecorderInput := ""
global RecorderHeldKeys := Map(), RecorderHeldButtons := Map()
global RecorderMouseX := "", RecorderMouseY := ""
; Playback-held inputs must always be released when stopped/aborted.
global PlaybackHeldKeys := Map(), PlaybackHeldButtons := Map()

; GUI globals are declared here so that all included functions can share them.
global Themes := Map(), ThemeOrder := []
global CurTheme := "", Pal := Map(), CurPage := "Main", LogText := ""
global g := "", panels := Map(), navItems := Map(), NavHovered := ""
global UiHoverButtons := Map(), UiHoveredHwnd := 0
global ExportDialogHwnd := 0
global ddl := "", edLoops := "", edSpeed := "", edWin := ""
global chkTop := "", statusTxt := "", recBtn := "", logBox := ""
global hkStart := "", hkStop := "", hkRecord := "", keybindStatus := ""
; Read-only shortcut chips shown in the title/header area on every page.
global headerKeybindPic := ""
; Prevent programmatic resets of hotkey fields from causing a save callback.
global UpdatingHotkeyFields := false
; Live hotkeys and the previously registered shortcuts (both held by the macro module).
global ActionHotkeys := Map("start", "F5", "stop", "F8", "record", "F7")
global InstalledActionHotkeys := Map()

; When the main app is compiled, bundle the icon and export-player source
; inside the executable so a user can distribute one PhantomMacro.exe.
; FileInstall's source must be a literal for Ahk2Exe to embed it.
if A_IsCompiled {
    DirCreate AppSupportDir
    FileInstall "PhantomMacro.ico", AppIconPath, 1
    FileInstall "PlayerTemplate.ahk", PlayerTemplatePath, 1
}
DirCreate PresetDir
; The icon is local; PhantomMacro no longer contacts GitHub for updates.
if FileExist(AppIconPath) {
    try TraySetIcon(AppIconPath)
}
OnExit ReleaseMacroIcons
InitGuiState()
LoadActionHotkeySettings()
BuildGui()
OnMessage(0x201, DragWindow)   ; Drag the window using empty space.
OnMessage(0x200, NavMouseMove)  ; Sidebar hover.
OnMessage(0x200, UiHoverMouseMove) ; Action and dialog button hover.
InitRecorderHotkeys()
InitActionHotkeys()

; Include implementation of GUI and macro in this SAME AutoHotkey process.
; Use this entrypoint, not GUI.ahk or Macro.ahk.
#Include %A_ScriptDir%\GUI.ahk
#Include %A_ScriptDir%\Macro.ahk
#Include %A_ScriptDir%\ExportManager.ahk
