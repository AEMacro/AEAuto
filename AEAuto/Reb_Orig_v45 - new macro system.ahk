; ======================================================================================================================
; SCRIPT:           Reb_Orig_v46 - Modular Macro System (Fixed)
; DESCRIPTION:      A multi-purpose tool featuring a key presser, autoclicker, and a modular macro system that
;                   loads and runs external macro files from a 'macros' sub-folder.
; VERSION:          46.16 (Fixed)
; AUTHOR:           Gemini (Fixed by Assistant)
;
; --- HOTKEYS ---
;   PgUp            - Toggles the Key Presser on/off.
;   PgDn            - Toggles the Autoclicker on/off.
;   F10             - Toggles the currently selected Macro on/off.
;   F9              - Triggers the 'Reject' action for the current macro (if supported).
;   Home            - Start/Stop Mouse Recording.
;   End             - Start/Stop Playback of recorded actions.
;   Enter           - Toggles Pause/Resume. Double-press to resync.
;   F11             - Opens the configuration window for the selected macro.
;   F12             - Exits the script completely.
; ======================================================================================================================

; --- SCRIPT SETTINGS ---
#SingleInstance Force
#Warn ; Enable warnings to catch potential errors.
CoordMode("Mouse", "Screen")
SetWorkingDir(A_ScriptDir) ; Ensures file operations are relative to the script's location

; --- VERSION CHECK ---
try {
    VerCompare("2.0", "1.0")
} catch {
    MsgBox("This script requires AutoHotkey v2.0 or later.", "Version Error", 48)
    ExitApp
}

; --- INITIALIZE GLOBAL VARIABLES BEFORE INCLUDES ---
global g_MacroClassesToLoad := [] ; MUST be initialized before includes

; --- MACRO INCLUDES ---
; Check if macros folder exists
macrosPath := A_ScriptDir . "\macros"
if !DirExist(macrosPath) {
    MsgBox("The 'macros' folder was not found at:`n" . macrosPath . "`n`nPlease create it and add your macro files.", "Macros Folder Missing", 48)
    ExitApp
}

; Include macro files
try {
    #Include macros\dtm_quest.ahk
    #Include macros\easy_guide_setup.ahk
} catch as e {
    MsgBox("Failed to include a macro file.`n`nError: " . e.Message . "`nFile: " . e.File . "`nLine: " . e.Line, "Macro Include Error", 48)
    ExitApp
}

; --- GLOBAL VARIABLES ---
global isKeyPressToggled := false
global isClickerToggled := false
global isMacroToggled := false
global isPaused := false
global isRecording := false
global isPlayingBack := false
global CurrentKeyDelay := 500
global CurrentClickDelay := 500
global CurrentTransparency := 220
global keyPressStartTime := 0
global clickerStartTime := 0
global macroStartTime := 0
global lastEnterPress := 0

; --- STATISTICS ---
global totalClicks := 0
global totalKeyPresses := 0
global totalMacroRuns := 0
global sessionStartTime := A_TickCount

; --- MOUSE RECORDING ---
global recordedActions := []

; --- MODULAR MACRO SYSTEM ---
global g_Macros := Map()
global g_CurrentMacro := ""
global g_MacroFolder := A_ScriptDir . "\macros"

; --- GUI CREATION ---
global MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "Multi-Tool v46.16")
MyGui.BackColor := "222222"
MyGui.SetFont("s10 cFFFFFF", "Verdana")

; Main status displays
global KeypressStatusText := MyGui.Add("Text", "x10 y10 w280 h20", "Keypress: OFF")
global ClickerStatusText := MyGui.Add("Text", "x10 y35 w280 h20", "Autoclick: OFF")
global MacroStatusText := MyGui.Add("Text", "x10 y60 w280 h20", "Macro: No macro loaded")
global RecorderStatusText := MyGui.Add("Text", "x10 y85 w280 h20", "Recorder: Ready")
global PauseStatusText := MyGui.Add("Text", "x10 y110 w280 Center cYellow", "PAUSED")
PauseStatusText.Visible := false
global ResyncText := MyGui.Add("Text", "x10 y110 w280 Center cLime", "RESYNCED!")
ResyncText.Visible := false

