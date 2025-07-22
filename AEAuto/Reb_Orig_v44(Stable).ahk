; Description:
; A multi-purpose tool featuring a key presser, autoclicker, mouse recorder,
; and a quest macro system with coordinate-based clicking.
;
; Hotkeys:
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

; --- SCRIPT SETTINGS ---
#SingleInstance Force
CoordMode("Mouse", "Screen")

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
global rejectionStep := 0 ; Added for rejection sequence
global macroState := "idle" ; idle, running, waiting_for_reset
global lastMacroAction := 0
global macroWaitTime := 2000 ; Default wait time between actions

; Coordinate storage for macro targets - Updated with your exact coordinates
global coords := Map()
coords["dtm_npc"] := {x: 1830, y: 1080, name: "DTM NPC"}
coords["continue_1st"] := {x: 1494, y: 888, name: "1st Continue"}
coords["continue_2nd"] := {x: 1496, y: 888, name: "2nd Continue"}
coords["sure_btn"] := {x: 1526, y: 816, name: "Sure!"}
coords["continue_3rd"] := {x: 1484, y: 882, name: "3rd Continue"}

; Creature selection - Page 1
coords["show_more_1"] := {x: 1402, y: 708, name: "Show More Creatures (Page 1)"}
coords["dragons_btn"] := {x: 1532, y: 766, name: "Dragons"}
coords["kobolds_btn"] := {x: 1510, y: 828, name: "Kobolds"}
coords["nevermind_1"] := {x: 1394, y: 886, name: "Nevermind (Page 1)"}

; Creature selection - Page 2
coords["show_more_2"] := {x: 1436, y: 694, name: "Show More Creatures (Page 2)"}
coords["undead_btn"] := {x: 1516, y: 756, name: "Undead"}
coords["elementals_btn"] := {x: 1494, y: 826, name: "Elementals"}
coords["nevermind_2"] := {x: 1386, y: 890, name: "Nevermind (Page 2)"}

; Creature selection - Page 3
coords["show_more_3"] := {x: 1436, y: 696, name: "Show More Creatures (Page 3)"}
coords["giants_btn"] := {x: 1518, y: 762, name: "Giants"}
coords["goblins_btn"] := {x: 1502, y: 824, name: "Goblins"}
coords["nevermind_3"] := {x: 1396, y: 890, name: "Nevermind (Page 3)"}

; Creature selection - Page 4
coords["show_more_4"] := {x: 1436, y: 696, name: "Show More Creatures (Page 4)"}
coords["minotaurs_btn"] := {x: 1500, y: 750, name: "Minotaurs"}
coords["werewolves_btn"] := {x: 1476, y: 824, name: "Werewolves"}
coords["nevermind_4"] := {x: 1396, y: 890, name: "Nevermind (Page 4)"}

; Creature selection - Page 5
coords["show_more_5"] := {x: 1472, y: 686, name: "Show More Creatures (Page 5)"}
coords["humanoids_btn"] := {x: 1498, y: 756, name: "Humanoids"}
coords["demons_btn"] := {x: 1510, y: 820, name: "Demons"}
coords["nevermind_5"] := {x: 1388, y: 892, name: "Nevermind (Page 5)"}

; Creature selection - Page 6
coords["show_more_6"] := {x: 1420, y: 692, name: "Show More Creatures (Page 6)"}
coords["insects_btn"] := {x: 1508, y: 760, name: "Insects"}
coords["wyverns_btn"] := {x: 1496, y: 828, name: "Wyverns"}
coords["nevermind_6"] := {x: 1416, y: 886, name: "Nevermind (Page 6)"}

; Creature selection - Page 7
coords["show_more_7"] := {x: 1396, y: 694, name: "Show More Creatures (Page 7)"}
coords["vermins_btn"] := {x: 1508, y: 756, name: "Vermins"}
coords["sea_creatures_btn"] := {x: 1478, y: 822, name: "Sea Creatures"}
coords["nevermind_7"] := {x: 1402, y: 890, name: "Nevermind (Page 7)"}

; Creature selection - Page 8
coords["animals_btn"] := {x: 1530, y: 758, name: "Animals"}
coords["fungoids_btn"] := {x: 1488, y: 830, name: "Fungoids"}
coords["nevermind_8"] := {x: 1390, y: 890, name: "Nevermind (Page 8)"}

; After creature selection
coords["continue_after_creature"] := {x: 1486, y: 886, name: "Continue After Creature"}
coords["extra_challenge_btn"] := {x: 1354, y: 822, name: "Yes I Need Extra Challenge"}

