; ======================================================================================================================
; MACRO FILE:       dtm_quest_image_search.ahk
; DESCRIPTION:      A fully automated macro for the DTM quest using OCR for UI elements and ImageSearch for NPCs.
;                   This file is designed to be loaded by the main script.
; VERSION:          1.7 (Final GUI Event Fix)
; ======================================================================================================================

class DTMQuestImageSearchMacro {
    ; --- Basic Macro Properties ---
    Name := "DTM Quest (ImageSearch + OCR)"
    Description := "Automates the DTM quest using ImageSearch and OCR."

    ; --- Configuration ---
    targetWinTitle := "ahk_exe YourGame.exe" ; IMPORTANT: Change this to your game's window title!
    images := Map(
        "dtm_npc", "*30 dtm_npc.png",       ; The *30 allows for some color variation
        "dtm_reject", "*30 dtm_reject.png"
    )

    ; --- Internal State Variables ---
    macroStep := 0
    rejectionStep := 0
    questState := "idle"
    _currentPage := 1
    
    ; --- Data ---
    selectedCreatureName := "Dragons"
    creatureData := Map()
    macroSequence := []
    rejectionSequence := []

    __New() {
        this.creatureData := Map("Dragons", 1, "Kobolds", 1, "Undead", 2, "Elementals", 2)

        this.macroSequence := [
            {action: "image_click", target: "dtm_npc", wait: 1500, description: "Finding DTM NPC..."},
            {action: "ocr_click", text: "Continue", wait: 1000, description: "Finding 'Continue'..."},
            {action: "ocr_click", text: "Continue", wait: 1000, description: "Finding 2nd 'Continue'..."},
            {action: "ocr_click", text: "Sure!", wait: 1000, description: "Finding 'Sure!'..."},
            {action: "ocr_click", text: "Continue", wait: 1500, description: "Finding 3rd 'Continue'..."},
            {action: "navigate_to_creature", wait: 1000, description: "Navigating to creature page..."},
            {action: "select_chosen_creature", wait: 2000, description: "Selecting chosen creature..."},
            {action: "ocr_click", text: "Continue", wait: 1000, description: "Finding 'Continue' after creature..."},
            {action: "ocr_click", text: "Yes, Extra Challenge", wait: 3000, description: "Finding 'Yes, Extra Challenge'..."},
            {action: "wait_for_decision", wait: 10000, description: "Waiting for quest decision..."}
        ]

        this.rejectionSequence := [
            {action: "image_click", target: "dtm_reject", wait: 1000, description: "Finding DTM NPC to reject..."},
            {action: "ocr_click", text: "Continue", wait: 1000, description: "Finding 'Continue' (Reject)..."},
            {action: "ocr_click", text: "Continue", wait: 1000, description: "Finding 2nd 'Continue' (Reject)..."},
            {action: "ocr_click", text: "No, I'm Not Strong Enough", wait: 1000, description: "Finding 'Not Strong Enough'..."},
            {action: "ocr_click", text: "Continue", wait: 1000, description: "Finding 3rd 'Continue' (Reject)..."},
            {action: "ocr_click", text: "Continue", wait: 1500, description: "Finding 4th 'Continue' to cancel..."},
            {action: "restart_macro", description: "Restarting macro run..."}
        ]
    }

    Start() {
        this.questState := "seeking"
        this.macroStep := 0
        this.rejectionStep := 0
        this._currentPage := 1
    }

    Stop() {
        this.questState := "idle"
    }

    Reject() {
        if (this.questState = "waiting_for_decision") {
            this.questState := "rejecting"
            this.rejectionStep := 0
        }
    }

