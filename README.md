# PhantomMacro

**PhantomMacro** is an offline Windows macro recorder and player. Record mouse and keyboard actions in a chosen application, save them as reusable presets, control how they play back, and export a recording as a standalone Windows executable.

Designed for a straightforward workflow: **pick an application → record → save → play or export**.

For the compiled Windows app, open the **Releases** section of this GitHub repository and download the latest `PhantomMacro.exe` release.

## Features

- **Mouse and keyboard recording** — captures pointer movement, mouse button presses and releases, dragging, scrolling, key presses and releases, and timing between actions.
- **Application-specific recording and playback** — choose a target Windows application. Recording captures input while that application is active, and playback stops if it loses focus.
- **Reusable presets** — recordings are saved as editable `.txt` files. Select a preset, reload the list, edit it in Notepad, or open your preset folder.
- **Playback controls** — start, stop, repeat a recording, and change its playback speed. Stopping also releases any keys or mouse buttons held by the macro.
- **Custom shortcuts** — rebind Start, Stop, and Record, including combinations with Ctrl, Alt, or Shift.
- **Built-in pixel tool** — pick a screen colour and position to help create a `waitpixel` step in a preset.
- **Four interface themes** — Crimson, Ammo Lead, Cherry Blossom, and Phantom.
- **Always on Top** — optionally keep the PhantomMacro window above other windows.
- **Standalone EXE export** — package a recording, its target, the current theme, selected hotkeys, and playback options into a separate Windows `.exe`.
- **Local-first operation** — no account or internet connection is needed to record or play macros.

## Getting started

1. **Open PhantomMacro** on Windows.
2. Go to **Settings** and choose **Pick EXE**. Right-click the window of the application you want to automate; PhantomMacro will select its executable. You can also enter the target manually.
3. Return to **RUN**, then click **Record** (default hotkey **F7**).
4. Switch to your chosen application and perform the actions you want to capture.
5. Press **F7** again, or use **Stop Rec**, to finish recording. PhantomMacro saves the recording automatically in the `presets` folder.
6. Select the recording in the **RUN** dropdown. Use **Reload** if necessary.
7. Set the **Loops** and **Speed** values, then click **Start** (default **F5**). Use **Stop** (default **F8**) to end playback at any time.

> **Loop safety:** New installations default to **1 loop**. A loop count of **0** means repeat indefinitely, so choose it only when intended.

## Playback options

| Setting | What it does |
| --- | --- |
| **Loops: 1** | Play the selected recording once (default). |
| **Loops: 2, 3, ...** | Repeat the recording the specified number of times. |
| **Loops: 0** | Keep repeating until you stop it. |
| **Speed: 1.0** | Replay recorded timing at normal speed. |
| **Speed: 2.0** | Replay timed actions at approximately twice the speed. |
| **Speed: 0.5** | Replay timed actions at approximately half the speed. |

Playback uses the selected target application; PhantomMacro attempts to focus it when playback starts. It does not continue sending recorded input to unrelated applications if the target loses focus.

## Default keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| **F5** | Start playback |
| **F8** | Stop playback |
| **F7** | Start / stop recording |
| **F9** | Pick a pixel and copy a `waitpixel` instruction |

Change **Start**, **Stop**, and **Record** in **Settings → Macro Keybinds**. These assignments are saved and can include modifier keys. **F9** is reserved for the pixel picker.

## Settings and tools

In **Settings**, you can:

- Pick or enter the target application's `.exe`.
- Toggle **Keep this window on top**.
- Rebind and reset the three primary macro shortcuts.
- Use **Open folder** to access saved recordings.
- Use **Edit preset** to edit the selected recording in Notepad.
- Use **Pick pixel** for an advanced wait condition.

The **THEMES** tab lets you switch between Crimson, Ammo Lead, Cherry Blossom, and Phantom. Your selected theme is remembered.

### Advanced presets: waiting for a pixel

The pixel picker copies a line in this format to your clipboard:

```text
waitpixel <x> <y> <colour> <timeout-ms> <tolerance>
```

To use it, move the cursor over the desired position, press **F9** (or click **Pick pixel**), then open **Edit preset** and paste the copied line at the point where playback should wait. Save the preset before playing it again. The coordinates are relative to the target application's client area.

Presets also support individual movement, mouse button, scroll, keyboard, click, and wait instructions. Recordings are plain-text files, so they can be inspected and customized.

## Export a recording as a standalone EXE

PhantomMacro can convert your selected preset into its own Windows program with a simplified **RUN-only** player.

1. Select the target application and the preset you want to export.
2. Click **EXPORT EXE** on the **RUN** page.
3. Choose an **EXE name**, **Loops**, and **Speed**.
4. Optionally select **Start playback when the EXE opens**.
5. Choose whether the exported player should **stay above other windows**. This option initially matches the main app's Always on Top setting.
6. Click **Build EXE** and choose where to save the file.
7. Open the resulting `.exe` to run the recording.

The exported player includes:

- The recorded actions and selected target application.
- The theme that was selected when exporting.
- Your current **Start** and **Stop** hotkeys.
- **Start**, **Stop**, and **Focus target application** buttons.
- Loop count and playback speed controls.
- Optional auto-start and Always on Top behaviour.

**Inside the exported player**, you can adjust loops and speed while stopped. Those changes are temporary: closing and reopening the EXE restores the values chosen when it was exported.

### Requirements for creating an exported EXE

**Exporting requires AutoHotkey v2 and the Ahk2Exe compiler on the computer doing the export.** PhantomMacro does not include these tools. They are **not** required just to run a precompiled PhantomMacro application or an already-exported macro EXE.

Install them from the official site: **https://www.autohotkey.com/**

After installing AutoHotkey **v2**, open **AutoHotkey Dash → Compile**. If Ahk2Exe is not installed, the dashboard offers to download and install it. Then return to PhantomMacro and use **EXPORT EXE**.

For step-by-step setup, paths to the compiler files, and export instructions, see **[EXE Export Guide](EXE_EXPORT_GUIDE.md)**.

## Where your files are stored

PhantomMacro keeps its data locally, beside the program:

```text
PhantomMacro.exe
settings.ini       ← Your settings and keybinds
presets/           ← Your saved recordings (.txt)
```

Place PhantomMacro in a folder where Windows allows it to create and update these files.

## Requirements

- **Windows** computer.
- A compiled `PhantomMacro.exe` to use the app without installing AutoHotkey.
- **AutoHotkey v2 + Ahk2Exe only if you want to create standalone macro EXEs** using the in-app exporter.

The exported macro's recipient does **not** need AutoHotkey installed, although the application targeted by the recording must be available.


## Licence and source code

PhantomMacro's original project contributions are released by **Phantomskullzz** under the **GNU General Public License version 2.0 (GPL-2.0-only)**. See [LICENSE.md](LICENSE.md). The compiled application contains the AutoHotkey runtime, which is third-party software with its own copyright holders and licensing terms; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

The source code corresponding to a GPL-covered published EXE must be made available under the applicable GPL terms. The official project is maintained by **Phantomskullzz**; sharing and modifying under the GPL does not make a modified version an official PhantomMacro release.
