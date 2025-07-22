; ======================================================================================================================
; MACRO FILE:       dtm_quest.ahk
; DESCRIPTION:      A complex macro for completing the DTM quest, including creature selection and rejection logic.
;                   This file is designed to be loaded by the main script.
; ======================================================================================================================

class DTMQuestMacro {
    ; --- Basic Macro Properties ---
    Name := "DTM Quest"
    Description := "Automates the DTM quest, including creature selection and rejection."

    ; --- Internal State Variables ---
    macroStep := 0
    rejectionStep := 0
    questState := "idle" ; idle, seeking, waiting_for_decision, rejecting
    
    ; --- Configuration & Data (Declared here, initialized in __New) ---
    selectedCreatureKey := "dragons_btn"
    selectedCreatureName := "Dragons"
    selectedCreaturePage := 1
    coords := Map()
    creatureData := Map()
    macroSequence := []
    rejectionSequence := []

    __New() {
        ; Initialize coordinates as a Map
        this.coords := Map(
            "dtm_npc", {x: 1830, y: 1080, name: "DTM NPC"},
            "continue_1st", {x: 1494, y: 888, name: "1st Continue"},
            "continue_2nd", {x: 1496, y: 888, name: "2nd Continue"},
            "sure_btn", {x: 1526, y: 816, name: "Sure!"},
            "continue_3rd", {x: 1484, y: 882, name: "3rd Continue"},
            "show_more_1", {x: 1402, y: 708, name: "Show More (P1)"},
            "dragons_btn", {x: 1532, y: 766, name: "Dragons"},
            "kobolds_btn", {x: 1510, y: 828, name: "Kobolds"},
            "continue_after_creature", {x: 1486, y: 886, name: "Continue After Creature"},
            "extra_challenge_btn", {x: 1354, y: 822, name: "Yes, Extra Challenge"},
            "dtm_reject", {x: 1818, y: 1086, name: "DTM NPC (Reject)"},
            "continue_reject_1st", {x: 1478, y: 882, name: "1st Continue (Reject)"},
            "continue_reject_2nd", {x: 1482, y: 886, name: "2nd Continue (Reject)"},
            "not_strong_btn", {x: 1354, y: 820, name: "No, I'm Not Strong Enough"},
            "continue_reject_3rd", {x: 1482, y: 890, name: "3rd Continue (Reject)"},
            "continue_reject_4th", {x: 1482, y: 890, name: "4th Continue (Reject)"}
        )

        ; Initialize creature data
        this.creatureData := Map(
            1, Map("creatures", Map("Dragons", "dragons_btn", "Kobolds", "kobolds_btn"), "show_more", "show_more_1"),
            2, Map("creatures", Map("Undead", "undead_btn", "Elementals", "elementals_btn"), "show_more", "show_more_2")
        )

        this.macroSequence := [
            {action: "click", target: "dtm_npc", wait: 1500, description: "Click DTM NPC"},
            {action: "click", target: "continue_1st", wait: 1000, description: "Click 1st Continue"},
            {action: "click", target: "continue_2nd", wait: 1000, description: "Click 2nd Continue"},
            {action: "click", target: "sure_btn", wait: 1000, description: "Click Sure!"},
            {action: "click", target: "continue_3rd", wait: 1500, description: "Click 3rd Continue"},
            {action: "navigate_to_creature", wait: 1000, description: "Navigate to selected creature"},
            {action: "select_chosen_creature", wait: 2000, description: "Select chosen creature type"},
            {action: "click", target: "continue_after_creature", wait: 1000, description: "Click Continue after creature"},
            {action: "click", target: "extra_challenge_btn", wait: 3000, description: "Click Yes, Extra Challenge"},
            {action: "wait_for_decision", wait: 10000, description: "Waiting for quest decision..."}
        ]

        this.rejectionSequence := [
            {action: "click", target: "dtm_reject", wait: 1000, description: "Click DTM NPC to reject"},
            {action: "click", target: "continue_reject_1st", wait: 1000, description: "Click 1st Continue (Reject)"},
            {action: "click", target: "continue_reject_2nd", wait: 1000, description: "Click 2nd Continue (Reject)"},
            {action: "click", target: "not_strong_btn", wait: 1000, description: "Click Not Strong Enough"},
            {action: "click", target: "continue_reject_3rd", wait: 1000, description: "Click 3rd Continue (Reject)"},
            {action: "click", target: "continue_reject_4th", wait: 1500, description: "Click 4th Continue to cancel"},
            {action: "restart_macro", description: "Restarting macro run..."}
        ]
    }