; Macro control section
MyGui.Add("Text", "x10 y140 w100", "Select Macro:")
global MacroDropdown := MyGui.Add("DropDownList", "x10 y160 w195 vSelectedMacro", ["No macros found"])
global ReloadMacrosBtn := MyGui.Add("Button", "x215 y160 w75 h23", "Reload")
ReloadMacrosBtn.OnEvent("Click", (*) => LoadMacros())

; Macro status display
global MacroActionText := MyGui.Add("Text", "x10 y190 w280 Center cLime", "Macro Action: Idle")
MacroActionText.Visible := false

; Control buttons
global OptionsButton := MyGui.Add("Button", "x10 y220 w85 h25", "Options")
global HotkeysButton := MyGui.Add("Button", "x105 y220 w85 h25", "Hotkeys")
global StatsButton := MyGui.Add("Button", "x200 y220 w90 h25", "Statistics")

; --- OPTIONS SECTION (Collapsible) ---
global OptionsGroup := MyGui.Add("GroupBox", "x5 y255 w290 h150", "Options")
OptionsGroup.Visible := false
global OptKeyDelayLabel := MyGui.Add("Text", "x15 y280 cSilver", "Key Delay (ms):")
OptKeyDelayLabel.Visible := false
global KeyDelaySlider := MyGui.Add("Slider", "x15 y300 w200 vCurrentKeyDelay Range40-2500 ToolTip", CurrentKeyDelay)
KeyDelaySlider.Visible := false
global KeyDelayText := MyGui.Add("Text", "x220 y300 w60 cWhite", CurrentKeyDelay . "ms")
KeyDelayText.Visible := false
global OptClickDelayLabel := MyGui.Add("Text", "x15 y325 cSilver", "Click Delay (ms):")
OptClickDelayLabel.Visible := false
global ClickDelaySlider := MyGui.Add("Slider", "x15 y345 w200 vCurrentClickDelay Range40-2500 ToolTip", CurrentClickDelay)
ClickDelaySlider.Visible := false
global ClickDelayText := MyGui.Add("Text", "x220 y345 w60 cWhite", CurrentClickDelay . "ms")
ClickDelayText.Visible := false
global OptOpacityLabel := MyGui.Add("Text", "x15 y370 cSilver", "GUI Opacity:")
OptOpacityLabel.Visible := false
global TransSlider := MyGui.Add("Slider", "x15 y390 w200 vCurrentTransparency Range50-255 ToolTip", CurrentTransparency)
TransSlider.Visible := false
global TransText := MyGui.Add("Text", "x220 y390 w60 cWhite", CurrentTransparency)
TransText.Visible := false

; --- HOTKEYS SECTION (Collapsible) ---
global HotkeysGroup := MyGui.Add("GroupBox", "x5 y255 w290 h210", "Hotkeys")
HotkeysGroup.Visible := false
global HotkeyLabels := []
HotkeyLabels.Push(MyGui.Add("Text", "x15 y280 cSilver", "PgUp: Toggle Keypress"))
HotkeyLabels.Push(MyGui.Add("Text", "x15 y300 cSilver", "PgDn: Toggle Autoclicker"))
HotkeyLabels.Push(MyGui.Add("Text", "x15 y320 cSilver", "F10: Toggle Selected Macro"))
HotkeyLabels.Push(MyGui.Add("Text", "x15 y340 cSilver", "F9: Reject Macro Quest"))
HotkeyLabels.Push(MyGui.Add("Text", "x15 y360 cSilver", "Home/End: Record/Play"))
HotkeyLabels.Push(MyGui.Add("Text", "x15 y380 cSilver", "Enter: Pause (2x = Resync)"))
HotkeyLabels.Push(MyGui.Add("Text", "x15 y400 cSilver", "F11: Configure Macro"))
HotkeyLabels.Push(MyGui.Add("Text", "x15 y420 cSilver", "F12: Exit Program"))
for label in HotkeyLabels {
    label.Visible := false
}