; Rejection sequence
coords["dtm_reject"] := {x: 1818, y: 1086, name: "DTM NPC (Reject)"}
coords["continue_reject_1st"] := {x: 1478, y: 882, name: "1st Continue (Reject)"}
coords["continue_reject_2nd"] := {x: 1482, y: 886, name: "2nd Continue (Reject)"}
coords["not_strong_btn"] := {x: 1354, y: 820, name: "Yes I Am Not Strong Enough"}
coords["continue_reject_3rd"] := {x: 1482, y: 890, name: "3rd Continue (Reject)"}
coords["continue_reject_4th"] := {x: 1482, y: 890, name: "4th Continue (Reject)"}

; All creature types organized by page with their show_more buttons
global creatureData := Map()
creatureData[1] := {creatures: ["dragons_btn", "kobolds_btn"], show_more: "show_more_1"}
creatureData[2] := {creatures: ["undead_btn", "elementals_btn"], show_more: "show_more_2"}
creatureData[3] := {creatures: ["giants_btn", "goblins_btn"], show_more: "show_more_3"}
creatureData[4] := {creatures: ["minotaurs_btn", "werewolves_btn"], show_more: "show_more_4"}
creatureData[5] := {creatures: ["humanoids_btn", "demons_btn"], show_more: "show_more_5"}
creatureData[6] := {creatures: ["insects_btn", "wyverns_btn"], show_more: "show_more_6"}
creatureData[7] := {creatures: ["vermins_btn", "sea_creatures_btn"], show_more: "show_more_7"}
creatureData[8] := {creatures: ["animals_btn", "fungoids_btn"], show_more: ""}  ; Page 8 has no show_more

; Creature selection settings
global selectedCreature := "dragons_btn" ; Default creature
global selectedCreaturePage := 1
global selectedCreatureName := "Dragons"

global currentCreaturePage := 1
global currentCreatureIndex := 1
global questAcceptanceTimeout := 10000 ; 10 seconds to decide if quest is good
global questState := "seeking" ; seeking, waiting_for_decision, rejecting
global baseClickDelay := 350 ; Base delay between clicks in milliseconds
global humanizeClicks := true ; Enable humanization features

; OCR and Text Detection Variables
global ocrEnabled := false
global killCountRegion := {x: 0, y: 0, w: 200, h: 50}  ; Region to check for kill count
global continueButtonRegion := {x: 0, y: 0, w: 200, h: 50}  ; Region for continue button
global lastDetectedKills := 0
global autoClickContinue := false

; Macro sequence configuration - Updated with new coordinates
global macroSequence := [
    {action: "click", target: "dtm_npc", wait: 1500, description: "Click DTM NPC"},
    {action: "click", target: "continue_1st", wait: 1000, description: "Click 1st Continue"},
    {action: "click", target: "continue_2nd", wait: 1000, description: "Click 2nd Continue"},
    {action: "click", target: "sure_btn", wait: 1000, description: "Click Sure!"},
    {action: "click", target: "continue_3rd", wait: 1500, description: "Click 3rd Continue to creatures"},
    {action: "navigate_to_creature", wait: 1000, description: "Navigate to selected creature"},
    {action: "select_chosen_creature", wait: 2000, description: "Select chosen creature type"},
    {action: "click", target: "continue_after_creature", wait: 1000, description: "Click Continue after creature"},
    {action: "click", target: "extra_challenge_btn", wait: 3000, description: "Click Yes I Need Extra Challenge"},
    {action: "wait_for_decision", wait: questAcceptanceTimeout, description: "Waiting for quest decision..."},
    {action: "check_continue_or_reject", description: "Continue with quest or reject and retry"}
]

; Rejection sequence when quest is not good enough - Updated coordinates
global rejectionSequence := [
    {action: "click", target: "dtm_reject", wait: 1000, description: "Click DTM NPC to reject"},
    {action: "click", target: "continue_reject_1st", wait: 1000, description: "Click 1st Continue (Reject)"},
    {action: "click", target: "continue_reject_2nd", wait: 1000, description: "Click 2nd Continue (Reject)"},
    {action: "click", target: "not_strong_btn", wait: 1000, description: "Click Yes I Am Not Strong Enough"},
    {action: "click", target: "continue_reject_3rd", wait: 1000, description: "Click 3rd Continue (Reject)"},
    {action: "click", target: "continue_reject_4th", wait: 1500, description: "Click 4th Continue to cancel quest"},
    {action: "restart_same_creature", description: "Restart with same creature"}
]