    ; ==================================================================================================================
    ;                                                 REQUIRED CLASS METHODS
    ; ==================================================================================================================
    
    Start() {
        this.questState := "seeking"
        this.macroStep := 0
        this.rejectionStep := 0
    }

    Stop() {
        this.questState := "idle"
    }

    Reject() {
        if this.questState = "waiting_for_decision" {
            this.questState := "rejecting"
            this.rejectionStep := 0
        }
    }

    GetNextAction() {
        local currentAction := ""
        local sequence := ""

        if this.questState = "rejecting" {
            sequence := this.rejectionSequence
            if this.rejectionStep >= sequence.Length {
                this.questState := "seeking"
                this.macroStep := 0
                this.rejectionStep := 0
                return {type: "end_run", wait: 1000, infoText: "Rejection finished. Restarting."}
            }
            currentAction := sequence[this.rejectionStep + 1]
            this.rejectionStep++
        } else if this.questState = "seeking" {
            sequence := this.macroSequence
            if this.macroStep >= sequence.Length {
                this.macroStep := 0
                return {type: "end_run", wait: 1000, infoText: "Macro run finished."}
            }
            currentAction := sequence[this.macroStep + 1]
            this.macroStep++
        } else {
            ; If waiting or idle, do nothing. The main loop will time out.
            return "" 
        }

        local actionObject := Map()
        actionObject["wait"] := currentAction.HasProp("wait") ? currentAction.wait : 1000
        actionObject["infoText"] := currentAction.description

        switch currentAction.action {
            case "click":
                actionObject["type"] := "click"
                actionObject["x"] := this.coords[currentAction.target].x
                actionObject["y"] := this.coords[currentAction.target].y
            
            case "navigate_to_creature":
                clicksNeeded := this.selectedCreaturePage - 1
                if clicksNeeded > 0 {
                    showMoreKey := this.creatureData[1]["show_more"] ; Get show_more key from page 1
                    coord := this.coords[showMoreKey]
                    actionObject["type"] := "click"
                    actionObject["x"] := coord.x
                    actionObject["y"] := coord.y
                    ; Decrement the main macro step so the next GetNextAction call re-evaluates this step
                    this.macroStep-- 
                    this.selectedCreaturePage-- ; Decrement pages needed
                } else {
                    ; If no navigation is needed, just send an info update and continue
                    actionObject["type"] := "info"
                }

            case "select_chosen_creature":
                actionObject["type"] := "click"
                actionObject["x"] := this.coords[this.selectedCreatureKey].x
                actionObject["y"] := this.coords[this.selectedCreatureKey].y

            case "wait_for_decision":
                actionObject["type"] := "info"
                actionObject["infoText"] := "Quest Ready! Press F9 to REJECT."
                this.questState := "waiting_for_decision"

            case "restart_macro":
                actionObject["type"] := "info"
                this.questState := "seeking"
                this.macroStep := 0
        }
        
        return actionObject
    }

