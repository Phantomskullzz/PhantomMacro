#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon

; Headless Windows regression test for version parsing and hidden gh commands.
global testLog := A_ScriptDir "\updater-test-status.txt"
try FileDelete testLog
OnError CIUnexpectedError
FileAppend "Begin test`n", testLog, "UTF-8"
SetTimer (*) => CIQuit(98, "Async runner timed out"), -18000

try {
    CIAssert(ParseGitHubExitCode("0") = 0, "Exit code zero")
    CIAssert(ParseGitHubExitCode(Chr(0xFEFF) "  0`r`n") = 0, "UTF-8 BOM / whitespace")
    CIAssert(ParseGitHubExitCode("12`r`n") = 12, "Nonzero exit code")
    invalidRejected := false
    try ParseGitHubExitCode("not-a-number")
    catch
        invalidRejected := true
    CIAssert(invalidRejected, "Invalid completion marker rejected")

    rel := ReadLatestReleaseJson('{"tagName":"v0.3.7","body":"Note`nSecond"}')
    CIAssert(rel["version"] = "0.3.7", "Version parsing")
    CIAssert(InStr(rel["notes"], "Note"), "Release notes parsing")
    FileAppend "Parsing passed`n", testLog, "UTF-8"
    StartGitHubCommandAsync("--version", CIGitHubVersion, 10000)
} catch as e {
    CIQuit(11, "Parse/launch error: " e.Message)
}

CIAssert(ok, name) {
    if !ok
        throw Error("Failed: " name)
}

CIGitHubVersion(code, output, errors) {
    try {
        CIAssert(code = 0, "gh --version exit code: " code " / " errors)
        CIAssert(InStr(output, "gh version") > 0, "gh --version output: " output)
        FileAppend "Hidden gh --version passed`n", testLog, "UTF-8"
        StartGitHubCommandAsync("phantom-macro-intentionally-invalid-command", CIInvalidCommand, 10000)
    } catch as e {
        CIQuit(21, e.Message)
    }
}

CIInvalidCommand(code, output, errors) {
    try {
        CIAssert(code != 0, "Bad command exit code should not be success")
        CIAssert(StrLen(errors) > 0, "Bad command must report stderr")
        FileAppend "Hidden error path passed`n", testLog, "UTF-8"
        CIQuit(0, "PASS")
    } catch as e {
        CIQuit(22, e.Message)
    }
}

CIUnexpectedError(error, mode) {
    CIQuit(99, "Unhandled: " error.Message " at " error.File ":" error.Line)
    return true
}

CIQuit(code, message) {
    global testLog
    try FileAppend message "`n", testLog, "UTF-8"
    ExitApp code
}

#Include %A_ScriptDir%\..\UpdateManager.ahk