; --- SOUND FUNCTIONS ---
PlaySound(type := "info") {
    try {
        switch type {
            case "error":
                SoundPlay("*16") ; SystemHand
            case "success":
                SoundPlay("*64") ; SystemDefault / Asterisk
            case "warning":
                SoundPlay("*48") ; SystemExclamation
            case "info":
                SoundPlay("*64") ; SystemDefault / Asterisk
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
global SetKillRegionBtn := MyGui.Add("Button", "x10 y500 w125 h20", "Set Kill Region")
SetKillRegionBtn.Visible := false
global AutoContinueCheck := MyGui.Add("Checkbox", "x145 y500 w120", "Auto-Continue")
AutoContinueCheck.Visible := false

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
HotkeyTexts.Push(MyGui.Add("Text", "x10 y350 cSilver", "F12: Exit Program"))
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
HumanizeCheckbox.OnEvent("Click", UpdateHumanization)
ConfigCoordsBtn.OnEvent("Click", ShowCoordinateConfig)
OCRCheckbox.OnEvent("Click", ToggleOCR)
SetKillRegionBtn.OnEvent("Click", SetKillCountRegion)
AutoContinueCheck.OnEvent("Click", ToggleAutoContinue)
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
global gameTitle := "Ashen Empires"  ; Specific game title for better targeting

; Function to restore focus to game
RestoreGameFocus() {
    global gameWindow, gameTitle
    ; Try multiple methods to keep game active
    try {
        if WinExist(gameTitle) {
            WinActivate(gameTitle)
        } else if (gameWindow) {
            WinActivate(gameWindow)
        }
    }
}

; Enhanced GUI creation for popups that won't minimize games
CreateNoStealFocusGui(title) {
    global gameTitle
    ; Create GUI with special properties to prevent game minimizing
    newGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000", title)
    
    ; Try to find the game window and set it as owner
    gameHwnd := WinExist(gameTitle)
    if (!gameHwnd) {
        gameHwnd := WinExist("A") ; Use active window if game not found
    }
    
    ; Set the game window as parent to prevent focus stealing
    if (gameHwnd) {
        try {
            ; Use SetWindowLongPtr for 64-bit compatibility
            if (A_PtrSize = 8) { ; 64-bit
                DllCall("SetWindowLongPtr", "Ptr", newGui.Hwnd, "Int", -8, "Ptr", gameHwnd)
            } else { ; 32-bit
                DllCall("SetWindowLong", "Ptr", newGui.Hwnd, "Int", -8, "Ptr", gameHwnd)
            }
        }
    }
    
    return newGui
}

; --- HOTKEY DEFINITIONS ---
PgUp::ToggleKeyPresser()
PgDn::ToggleClicker()
F10::ToggleMacro()
F9::RejectCurrentQuest()
Home::ToggleMouseRecording()
End::TogglePlayback()
MButton::F1ClickMacro()
~Enter::HandleEnterKey()
F11::ShowCoordinateConfig()
F12::ExitApp

; Context-sensitive hotkey for closing sub-GUIs
#HotIf WinActive("Select Creature") or WinActive("Configure Macro Coordinates")
Escape:: {
    global
    if (CreatureGuiOpen) {
        CloseCreatureGui()
    }
    if (ConfigGuiOpen) {
        CloseConfigGui()
    }
}
#HotIf ; Turn off context-sensitivity

; --- CORE FUNCTIONS ---
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
        PlaySound("warning")
        SetTimer(PressTheKey, 0)
        SetTimer(ClickTheMouse, 0)
        SetTimer(RunMacro, 0)
    } else {
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
    controls := [OptionsTitle, KeyDelayLabel, KeyDelaySlider, KeyDelayText, ClickDelayLabel, ClickDelaySlider, ClickDelayText, TransLabel, TransSlider, TransText, MacroWaitLabel, MacroWaitSlider, MacroWaitText, CreatureLabel, CreatureCurrentText, CreatureChangeBtn, HumanizeLabel, HumanizeCheckbox, ConfigCoordsBtn, OCRLabel, OCRCheckbox, SetKillRegionBtn, AutoContinueCheck]
    for control in controls {
        control.Visible := true
    }
    MyGui.Move(,, 280, 530)
    OptionsButton.Text := "Hide Options"
}

HideOptionsSection() {
    global
    controls := [OptionsTitle, KeyDelayLabel, KeyDelaySlider, KeyDelayText, ClickDelayLabel, ClickDelaySlider, ClickDelayText, TransLabel, TransSlider, TransText, MacroWaitLabel, MacroWaitSlider, MacroWaitText, CreatureLabel, CreatureCurrentText, CreatureChangeBtn, HumanizeLabel, HumanizeCheckbox, ConfigCoordsBtn, OCRLabel, OCRCheckbox, SetKillRegionBtn, AutoContinueCheck]
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
    MyGui.Move(,, 280, 380)
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
    SetTimer(PressTheKey, -CurrentKeyDelay)
}

ClickTheMouse() {
    global
    if (!isClickerToggled || isPaused) {
        return
    }
    Click()
    totalClicks++
    SetTimer(ClickTheMouse, -CurrentClickDelay)
}

F1ClickMacro() {
    global totalClicks  ; Added missing global declaration
    Send("{F1}")
    Sleep(550)
    MouseGetPos(&x, &y)
    HumanizedClick(x, y)
    totalClicks++
}

; --- MOUSE RECORDING (Simplified) ---
ToggleMouseRecording(*) {
    global
    if (isPlayingBack) {
        return
    }
    isRecording := !isRecording
    if (isRecording) {
        recordedActions := []
        PlaySound("success")
    } else {
        PlaySound("info")
        totalRecordings++
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
    }
}

StopPlayback() {
    global
    isPlayingBack := false
}

; --- UPDATE FUNCTIONS ---
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

UpdateMacroWait(SliderObj, *) {
    global
    macroWaitTime := SliderObj.Value
    MacroWaitText.Text := macroWaitTime . "ms"
}

UpdateGuiDisplay() {
    global
    if (isKeyPressToggled) {
        KeypressStatusText.SetFont("cLime")
        local elapsed := FormatTime((A_TickCount - keyPressStartTime) / 1000)
        KeypressStatusText.Text := "Keypress: ON (" . elapsed . ")"
    } else {
        KeypressStatusText.SetFont("cWhite")
        KeypressStatusText.Text := "Keypress: OFF"
    }
    if (isClickerToggled) {
        ClickerStatusText.SetFont("cLime")
        local elapsed := FormatTime((A_TickCount - clickerStartTime) / 1000)
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
            local elapsed := FormatTime((A_TickCount - macroStartTime) / 1000)
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
        SessionTimeText.Text := "Session Time: " . FormatTime(sessionTime)
        TotalClicksText.Text := "Total Clicks: " . totalClicks
        TotalKeysText.Text := "Keys Pressed: " . totalKeyPresses
        MacroRunsText.Text := "Macro Runs: " . totalMacroRuns
        RecordingsText.Text := "Recordings: " . totalRecordings
        PlaybacksText.Text := "Playbacks: " . totalPlaybacks
    }
    if (ocrEnabled && isMacroToggled) {
        KillCountText.Visible := true
        if (lastDetectedKills > 0) {
            KillCountText.Text := "Kills Remaining: " . lastDetectedKills
            KillCountText.SetFont("cLime")
        } else {
            KillCountText.Text := "Kills: Detecting..."
            KillCountText.SetFont("cFFA500")
        }
    } else {
        KillCountText.Visible := false
    }
}

FormatTime(totalSeconds) {
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
    }
}

ExportStats(*) {
    global
    sessionTime := (A_TickCount - sessionStartTime) / 1000
    statsText := "=== AutoHotkey Multi-Tool Statistics ===`n`n"
    statsText .= "Session Time: " . FormatTime(sessionTime) . "`n"
    statsText .= "Total Clicks: " . totalClicks . "`n"
    statsText .= "Total Keys Pressed: " . totalKeyPresses . "`n"
    statsText .= "Total Macro Runs: " . totalMacroRuns . "`n"
    statsText .= "Total Recordings: " . totalRecordings . "`n"
    statsText .= "Total Playbacks: " . totalPlaybacks . "`n`n"
    statsText .= "Current Settings:`n"
    statsText .= "- Key Delay: " . CurrentKeyDelay . "ms`n"
    statsText .= "- Click Delay: " . CurrentClickDelay . "ms`n"
    statsText .= "- Macro Wait Time: " . macroWaitTime . "ms`n`n"
    statsText .= "Macro Coordinates:`n"
    for key, coord in coords.OwnProps() {
        statsText .= "- " . coord.name . ": " . coord.x . ", " . coord.y . "`n"
    }
    statsText .= "`nExported: " . FormatDateTime(A_Now)
    A_Clipboard := statsText
    PlaySound("success")
    MsgBox("Statistics copied to clipboard!", "Export Complete", 64)
}

FormatDateTime(dateTime) {
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
        if (!isPaused) {
            SetTimer(PressTheKey, -CurrentKeyDelay)
        }
    } else {
        if (keyPressStartTime > 0) {
            previousActionRuntime := FormatTime((A_TickCount - keyPressStartTime) / 1000)
        }
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
        if (clickerStartTime > 0) {
            previousActionRuntime := FormatTime((A_TickCount - clickerStartTime) / 1000)
        }
        clickerStartTime := 0
        PlaySound("error")
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
    }
}

