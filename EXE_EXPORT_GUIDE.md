# PhantomMacro — How to export a macro as an EXE

PhantomMacro's **EXPORT EXE** feature turns a saved recording into a standalone Windows program. People running that exported EXE **do not need AutoHotkey installed**.

To **create** an EXE, the exporting computer needs two free tools: **AutoHotkey v2** and its **Ahk2Exe** compiler.

## 1. Install the compiler

1. Visit the official AutoHotkey website: **https://www.autohotkey.com/**.
2. Download and install **AutoHotkey v2** for Windows.
3. Open the Windows Start menu and launch **AutoHotkey** (the **AutoHotkey Dash**).
4. Select **Compile**. If Ahk2Exe is not installed, choose the option to download and install it.
5. Once installed, close and reopen PhantomMacro if it was already running.

Official AutoHotkey documentation: https://www.autohotkey.com/docs/v2/Scripts.htm#ahk2exe

> You only need to do this on a PC that **creates** standalone macro EXEs. It is not required to use a precompiled copy of PhantomMacro for regular recording and playback.

## 2. Record or choose a macro

1. In PhantomMacro, open **Settings → Pick EXE**.
2. Right-click the target application's window to select it.
3. Go to **RUN** and choose a saved recording, or make a new one with **Record** (**F7** by default).
4. Stop the recording with **F7**. It will be saved to your `presets` folder.

## 3. Build the EXE

1. On the **RUN** page, select your saved recording and click **EXPORT EXE**.
2. Enter the filename you want for the new program.
3. Choose its starting **Loops** and **Speed** values:
   - **1 loop:** run once (recommended).
   - **0 loops:** repeat until stopped.
   - **1.0 speed:** normal recorded timing; **2.0:** faster; **0.5:** slower.
4. Optionally enable **Start playback when the EXE opens**.
5. Choose **Keep exported EXE above other windows** if you want the player to remain on top.
6. Review the Start and Stop hotkeys shown in the dialog; they come from your current PhantomMacro settings.
7. Click **Build EXE**, choose a save location, and confirm.

PhantomMacro will compile the recording and display the location of the created `.exe`.

## 4. Use the exported EXE

Open the saved EXE. Its **RUN-only** interface includes **Start**, **Stop**, **Focus target application**, and **Loops / Speed** controls.

- The macro, theme, target application, and Start/Stop hotkeys are built into the EXE.
- You can adjust loops and speed while playback is stopped.
- Loop and speed changes made **inside** the exported player reset to the exported defaults when you close it.
- Recipients don't need to install AutoHotkey or Ahk2Exe to **run** the exported EXE.

## If PhantomMacro can't find Ahk2Exe

Ensure you installed **AutoHotkey v2** and opened **AutoHotkey Dash → Compile** to install the compiler.

If PhantomMacro asks you to locate the files, browse to the installed copies. Typical Windows paths are:

**Ahk2Exe compiler:**

```text
C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe
```

**AutoHotkey v2 base interpreter:**

```text
C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe
```

For a per-user installation, they may be under:

```text
%LOCALAPPDATA%\Programs\AutoHotkey\
```

Choose the **AutoHotkey v2** base executable, **not `PhantomMacro.exe`**. If the files aren't at those locations, use the folders where you installed AutoHotkey.

**Official download and setup:** https://www.autohotkey.com/