    GetNextAction() {
        local currentAction, sequence

        if (this.questState = "rejecting") {
            sequence := this.rejectionSequence
            if (this.rejectionStep >= sequence.Length) {
                return {type: "end_run", wait: 1000, infoText: "Rejection finished. Restarting."}
            }
            currentAction := sequence[++this.rejectionStep]
        } else if (this.questState = "seeking") {
            sequence := this.macroSequence
            if (this.macroStep >= sequence.Length) {
                return {type: "end_run", wait: 1000, infoText: "Macro run finished."}
            }
            currentAction := sequence[++this.macroStep]
        } else {
            return ""
        }

        local actionObject := Map(
            "wait", currentAction.HasProp("wait") ? currentAction.wait : 1000,
            "infoText", currentAction.description
        )

        switch currentAction.action {
            case "image_click":
                actionObject["type"] := "image"
                actionObject["imageFile"] := this.images[currentAction.target]
            
            case "ocr_click":
                actionObject["type"] := "ocr"
                actionObject["text"] := currentAction.text
            
            case "navigate_to_creature":
                actionObject["type"] := "info"
                targetPage := this.creatureData.Has(this.selectedCreatureName) ? this.creatureData[this.selectedCreatureName] : 1
                if (this._currentPage < targetPage) {
                    actionObject["type"] := "ocr"
                    actionObject["text"] := "Show More"
                    this.macroStep--
                    this._currentPage++
                }

            case "select_chosen_creature":
                actionObject["type"] := "ocr"
                actionObject["text"] := this.selectedCreatureName

            case "wait_for_decision":
                actionObject["type"] := "info"
                actionObject["infoText"] := "Quest Ready! Press F9 to REJECT."
                this.questState := "waiting_for_decision"

            case "restart_macro":
                actionObject["type"] := "info"
                this.questState := "seeking"
                this.macroStep := 0
                this._currentPage := 1
        }
        
        return actionObject
    }

    ShowConfigGui() {
        ConfigGui := Gui("+AlwaysOnTop +ToolWindow", this.Name . " Configuration")
        ConfigGui.BackColor := "222222"
        ConfigGui.SetFont("s10 cFFFFFF", "Verdana")
        
        ConfigGui.Add("Text", "x0 y0 w500 h30 Center Background333333 0x200", this.Name . " Configuration").SetFont("s12 Bold")

        ConfigGui.Add("Text", "x20 y50", "Game Window Title (use ahk_exe or ahk_class):")
        WinTitleEdit := ConfigGui.Add("Edit", "xs y+5 w460 vTargetWinTitle", this.targetWinTitle)

        ConfigGui.Add("Text", "xs y+15", "Select Creature Type:")
        
        creatureList := []
        for name, page in this.creatureData {
            creatureList.Push(name)
        }

        CreatureDDL := ConfigGui.Add("DropDownList", "xs y+5 w200", creatureList)
        CreatureDDL.Choose(this.selectedCreatureName)
        
        infoBox := ConfigGui.Add("Text", "xs y+20 w460 r4 Section Background1a1a1a",
            "This macro uses ImageSearch. Please place the following files in an 'images' subfolder:`n"
            . "  - dtm_npc.png`n"
            . "  - dtm_reject.png")
        infoBox.SetFont("s9 cAAAAAA")

        infoBox.GetPos(,,,&infoH)
        ButtonY := infoBox.Y + infoH + 20
        SaveBtn := ConfigGui.Add("Button", "x150 y" . ButtonY . " w100 h30", "&Save")
        CancelBtn := ConfigGui.Add("Button", "x260 y" . ButtonY . " w100 h30", "&Cancel")

        SaveBtn.OnEvent("Click", (*) => {
            this.targetWinTitle := WinTitleEdit.Value
            this.selectedCreatureName := CreatureDDL.Text
            ConfigGui.Destroy()
        })

        CancelBtn.OnEvent("Click", (*) => {
            ConfigGui.Destroy()
        })

        ConfigGui.OnEvent("Close", (*) => ConfigGui.Destroy())
        ConfigGui.OnEvent("Escape", (*) => ConfigGui.Destroy())
        
        ConfigGui.Show("w500 h" . (ButtonY + 45))
        ConfigGui.GetPos(&x, &y, &w, &h)
        ConfigGui.Move((A_ScreenWidth - w) // 2, (A_ScreenHeight - h) // 2)
    }
}

g_MacroClassesToLoad.Push(DTMQuestImageSearchMacro)