ToggleMacro(*) {
    global
    isMacroToggled := !isMacroToggled
    if (isMacroToggled) {
        macroStartTime := A_TickCount
        macroStep := 0
        macroState := "running"
        questState := "seeking"
        MacroActionText.Visible := true
        CreatureStatusText.Visible := true
        QuestDecisionText.Visible := false
        if (ocrEnabled) {
            KillCountText.Visible := true
        }
        UpdateCreatureStatusDisplay()
        PlaySound("success")
        if (!isPaused) {
            SetTimer(RunMacro, -macroWaitTime)
        }
    } else {
        if (macroStartTime > 0) {
            previousActionRuntime := FormatTime((A_TickCount - macroStartTime) / 1000)
        }
        macroStartTime := 0
        macroState := "idle"
        questState := "seeking"
        MacroActionText.Visible := false
        CreatureStatusText.Visible := false
        QuestDecisionText.Visible := false
        KillCountText.Visible := false
        PlaySound("error")
        SetTimer(RunMacro, 0)
    }
}

; --- MACRO SYSTEM ---
RunMacro() {
    global
    if (!isMacroToggled || isPaused) {
        return
    }
    if (questState == "rejecting") {
        RunRejectionSequence()
        return
    }
    if (macroStep >= macroSequence.Length) {
        macroStep := 0
        totalMacroRuns++
    }
    currentAction := macroSequence[macroStep + 1]
    MacroActionText.Text := "Macro: " . currentAction.description
    switch currentAction.action {
        case "click":
            coord := coords[currentAction.target]
            if (coord) {
                HumanizedClick(coord.x, coord.y)
                totalClicks++
            }
        case "navigate_to_creature":
            NavigateToSelectedCreature()
        case "select_chosen_creature":
            SelectChosenCreature()
        case "wait_for_decision":
            questState := "waiting_for_decision"
            QuestDecisionText.Visible := true
            QuestDecisionText.Text := "Quest Ready! F9=Reject, F10=Keep & Stop"
            MacroActionText.Text := "QUEST DECISION TIME!"
            return
        case "check_continue_or_reject":
            macroStep := -1
    }
    macroStep++
    nextWait := currentAction.HasProp("wait") ? currentAction.wait : macroWaitTime
    if (isMacroToggled && !isPaused) {
        SetTimer(RunMacro, -nextWait)
    }
}