; --- STATISTICS SECTION (Collapsible) ---
global StatsGroup := MyGui.Add("GroupBox", "x5 y255 w290 h140", "Statistics")
StatsGroup.Visible := false
global SessionTimeText := MyGui.Add("Text", "x15 y280 w270 cSilver", "Session Time: 0s")
SessionTimeText.Visible := false
global TotalClicksText := MyGui.Add("Text", "x15 y300 w270 cSilver", "Total Clicks: 0")
TotalClicksText.Visible := false
global TotalKeysText := MyGui.Add("Text", "x15 y320 w270 cSilver", "Keys Pressed: 0")
TotalKeysText.Visible := false
global MacroRunsText := MyGui.Add("Text", "x15 y340 w270 cSilver", "Macro Runs: 0")
MacroRunsText.Visible := false
global ResetStatsBtn := MyGui.Add("Button", "x95 y365 w120 h25", "Reset Stats")
ResetStatsBtn.Visible := false
ResetStatsBtn.OnEvent("Click", ResetStats)

; --- EVENT BINDINGS ---
OptionsButton.OnEvent("Click", (*) => ToggleSection("options"))
HotkeysButton.OnEvent("Click", (*) => ToggleSection("hotkeys"))
StatsButton.OnEvent("Click", (*) => ToggleSection("stats"))
KeyDelaySlider.OnEvent("Change", UpdateKeyDelay)
ClickDelaySlider.OnEvent("Change", UpdateClickDelay)
TransSlider.OnEvent("Change", UpdateTransparency)
MacroDropdown.OnEvent("Change", SelectMacro)
MyGui.OnEvent("Close", (*) => ExitApp())
OnMessage(0x201, GuiDrag)

; --- INITIALIZATION ---
MyGui.Show("w300 h255")
WinSetTransparent(CurrentTransparency, MyGui.Hwnd)
SetTimer(UpdateGuiDisplay, 250)
LoadMacros() ; Initial load of macros

; --- HOTKEY DEFINITIONS ---
PgUp::ToggleKeyPresser()
PgDn::ToggleClicker()
F10::ToggleMacro()
F9::RejectMacro()
Home::ToggleMouseRecording()
End::TogglePlayback()
~Enter::HandleEnterKey()
F11::ConfigureMacro()
F12::ExitApp

; ======================================================================================================================
;                                               CORE LOGIC
; ======================================================================================================================

; --- MACRO MANAGEMENT ---
LoadMacros() {
    global
    g_Macros.Clear()
    MacroDropdown.Delete()

    if IsSet(g_MacroClassesToLoad) and g_MacroClassesToLoad.Length > 0 {
        for ClassType in g_MacroClassesToLoad {
            instance := ClassType()
            g_Macros[instance.Name] := instance
        }
    }

    if g_Macros.Count = 0 {
        MacroDropdown.Add(["No macros found"])
        if !DirExist(g_MacroFolder) {
            DirCreate(g_MacroFolder)
        }
    } else {
        macroList := []
        for name, macro in g_Macros {
            macroList.Push(name)
        }
        MacroDropdown.Add(macroList)
    }
    
    MacroDropdown.Choose(1)
    SelectMacro()
    PlaySound("success")
}

SelectMacro(*) {
    global
    selectedName := MacroDropdown.Text
    if g_Macros.Has(selectedName) {
        g_CurrentMacro := g_Macros[selectedName]
        MacroStatusText.Opt("cWhite")
        MacroStatusText.Text := "Macro: " . g_CurrentMacro.Name . " (Ready)"
    } else {
        g_CurrentMacro := ""
        MacroStatusText.Opt("cRed")
        MacroStatusText.Text := "Macro: Not loaded"
    }
}

