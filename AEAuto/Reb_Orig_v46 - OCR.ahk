; ======================================================================================================================
; SCRIPT:           Reb_Orig_v47 - ImageSearch & OCR
; DESCRIPTION:      A multi-purpose tool with a modular macro system that supports coordinates, OCR, and ImageSearch.
; VERSION:          47.3 (Robust Bracing)
; AUTHOR:           Gemini
;
; --- HOTKEYS ---
;   F10             - Toggles the currently selected Macro on/off.
;   F9              - Triggers the 'Reject' action for the current macro (if supported).
;   Enter           - Toggles Pause/Resume. Double-press to resync.
;   F11             - Opens the configuration window for the selected macro.
;   F12             - Exits the script completely.
; ======================================================================================================================

; --- SCRIPT SETTINGS ---
#SingleInstance Force
#Warn
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen" ; Important for ImageSearch and OCR
SetWorkingDir A_ScriptDir

; --- INITIALIZE GLOBAL VARS & LIBRARIES ---
global g_MacroClassesToLoad := []
try {
    #Include OCR.ahk ; Include the OCR library
} catch {
    MsgBox "Could not find OCR.ahk. Please ensure it's in the same directory.", "Library Missing", 48
    ExitApp
}

; --- FOLDER SETUP ---
macrosPath := A_ScriptDir . "\macros"
imagesPath := A_ScriptDir . "\images"
if !DirExist(macrosPath) {
    DirCreate(macrosPath)
}
if !DirExist(imagesPath) {
    DirCreate(imagesPath)
}

; --- MACRO INCLUDES ---
try {
    #Include macros\dtm_quest_image_search.ahk
    ; #Include macros\your_other_macros.ahk
} catch as e {
    MsgBox "Failed to include a macro file.`n`nError: " . e.Message, "Macro Include Error", 48
    ExitApp
}

; --- GLOBAL VARIABLES ---
global isMacroToggled := false, isPaused := false
global macroStartTime := 0, lastEnterPress := 0
global totalClicks := 0, totalMacroRuns := 0, sessionStartTime := A_TickCount
global g_Macros := Map(), g_CurrentMacro := ""

; --- GUI CREATION ---
global MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "Multi-Tool v47.3")
MyGui.BackColor := "222222"
MyGui.SetFont("s10 cFFFFFF", "Verdana")

global MacroStatusText := MyGui.Add("Text", "x10 y10 w280 h20", "Macro: No macro loaded")
global PauseStatusText := MyGui.Add("Text", "x10 y35 w280 Center cYellow", "PAUSED")
PauseStatusText.Visible := false
global ResyncText := MyGui.Add("Text", "x10 y35 w280 Center cLime", "RESYNCED!")
ResyncText.Visible := false

MyGui.Add("Text", "x10 y60 w100", "Select Macro:")
global MacroDropdown := MyGui.Add("DropDownList", "x10 y80 w195 vSelectedMacro", ["No macros found"])
global ReloadMacrosBtn := MyGui.Add("Button", "x215 y80 w75 h23", "Reload")
ReloadMacrosBtn.OnEvent("Click", (*) => LoadMacros())

global MacroActionText := MyGui.Add("Text", "x10 y110 w280 Center cLime", "Macro Action: Idle")
MacroActionText.Visible := false

MyGui.OnEvent("Close", (*) => ExitApp())
OnMessage(0x201, (*) => PostMessage(0xA1, 2))

; --- INITIALIZATION ---
MyGui.Show("w300 h145")
SetTimer UpdateGuiDisplay, 250
LoadMacros()

; --- HOTKEY DEFINITIONS ---
F10::ToggleMacro()
F9::RejectMacro()
~Enter::HandleEnterKey()
F11::ConfigureMacro()
F12::ExitApp

; ======================================================================================================================
;                                               CORE LOGIC
; ======================================================================================================================

LoadMacros() {
    global g_Macros, g_MacroClassesToLoad, MacroDropdown
    g_Macros.Clear()
    MacroDropdown.Delete()

    for ClassType in g_MacroClassesToLoad {
        instance := ClassType()
        g_Macros[instance.Name] := instance
    }

    if g_Macros.Count = 0 {
        MacroDropdown.Add(["No macros found"])
    } else {
        local macroList := []
        for name, macro in g_Macros {
            macroList.Push(name)
        }
        MacroDropdown.Add(macroList)
    }
    
    MacroDropdown.Choose(1)
    SelectMacro()
}

SelectMacro(*) {
    global g_CurrentMacro, MacroDropdown, MacroStatusText
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
    global isMacroToggled, macroStartTime, g_CurrentMacro, MacroActionText
    if !IsObject(g_CurrentMacro) {
        MsgBox "Please select a valid macro first.", "No Macro Selected", 48
        return
    }
    isMacroToggled := !isMacroToggled
    if (isMacroToggled) {
        macroStartTime := A_TickCount
        g_CurrentMacro.Start()
        MacroActionText.Visible := true
        if (!isPaused) {
            SetTimer(RunMacroLoop, -100)
        }
    } else {
        g_CurrentMacro.Stop()
        macroStartTime := 0
        MacroActionText.Visible := false
        SetTimer(RunMacroLoop, 0)
        MacroStatusText.Text := "Macro: " . g_CurrentMacro.Name . " (Stopped)"
    }
}