RunRejectionSequence() {
    global
    if (rejectionStep >= rejectionSequence.Length) {
        questState := "seeking"
        macroStep := 0
        rejectionStep := 0
        QuestDecisionText.Visible := false
        MacroActionText.Text := "Macro: Restarting..."
        if (isMacroToggled && !isPaused) {
            SetTimer(RunMacro, -macroWaitTime)
        }
        return
    }
    currentAction := rejectionSequence[rejectionStep + 1]
    MacroActionText.Text := "Rejecting: " . currentAction.description
    switch currentAction.action {
        case "click":
            coord := coords[currentAction.target]
            if (coord) {
                HumanizedClick(coord.x, coord.y)
                totalClicks++
            }
        case "restart_same_creature":
            ; Do nothing, just restart
    }
    rejectionStep++
    nextWait := currentAction.HasProp("wait") ? currentAction.wait : macroWaitTime
    if (isMacroToggled && !isPaused) {
        SetTimer(RunMacro, -nextWait)
    }
}

RejectCurrentQuest() {
    global
    if (!isMacroToggled || questState != "waiting_for_decision") {
        return
    }
    questState := "rejecting"
    rejectionStep := 0
    QuestDecisionText.Text := "Rejecting quest..."
    MacroActionText.Text := "Quest rejected - starting rejection sequence"
    PlaySound("error")
    if (!isPaused) {
        SetTimer(RunMacro, -100)
    }
}

NavigateToSelectedCreature() {
    global
    targetPage := selectedCreaturePage
    clicksNeeded := targetPage - 1
    MacroActionText.Text := "Navigating to " . selectedCreatureName . " (Page " . targetPage . ")"
    Loop clicksNeeded {
        pageData := creatureData[A_Index]
        if (pageData.show_more != "") {
            coord := coords[pageData.show_more]
            if (coord) {
                HumanizedClick(coord.x, coord.y)
                totalClicks++
                Sleep(800)
            }
        }
    }
}

