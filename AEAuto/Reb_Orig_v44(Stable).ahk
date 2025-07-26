; ======================================================================================================================
; SCRIPT:           AE Auto v44 - OCR Edition with Debug Window (Fixed)
; DESCRIPTION:      A multi-purpose tool featuring key presser, autoclicker, mouse recorder, and OCR-based quest macro
;                   with comprehensive debug logging window.
; VERSION:          44.OCR.Debug.Fixed
;
; --- HOTKEYS ---
;   PgUp          - Toggles the Key Presser on/off.
;   PgDn          - Toggles the Autoclicker on/off.
;   F10           - Toggles the Quest Macro on/off.
;   F9            - Rejects the current quest and restarts the macro.
;   Home          - Start/Stop Mouse Recording.
;   End           - Start/Stop Playback of recorded actions.
;   MButton       - Presses F1 and then clicks.
;   Enter         - Toggles Pause/Resume. Double-press to resync.
;   F11           - Configure macro coordinates.
;   F12           - Exits the script completely.
;   F8            - Toggle Debug Window
; ======================================================================================================================

; --- SCRIPT SETTINGS ---
#SingleInstance Force
CoordMode("Mouse", "Screen")
SetWorkingDir(A_ScriptDir)

; --- INCLUDE OCR LIBRARY ---
#Include lib\OCR.ahk