RunMacroLoop() {
    global isMacroToggled, isPaused, g_CurrentMacro, MacroActionText, totalClicks, totalMacroRuns
    if (!isMacroToggled || isPaused || !IsObject(g_CurrentMacro)) {
        return
    }

    action := g_CurrentMacro.GetNextAction()

    if (!IsObject(action) || action.type = "end_run") {
        if (IsObject(action)) {
            MacroActionText.Text := action.infoText
        }
        totalMacroRuns++
        isMacroToggled := false ; Stop the toggle
        g_CurrentMacro.Stop()
        macroStartTime := 0
        MacroActionText.Visible := false
        SetTimer(RunMacroLoop, 0)
        MacroStatusText.Text := "Macro: " . g_CurrentMacro.Name . " (Finished)"
        return
    }

    MacroActionText.Text := action.HasProp("infoText") ? action.infoText : "Executing..."
    
    try {
        switch action.type {
            case "click":
                HumanizedClick(action.x, action.y)
                totalClicks++
            
            case "ocr":
                ocr_result := OCR.FromWindow(g_CurrentMacro.targetWinTitle).FindString(action.text)
                ocr_result.Click()
                totalClicks++

            case "image":
                imagePath := A_ScriptDir . "\images\" . action.imageFile
                if !FileExist(imagePath) {
                    throw Error("Image file not found: " . action.imageFile)
                }
                if (ImageSearch(&foundX, &foundY, 0, 0, A_ScreenWidth, A_ScreenHeight, imagePath)) {
                    ImageGetSize(imagePath, &w, &h)
                    HumanizedClick(foundX + w/2, foundY + h/2)
                    totalClicks++
                } else {
                    throw Error("Image not found on screen: " . action.imageFile)
                }

            case "info": ; Do nothing, just display info text
        }
    } catch as e {
        MacroActionText.Opt("cRed")
        MacroActionText.Text := "ERROR: " . e.Message
        isMacroToggled := false ; Stop on error
        g_CurrentMacro.Stop()
        return
    }

    if (isMacroToggled && !isPaused) {
        SetTimer(RunMacroLoop, -(action.HasProp("wait") ? action.wait : 1000))
    }
}

RejectMacro() {
    global g_CurrentMacro
    ; === FIX START ===
    ; Added braces to all nested if-statements for robust parsing.
    if (isMacroToggled && IsObject(g_CurrentMacro) && g_CurrentMacro.HasMethod("Reject")) {
        g_CurrentMacro.Reject()
        if (!isPaused) {
            SetTimer(RunMacroLoop, -100)
        }
    }
    ; === FIX END ===
}

ConfigureMacro() {
    global g_CurrentMacro
    if (IsObject(g_CurrentMacro) && g_CurrentMacro.HasMethod("ShowConfigGui")) {
        g_CurrentMacro.ShowConfigGui()
    } else {
        MsgBox "The selected macro does not have a configuration window.", "No Configuration", 64
    }
}

HandleEnterKey() {
    global isPaused, lastEnterPress, PauseStatusText, ResyncText
    currentTime := A_TickCount
    ; === FIX START ===
    ; Added braces to all nested if-statements for robust parsing.
    if (currentTime - lastEnterPress < 300) { ; Double press for resync
        isPaused := false
        PauseStatusText.Visible := false
        ResyncText.Visible := true
        SetTimer(() => ResyncText.Visible := false, -1000)
        if (isMacroToggled) {
            SetTimer(RunMacroLoop, -100)
        }
    } else { ; Single press for pause
        isPaused := !isPaused
        PauseStatusText.Visible := isPaused
        if (isPaused) {
            SetTimer(RunMacroLoop, 0)
        } else {
            if (isMacroToggled) {
                SetTimer(RunMacroLoop, -100)
            }
        }
    }
    ; === FIX END ===
    lastEnterPress := currentTime
}

UpdateGuiDisplay() {
    global isMacroToggled, g_CurrentMacro, MacroStatusText, macroStartTime
    if (isMacroToggled) {
        MacroStatusText.Opt("cLime")
        MacroStatusText.Text := "Macro: " . g_CurrentMacro.Name . " (" . FormatTime((A_TickCount - macroStartTime) / 1000) . ")"
    } else if IsObject(g_CurrentMacro) {
        MacroStatusText.Opt("cWhite")
        MacroStatusText.Text := "Macro: " . g_CurrentMacro.Name . " (Stopped)"
    }
}

FormatTime(totalSeconds) {
    s := Mod(Floor(totalSeconds), 60)
    m := Mod(Floor(totalSeconds / 60), 60)
    h := Floor(totalSeconds / 3600)
    return (h > 0 ? h . "h " : "") . Format("{:02d}m {:02d}s", m, s)
}

HumanizedClick(x, y) {
    MouseMove x + Random(-2, 2), y + Random(-2, 2), Random(10, 20)
    Sleep Random(40, 90)
    Click
    Sleep Random(50, 100)
}