ToggleMacro() {
    global
    if !IsObject(g_CurrentMacro) {
        MsgBox "Please select a valid macro from the dropdown list first.", "No Macro Selected", 48
        Return
    }

    isMacroToggled := !isMacroToggled
    if (isMacroToggled) {
        macroStartTime := A_TickCount
        g_CurrentMacro.Start()
        MacroActionText.Visible := true
        PlaySound("success")
        if (!isPaused) {
            SetTimer(RunMacroLoop, -100)
        }
    } else {
        g_CurrentMacro.Stop()
        macroStartTime := 0
        MacroActionText.Visible := false
        PlaySound("error")
        SetTimer(RunMacroLoop, 0)
        MacroStatusText.Text := "Macro: " . g_CurrentMacro.Name . " (Stopped)"
    }
}

RunMacroLoop() {
    global
    if (!isMacroToggled || isPaused || !IsObject(g_CurrentMacro)) {
        Return
    }

    action := g_CurrentMacro.GetNextAction()

    if !IsObject(action) {
        SetTimer(RunMacroLoop, 0)
        ToggleMacro()
        MacroStatusText.Text := "Macro: " . g_CurrentMacro.Name . " (Finished)"
        totalMacroRuns++
        Return
    }

    MacroActionText.Text := action.HasProp("infoText") ? action.infoText : "Executing..."
    
    switch action.type {
        case "click":
            HumanizedClick(action.x, action.y)
            totalClicks++
        case "info":
            ; Just an info update
        case "end_run":
            totalMacroRuns++
    }

    nextWait := action.HasProp("wait") ? action.wait : 1000
    if (isMacroToggled && !isPaused) {
        SetTimer(RunMacroLoop, -nextWait)
    }
}

RejectMacro() {
    global
    if (isMacroToggled && IsObject(g_CurrentMacro) && g_CurrentMacro.HasMethod("Reject")) {
        g_CurrentMacro.Reject()
        PlaySound("warning")
        if (!isPaused) {
            SetTimer(RunMacroLoop, -100)
        }
    }
}

ConfigureMacro() {
    global
    if (IsObject(g_CurrentMacro) && g_CurrentMacro.HasMethod("ShowConfigGui")) {
        g_CurrentMacro.ShowConfigGui()
    } else {
        MsgBox "The selected macro does not have a configuration window.", "No Configuration", 64
    }
}

; --- ACTION TOGGLES ---
ToggleKeyPresser(*) {
    global
    isKeyPressToggled := !isKeyPressToggled
    if (isKeyPressToggled) {
        keyPressStartTime := A_TickCount
        PlaySound("success")
        if (!isPaused) {
            SetTimer(PressTheKey, -CurrentKeyDelay)
        }
    } else {
        keyPressStartTime := 0
        PlaySound("error")
        SetTimer(PressTheKey, 0)
    }
}

ToggleClicker(*) {
    global
    isClickerToggled := !isClickerToggled
    if (isClickerToggled) {
        clickerStartTime := A_TickCount
        PlaySound("success")
        if (!isPaused) {
            SetTimer(ClickTheMouse, -CurrentClickDelay)
        }
    } else {
        clickerStartTime := 0
        PlaySound("error")
        SetTimer(ClickTheMouse, 0)
    }
}

; --- ACTION LOOPS ---
PressTheKey() {
    global
    if (!isKeyPressToggled || isPaused) {
        Return
    }
    Send("{``}")
    totalKeyPresses++
    SetTimer(PressTheKey, -CurrentKeyDelay)
}

ClickTheMouse() {
    global
    if (!isClickerToggled || isPaused) {
        Return
    }
    Click()
    totalClicks++
    SetTimer(ClickTheMouse, -CurrentClickDelay)
}