; --- VERSION CHECK ---
try {
    testVer := VerCompare("2.0", "1.0")
} catch {
    MsgBox("This script requires AutoHotkey v2.0 or later.", "Version Error", 48)
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
global CurrentTransparency := 200
global CurrentPlaybackLoops := 1
global CurrentPlaybackSpeed := 1
global keyPressStartTime := 0
global clickerStartTime := 0
global macroStartTime := 0
global showingOptions := false
global showingHotkeys := false
global showingStats := false

; Window tracking
global ConfigGuiOpen := false
global CreatureGuiOpen := false
global ConfigGuiObj := ""
global CreatureGuiObj := ""

; Statistics
global totalClicks := 0
global totalKeyPresses := 0
global totalPlaybacks := 0
global totalRecordings := 0
global totalMacroRuns := 0
global sessionStartTime := A_TickCount
global previousActionRuntime := "N/A"
global lastEnterPress := 0

; Mouse recording
global recordedActions := []
global recordingStartTime := 0
global recordingStartX := 0
global recordingStartY := 0
global lastRecordedX := 0
global lastRecordedY := 0

; --- MACRO SYSTEM VARIABLES ---
global macroStep := 0
global rejectionStep := 0
global macroState := "idle"
global lastMacroAction := 0
global macroWaitTime := 2000
global currentSequence := "main"
global detectedQuestNumber := 0

; --- OCR VARIABLES ---
global ocrEnabled := false
global ocrLastResult := ""
global ocrSearchTimeout := 5000
global questNumberRegion := {x: 0, y: 0, w: 300, h: 100}
global gameWindowTitle := "Ashen Empires"
global ocrInitialized := false

; --- DEBUG WINDOW VARIABLES ---
global debugWindowVisible := false
global debugGui := ""
global debugListView := ""
global debugMessages := []
global maxDebugMessages := 500

; Coordinate storage for macro targets
global coords := Map()
coords["dtm_npc"] := {x: 1830, y: 1080, name: "DTM NPC"}

; Creature selection settings
global selectedCreature := "dragons_btn"
global selectedCreaturePage := 1
global selectedCreatureName := "Dragons"

global currentCreaturePage := 1
global currentCreatureIndex := 1
global questAcceptanceTimeout := 10000
global questState := "seeking"
global baseClickDelay := 350
global humanizeClicks := true

; Macro sequences
global macroSequence := [
    {action: "click_npc", wait: 1500, description: "Click DTM NPC"},
    {action: "check_quest_state", wait: 500, description: "Checking quest state..."},
    {action: "branch_sequence", wait: 100, description: "Branching to appropriate sequence"}
]

global normalQuestSequence := [
    {action: "ocr_click", text: "Continue", wait: 1000, description: "Click Continue"},
    {action: "ocr_click", text: "Continue", wait: 1000, description: "Click Continue (2)"},
    {action: "ocr_click", text: "Sure!", wait: 1000, description: "Click Sure!"},
    {action: "ocr_click", text: "Continue", wait: 1500, description: "Click Continue (3)"},
    {action: "navigate_to_creature_ocr", wait: 1000, description: "Navigate to creature"},
    {action: "select_creature_ocr", wait: 2000, description: "Select creature"},
    {action: "ocr_click", text: "Continue", wait: 1000, description: "Click Continue after creature"},
    {action: "ocr_click", text: "Yes I Need Extra Challenge", wait: 3000, description: "Click Extra Challenge"},
    {action: "check_quest_number", wait: 1000, description: "Checking quest value..."},
    {action: "decide_quest", wait: 100, description: "Deciding to keep or reject..."}
]

global rejectionSequence := [
    {action: "ocr_click", text: "Continue", wait: 1000, description: "Click Continue (Reject 1)"},
    {action: "ocr_click", text: "Continue", wait: 1000, description: "Click Continue (Reject 2)"},
    {action: "ocr_click", text: "Yes I Am Not Strong Enough", wait: 1000, description: "Click Not Strong Enough"},
    {action: "ocr_click", text: "Continue", wait: 1000, description: "Click Continue (Reject 3)"},
    {action: "ocr_click", text: "Continue", wait: 1500, description: "Click Continue (Reject 4)"},
    {action: "restart_with_normal", description: "Restarting with normal sequence..."}
]

; --- DEBUG FUNCTIONS ---
DebugLog(category, message, level := "INFO") {
    global debugMessages, debugListView, maxDebugMessages
    
    timestamp := A_Now
    timestamp := SubStr(timestamp, 9, 2) . ":" . SubStr(timestamp, 11, 2) . ":" . SubStr(timestamp, 13, 2) ; Extract HH:MM:SS
    
    ; Add to messages array
    msgObj := {
        time: timestamp,
        category: category,
        message: message,
        level: level
    }
    
    debugMessages.Push(msgObj)
    
    ; Limit message count
    if (debugMessages.Length > maxDebugMessages) {
        debugMessages.RemoveAt(1)
    }
    
    ; Update ListView if debug window is open
    if (debugWindowVisible && IsObject(debugListView)) {
        ; Determine icon based on level
        iconNum := 1
        switch level {
            case "ERROR": iconNum := 2
            case "WARNING": iconNum := 3
            case "SUCCESS": iconNum := 4
            case "OCR": iconNum := 5
        }
        
        ; Add to ListView
        debugListView.Add("Icon" . iconNum, timestamp, category, message, level)
        
        ; Auto-scroll to bottom
        debugListView.Modify(debugListView.GetCount(), "Vis")
    }
}

CreateDebugWindow() {
    global debugGui, debugListView, debugWindowVisible
    
    if (IsObject(debugGui)) {
        debugGui.Show()
        debugWindowVisible := true
        return
    }
    
    ; Create debug window with no-activate flags
    debugGui := Gui("+Resize +AlwaysOnTop +ToolWindow", "AE Auto Debug Console")
    debugGui.Opt("+E0x08000000") ; WS_EX_NOACTIVATE
    debugGui.BackColor := "1a1a1a"
    debugGui.SetFont("s9 cFFFFFF", "Consolas")
    
    ; Create toolbar
    debugGui.Add("Text", "x10 y10 w100 cLime", "Debug Console")
    clearBtn := debugGui.Add("Button", "x600 y5 w80 h25", "Clear")
    clearBtn.OnEvent("Click", (*) => debugListView.Delete())
    
    ; Create ListView with columns
    debugListView := debugGui.Add("ListView", "x10 y35 w770 h400 Background0a0a0a cWhite Grid", ["Time", "Category", "Message", "Level"])
    
    ; Set column widths
    debugListView.ModifyCol(1, 80)   ; Time
    debugListView.ModifyCol(2, 100)  ; Category
    debugListView.ModifyCol(3, 500)  ; Message
    debugListView.ModifyCol(4, 70)   ; Level
    
    ; Create ImageList for icons
    IL := IL_Create(5)
    IL_Add(IL, "shell32.dll", 78)   ; 1: Info
    IL_Add(IL, "shell32.dll", 110)  ; 2: Error
    IL_Add(IL, "shell32.dll", 84)   ; 3: Warning
    IL_Add(IL, "shell32.dll", 297)  ; 4: Success
    IL_Add(IL, "shell32.dll", 23)   ; 5: OCR
    debugListView.SetImageList(IL)
    
    ; Add filter controls
    debugGui.Add("Text", "x10 y445 w50", "Filter:")
    filterEdit := debugGui.Add("Edit", "x65 y443 w200")
    filterBtn := debugGui.Add("Button", "x270 y442 w60 h22", "Apply")
    
    filterBtn.OnEvent("Click", (*) => FilterDebugMessages(filterEdit.Text))
    
    ; Add existing messages
    for msg in debugMessages {
        iconNum := 1
        switch msg.level {
            case "ERROR": iconNum := 2
            case "WARNING": iconNum := 3
            case "SUCCESS": iconNum := 4
            case "OCR": iconNum := 5
        }
        debugListView.Add("Icon" . iconNum, msg.time, msg.category, msg.message, msg.level)
    }
    
    debugGui.OnEvent("Close", (*) => (debugWindowVisible := false))
    debugGui.OnEvent("Size", DebugWindowResize)
    
    debugGui.Show("w800 h480 x" . (A_ScreenWidth - 820) . " y20")
    debugWindowVisible := true
    
    DebugLog("SYSTEM", "Debug window opened", "INFO")
}

DebugWindowResize(GuiObj, MinMax, Width, Height) {
    global debugListView
    if MinMax = -1
        return
    debugListView.Move(, , Width - 30, Height - 80)
}

FilterDebugMessages(filterText) {
    global debugListView, debugMessages
    debugListView.Delete()
    
    for msg in debugMessages {
        if (filterText = "" || InStr(msg.message, filterText) || InStr(msg.category, filterText)) {
            iconNum := 1
            switch msg.level {
                case "ERROR": iconNum := 2
                case "WARNING": iconNum := 3
                case "SUCCESS": iconNum := 4
                case "OCR": iconNum := 5
            }
            debugListView.Add("Icon" . iconNum, msg.time, msg.category, msg.message, msg.level)
        }
    }
}

; --- OCR WRAPPER FUNCTIONS ---
InitializeOCR() {
    global ocrInitialized
    try {
        DebugLog("OCR", "Initializing OCR system...", "INFO")
        result := OCR.FromDesktop()
        ocrInitialized := true
        DebugLog("OCR", "OCR initialized successfully", "SUCCESS")
        return true
    } catch as e {
        DebugLog("OCR", "OCR initialization failed: " . e.Message, "ERROR")
        MsgBox("OCR initialization failed. Make sure you have Windows 10/11 with OCR language packs installed.`n`nError: " . e.Message, "OCR Error", 48)
        return false
    }
}

FindAndClickButton(buttonText, timeout := 5000) {
    global gameWindowTitle, ocrLastResult
    startTime := A_TickCount
    
    DebugLog("OCR", "Searching for button: " . buttonText, "INFO")
    
    Loop {
        try {
            ; Capture game window
            result := OCR.FromWindow(gameWindowTitle)
            ocrLastResult := result.Text
            
            ; Log the captured text (first 200 chars)
            DebugLog("OCR", "Captured text: " . SubStr(result.Text, 1, 200) . "...", "OCR")
            
            ; Search for the button text
            found := result.FindString(buttonText, {CaseSense: false})
            if (found) {
                ; Add small random offset for human-like clicking
                offsetX := Random(-5, 5)
                offsetY := Random(-5, 5)
                
                ; Click the center of the found text
                found.Click()
                totalClicks++
                
                DebugLog("OCR", "Found and clicked: " . buttonText . " at " . found.x . "," . found.y, "SUCCESS")
                MacroActionText.Text := "Clicked: " . buttonText
                return true
            }
        } catch as e {
            DebugLog("OCR", "OCR error: " . e.Message, "ERROR")
        }
        
        ; Check timeout
        if (A_TickCount - startTime > timeout) {
            DebugLog("OCR", "Timeout finding button: " . buttonText, "WARNING")
            MacroActionText.Text := "Timeout finding: " . buttonText
            return false
        }
        
        Sleep(100)
    }
}

ReadQuestNumber(region := "") {
    global questNumberRegion, gameWindowTitle
    
    if (!region) {
        region := questNumberRegion
    }
    
    DebugLog("OCR", "Reading quest number from region: " . region.x . "," . region.y . " " . region.w . "x" . region.h, "INFO")
    
    try {
        ; Capture specific region of game window
        result := OCR.FromWindow(gameWindowTitle, {x: region.x, y: region.y, w: region.w, h: region.h})
        
        ; Look for numbers
        text := result.Text
        DebugLog("OCR", "Quest region text: " . text, "OCR")
        
        ; Extract numbers using regex
        if (RegExMatch(text, "(\d+)", &match)) {
            number := Integer(match[1])
            DebugLog("OCR", "Found quest number: " . number, "SUCCESS")
            return number
        }
    } catch as e {
        DebugLog("OCR", "Failed to read quest number: " . e.Message, "ERROR")
    }
    
    DebugLog("OCR", "No quest number found", "WARNING")
    return 0
}

CheckQuestState() {
    global gameWindowTitle, ocrLastResult
    
    DebugLog("MACRO", "Checking quest state...", "INFO")
    
    try {
        result := OCR.FromWindow(gameWindowTitle)
        text := result.Text
        ocrLastResult := text
        
        ; Log first 300 chars of captured text
        DebugLog("OCR", "Full screen text: " . SubStr(text, 1, 300) . "...", "OCR")
        
        ; Check for indicators that we already have a quest
        if (InStr(text, "Yes I Am Not Strong Enough") || InStr(text, "not strong enough")) {
            DebugLog("MACRO", "Detected existing quest (rejection options found)", "SUCCESS")
            return "has_quest"
        }
        
        ; Check for fresh quest dialog
        if (InStr(text, "Sure!") || InStr(text, "continue")) {
            DebugLog("MACRO", "Detected no existing quest (normal options found)", "SUCCESS")
            return "no_quest"
        }
        
    } catch as e {
        DebugLog("OCR", "Quest state check failed: " . e.Message, "ERROR")
    }
    
    DebugLog("MACRO", "Could not determine quest state", "WARNING")
    return "unknown"
}

FindAndClickCreature(creatureName) {
    DebugLog("MACRO", "Searching for creature: " . creatureName, "INFO")
    return FindAndClickButton(creatureName, 3000)
}

NavigateToCreatureOCR() {
    global selectedCreaturePage
    clicksNeeded := selectedCreaturePage - 1
    
    DebugLog("MACRO", "Navigating to creature page " . selectedCreaturePage . " (needs " . clicksNeeded . " clicks)", "INFO")
    
    Loop clicksNeeded {
        if (!FindAndClickButton("Show More", 3000)) {
            DebugLog("MACRO", "Failed to find Show More button on page " . A_Index, "ERROR")
            return false
        }
        Sleep(800)
    }
    return true
}

SetQuestNumberRegion() {
    global questNumberRegion
    
    DebugLog("SETTINGS", "Setting quest number region...", "INFO")
    
    MsgBox("Position your mouse at the TOP-LEFT of where quest numbers appear and press SPACE", "Set Region", 0)
    MouseGetPos(&x1, &y1)
    
    MsgBox("Position your mouse at the BOTTOM-RIGHT of where quest numbers appear and press SPACE", "Set Region", 0)
    MouseGetPos(&x2, &y2)
    
    questNumberRegion.x := x1
    questNumberRegion.y := y1
    questNumberRegion.w := x2 - x1
    questNumberRegion.h := y2 - y1
    
    DebugLog("SETTINGS", "Quest number region set to: " . x1 . "," . y1 . " - " . x2 . "," . y2, "SUCCESS")
    MsgBox("Quest number region set to: " . x1 . "," . y1 . " - " . x2 . "," . y2, "Region Set", 64)
}

TestOCR(*) {
    DebugLog("OCR", "Starting OCR test...", "INFO")
    
    if (!ocrInitialized && !InitializeOCR()) {
        return
    }
    
    try {
        result := OCR.FromWindow(gameWindowTitle)
        fullText := result.Text
        DebugLog("OCR", "Full OCR result: " . fullText, "OCR")
        MsgBox("OCR Test Result:`n`n" . SubStr(fullText, 1, 500) . "...", "OCR Test", 64)
    } catch as e {
        DebugLog("OCR", "OCR test failed: " . e.Message, "ERROR")
        MsgBox("OCR test failed: " . e.Message, "Error", 48)
    }
}

; --- SOUND FUNCTIONS ---
PlaySound(type := "info") {
    try {
        switch type {
            case "error":
                SoundPlay("*16")
            case "success":
                SoundPlay("*64")
            case "warning":
                SoundPlay("*48")
            case "info":
                SoundPlay("*64")
            case "resync":
                SoundPlay("*64")
                Sleep(60)
                SoundPlay("*64")
        }
    } catch {
        try {
            switch type {
                case "error":
                    SoundBeep(200, 200)
                case "success":
                    SoundBeep(800, 150)
                case "warning":
                    SoundBeep(500, 150)
                case "info":
                    SoundBeep(600, 100)
                case "resync":
                    SoundBeep(1000, 100)
                    Sleep(50)
                    SoundBeep(1000, 100)
            }
        }
    }
}

; --- GUI CREATION ---
global MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000", "Multi-Tool")
MyGui.BackColor := "222222"
MyGui.SetFont("s10 cFFFFFF", "Verdana")

; Main status displays
global KeypressStatusText := MyGui.Add("Text", "x10 y10 w260 h20", "Keypress: OFF")
global ClickerStatusText := MyGui.Add("Text", "x10 y35 w260 h20", "Autoclick: OFF")
global MacroStatusText := MyGui.Add("Text", "x10 y60 w260 h20", "Quest Macro: OFF")
global RecorderStatusText := MyGui.Add("Text", "x10 y85 w260 h20", "Mouse Recorder: Ready")
global PauseStatusText := MyGui.Add("Text", "x10 y110 w260 Center cYellow", "PAUSED")
PauseStatusText.Visible := false
global ResyncText := MyGui.Add("Text", "x10 y110 w260 Center cLime", "RESYNCED!")
ResyncText.Visible := false

; Macro status display
global MacroActionText := MyGui.Add("Text", "x10 y160 w260 Center cLime", "Macro: Ready")
MacroActionText.SetFont("s10", "Verdana")
MacroActionText.Visible := false
global CreatureStatusText := MyGui.Add("Text", "x10 y180 w260 Center cAqua", "Next: Dragons (Page 1)")
CreatureStatusText.SetFont("s10", "Verdana")
CreatureStatusText.Visible := false
global QuestDecisionText := MyGui.Add("Text", "x10 y200 w260 Center cYellow", "Press F9 to REJECT quest")
QuestDecisionText.SetFont("s10", "Verdana")
QuestDecisionText.Visible := false
global KillCountText := MyGui.Add("Text", "x10 y220 w260 Center cFFA500", "Kills: Not Detected")
KillCountText.SetFont("s10", "Verdana")
KillCountText.Visible := false

; Control buttons
global OptionsButton := MyGui.Add("Button", "x10 y130 w75 h25", "Options")
global HotkeysButton := MyGui.Add("Button", "x95 y130 w75 h25", "Hotkeys")
global StatsButton := MyGui.Add("Button", "x180 y130 w85 h25", "Statistics")

; --- OPTIONS SECTION ---
global OptionsTitle := MyGui.Add("Text", "x10 y165 w260 Center cLime", "--- OPTIONS ---")
OptionsTitle.Visible := false
global KeyDelayLabel := MyGui.Add("Text", "x10 y190 cSilver", "Key Delay (ms):")
KeyDelayLabel.Visible := false
global KeyDelaySlider := MyGui.Add("Slider", "x10 y210 w200 Range40-2500", CurrentKeyDelay)
KeyDelaySlider.Visible := false
global KeyDelayText := MyGui.Add("Text", "x215 y210 w50 cWhite", CurrentKeyDelay . "ms")
KeyDelayText.Visible := false
global ClickDelayLabel := MyGui.Add("Text", "x10 y235 cSilver", "Click Delay (ms):")
ClickDelayLabel.Visible := false
global ClickDelaySlider := MyGui.Add("Slider", "x10 y255 w200 Range40-2500", CurrentClickDelay)
ClickDelaySlider.Visible := false
global ClickDelayText := MyGui.Add("Text", "x215 y255 w50 cWhite", CurrentClickDelay . "ms")
ClickDelayText.Visible := false
global TransLabel := MyGui.Add("Text", "x10 y280 cSilver", "GUI Opacity:")
TransLabel.Visible := false
global TransSlider := MyGui.Add("Slider", "x10 y300 w200 Range50-255", CurrentTransparency)
TransSlider.Visible := false
global TransText := MyGui.Add("Text", "x215 y300 w50 cWhite", CurrentTransparency)
TransText.Visible := false
global MacroWaitLabel := MyGui.Add("Text", "x10 y325 cSilver", "Macro Wait Time (ms):")
MacroWaitLabel.Visible := false
global MacroWaitSlider := MyGui.Add("Slider", "x10 y345 w200 Range500-5000", macroWaitTime)
MacroWaitSlider.Visible := false
global MacroWaitText := MyGui.Add("Text", "x215 y345 w50 cWhite", macroWaitTime . "ms")
MacroWaitText.Visible := false
global CreatureLabel := MyGui.Add("Text", "x10 y370 cSilver", "Selected Creature:")
CreatureLabel.Visible := false
global CreatureCurrentText := MyGui.Add("Text", "x10 y390 w150 h20 Border", "Dragons")
CreatureCurrentText.Visible := false
CreatureCurrentText.SetFont("s9")
global CreatureChangeBtn := MyGui.Add("Button", "x165 y390 w100 h20", "Change")
CreatureChangeBtn.Visible := false
global ConfigCoordsBtn := MyGui.Add("Button", "x10 y420 w255 h25", "Configure Coordinates")
ConfigCoordsBtn.Visible := false
global HumanizeLabel := MyGui.Add("Text", "x10 y450 cSilver", "Humanization:")
HumanizeLabel.Visible := false
global HumanizeCheckbox := MyGui.Add("Checkbox", "x110 y450 w100", "Enable")
HumanizeCheckbox.Visible := false
HumanizeCheckbox.Value := true

; OCR Options
global OCRLabel := MyGui.Add("Text", "x10 y475 cSilver", "Text Detection:")
OCRLabel.Visible := false
global OCRCheckbox := MyGui.Add("Checkbox", "x110 y475 w100", "Enable OCR")
OCRCheckbox.Visible := false
global OCRTestBtn := MyGui.Add("Button", "x10 y500 w125 h20", "Test OCR")
OCRTestBtn.Visible := false
global SetQuestRegionBtn := MyGui.Add("Button", "x145 y500 w120 h20", "Set Quest Region")
SetQuestRegionBtn.Visible := false
global DebugWindowBtn := MyGui.Add("Button", "x10 y525 w255 h25", "Toggle Debug Window (F8)")
DebugWindowBtn.Visible := false

; --- HOTKEYS SECTION ---
global HotkeysTitle := MyGui.Add("Text", "x10 y165 w260 Center cLime", "--- HOTKEYS ---")
HotkeysTitle.SetFont("s10", "Verdana")
HotkeysTitle.Visible := false
global HotkeyTexts := []
HotkeyTexts.Push(MyGui.Add("Text", "x10 y190 cSilver", "PgUp: Toggle Keypress"))
HotkeyTexts.Push(MyGui.Add("Text", "x10 y210 cSilver", "PgDn: Toggle Autoclicker"))
HotkeyTexts.Push(MyGui.Add("Text", "x10 y230 cSilver", "F10: Toggle Quest Macro"))
HotkeyTexts.Push(MyGui.Add("Text", "x10 y250 cSilver", "F9: Reject Current Quest"))
HotkeyTexts.Push(MyGui.Add("Text", "x10 y270 cSilver", "Home: Record Mouse"))
HotkeyTexts.Push(MyGui.Add("Text", "x10 y290 cSilver", "End: Playback Mouse"))
HotkeyTexts.Push(MyGui.Add("Text", "x10 y310 cSilver", "Middle Mouse: F1+click"))
HotkeyTexts.Push(MyGui.Add("Text", "x10 y330 cSilver", "Enter: Pause (2x = Resync)"))
HotkeyTexts.Push(MyGui.Add("Text", "x10 y350 cSilver", "F8: Toggle Debug Window"))
HotkeyTexts.Push(MyGui.Add("Text", "x10 y370 cSilver", "F12: Exit Program"))
for text in HotkeyTexts {
    text.Visible := false
}

; --- STATISTICS SECTION ---
global StatsTitle := MyGui.Add("Text", "x10 y165 w260 Center cLime", "--- STATISTICS ---")
StatsTitle.SetFont("s10", "Verdana")
StatsTitle.Visible := false
global SessionTimeText := MyGui.Add("Text", "x10 y190 w260 cSilver", "Session Time: 00:00:00")
SessionTimeText.Visible := false
global TotalClicksText := MyGui.Add("Text", "x10 y210 w260 cSilver", "Total Clicks: 0")
TotalClicksText.Visible := false
global TotalKeysText := MyGui.Add("Text", "x10 y230 w260 cSilver", "Keys Pressed: 0")
TotalKeysText.Visible := false
global MacroRunsText := MyGui.Add("Text", "x10 y250 w260 cSilver", "Macro Runs: 0")
MacroRunsText.Visible := false
global RecordingsText := MyGui.Add("Text", "x10 y270 w260 cSilver", "Recordings: 0")
RecordingsText.Visible := false
global PlaybacksText := MyGui.Add("Text", "x10 y290 w260 cSilver", "Playbacks: 0")
PlaybacksText.Visible := false
global ResetStatsBtn := MyGui.Add("Button", "x10 y315 w125 h25", "Reset Stats")
ResetStatsBtn.Visible := false
global ExportStatsBtn := MyGui.Add("Button", "x145 y315 w125 h25", "Export Stats")
ExportStatsBtn.Visible := false

; --- EVENT BINDINGS ---
OptionsButton.OnEvent("Click", ToggleOptionsSection)
HotkeysButton.OnEvent("Click", ToggleHotkeysSection)
StatsButton.OnEvent("Click", ToggleStatsSection)
KeyDelaySlider.OnEvent("Change", UpdateKeyDelay)
ClickDelaySlider.OnEvent("Change", UpdateClickDelay)
TransSlider.OnEvent("Change", UpdateTransparency)
MacroWaitSlider.OnEvent("Change", UpdateMacroWait)
CreatureChangeBtn.OnEvent("Click", ShowCreatureSelector)
; HumanizeCheckbox.On() ; This line was incomplete and unnecessary
HumanizeCheckbox.OnEvent("Click", UpdateHumanization)
ConfigCoordsBtn.OnEvent("Click", ShowCoordinateConfig)
OCRCheckbox.OnEvent("Click", ToggleOCR)
OCRTestBtn.OnEvent("Click", TestOCR)
SetQuestRegionBtn.OnEvent("Click", (*) => SetQuestNumberRegion())
DebugWindowBtn.OnEvent("Click", (*) => ToggleDebugWindow())
ResetStatsBtn.OnEvent("Click", ResetStats)
ExportStatsBtn.OnEvent("Click", ExportStats)
MyGui.OnEvent("Close", (*) => ExitApp())
OnMessage(0x201, GuiDrag)

; --- INITIALIZE GUI ---
MyGui.Show("x20 y20 w280 h160")
WinSetTransparent(CurrentTransparency, MyGui.Hwnd)
SetTimer(KeepGuiOnTop, 2000)
SetTimer(UpdateGuiDisplay, 250)

; Store the active window before showing our GUI
global gameWindow := WinExist("A")
global gameTitle := "Ashen Empires"

; Initialize debug system
DebugLog("SYSTEM", "AE Auto v44 OCR Edition started", "SUCCESS")
DebugLog("SYSTEM", "Debug logging initialized", "INFO")

; Enhanced GUI creation for popups that won't minimize games
CreateNoStealFocusGui(title) {
   ; Create GUI with special flags to prevent focus stealing
   newGui := Gui("+AlwaysOnTop +ToolWindow", title)
   newGui.Opt("-MinimizeBox +E0x08000000") ; WS_EX_NOACTIVATE
   
   ; Set owner to main GUI to prevent taskbar appearance
   newGui.Opt("+Owner" . MyGui.Hwnd)
   
   return newGui
}

; Store the main GUI hwnd for hotkey context
global MainGuiHwnd := MyGui.Hwnd

; --- HOTKEY DEFINITIONS ---
; F8 for debug window toggle
F8::ToggleDebugWindow()

; Only activate hotkeys when the main tool window exists
#HotIf WinExist("ahk_id " . MainGuiHwnd)
PgUp::ToggleKeyPresser()
PgDn::ToggleClicker()
F10::ToggleMacro()
F9::RejectCurrentQuest()
Home::ToggleMouseRecording()
End::TogglePlayback()
MButton::F1ClickMacro()
~Enter::HandleEnterKey()
F11::ShowCoordinateConfig()
#HotIf

; F12 should work globally to exit the script
*F12:: {
   DebugLog("SYSTEM", "F12 pressed - Exiting script", "WARNING")
   ExitApp
}

; Context-sensitive hotkey for closing sub-GUIs
#HotIf WinActive("Select Creature") or WinActive("Configure Macro Coordinates") or WinActive("Set Detection Region") or WinActive("Quick Setup") or WinActive("Set Coordinate")
Escape:: {
   global
   if (CreatureGuiOpen) {
       CloseCreatureGui()
   }
   if (ConfigGuiOpen) {
       CloseConfigGui()
   }
   ; Close any other open dialogs
   try {
       WinClose("A")
   }
}
#HotIf

; --- CORE FUNCTIONS ---
ToggleDebugWindow() {
   global debugWindowVisible
   if (debugWindowVisible) {
       if (IsObject(debugGui)) {
           debugGui.Hide()
           debugWindowVisible := false
           DebugLog("SYSTEM", "Debug window hidden", "INFO")
       }
   } else {
       CreateDebugWindow()
   }
}

HandleEnterKey() {
   global
   local currentTime := A_TickCount
   if (currentTime - lastEnterPress < 300) {
       if (isPaused) {
           isPaused := false
           PauseStatusText.Visible := false
           ResyncText.Visible := true
           SetTimer(() => ResyncText.Visible := false, -500)
           PlaySound("resync")
           DebugLog("SYSTEM", "Resync performed", "SUCCESS")
           if (isKeyPressToggled) {
               SetTimer(PressTheKey, -CurrentKeyDelay)
           }
           if (isClickerToggled) {
               SetTimer(ClickTheMouse, -CurrentClickDelay)
           }
           if (isMacroToggled) {
               SetTimer(RunMacro, -macroWaitTime)
           }
       } else {
           ResyncText.Visible := true
           SetTimer(() => ResyncText.Visible := false, -500)
           PlaySound("resync")
           DebugLog("SYSTEM", "Double Enter pressed (already unpaused)", "INFO")
       }
       lastEnterPress := 0
       return
   }
   lastEnterPress := currentTime
   TogglePause()
}

TogglePause() {
   global
   isPaused := !isPaused
   PauseStatusText.Visible := isPaused
   if (isPaused) {
       DebugLog("SYSTEM", "Script paused", "WARNING")
       PlaySound("warning")
       SetTimer(PressTheKey, 0)
       SetTimer(ClickTheMouse, 0)
       SetTimer(RunMacro, 0)
   } else {
       DebugLog("SYSTEM", "Script resumed", "SUCCESS")
       PlaySound("info")
       if (isKeyPressToggled) {
           SetTimer(PressTheKey, -CurrentKeyDelay)
       }
       if (isClickerToggled) {
           SetTimer(ClickTheMouse, -CurrentClickDelay)
       }
       if (isMacroToggled) {
           SetTimer(RunMacro, -macroWaitTime)
       }
   }
}

; --- SECTION TOGGLES ---
ToggleOptionsSection(*) {
   global
   showingOptions := !showingOptions
   if (showingOptions) {
       HideOtherSections("options")
       ShowOptionsSection()
   } else {
       HideOptionsSection()
   }
}

ToggleHotkeysSection(*) {
   global
   showingHotkeys := !showingHotkeys
   if (showingHotkeys) {
       HideOtherSections("hotkeys")
       ShowHotkeysSection()
   } else {
       HideHotkeysSection()
   }
}

ToggleStatsSection(*) {
   global
   showingStats := !showingStats
   if (showingStats) {
       HideOtherSections("stats")
       ShowStatsSection()
   } else {
       HideStatsSection()
   }
}

HideOtherSections(except) {
   global
   if (except != "options" && showingOptions) {
       HideOptionsSection()
       showingOptions := false
   }
   if (except != "hotkeys" && showingHotkeys) {
       HideHotkeysSection()
       showingHotkeys := false
   }
   if (except != "stats" && showingStats) {
       HideStatsSection()
       showingStats := false
   }
}

ShowOptionsSection() {
   global
   controls := [OptionsTitle, KeyDelayLabel, KeyDelaySlider, KeyDelayText, ClickDelayLabel, ClickDelaySlider, ClickDelayText, TransLabel, TransSlider, TransText, MacroWaitLabel, MacroWaitSlider, MacroWaitText, CreatureLabel, CreatureCurrentText, CreatureChangeBtn, HumanizeLabel, HumanizeCheckbox, ConfigCoordsBtn, OCRLabel, OCRCheckbox, OCRTestBtn, SetQuestRegionBtn, DebugWindowBtn]
   for control in controls {
       control.Visible := true
   }
   MyGui.Move(,, 280, 560)
   OptionsButton.Text := "Hide Options"
}

HideOptionsSection() {
   global
   controls := [OptionsTitle, KeyDelayLabel, KeyDelaySlider, KeyDelayText, ClickDelayLabel, ClickDelaySlider, ClickDelayText, TransLabel, TransSlider, TransText, MacroWaitLabel, MacroWaitSlider, MacroWaitText, CreatureLabel, CreatureCurrentText, CreatureChangeBtn, HumanizeLabel, HumanizeCheckbox, ConfigCoordsBtn, OCRLabel, OCRCheckbox, OCRTestBtn, SetQuestRegionBtn, DebugWindowBtn]
   for control in controls {
       control.Visible := false
   }
   if (!showingHotkeys && !showingStats) {
       MyGui.Move(,, 280, 160)
   }
   OptionsButton.Text := "Options"
}

ShowHotkeysSection() {
   global
   HotkeysTitle.Visible := true
   for text in HotkeyTexts {
       text.Visible := true
   }
   MyGui.Move(,, 280, 400)
   HotkeysButton.Text := "Hide Hotkeys"
}

HideHotkeysSection() {
   global
   HotkeysTitle.Visible := false
   for text in HotkeyTexts {
       text.Visible := false
   }
   if (!showingOptions && !showingStats) {
       MyGui.Move(,, 280, 160)
   }
   HotkeysButton.Text := "Hotkeys"
}

ShowStatsSection() {
   global
   controls := [StatsTitle, SessionTimeText, TotalClicksText, TotalKeysText, MacroRunsText, RecordingsText, PlaybacksText, ResetStatsBtn, ExportStatsBtn]
   for control in controls {
       control.Visible := true
   }
   MyGui.Move(,, 280, 345)
   StatsButton.Text := "Hide Stats"
}

HideStatsSection() {
   global
   controls := [StatsTitle, SessionTimeText, TotalClicksText, TotalKeysText, MacroRunsText, RecordingsText, PlaybacksText, ResetStatsBtn, ExportStatsBtn]
   for control in controls {
       control.Visible := false
   }
   if (!showingOptions && !showingHotkeys) {
       MyGui.Move(,, 280, 160)
   }
   StatsButton.Text := "Statistics"
}

; --- ACTION FUNCTIONS ---
PressTheKey() {
   global
   if (!isKeyPressToggled || isPaused) {
       return
   }
   Send("{``}")
   totalKeyPresses++
   DebugLog("KEYPRESS", "Sent backtick key", "INFO")
   SetTimer(PressTheKey, -CurrentKeyDelay)
}

ClickTheMouse() {
   global
   if (!isClickerToggled || isPaused) {
       return
   }
   Click()
   totalClicks++
   DebugLog("AUTOCLICK", "Clicked at cursor position", "INFO")
   SetTimer(ClickTheMouse, -CurrentClickDelay)
}

F1ClickMacro() {
   global totalClicks
   Send("{F1}")
   Sleep(550)
   MouseGetPos(&x, &y)
   HumanizedClick(x, y)
   totalClicks++
   DebugLog("MACRO", "F1+Click macro executed", "INFO")
}

; --- MOUSE RECORDING ---
ToggleMouseRecording(*) {
   global
   if (isPlayingBack) {
       return
   }
   isRecording := !isRecording
   if (isRecording) {
       recordedActions := []
       PlaySound("success")
       DebugLog("RECORDER", "Mouse recording started", "SUCCESS")
   } else {
       PlaySound("info")
       totalRecordings++
       DebugLog("RECORDER", "Mouse recording stopped (" . recordedActions.Length . " actions)", "INFO")
   }
}

TogglePlayback() {
   global
   if (isRecording || recordedActions.Length == 0) {
       return
   }
   if (!isPlayingBack) {
       isPlayingBack := true
       totalPlaybacks++
       SetTimer(StopPlayback, -5000)
       DebugLog("RECORDER", "Playback started", "INFO")
   }
}

StopPlayback() {
   global
   isPlayingBack := false
   DebugLog("RECORDER", "Playback stopped", "INFO")
}

; --- UPDATE FUNCTIONS ---
UpdateKeyDelay(SliderObj, *) {
   global
   CurrentKeyDelay := SliderObj.Value
   KeyDelayText.Text := CurrentKeyDelay . "ms"
   DebugLog("SETTINGS", "Key delay changed to " . CurrentKeyDelay . "ms", "INFO")
}

UpdateClickDelay(SliderObj, *) {
   global
   CurrentClickDelay := SliderObj.Value
   ClickDelayText.Text := CurrentClickDelay . "ms"
   DebugLog("SETTINGS", "Click delay changed to " . CurrentClickDelay . "ms", "INFO")
}

UpdateTransparency(SliderObj, *) {
   global
   CurrentTransparency := SliderObj.Value
   TransText.Text := CurrentTransparency
   WinSetTransparent(CurrentTransparency, MyGui.Hwnd)
   DebugLog("SETTINGS", "GUI transparency changed to " . CurrentTransparency, "INFO")
}

UpdateMacroWait(SliderObj, *) {
   global
   macroWaitTime := SliderObj.Value
   MacroWaitText.Text := macroWaitTime . "ms"
   DebugLog("SETTINGS", "Macro wait time changed to " . macroWaitTime . "ms", "INFO")
}

UpdateGuiDisplay() {
   global
   if (isKeyPressToggled) {
       KeypressStatusText.SetFont("cLime")
       local elapsed := FormatElapsedTime((A_TickCount - keyPressStartTime) / 1000)
       KeypressStatusText.Text := "Keypress: ON (" . elapsed . ")"
   } else {
       KeypressStatusText.SetFont("cWhite")
       KeypressStatusText.Text := "Keypress: OFF"
   }
   if (isClickerToggled) {
       ClickerStatusText.SetFont("cLime")
       local elapsed := FormatElapsedTime((A_TickCount - clickerStartTime) / 1000)
       ClickerStatusText.Text := "Autoclick: ON (" . elapsed . ")"
   } else {
       ClickerStatusText.SetFont("cWhite")
       ClickerStatusText.Text := "Autoclick: OFF"
   }
   if (isMacroToggled) {
       if (questState == "waiting_for_decision") {
           MacroStatusText.SetFont("cYellow")
           MacroStatusText.Text := "Quest Macro: Awaiting Decision"
       } else {
           MacroStatusText.SetFont("cLime")
           local elapsed := FormatElapsedTime((A_TickCount - macroStartTime) / 1000)
           MacroStatusText.Text := "Quest Macro: ON (" . elapsed . ")"
       }
   } else {
       MacroStatusText.SetFont("cWhite")
       MacroStatusText.Text := "Quest Macro: OFF"
   }
   if (isRecording) {
       RecorderStatusText.SetFont("cRed")
       RecorderStatusText.Text := "Mouse Recorder: RECORDING"
   } else if (isPlayingBack) {
       RecorderStatusText.SetFont("cLime")
       RecorderStatusText.Text := "Mouse Recorder: PLAYING"
   } else {
       RecorderStatusText.SetFont("cWhite")
       RecorderStatusText.Text := "Mouse Recorder: Ready"
   }
   if (showingStats) {
       sessionTime := (A_TickCount - sessionStartTime) / 1000
       SessionTimeText.Text := "Session Time: " . FormatElapsedTime(sessionTime)
       TotalClicksText.Text := "Total Clicks: " . totalClicks
       TotalKeysText.Text := "Keys Pressed: " . totalKeyPresses
       MacroRunsText.Text := "Macro Runs: " . totalMacroRuns
       RecordingsText.Text := "Recordings: " . totalRecordings
       PlaybacksText.Text := "Playbacks: " . totalPlaybacks
   }
   if (ocrEnabled && isMacroToggled) {
       KillCountText.Visible := true
       if (detectedQuestNumber > 0) {
           KillCountText.Text := "Quest Kills: " . detectedQuestNumber
           KillCountText.SetFont("cLime")
       } else {
           KillCountText.Text := "Kills: Detecting..."
           KillCountText.SetFont("cFFA500")
       }
   } else {
       KillCountText.Visible := false
   }
}

FormatElapsedTime(totalSeconds) {
   hours := Floor(totalSeconds / 3600)
   minutes := Floor(Mod(totalSeconds, 3600) / 60)
   seconds := Floor(Mod(totalSeconds, 60))
   if (hours > 0) {
       return Format("{:d}h {:02d}m", hours, minutes)
   } else if (minutes > 0) {
       return Format("{:d}m {:02d}s", minutes, seconds)
   } else {
       return Format("{:d}s", seconds)
   }
}

; --- STATISTICS ---
ResetStats(*) {
   global
   result := MsgBox("Reset all statistics?", "Reset Statistics", 4)
   if (result = "Yes") {
       totalClicks := 0
       totalKeyPresses := 0
       totalPlaybacks := 0
       totalRecordings := 0
       totalMacroRuns := 0
       sessionStartTime := A_TickCount
       previousActionRuntime := "N/A"
       PlaySound("error")
       DebugLog("SYSTEM", "Statistics reset", "WARNING")
   }
}

ExportStats(*) {
   global
   sessionTime := (A_TickCount - sessionStartTime) / 1000
   statsText := "=== AutoHotkey Multi-Tool Statistics ===`n`n"
   statsText .= "Session Time: " . FormatElapsedTime(sessionTime) . "`n"
   statsText .= "Total Clicks: " . totalClicks . "`n"
   statsText .= "Total Keys Pressed: " . totalKeyPresses . "`n"
   statsText .= "Total Macro Runs: " . totalMacroRuns . "`n"
   statsText .= "Total Recordings: " . totalRecordings . "`n"
   statsText .= "Total Playbacks: " . totalPlaybacks . "`n`n"
   statsText .= "Current Settings:`n"
   statsText .= "- Key Delay: " . CurrentKeyDelay . "ms`n"
   statsText .= "- Click Delay: " . CurrentClickDelay . "ms`n"
   statsText .= "- Macro Wait Time: " . macroWaitTime . "ms`n"
   statsText .= "- OCR Enabled: " . (ocrEnabled ? "Yes" : "No") . "`n`n"
   statsText .= "Exported: " . FormatDateTime(A_Now)
   A_Clipboard := statsText
   PlaySound("success")
   MsgBox("Statistics copied to clipboard!", "Export Complete", 64)
   DebugLog("SYSTEM", "Statistics exported to clipboard", "SUCCESS")
}

FormatDateTime(dateTime) {
   ; dateTime is already in YYYYMMDDHHMISS format
   year := SubStr(dateTime, 1, 4)
   month := SubStr(dateTime, 5, 2)
   day := SubStr(dateTime, 7, 2)
   hour := SubStr(dateTime, 9, 2)
   minute := SubStr(dateTime, 11, 2)
   second := SubStr(dateTime, 13, 2)
   return year . "-" . month . "-" . day . " " . hour . ":" . minute . ":" . second
}

; --- UTILITY FUNCTIONS ---
KeepGuiOnTop() {
   global
   WinSetAlwaysOnTop(true, MyGui.Hwnd)
}

GuiDrag(*) {
   PostMessage(0xA1, 2)
}

; --- TOGGLE FUNCTIONS ---
ToggleKeyPresser(*) {
   global
   isKeyPressToggled := !isKeyPressToggled
   if (isKeyPressToggled) {
       keyPressStartTime := A_TickCount
       PlaySound("success")
       DebugLog("KEYPRESS", "Key presser activated", "SUCCESS")
       if (!isPaused) {
           SetTimer(PressTheKey, -CurrentKeyDelay)
       }
   } else {
       if (keyPressStartTime > 0) {
           previousActionRuntime := FormatElapsedTime((A_TickCount - keyPressStartTime) / 1000)
       }
       keyPressStartTime := 0
       PlaySound("error")
       DebugLog("KEYPRESS", "Key presser deactivated", "INFO")
       SetTimer(PressTheKey, 0)
   }
}

ToggleClicker(*) {
   global
   isClickerToggled := !isClickerToggled
   if (isClickerToggled) {
       clickerStartTime := A_TickCount
       PlaySound("success")
       DebugLog("AUTOCLICK", "Auto-clicker activated", "SUCCESS")
       if (!isPaused) {
           SetTimer(ClickTheMouse, -CurrentClickDelay)
       }
   } else {
       if (clickerStartTime > 0) {
           previousActionRuntime := FormatElapsedTime((A_TickCount - clickerStartTime) / 1000)
       }
       clickerStartTime := 0
       PlaySound("error")
       DebugLog("AUTOCLICK", "Auto-clicker deactivated", "INFO")
       SetTimer(ClickTheMouse, 0)
   }
}

UpdateCreatureStatusDisplay() {
   global
   CreatureStatusText.Text := "Selected: " . selectedCreatureName . " (Page " . selectedCreaturePage . ")"
}

UpdateSelectedCreatureFromName(creatureName) {
   global
   selectedCreatureName := creatureName
   creatureMap := Map("Dragons", {key: "dragons_btn", page: 1}, "Kobolds", {key: "kobolds_btn", page: 1}, "Undead", {key: "undead_btn", page: 2}, "Elementals", {key: "elementals_btn", page: 2}, "Giants", {key: "giants_btn", page: 3}, "Goblins", {key: "goblins_btn", page: 3}, "Minotaurs", {key: "minotaurs_btn", page: 4}, "Werewolves", {key: "werewolves_btn", page: 4}, "Humanoids", {key: "humanoids_btn", page: 5}, "Demons", {key: "demons_btn", page: 5}, "Insects", {key: "insects_btn", page: 6}, "Wyverns", {key: "wyverns_btn", page: 6}, "Vermins", {key: "vermins_btn", page: 7}, "Sea Creatures", {key: "sea_creatures_btn", page: 7}, "Animals", {key: "animals_btn", page: 8}, "Fungoids", {key: "fungoids_btn", page: 8})
   if (creatureMap.Has(creatureName)) {
       creatureInfo := creatureMap[creatureName]
       selectedCreature := creatureInfo.key
       selectedCreaturePage := creatureInfo.page
       UpdateCreatureStatusDisplay()
       DebugLog("SETTINGS", "Selected creature changed to: " . creatureName . " (Page " . selectedCreaturePage . ")", "INFO")
   }
}

ToggleMacro(*) {
   global
   isMacroToggled := !isMacroToggled
   if (isMacroToggled) {
       if (ocrEnabled && !ocrInitialized) {
           if (!InitializeOCR()) {
               isMacroToggled := false
               return
           }
       }
       macroStartTime := A_TickCount
       macroStep := 0
       macroState := "running"
       questState := "seeking"
       currentSequence := "main"
       MacroActionText.Visible := true
       CreatureStatusText.Visible := true
       QuestDecisionText.Visible := false
       if (ocrEnabled) {
           KillCountText.Visible := true
       }
       UpdateCreatureStatusDisplay()
       PlaySound("success")
       DebugLog("MACRO", "Quest macro started", "SUCCESS")
       if (!isPaused) {
           SetTimer(RunMacro, -macroWaitTime)
       }
   } else {
       if (macroStartTime > 0) {
           previousActionRuntime := FormatElapsedTime((A_TickCount - macroStartTime) / 1000)
       }
       macroStartTime := 0
       macroState := "idle"
       questState := "seeking"
       MacroActionText.Visible := false
       CreatureStatusText.Visible := false
       QuestDecisionText.Visible := false
       KillCountText.Visible := false
       PlaySound("error")
       DebugLog("MACRO", "Quest macro stopped", "INFO")
       SetTimer(RunMacro, 0)
   }
}

; --- MACRO SYSTEM ---
RunMacro() {
   global
   if (!isMacroToggled || isPaused) {
       return
   }
   
   ; Determine which sequence we're in
   local currentActionList := ""
   switch currentSequence {
       case "main":
           currentActionList := macroSequence
       case "normal":
           currentActionList := normalQuestSequence
       case "rejection":
           currentActionList := rejectionSequence
   }
   
   if (macroStep >= currentActionList.Length) {
       if (currentSequence == "main") {
           ; Main sequence completed, should have branched by now
           DebugLog("MACRO", "Main sequence completed without branching", "ERROR")
           ToggleMacro()
           return
       }
       macroStep := 0
       totalMacroRuns++
   }
   
   currentAction := currentActionList[macroStep + 1]
   MacroActionText.Text := currentAction.description
   DebugLog("MACRO", "Executing: " . currentAction.description, "INFO")
   
   switch currentAction.action {
       case "click_npc":
           coord := coords["dtm_npc"]
           if (coord) {
               HumanizedClick(coord.x, coord.y)
               totalClicks++
               DebugLog("MACRO", "Clicked NPC at " . coord.x . "," . coord.y, "SUCCESS")
           }
       
       case "check_quest_state":
           if (ocrEnabled) {
               questState := CheckQuestState()
               MacroActionText.Text := "Quest State: " . questState
           } else {
               DebugLog("MACRO", "OCR not enabled, assuming no quest", "WARNING")
               questState := "no_quest"
           }
       
       case "branch_sequence":
           if (questState == "has_quest") {
               currentSequence := "rejection"
               macroStep := -1
               MacroActionText.Text := "Existing quest detected - rejecting first"
               DebugLog("MACRO", "Branching to rejection sequence", "INFO")
           } else {
               currentSequence := "normal"
               macroStep := -1
               MacroActionText.Text := "No quest detected - proceeding normally"
               DebugLog("MACRO", "Branching to normal sequence", "INFO")
           }
       
       case "ocr_click":
           if (ocrEnabled) {
               success := FindAndClickButton(currentAction.text)
               if (!success) {
                   MacroActionText.Text := "Failed to find: " . currentAction.text
                   DebugLog("MACRO", "Failed to find button: " . currentAction.text, "ERROR")
               }
           } else {
               DebugLog("MACRO", "OCR not enabled, skipping button: " . currentAction.text, "WARNING")
           }
       
       case "navigate_to_creature_ocr":
           if (ocrEnabled) {
               NavigateToCreatureOCR()
           } else {
               DebugLog("MACRO", "OCR not enabled, cannot navigate to creature", "WARNING")
           }
       
       case "select_creature_ocr":
           if (ocrEnabled) {
               FindAndClickCreature(selectedCreatureName)
           } else {
               DebugLog("MACRO", "OCR not enabled, cannot select creature", "WARNING")
           }
       
       case "check_quest_number":
           if (ocrEnabled) {
               detectedQuestNumber := ReadQuestNumber()
               MacroActionText.Text := "Quest kills: " . detectedQuestNumber
           } else {
               DebugLog("MACRO", "OCR not enabled, cannot read quest number", "WARNING")
               detectedQuestNumber := 0
           }
       
       case "decide_quest":
           if (detectedQuestNumber > 1000) {
               MacroActionText.Text := "Good quest! (" . detectedQuestNumber . " kills)"
               DebugLog("MACRO", "Quest accepted: " . detectedQuestNumber . " kills", "SUCCESS")
               isMacroToggled := false
               SetTimer(RunMacro, 0)
               PlaySound("success")
               return
           } else {
               currentSequence := "rejection"
               macroStep := -1
               MacroActionText.Text := "Bad quest (" . detectedQuestNumber . " kills) - rejecting"
               DebugLog("MACRO", "Quest rejected: " . detectedQuestNumber . " kills", "WARNING")
           }
       
       case "restart_with_normal":
           currentSequence := "main"
           macroSequence := [
               {action: "click_npc", wait: 1500, description: "Click DTM NPC"},
               {action: "check_quest_state", wait: 500, description: "Checking quest state..."},
               {action: "branch_sequence", wait: 100, description: "Branching to appropriate sequence"}
           ]
           macroStep := -1
           DebugLog("MACRO", "Restarting macro sequence", "INFO")
       
       case "wait_for_decision":
           questState := "waiting_for_decision"
           QuestDecisionText.Visible := true
           QuestDecisionText.Text := "Quest Ready! F9=Reject, F10=Keep & Stop"
           MacroActionText.Text := "QUEST DECISION TIME!"
           DebugLog("MACRO", "Waiting for quest decision", "INFO")
           return
   }
   
   macroStep++
   nextWait := currentAction.HasProp("wait") ? currentAction.wait : macroWaitTime
   if (isMacroToggled && !isPaused) {
       SetTimer(RunMacro, -nextWait)
   }
}

RejectCurrentQuest() {
   global
   if (!isMacroToggled || questState != "waiting_for_decision") {
       DebugLog("MACRO", "Cannot reject - not in decision state", "WARNING")
       return
   }
   questState := "rejecting"
   currentSequence := "rejection"
   macroStep := 0
   QuestDecisionText.Text := "Rejecting quest..."
   MacroActionText.Text := "Quest rejected - starting rejection sequence"
   PlaySound("error")
   DebugLog("MACRO", "Quest rejection initiated", "INFO")
   if (!isPaused) {
       SetTimer(RunMacro, -100)
   }
}

; --- HUMANIZATION FUNCTIONS ---
HumanizedClick(x, y) {
   global
   if (!humanizeClicks) {
       Click(x, y)
       Sleep(baseClickDelay)
       return
   }
   offsetX := Random(-3, 3)
   offsetY := Random(-3, 3)
   finalX := x + offsetX
   finalY := y + offsetY
   MouseGetPos(&currentX, &currentY)
   distance := Sqrt((finalX - currentX)**2 + (finalY - currentY)**2)
   moveTime := Max(50, Min(300, distance * 2))
   if (distance > 10) {
       midX := (currentX + finalX) / 2 + Random(-5, 5)
       midY := (currentY + finalY) / 2 + Random(-5, 5)
       MouseMove(midX, midY, moveTime / 2)
       Sleep(Random(5, 15))
   }
   MouseMove(finalX, finalY, moveTime / 2)
   Sleep(Random(30, 80))
   Click(finalX, finalY)
   postDelay := baseClickDelay + Random(-20, 50)
   Sleep(Max(50, postDelay))
}

UpdateHumanization(CheckboxObj, *) {
   global
   humanizeClicks := CheckboxObj.Value
   DebugLog("SETTINGS", "Humanization " . (humanizeClicks ? "enabled" : "disabled"), "INFO")
}

; --- OCR TOGGLE ---
ToggleOCR(CheckboxObj, *) {
   global
   ocrEnabled := CheckboxObj.Value
   if (ocrEnabled) {
       if (!InitializeOCR()) {
           CheckboxObj.Value := false
           ocrEnabled := false
           return
       }
       PlaySound("success")
       DebugLog("OCR", "OCR system enabled", "SUCCESS")
   } else {
       ocrInitialized := false
       PlaySound("info")
       DebugLog("OCR", "OCR system disabled", "INFO")
   }
}

; --- CREATURE SELECTOR GUI ---
ShowCreatureSelector(*) {
   global
   if (CreatureGuiOpen) {
       CloseCreatureGui()
       return
   }
   if (ConfigGuiOpen) {
       CloseConfigGui()
   }
   CreatureGuiOpen := true
   CreatureGuiObj := CreateNoStealFocusGui("Select Creature")
   CreatureGuiObj.BackColor := "222222"
   CreatureGuiObj.SetFont("s9 cFFFFFF", "Verdana")
   CreatureGuiObj.OnEvent("Close", CloseCreatureGui)
   CreatureGuiObj.Add("Text", "x0 y0 w250 h25 Center Background333333", " Select Creature Type ")
   creatures := ["Dragons", "Kobolds", "Undead", "Elementals", "Giants", "Goblins", "Minotaurs", "Werewolves", "Humanoids", "Demons", "Insects", "Wyverns", "Vermins", "Sea Creatures", "Animals", "Fungoids"]
   creatureRadios := []
   y_start := 35
   Loop creatures.Length {
       x_pos := (Mod(A_Index - 1, 2) == 0) ? 15 : 130
       y_pos := y_start + (Floor((A_Index - 1) / 2) * 25)
       radio := CreatureGuiObj.Add("Radio", "x" . x_pos . " y" . y_pos . " cSilver", creatures[A_Index])
       if (creatures[A_Index] == selectedCreatureName) {
           radio.Value := true
       }
       creatureRadios.Push(radio)
   }
   y_button := y_start + (Floor((creatures.Length - 1) / 2) + 1) * 25 + 10
   selectBtn := CreatureGuiObj.Add("Button", "x40 y" . y_button . " w70 h25", "Select")
   cancelBtn := CreatureGuiObj.Add("Button", "x140 y" . y_button . " w70 h25", "Cancel")
   
   SelectCreatureHandler(*) {
       global
       Loop creatureRadios.Length {
           if (creatureRadios[A_Index].Value) {
               selectedCreatureName := creatures[A_Index]
               UpdateSelectedCreatureFromName(selectedCreatureName)
               CreatureCurrentText.Text := selectedCreatureName
               PlaySound("success")
               break
           }
       }
       CloseCreatureGui()
   }
   
   selectBtn.OnEvent("Click", SelectCreatureHandler)
   cancelBtn.OnEvent("Click", CloseCreatureGui)
   
   ; Make window draggable
   ; CreatureGuiObj.OnEvent("Click", (*) => PostMessage(0xA1, 2))
   
   CreatureGuiObj.Show("w250 h" . (y_button + 35))
   WinSetTransparent(CurrentTransparency, CreatureGuiObj.Hwnd)
   DebugLog("GUI", "Creature selector opened", "INFO")
}

CloseCreatureGui(*) {
   global
   if (IsObject(CreatureGuiObj)) {
       try {
           CreatureGuiObj.Destroy()
       } catch {
       }
   }
   CreatureGuiOpen := false
   CreatureGuiObj := ""
   DebugLog("GUI", "Creature selector closed", "INFO")
}

; --- COORDINATE CONFIGURATION GUI ---
ShowCoordinateConfig(*) {
   global
   if (ConfigGuiOpen) {
       CloseConfigGui()
       return
   }
   if (CreatureGuiOpen) {
       CloseCreatureGui()
   }
   ConfigGuiOpen := true
   ConfigGuiObj := CreateNoStealFocusGui("Configure Macro Coordinates")
   ConfigGuiObj.BackColor := "222222"
   ConfigGuiObj.SetFont("s9 cFFFFFF", "Verdana")
   ConfigGuiObj.OnEvent("Close", CloseConfigGui)
   ConfigGuiObj.Add("Text", "x0 y0 w400 h25 Center Background333333", " Configure Macro Coordinates ")
   y_pos := 35
   ConfigGuiObj.Add("Text", "x10 y" . y_pos . " w380 cLime", "Click 'Set', hover over target, press SPACE")
   y_pos += 25
   ConfigGuiObj.Add("Text", "x10 y" . y_pos . " w380 cGray", "════════════════════════════════════════")
   y_pos += 15
   
   ; Only show DTM NPC coordinate since we're using OCR for everything else
   ConfigGuiObj.Add("Text", "x10 y" . y_pos . " w200 cSilver", "DTM NPC Location:")
   coord := coords["dtm_npc"]
   posText := ConfigGuiObj.Add("Text", "x210 y" . y_pos . " w100 cWhite", coord.x . ", " . coord.y)
   setBtn := ConfigGuiObj.Add("Button", "x320 y" . (y_pos-2) . " w60 h20", "Set")
   setBtn.OnEvent("Click", SetCoordinate.Bind("dtm_npc", posText, coord, ConfigGuiObj))
   y_pos += 30
   
   ConfigGuiObj.Add("Text", "x10 y" . y_pos . " w380 cAqua Center", "All other buttons are detected using OCR")
   y_pos += 30
   
   saveBtn := ConfigGuiObj.Add("Button", "x10 y" . y_pos . " w120 h30", "Save & Close")
   saveBtn.OnEvent("Click", CloseConfigGui)
   testBtn := ConfigGuiObj.Add("Button", "x140 y" . y_pos . " w120 h30", "Test NPC Click")
   testBtn.OnEvent("Click", TestNPCClick)
   
   ; Make window draggable
   ; ConfigGuiObj.OnEvent("Click", (*) => PostMessage(0xA1, 2))
   
   ConfigGuiObj.Show("w400 h" . (y_pos + 45))
   WinSetTransparent(CurrentTransparency, ConfigGuiObj.Hwnd)
   DebugLog("GUI", "Coordinate configuration opened", "INFO")
}

CloseConfigGui(*) {
   global
   if (IsObject(ConfigGuiObj)) {
       try {
           ConfigGuiObj.Destroy()
       } catch {
       }
   }
   ConfigGuiOpen := false
   ConfigGuiObj := ""
   DebugLog("GUI", "Coordinate configuration closed", "INFO")
}

SetCoordinate(coordKey, textControl, coordObj, parentGui, *) {
   global CurrentTransparency
   parentGui.Hide()
   InstructGui := CreateNoStealFocusGui("Set Coordinate")
   InstructGui.BackColor := "1a1a1a"
   InstructGui.SetFont("s10 Bold cFFFFFF", "Verdana")
   InstructGui.Add("Text", "x10 y10 w300 Center", "Hover over target location")
   InstructGui.SetFont("s9 Norm", "Verdana")
   InstructGui.Add("Text", "x10 y35 w300 Center", "Setting: " . coordObj.name)
   InstructGui.Add("Text", "x10 y60 w300 Center cLime", "Press SPACE to set coordinate")
   InstructGui.Add("Text", "x10 y80 w300 Center cRed", "Press ESC to cancel")
   CoordDisplay := InstructGui.Add("Text", "x10 y110 w300 Center", "Current Position: 0, 0")
   CoordDisplay.SetFont("s10")
   InstructGui.Show("w320 h140")
   
   UpdateMousePos() {
       if WinExist("Set Coordinate") {
           MouseGetPos(&currentX, &currentY)
           CoordDisplay.Text := "Current Position: " . currentX . ", " . currentY
       }
   }
   
   SetTimer(UpdateMousePos, 50)
   savedCoords := {x: 0, y: 0, set: false}
   
   SpaceCapture(*) {
       MouseGetPos(&captureX, &captureY)
       savedCoords.x := captureX
       savedCoords.y := captureY
       savedCoords.set := true
       CoordDisplay.SetFont("cYellow")
       CoordDisplay.Text := "CAPTURED: " . captureX . ", " . captureY
       PlaySound("success")
       Sleep(500)
       Hotkey("Space", "Off")
       Hotkey("Escape", "Off")
       SetTimer(UpdateMousePos, 0)
       InstructGui.Close()
   }
   
   EscapeCancel(*) {
       Hotkey("Space", "Off")
       Hotkey("Escape", "Off")
       SetTimer(UpdateMousePos, 0)
       InstructGui.Close()
       PlaySound("error")
   }
   
   Hotkey("Space", SpaceCapture)
   Hotkey("Escape", EscapeCancel)
   WinWaitClose("Set Coordinate")
   try {
       Hotkey("Space", "Off")
       Hotkey("Escape", "Off")
   }
   parentGui.Show()
   if (savedCoords.set) {
       coordObj.x := savedCoords.x
       coordObj.y := savedCoords.y
       textControl.Text := savedCoords.x . ", " . savedCoords.y
       DebugLog("SETTINGS", "Coordinate set: " . coordKey . " = " . savedCoords.x . ", " . savedCoords.y, "SUCCESS")
   }
}

TestNPCClick(*) {
   coord := coords["dtm_npc"]
   MouseMove(coord.x, coord.y, 10)
   PlaySound("success")
   DebugLog("TEST", "Moved to NPC location: " . coord.x . ", " . coord.y, "INFO")
}

; --- CLEANUP AND EXIT ---
ExitScript(*) {
   DebugLog("SYSTEM", "Script exiting...", "WARNING")
   if (IsObject(debugGui)) {
       debugGui.Destroy()
   }
   ExitApp
}