SelectChosenCreature() {
    global
    coord := coords[selectedCreature]
    if (coord) {
        HumanizedClick(coord.x, coord.y)
        totalClicks++
        MacroActionText.Text := "Selected: " . selectedCreatureName
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
}

; --- OCR AND TEXT DETECTION FUNCTIONS ---
ToggleOCR(CheckboxObj, *) {
    global
    ocrEnabled := CheckboxObj.Value
    if (ocrEnabled) {
        SetTimer(CheckGameText, 1000)  ; Check every second
        PlaySound("success")
    } else {
        SetTimer(CheckGameText, 0)
        PlaySound("info")
    }
}

ToggleAutoContinue(CheckboxObj, *) {
    global
    autoClickContinue := CheckboxObj.Value
}

; Simple OCR using Windows OCR (requires Windows 10/11)
PerformOCR(x, y, w, h) {
    ; Create a temporary screenshot of the region
    tempFile := A_Temp . "\ahk_ocr_temp.png"
    
    ; Take screenshot of region
    RunWait("snippingtool /clip", , "Hide")
    
    ; For now, we'll use a simpler approach with ImageSearch
    ; You can expand this with actual OCR libraries later
    return ""
}

; Alternative: Look for specific text patterns using ImageSearch
CheckForText(region, textImage) {
    ; Search for pre-captured text images
    try {
        ImageSearch(&foundX, &foundY, region.x, region.y, region.x + region.w, region.y + region.h, textImage)
        return {found: true, x: foundX, y: foundY}
    } catch {
        return {found: false, x: 0, y: 0}
    }
}

; Simple text detection using pixel patterns
DetectNumbers(x, y, w, h) {
    ; This is a simplified number detection
    ; You would need to capture pixel patterns for each number in your game
    detectedText := ""
    
    ; Example: Check for white text on dark background
    Loop w {
        xPos := x + A_Index - 1
        pixelColor := PixelGetColor(xPos, y)
        ; Check if pixel is white-ish (text color)
        if ((pixelColor & 0xFFFFFF) > 0xCCCCCC) {
            detectedText .= "1" ; Simplified - you'd need pattern matching
        }
    }
    
    return detectedText
}

; Check game text periodically
CheckGameText() {
    global
    if (!ocrEnabled) {
        return
    }
    
    ; Example: Check for "Continue" button
    if (autoClickContinue) {
        ; Look for white text that says "Continue"
        ; You can use ImageSearch with a pre-captured image of "Continue"
        ; Or use pixel pattern detection
        
        ; Simple pixel check for a button
        pixelColor := PixelGetColor(continueButtonRegion.x, continueButtonRegion.y)
        if ((pixelColor & 0xFFFFFF) > 0xCCCCCC) { ; If pixel is white-ish
            HumanizedClick(continueButtonRegion.x + 50, continueButtonRegion.y + 10)
            totalClicks++
            Sleep(1000) ; Prevent multiple clicks
        }
    }
    
    ; Check kill count region
    if (killCountRegion.w > 0) {
        ; Simple number detection in kill count area
        detectedNum := DetectNumbers(killCountRegion.x, killCountRegion.y, killCountRegion.w, killCountRegion.h)
        if (detectedNum != "") {
            try {
                lastDetectedKills := Integer(detectedNum)
            }
        }
    }
}

; Set region for kill count detection
SetKillCountRegion(*) {
    global
    RegionGui := CreateNoStealFocusGui("Set Detection Region")
    RegionGui.BackColor := "222222"
    RegionGui.SetFont("s10 cFFFFFF", "Verdana")
    RegionGui.Add("Text", "x10 y10 w300 Center", "Select Region Type")
    
    killRadio := RegionGui.Add("Radio", "x50 y40 w100", "Kill Count")
    killRadio.Value := true
    continueRadio := RegionGui.Add("Radio", "x160 y40 w100", "Continue Button")
    
    RegionGui.Add("Text", "x10 y70 w300 Center cYellow", "Click and drag to select the area")
    RegionGui.Add("Text", "x10 y95 w300 Center cLime", "Press ESC to cancel")
    startBtn := RegionGui.Add("Button", "x75 y125 w70 h25", "Start")
    cancelBtn := RegionGui.Add("Button", "x165 y125 w70 h25", "Cancel")
    
    StartSelection(*) {
        global killCountRegion, continueButtonRegion
        isKillCount := killRadio.Value
        RegionGui.Destroy()
        
        ; Create overlay for selection
        OverlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "Selection")
        OverlayGui.BackColor := isKillCount ? "Lime" : "Aqua"
        WinSetTransparent(50, OverlayGui.Hwnd)
        
        selecting := false
        startX := 0
        startY := 0
        
        ; Function to handle left button down
        OnLButtonDown() {
            MouseGetPos(&startX, &startY)
            selecting := true
        }
        
        ; Function to handle left button up
        OnLButtonUp() {
            if (selecting) {
                MouseGetPos(&endX, &endY)
                targetRegion := isKillCount ? killCountRegion : continueButtonRegion
                targetRegion.x := Min(startX, endX)
                targetRegion.y := Min(startY, endY)
                targetRegion.w := Abs(endX - startX)
                targetRegion.h := Abs(endY - startY)
                selecting := false
                OverlayGui.Destroy()
                Hotkey("LButton", "Off")
                Hotkey("LButton Up", "Off")
                Hotkey("Escape", "Off")
                PlaySound("success")
                regionType := isKillCount ? "Kill count" : "Continue button"
                MsgBox(regionType . " region set!", "Success", 64)
                RestoreGameFocus()
            }
        }
        
        ; Function to handle escape key
        OnEscapeKey() {
            OverlayGui.Destroy()
            Hotkey("LButton", "Off")
            Hotkey("LButton Up", "Off")
            Hotkey("Escape", "Off")
            RestoreGameFocus()
        }
        
        ; Hotkeys for selection
        Hotkey("LButton", OnLButtonDown)
        Hotkey("LButton Up", OnLButtonUp)
        Hotkey("Escape", OnEscapeKey)
        
        ; Update overlay position
        UpdateOverlay() {
            if (selecting) {
                MouseGetPos(&currentX, &currentY)
                OverlayGui.Move(Min(startX, currentX), Min(startY, currentY), Abs(currentX - startX), Abs(currentY - startY))
                OverlayGui.Show("NA")
            }
        }
        
        SetTimer(UpdateOverlay, 10)
    }
    
    startBtn.OnEvent("Click", StartSelection)
    cancelBtn.OnEvent("Click", (*) => RegionGui.Destroy())
    RegionGui.Show("w310 h160")
    RestoreGameFocus()
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
    OnMessage(0x201, CreatureGuiDrag)
    
    CreatureGuiDrag(wParam, lParam, msg, hwnd) {
        global CreatureGuiObj
        if (IsObject(CreatureGuiObj) && hwnd = CreatureGuiObj.Hwnd) {
            PostMessage(0xA1, 2)
        }
    }
    
    CreatureGuiObj.Show("w250 h" . (y_button + 35))
    WinSetTransparent(CurrentTransparency, CreatureGuiObj.Hwnd)
    RestoreGameFocus()
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
    for key, coord in coords.OwnProps() {
        ConfigGuiObj.Add("Text", "x10 y" . y_pos . " w200 cSilver", coord.name . ":")
        posText := ConfigGuiObj.Add("Text", "x210 y" . y_pos . " w100 cWhite", coord.x . ", " . coord.y)
        setBtn := ConfigGuiObj.Add("Button", "x320 y" . (y_pos-2) . " w60 h20", "Set")
        setBtn.OnEvent("Click", SetCoordinate.Bind(key, posText, coord, ConfigGuiObj))
        y_pos += 25
        if (key == "continue_3rd" || key == "nevermind_8" || key == "extra_challenge_btn" || key == "continue_reject_4th") {
            ConfigGuiObj.Add("Text", "x10 y" . y_pos . " w380 cGray", "────────────────────────────────────────")
            y_pos += 10
        }
    }
    y_pos += 10
    saveBtn := ConfigGuiObj.Add("Button", "x10 y" . y_pos . " w120 h30", "Save & Close")
    saveBtn.OnEvent("Click", CloseConfigGui)
    testBtn := ConfigGuiObj.Add("Button", "x140 y" . y_pos . " w120 h30", "Test All")
    testBtn.OnEvent("Click", TestAllCoordinates)
    quickSetBtn := ConfigGuiObj.Add("Button", "x270 y" . y_pos . " w120 h30", "Quick Setup")
    quickSetBtn.OnEvent("Click", ShowQuickSetupConfig)
    OnMessage(0x201, ConfigGuiDrag)
    
    ConfigGuiDrag(wParam, lParam, msg, hwnd) {
        global ConfigGuiObj
        if (IsObject(ConfigGuiObj) && hwnd = ConfigGuiObj.Hwnd) {
            PostMessage(0xA1, 2)
        }
    }
    
    ConfigGuiObj.Show("w400 h" . (y_pos + 45))
    WinSetTransparent(CurrentTransparency, ConfigGuiObj.Hwnd)
    RestoreGameFocus()
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
}