; --- PAUSE & RESYNC ---
HandleEnterKey() {
    global
    currentTime := A_TickCount
    if (currentTime - lastEnterPress < 300) { ; Double press
        isPaused := false
        PauseStatusText.Visible := false
        ResyncText.Visible := true
        SetTimer(() => ResyncText.Visible := false, -1000)
        PlaySound("resync")
        if (isKeyPressToggled) {
            SetTimer(PressTheKey, -CurrentKeyDelay)
        }
        if (isClickerToggled) {
            SetTimer(ClickTheMouse, -CurrentClickDelay)
        }
        if (isMacroToggled) {
            SetTimer(RunMacroLoop, -100)
        }
        lastEnterPress := 0
    } else { ; Single press
        isPaused := !isPaused
        PauseStatusText.Visible := isPaused
        if (isPaused) {
            PlaySound("warning")
            SetTimer(PressTheKey, 0)
            SetTimer(ClickTheMouse, 0)
            SetTimer(RunMacroLoop, 0)
        } else {
            PlaySound("info")
            if (isKeyPressToggled) {
                SetTimer(PressTheKey, -CurrentKeyDelay)
            }
            if (isClickerToggled) {
                SetTimer(ClickTheMouse, -CurrentClickDelay)
            }
            if (isMacroToggled) {
                SetTimer(RunMacroLoop, -100)
            }
        }
    }
    lastEnterPress := currentTime
}

; --- MOUSE RECORDING (Simplified) ---
ToggleMouseRecording(*) {
    global
    isRecording := !isRecording
    RecorderStatusText.Text := isRecording ? "Recorder: RECORDING" : "Recorder: Ready"
    RecorderStatusText.Opt(isRecording ? "cRed" : "cWhite")
    if (isRecording) {
        recordedActions := []
        PlaySound("success")
    } else {
        PlaySound("info")
    }
}

TogglePlayback() => MsgBox("Playback not implemented in this version.", "Info", 64)

; --- GUI & UPDATE FUNCTIONS ---
UpdateGuiDisplay() {
    global
    if (isKeyPressToggled) {
        KeypressStatusText.Opt("cLime")
        KeypressStatusText.Text := "Keypress: ON (" . FormatTime((A_TickCount - keyPressStartTime) / 1000) . ")"
    } else {
        KeypressStatusText.Opt("cWhite")
        KeypressStatusText.Text := "Keypress: OFF"
    }
    if (isClickerToggled) {
        ClickerStatusText.Opt("cLime")
        ClickerStatusText.Text := "Autoclick: ON (" . FormatTime((A_TickCount - clickerStartTime) / 1000) . ")"
    } else {
        ClickerStatusText.Opt("cWhite")
        ClickerStatusText.Text := "Autoclick: OFF"
    }
    if (isMacroToggled) {
        MacroStatusText.Opt("cLime")
        MacroStatusText.Text := "Macro: " . g_CurrentMacro.Name . " (" . FormatTime((A_TickCount - macroStartTime) / 1000) . ")"
    } else if IsObject(g_CurrentMacro) {
        MacroStatusText.Opt("cWhite")
        MacroStatusText.Text := "Macro: " . g_CurrentMacro.Name . " (Stopped)"
    }
    if (StatsGroup.Visible) {
        SessionTimeText.Text := "Session Time: " . FormatTime((A_TickCount - sessionStartTime) / 1000)
        TotalClicksText.Text := "Total Clicks: " . totalClicks
        TotalKeysText.Text := "Keys Pressed: " . totalKeyPresses
        MacroRunsText.Text := "Macro Runs: " . totalMacroRuns
    }
}

UpdateKeyDelay(SliderObj, *) {
    global
    CurrentKeyDelay := SliderObj.Value
    KeyDelayText.Text := CurrentKeyDelay . "ms"
}

UpdateClickDelay(SliderObj, *) {
    global
    CurrentClickDelay := SliderObj.Value
    ClickDelayText.Text := CurrentClickDelay . "ms"
}

UpdateTransparency(SliderObj, *) {
    global
    CurrentTransparency := SliderObj.Value
    TransText.Text := CurrentTransparency
    WinSetTransparent(CurrentTransparency, MyGui.Hwnd)
}