    ShowConfigGui() {
        ConfigGui := Gui("+AlwaysOnTop +ToolWindow", this.Name . " Configuration")
        ConfigGui.BackColor := "222222"
        ConfigGui.SetFont("s10 cFFFFFF", "Verdana")
        
        ; Title bar
        TitleBar := ConfigGui.Add("Text", "x0 y0 w500 h30 Center Background333333 0x200", this.Name . " Configuration")
        TitleBar.SetFont("s12 Bold")

        ; Creature selection section
        ConfigGui.Add("Text", "x20 y50 Section", "Select Creature Type:")
        creatureList := []
        
        ; Build creature list from all pages
        for pageNum, pageData in this.creatureData {
            creatures := pageData["creatures"]
            for name, key in creatures {
                creatureList.Push(name)
            }
        }
        
        CreatureDDL := ConfigGui.Add("DropDownList", "xs y+10 w200", creatureList)
        
        ; Find and select current creature
        selectedIndex := 1
        for i, name in creatureList {
            if name = this.selectedCreatureName {
                selectedIndex := i
                break
            }
        }
        CreatureDDL.Choose(selectedIndex)
        
        ; Update creature when selection changes
        CreatureDDL.OnEvent("Change", (*) => this._UpdateSelectedCreature(CreatureDDL.Text))

        ; Coordinates section with scrollable area
        ConfigGui.Add("Text", "xs y+30", "Click Coordinates (hover and press 'Set'):")
        
        ; Create a frame for coordinates
        CoordFrame := ConfigGui.Add("Text", "xs y+10 w460 h300 Background1a1a1a")
        
        yPos := CoordFrame.Y + 10
        xStart := CoordFrame.X + 10
        
        ; Add coordinate entries
        for key, coord in this.coords {
            ; Coordinate name
            ConfigGui.Add("Text", "x" . xStart . " y" . yPos . " w200 cAAAAAA", coord.name . ":")
            
            ; Coordinate values
            posText := ConfigGui.Add("Text", "x" . (xStart + 210) . " y" . yPos . " w100 c00FF00", coord.x . ", " . coord.y)
            
            ; Set button
            setBtn := ConfigGui.Add("Button", "x" . (xStart + 320) . " y" . (yPos-2) . " w60 h22", "Set")
            setBtn.OnEvent("Click", this._SetCoordinate.Bind(this, key, posText))
            
            yPos += 28
            
            ; Limit visible items to prevent overflow
            if yPos > (CoordFrame.Y + 280) {
                break
            }
        }

        ; Buttons at bottom
        ButtonY := CoordFrame.Y + 320
        SaveBtn := ConfigGui.Add("Button", "x150 y" . ButtonY . " w100 h30", "&Save")
        SaveBtn.OnEvent("Click", (*) => ConfigGui.Destroy())
        
        CancelBtn := ConfigGui.Add("Button", "x260 y" . ButtonY . " w100 h30", "&Cancel")
        CancelBtn.OnEvent("Click", (*) => ConfigGui.Destroy())
        
        ; Hotkeys
        ConfigGui.OnEvent("Close", (*) => ConfigGui.Destroy())
        ConfigGui.OnEvent("Escape", (*) => ConfigGui.Destroy())
        
        ; Show centered on screen
        ConfigGui.Show("w500 h" . (ButtonY + 45))
        
        ; Center the window
        ConfigGui.GetPos(&x, &y, &w, &h)
        ConfigGui.Move((A_ScreenWidth - w) // 2, (A_ScreenHeight - h) // 2)
    }

    ; ==================================================================================================================
    ;                                               INTERNAL HELPER METHODS
    ; ==================================================================================================================
    
    _UpdateSelectedCreature(creatureName) {
        this.selectedCreatureName := creatureName
        for pageNum, pageData in this.creatureData {
            creatures := pageData["creatures"]
            for name, key in creatures {
                if name = creatureName {
                    this.selectedCreatureKey := key
                    this.selectedCreaturePage := pageNum
                    return
                }
            }
        }
    }

    _SetCoordinate(key, textControl, *) {
        local coordObj := this.coords[key]
        ToolTip("Move mouse to target location and press SPACE")
        
        ; Wait for space key
        KeyWait("Space", "D")
        MouseGetPos(&x, &y)
        coordObj.x := x
        coordObj.y := y
        textControl.Text := x . ", " . y
        
        ToolTip()  ; Clear tooltip
        try {
            SoundPlay("*64")  ; Success sound
        }
    }
}

; IMPORTANT: Register the class type with the main script for loading.
g_MacroClassesToLoad.Push(DTMQuestMacro)