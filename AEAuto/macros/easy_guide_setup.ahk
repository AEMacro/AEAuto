; ======================================================================================================================
; MACRO FILE:       easy_guide_setup.ahk
; DESCRIPTION:      A simple template macro to demonstrate how to create new macros for the main loader.
; ======================================================================================================================

class EasyGuideSetupMacro {
    ; --- Basic Macro Properties ---
    Name := "Easy Guide Setup"
    Description := "A simple macro that clicks three points in a sequence."

    ; --- Internal State Variables ---
    macroStep := 0

    ; --- Configuration & Data (Declared here, initialized in __New) ---
    coords := Map()
    macroSequence := []

    __New() {
        ; Initialize coordinates as a Map
        this.coords := Map(
            "start_point", {x: 800, y: 500, name: "Start Point"},
            "middle_point", {x: 1000, y: 500, name: "Middle Point"},
            "end_point", {x: 900, y: 600, name: "End Point"}
        )
        
        this.macroSequence := [
            {action: "click", target: "start_point", wait: 1000, description: "Clicking the start point"},
            {action: "click", target: "middle_point", wait: 1000, description: "Clicking the middle point"},
            {action: "click", target: "end_point", wait: 1000, description: "Clicking the end point"}
        ]
    }

    ; ==================================================================================================================
    ;                                                 REQUIRED CLASS METHODS
    ; ==================================================================================================================

    Start() {
        this.macroStep := 0
    }

    Stop() {
        this.macroStep := 0
    }

    Reject() {
        MsgBox "This macro does not support the 'Reject' action.", "Info", 64
    }

    GetNextAction() {
        if this.macroStep >= this.macroSequence.Length {
            this.macroStep := 0 ; Reset for the next run
            return {type: "end_run", wait: 1000, infoText: "Easy Guide finished. Looping."}
        }

        local currentAction := this.macroSequence[this.macroStep + 1]
        this.macroStep++

        local actionObject := Map(
            "wait", currentAction.HasProp("wait") ? currentAction.wait : 1000,
            "infoText", currentAction.description,
            "type", "click",
            "x", this.coords[currentAction.target].x,
            "y", this.coords[currentAction.target].y
        )
        
        return actionObject
    }

    ShowConfigGui() {
        ConfigGui := Gui("+AlwaysOnTop +ToolWindow", this.Name . " Configuration")
        ConfigGui.BackColor := "222222"
        ConfigGui.SetFont("s10 cFFFFFF", "Verdana")
        
        ; Title bar
        TitleBar := ConfigGui.Add("Text", "x0 y0 w400 h30 Center Background333333 0x200", this.Name . " Configuration")
        TitleBar.SetFont("s12 Bold")
        
        ConfigGui.Add("Text", "x20 y50", "Click Coordinates (hover and press 'Set'):")
        
        ; Create a frame for coordinates
        CoordFrame := ConfigGui.Add("Text", "x20 y80 w360 h150 Background1a1a1a")
        
        yPos := CoordFrame.Y + 15
        xStart := CoordFrame.X + 15
        
        ; Add coordinate entries
        for key, coord in this.coords {
            ConfigGui.Add("Text", "x" . xStart . " y" . yPos . " w120 cAAAAAA", coord.name . ":")
            posText := ConfigGui.Add("Text", "x" . (xStart + 130) . " y" . yPos . " w100 c00FF00", coord.x . ", " . coord.y)
            setBtn := ConfigGui.Add("Button", "x" . (xStart + 240) . " y" . (yPos-2) . " w60 h22", "Set")
            setBtn.OnEvent("Click", this._SetCoordinate.Bind(this, key, posText))
            yPos += 40
        }

        ; Close button
        CloseBtn := ConfigGui.Add("Button", "x150 y250 w100 h30", "&Close")
        CloseBtn.OnEvent("Click", (*) => ConfigGui.Destroy())
        
        ; Hotkeys
        ConfigGui.OnEvent("Close", (*) => ConfigGui.Destroy())
        ConfigGui.OnEvent("Escape", (*) => ConfigGui.Destroy())
        
        ; Show centered
        ConfigGui.Show("w400 h290")
        ConfigGui.GetPos(&x, &y, &w, &h)
        ConfigGui.Move((A_ScreenWidth - w) // 2, (A_ScreenHeight - h) // 2)
    }
    
    ; --- Internal Helper Methods ---
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
g_MacroClassesToLoad.Push(EasyGuideSetupMacro)