ShowQuickSetupConfig(*) {
    global
    QuickGui := CreateNoStealFocusGui("Quick Setup")
    QuickGui.BackColor := "222222"
    QuickGui.SetFont("s10 cFFFFFF", "Verdana")
    QuickGui.Add("Text", "x0 y0 w400 h25 Center Background333333", " Quick Coordinate Setup ")
    QuickGui.Add("Text", "x10 y40 w380 Center", "Quick Setup Mode")
    QuickGui.Add("Text", "x10 y65 w380 Center cYellow", "This will guide you through setting up key coordinates")
    QuickGui.Add("Text", "x10 y90 w380 Center cSilver", "Press SPACE when hovering over each target")
    startBtn := QuickGui.Add("Button", "x100 y120 w100 h30", "Start")
    cancelBtn := QuickGui.Add("Button", "x210 y120 w100 h30", "Cancel")
    OnMessage(0x201, QuickGuiDrag)
    
    QuickGuiDrag(wParam, lParam, msg, hwnd) {
        if (hwnd = QuickGui.Hwnd) {
            PostMessage(0xA1, 2)
        }
    }
    
    StartQuickSetup(*) {
        QuickGui.Close()
        essentialCoords := ["dtm_npc", "continue_1st", "continue_2nd", "sure_btn", "continue_3rd", "dragons_btn", "continue_after_creature", "extra_challenge_btn"]
        currentIndex := 1
        
        SetNextCoordinate() {
            global coords, CurrentTransparency
            if (currentIndex > essentialCoords.Length) {
                CompletionGui := CreateNoStealFocusGui("Complete")
                CompletionGui.BackColor := "222222"
                CompletionGui.SetFont("s11 cFFFFFF", "Verdana")
                CompletionGui.Add("Text", "x0 y0 w300 h25 Center Background333333", " Setup Complete ")
                CompletionGui.Add("Text", "x10 y40 w280 Center cLime", "Quick setup completed successfully!")
                okBtn := CompletionGui.Add("Button", "x115 y80 w70 h25", "OK")
                okBtn.OnEvent("Click", (*) => CompletionGui.Close())
                CompletionGui.Show("w300 h115")
                WinSetTransparent(CurrentTransparency, CompletionGui.Hwnd)
                PlaySound("success")
                RestoreGameFocus()
                return
            }
            key := essentialCoords[currentIndex]
            coord := coords[key]
            SetupGui := CreateNoStealFocusGui("Quick Setup")
            SetupGui.BackColor := "1a1a1a"
            SetupGui.SetFont("s10 cFFFFFF", "Verdana")
            SetupGui.Add("Text", "x0 y0 w400 h25 Center Background0x0a0a0a", " Quick Setup - Step " . currentIndex . " of " . essentialCoords.Length . " ")
            SetupGui.Add("Text", "x10 y40 w380 Center cLime", "Setting: " . coord.name)
            SetupGui.Add("Text", "x10 y70 w380 Center", "Hover and press SPACE")
            CoordText := SetupGui.Add("Text", "x10 y100 w380 Center cAqua", "Position: 0, 0")
            CoordText.SetFont("s11 Bold")
            SetupGui.Add("Text", "x10 y130 w380 Center cGray", "Press ESC to skip this coordinate")
            SetupGui.Show("w400 h160")
            WinSetTransparent(230, SetupGui.Hwnd)
            RestoreGameFocus()
            OnMessage(0x201, SetupGuiDrag)
            
            SetupGuiDrag(wParam, lParam, msg, hwnd) {
                if (hwnd = SetupGui.Hwnd) {
                    PostMessage(0xA1, 2)
                }
            }
            
            UpdatePos() {
                try {
                    if WinExist("Quick Setup - Step") {
                        MouseGetPos(&mx, &my)
                        CoordText.Text := "Position: " . mx . ", " . my
                    }
                }
            }
            
            SetTimer(UpdatePos, 50)
            
            SpaceSet(*) {
                MouseGetPos(&captureX, &captureY)
                coord.x := captureX
                coord.y := captureY
                PlaySound("info")
                CoordText.SetFont("cYellow")  ; Changed from Opt("cYellow")
                CoordText.Text := "CAPTURED: " . captureX . ", " . captureY
                Sleep(500)
                Hotkey("Space", "Off")
                Hotkey("Escape", "Off")
                SetTimer(UpdatePos, 0)
                SetupGui.Close()
                currentIndex++
                SetNextCoordinate()
            }
            
            EscSkip(*) {
                Hotkey("Space", "Off")
                Hotkey("Escape", "Off")
                SetTimer(UpdatePos, 0)
                SetupGui.Close()
                currentIndex++
                SetNextCoordinate()
            }
            
            Hotkey("Space", SpaceSet)
            Hotkey("Escape", EscSkip)
        }
        
        SetNextCoordinate()
    }
    
    startBtn.OnEvent("Click", StartQuickSetup)
    cancelBtn.OnEvent("Click", (*) => QuickGui.Close())
    QuickGui.Show("w400 h165")
    WinSetTransparent(CurrentTransparency, QuickGui.Hwnd)
    RestoreGameFocus()
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
    RestoreGameFocus()
    
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
		CoordDisplay.SetFont("cYellow")  ; Changed from Opt("cYellow")
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
    }
}

TestAllCoordinates(*) {
    global coords
    for key, coord in coords.OwnProps() {
        MouseMove(coord.x, coord.y, 2)
        Sleep(500)
    }
    PlaySound("success")
}

; --- TEXT DETECTION SETUP GUIDE ---
; To use text detection features:
; 1. Enable OCR in Options menu
; 2. Set regions where you want to detect text (kill count, continue buttons, etc.)
; 3. For better accuracy, capture images of the text you want to detect
;    and save them as .png files in the script directory
;
; For ImageSearch method:
; - Capture screenshots of "Continue" buttons, quest text, etc.
; - Save as: continue_button.png, accept_quest.png, etc.
; - The script will search for these images in the specified regions
;
; For Pixel Detection method:
; - Identify the text color in your game (usually white or yellow)
; - The script checks for pixel patterns matching text
;
; Advanced OCR:
; - You can integrate Windows OCR API or Tesseract OCR
; - See AutoHotkey community forums for OCR library examples