ToggleSection(section) {
    global
    
    ; Check if the section is already visible
    wasVisible := false
    switch section {
        case "options":
            wasVisible := OptionsGroup.Visible
        case "hotkeys":
            wasVisible := HotkeysGroup.Visible
        case "stats":
            wasVisible := StatsGroup.Visible
    }
    
    ; Hide all sections
    HideAllSections()
    
    ; If the section wasn't visible, show it
    if !wasVisible {
        switch section {
            case "options":
                ShowOptionsSection()
                MyGui.Move(,,300, 430)  ; Increased height to show all options
            case "hotkeys":
                ShowHotkeysSection()
                MyGui.Move(,,300, 475)  ; Adjusted height for hotkeys
            case "stats":
                ShowStatsSection()
                MyGui.Move(,,300, 405)  ; Adjusted height for stats
        }
    } else {
        ; Return to default size
        MyGui.Move(,,300, 255)
    }
}

HideAllSections() {
    global
    ; Hide Options
    OptionsGroup.Visible := false
    OptKeyDelayLabel.Visible := false
    KeyDelaySlider.Visible := false
    KeyDelayText.Visible := false
    OptClickDelayLabel.Visible := false
    ClickDelaySlider.Visible := false
    ClickDelayText.Visible := false
    OptOpacityLabel.Visible := false
    TransSlider.Visible := false
    TransText.Visible := false
    
    ; Hide Hotkeys
    HotkeysGroup.Visible := false
    for label in HotkeyLabels {
        label.Visible := false
    }
    
    ; Hide Stats
    StatsGroup.Visible := false
    SessionTimeText.Visible := false
    TotalClicksText.Visible := false
    TotalKeysText.Visible := false
    MacroRunsText.Visible := false
    ResetStatsBtn.Visible := false
}

ShowOptionsSection() {
    global
    OptionsGroup.Visible := true
    OptKeyDelayLabel.Visible := true
    KeyDelaySlider.Visible := true
    KeyDelayText.Visible := true
    OptClickDelayLabel.Visible := true
    ClickDelaySlider.Visible := true
    ClickDelayText.Visible := true
    OptOpacityLabel.Visible := true
    TransSlider.Visible := true
    TransText.Visible := true
}

ShowHotkeysSection() {
    global
    HotkeysGroup.Visible := true
    for label in HotkeyLabels {
        label.Visible := true
    }
}

ShowStatsSection() {
    global
    StatsGroup.Visible := true
    SessionTimeText.Visible := true
    TotalClicksText.Visible := true
    TotalKeysText.Visible := true
    MacroRunsText.Visible := true
    ResetStatsBtn.Visible := true
}

ResetStats(*) {
    global
    if MsgBox("Reset all statistics?", "Confirm Reset", 36) = "Yes" {
        totalClicks := 0
        totalKeyPresses := 0
        totalMacroRuns := 0
        sessionStartTime := A_TickCount
        PlaySound("error")
    }
}

; --- UTILITY FUNCTIONS ---
GuiDrag(*) => PostMessage(0xA1, 2)

PlaySound(type) {
    try {
        switch type {
            case "error": SoundPlay("*16")
            case "success": SoundPlay("*64")
            case "warning": SoundPlay("*48")
            case "info": SoundPlay("*64")
            case "resync": 
                SoundPlay("*64")
                Sleep(60)
                SoundPlay("*64")
        }
    }
}

FormatTime(totalSeconds) {
    h := Floor(totalSeconds / 3600)
    m := Floor(Mod(totalSeconds, 3600) / 60)
    s := Floor(Mod(totalSeconds, 60))
    return (h > 0 ? h . "h " : "") . (m > 0 ? Format("{:02d}m ", m) : "") . Format("{:02d}s", s)
}

HumanizedClick(x, y) {
    offsetX := Random(-2, 2)
    offsetY := Random(-2, 2)
    moveTime := Random(50, 150)
    MouseMove(x + offsetX, y + offsetY, moveTime)
    Sleep(Random(40, 90))
    Click()
    Sleep(Random(50, 100))
}