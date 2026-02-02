	#Requires AutoHotkey v2.0
	#SingleInstance Force

	; =======================================================
	; 🚀 APP LAUNCHERS & WEBSITES
	; =======================================================

	; 🧠 SMART F1: Search Selected Text OR Open Google
	F1::
	{
		OldClip := A_Clipboard
		A_Clipboard := "" ; Clear clipboard to detect change
		Send "^c" ; Try to copy highlighted text
		
		if ClipWait(0.3) ; Wait 0.3s to see if text was copied
		{
			; ✅ Text WAS selected -> Search it
			Run "https://www.google.com/search?q=" . A_Clipboard
			Sleep 500 
			A_Clipboard := OldClip ; Restore original clipboard
		}
		else
		{
			; ❌ NO text selected -> Open Google Home
			A_Clipboard := OldClip ; Restore clipboard
			FocusOrLaunch("Google", "https://www.google.com")
		}
	}

	; 🧠 SMART WEB APPS (Focus if open, Launch if closed)
	F2::FocusOrLaunch("ChatGPT", "https://chat.openai.com")
	F3::FocusOrLaunch("Gemini", "https://gemini.google.com")
	F4::Run('"C:\Program Files\Notepad++\notepad++.exe"') ; Local App
	F6::FocusOrLaunch("Gmail", "https://mail.google.com")
	F7::Run("https://myaccount.google.com/u/1/security")
	F8::FocusOrLaunch("Google Drive", "https://drive.google.com")

	; Alt + Key Shortcuts
	!y::FocusOrLaunch("YouTube", "https://www.youtube.com")
	!d::Run('explorer.exe "C:\Users\ASUS\Downloads"')
	!g::FocusOrLaunch("GitHub", "https://github.com")
	!e::Run('"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"')
	!c::FocusOrLaunch("Canva", "https://www.canva.com")
	!w::FocusOrLaunch("Google Docs", "https://docs.google.com/document/u/0/")

; =======================================================
; ❓ CHEAT SHEET (Alt + Q) - Updated
; =======================================================
!q::
{
    MsgBox("
    (
    🚀 LAUNCHERS
    F1              - Smart Search / Google
    F2-F8           - Apps (ChatGPT, Gmail, etc)

    💻 DEVELOPER TOOLS
    Alt + H         - Host Folder on Network (Python)
    Ctrl + Alt + T  - Open Terminal Here (Explorer)
    Ctrl + Alt + N  - Create New File
    Ctrl + Shift + C- Copy File Path

    🛠️ SYSTEM & UTILS
    Ctrl + Esc      - ⏸️ SUSPEND SCRIPT (Toggle)
    Ctrl + Alt + R  - ♻️ Reload Script
    Win + Scroll    - Ghost Mode (Transparency)
    )", "My AHK Shortcuts", "Iconi")
}

	; =======================================================
	; 🔄 TEXT CASE CYCLER (Highlight -> Alt + T)
	; =======================================================
	!t::
	{
		OldClip := A_Clipboard
		A_Clipboard := ""
		Send "^c"
		if !ClipWait(0.5) {
			A_Clipboard := OldClip
			return
		}
		Str := A_Clipboard
		if (Str = StrUpper(Str))
			NewStr := StrLower(Str)
		else if (Str = StrLower(Str))
			NewStr := StrTitle(Str)
		else
			NewStr := StrUpper(Str)
		A_Clipboard := NewStr
		Send "^v"
		Sleep 100
		A_Clipboard := OldClip
	}


	; =======================================================
	; 📅 TEXT EXPANSION
	; =======================================================
	:*:;date:: ; Type ";date"
	{
		Send FormatTime(, "yyyy-MM-dd")
	}
	:*:@@::myemailaddress@gmail.com ; Type "@@" for email


	; =======================================================
	; 🔍 SCREEN SEARCH (Google Lens Style) - Alt + S
	; =======================================================
	!s::
	{
		A_Clipboard := ""
		Send "#+s" ; Open Snipping Tool
		if !ClipWait(30, 1)
			return

		Run "https://google.com/imghp"
		
		; Wait specifically for Google Images to be active
		if WinWaitActive("Google Images", , 5) 
		{
			Sleep 800 ; Allow page to render
			Send "{Tab}"
			Sleep 100
			Send "{Tab}" 
			Sleep 100
			Send "{Enter}" ; Open upload box
			Sleep 800 ; Wait for animation
			Send "^v" ; Paste image
		}
	}


	; =======================================================
	; 📌 WINDOW PINNING (Always On Top) - Ctrl + Space
	; =======================================================
	^Space:: 
	{
		if WinGetExStyle("A") & 0x8 
		{
			WinSetAlwaysOnTop 0, "A" 
			SoundBeep 500, 200        
		}
		else
		{
			WinSetAlwaysOnTop 1, "A" 
			SoundBeep 1000, 200       
		}
	}


	; =======================================================
	; 👻 ADVANCED GHOST MODE (Win + Scroll)
	; =======================================================
	#WheelDown:: ; Fade Out
	{
		try {
			CurrentOpacity := WinGetTransparent("A")
			if (CurrentOpacity = "")
				CurrentOpacity := 255
		} catch {
			return
		}
		NewOpacity := CurrentOpacity - 25
		if (NewOpacity < 30)
			NewOpacity := 30
		WinSetTransparent NewOpacity, "A"
		ShowOpacityTooltip(NewOpacity)
	}

	#WheelUp:: ; Fade In
	{
		try {
			CurrentOpacity := WinGetTransparent("A")
			if (CurrentOpacity = "")
				CurrentOpacity := 255
		} catch {
			return
		}
		NewOpacity := CurrentOpacity + 25
		if (NewOpacity >= 255) {
			WinSetTransparent "Off", "A"
			ShowOpacityTooltip(255)
		} else {
			WinSetTransparent NewOpacity, "A"
			ShowOpacityTooltip(NewOpacity)
		}
	}

	ShowOpacityTooltip(level)
	{
		Percentage := Round((level / 255) * 100)
		ToolTip "Opacity: " . Percentage . "%"
		SetTimer () => ToolTip(), -1000 
	}


	; =======================================================
	; 🖱️ EASY WINDOW DRAG & RESIZE (Alt + Click)
	; =======================================================
	!LButton:: ; Alt + Left Click to DRAG
	{
		try PostMessage(0xA1, 2, , , "A")
	}

	!RButton:: ; Alt + Right Click to RESIZE (Native)
	{
		try PostMessage(0xA1, 17, , , "A") 
	}


	; =======================================================
	; ✅ ROBUST LAZY CLOSE (Middle Click Title Bar)
	; ⛔ EXCLUDES CHROME
	; =======================================================
	~MButton::
	{
		CoordMode "Mouse", "Screen" 
		MouseGetPos &X, &Y, &WinID
		
		try {
			if WinGetProcessName("ahk_id " WinID) = "chrome.exe"
				return
		}
		if WinGetClass("ahk_id " WinID) = "Shell_TrayWnd"
			return

		try {
			MessageResult := SendMessage(0x84, 0, (Y << 16) | (X & 0xFFFF), , "ahk_id " WinID)
		} catch {
			return
		}

		if (MessageResult == 2)
			PostMessage(0x112, 0xF060, , , "ahk_id " WinID)
	}   


	; =======================================================
	; 🔊 SONIC SCROLL (Hover Taskbar -> Volume)
	; =======================================================
	#HotIf MouseIsOver("ahk_class Shell_TrayWnd") 
	WheelUp::Send "{Volume_Up}"       
	WheelDown::Send "{Volume_Down}" 
	MButton::Send "{Volume_Mute}"   
	#HotIf 

	MouseIsOver(WinTitle) 
	{
		MouseGetPos , , &Win
		return WinExist(WinTitle . " ahk_id " . Win)
	}


	; =======================================================
	; 📜 WINDOW SHADE (Alt + M to Roll Up)
	; =======================================================
	WindowHeights := Map()

	!m:: 
	{
		WinID := WinExist("A") 
		if WindowHeights.Has(WinID) 
		{
			WinMove , , , WindowHeights[WinID], "ahk_id " . WinID
			WindowHeights.Delete(WinID) 
		}
		else 
		{
			WinGetPos , , , &H, "ahk_id " . WinID 
			WindowHeights[WinID] := H 
			WinMove , , , 40, "ahk_id " . WinID ; Increased to 40 for safety
		}
	}


	; =======================================================
	; 🔧 HELPER FUNCTIONS
	; =======================================================
	FocusOrLaunch(PageTitle, URL, BrowserExe := "chrome.exe")
	{
		SetTitleMatchMode 2 ; Match any part of the title
		if WinExist(PageTitle . " ahk_exe " . BrowserExe)
		{
			WinActivate
		}
		else
		{
			Run URL, , "max"
		}
	}



	; =======================================================
	; 🌯 TEXT WRAPPING (Highlight -> Alt + ' OR Alt + [)
	; =======================================================
	!'::WrapSelection('"', '"')    ; Wrap in "Quotes"
	![::WrapSelection("[", "]")    ; Wrap in [Brackets]
	!(::WrapSelection("(", ")")    ; Wrap in (Parentheses)
	!{::WrapSelection("{", "}")    ; Alt + {
	!<::WrapSelection("<", ">")    ; Alt + <
	WrapSelection(LeftChar, RightChar)
	{
		OldClip := A_Clipboard
		A_Clipboard := ""
		Send "^c"
		if ClipWait(0.3)
		{
			A_Clipboard := LeftChar . A_Clipboard . RightChar
			Send "^v"
		}
		Sleep 500
		A_Clipboard := OldClip
	}


	; =======================================================
	; ♻️ INSTANT RELOAD (Ctrl + Alt + R)
	; =======================================================
	^!r::
	{
		SoundBeep 1000, 200
		Reload
	}



	; =======================================================
	; 📂 COPY FILE PATH (Ctrl + Shift + C in Explorer)
	; =======================================================
	#HotIf WinActive("ahk_class CabinetWClass") ; Only in File Explorer
	^+c::
	{
		A_Clipboard := ""
		Send "^c"
		if ClipWait(1)
		{
			; Convert file object to simple text path
			A_Clipboard := A_Clipboard
			SoundBeep 200, 100 ; Low beep confirmation
		}
	}
	#HotIf ; Turn off context sensitivity



	; =======================================================
	; ⏸️ SUSPEND HOTKEYS (Toggle on/off with Ctrl + Esc)
	; =======================================================
	^Esc::
	{
		Suspend ; Toggles the state
		if (A_IsSuspended)
			SoundBeep 500, 200 ; Low beep = Sleep Mode (Paused)
		else
			SoundBeep 1000, 200 ; High beep = Awake (Resumed)
	}
	
	
	
	; =======================================================
; 💻 SMART TERMINAL OPENER (Ctrl + Alt + T)
; =======================================================
^!t::
{
    if WinActive("ahk_class CabinetWClass") ; If in File Explorer
    {
        OldClip := A_Clipboard
        A_Clipboard := ""
        Send "^l"           ; Focus address bar
        Sleep 50            ; Wait for focus
        Send "^c"           ; Copy path
        if ClipWait(0.5)
        {
            Run "cmd.exe /K cd /d " . A_Clipboard
        }
        else
        {
            Run "cmd.exe" ; Fallback
        }
        A_Clipboard := OldClip
    }
    else
    {
        Run "cmd.exe" ; Open in default User folder
    }
}

; =======================================================
; 📡 NETWORK FILE HOSTING (Alt + H in Explorer)
; =======================================================
#HotIf WinActive("ahk_class CabinetWClass")
!h::
{
    ; 1. Copy the path
    OldClip := A_Clipboard
    A_Clipboard := ""
    Send "^c" 
    if !ClipWait(0.5)
    {
        MsgBox "Select a file or folder first!", "Error", "Icon!"
        return
    }
    SelectedPath := A_Clipboard

    ; 2. Get Folder Path
    if DirExist(SelectedPath)
        HostDir := SelectedPath
    else
        SplitPath SelectedPath, , &HostDir

    ; 3. 🧠 GET IP CORRECTLY (Using Helper Function)
    MyIP := GetLocalIP() 
    ShareLink := "http://" . MyIP . ":8000"

    ; 4. The Command
    Run 'cmd /k cd /d "' . HostDir . '" && title 📡 Hosting at: ' . ShareLink . ' && color 0B && cls && echo. && echo  ========================================== && echo   📡  YOUR FILES ARE LIVE! && echo   🔗  Link: ' . ShareLink . ' && echo  ========================================== && echo. && python -m http.server 8000'

    ; 5. Open Browser & Copy Link
    Sleep 500
    Run ShareLink 
    A_Clipboard := ShareLink
    SoundBeep 1000, 150
}
#HotIf


; =======================================================
; 🔧 HELPER FUNCTION: GET IP ADDRESS
; =======================================================
GetLocalIP()
{
    try {
        ; Use Windows built-in tool to run ipconfig visibly
        shell := ComObject("WScript.Shell")
        ; Run ipconfig and find the IPv4 line
        exec := shell.Exec("cmd /c ipconfig | findstr IPv4")
        output := exec.StdOut.ReadAll()
        
        ; Extract the IP number using Regex
        if RegExMatch(output, "(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})", &match)
            return match[1]
    }
    return "127.0.0.1" ; Fallback if failed
}




; =======================================================
; 📄 INSTANT NEW FILE (Ctrl + Alt + N)
; =======================================================
#HotIf WinActive("ahk_class CabinetWClass")
^!n::
{
    ; 1. Get Current Folder Path
    OldClip := A_Clipboard
    A_Clipboard := ""
    Send "^l" ; Focus address bar
    Sleep 50
    Send "^c" ; Copy path
    if !ClipWait(0.5)
        return
    CurrentPath := A_Clipboard
    A_Clipboard := OldClip ; Restore clipboard

    ; 2. Ask for Filename
    IB := InputBox("Name your file (e.g. script.py):", "New File", "w300 h130")
    if (IB.Result = "Cancel" or IB.Value = "")
        return

    NewFile := CurrentPath . "\" . IB.Value

    ; 3. Create and Open
    try {
        FileAppend "", NewFile ; Creates empty file
        Run NewFile ; Opens in default editor (VS Code / Notepad)
    } catch as e {
        MsgBox "Could not create file!`n" . e.Message, "Error", "IconX"
    }
}
#HotIf



; =======================================================
; 📝 COPY FILE CONTENT (Ctrl + Shift + X)
; =======================================================
#HotIf WinActive("ahk_class CabinetWClass")
^+x::
{
    ; 1. Get Path
    OldClip := A_Clipboard
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(0.5)
        return
    FilePath := A_Clipboard
    A_Clipboard := OldClip
    
    ; 2. CMD Magic: 'type' reads file, '| clip' sends to clipboard
    RunWait 'cmd /c type "' . FilePath . '" | clip', , "Hide"
    
    SoundBeep 1000, 100
    MsgBox "File contents copied to clipboard!", "Success", "T1"
}
#HotIf


; =======================================================
; 🧠 GEMINI AI INTEGRATION (Alt + Shift + G)
; =======================================================
Global GeminiKey := "AIzaSyAUnnO2tNpa9X5-4VEpuQEG2_mLsI9DwmQ" ; <--- PASTE YOUR KEY HERE

!+g::
{
    ; 1. Get Selected Text (The "Context")
    OldClip := A_Clipboard
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(0.5)
    {
        MsgBox "Highlight some text first!", "Error", "Icon!"
        return
    }
    UserContext := A_Clipboard
    A_Clipboard := OldClip ; Restore clipboard immediately

    ; 2. Ask User for Instruction
    IB := InputBox("Instruction (e.g. 'Fix bug', 'Summarize'):", "Ask Gemini", "w300 h130")
    if (IB.Result = "Cancel")
        return
    UserPrompt := IB.Value

    ; 3. Visual Feedback (Thinking...)
    ToolTip "🧠 Gemini is thinking..."

    ; 4. Send to API
    try {
        Response := CallGemini(UserPrompt, UserContext)
        ToolTip ; Clear tooltip
        
        ; 5. Show Result
        ; We use a GUI because AI responses are usually long
        ResultGui := Gui()
        ResultGui.SetFont("s10", "Consolas")
        ResultGui.Add("Edit", "w600 h400 ReadOnly", Response)
        ResultGui.Add("Button", "w600", "Copy to Clipboard").OnEvent("Click", (*) => (A_Clipboard := Response, SoundBeep(500, 100)))
        ResultGui.Show()
    } catch as e {
        ToolTip
        MsgBox "API Error: " . e.Message
    }
}



; =======================================================
; 🔌 GEMINI API FUNCTION (Final Production Version)
; =======================================================
CallGemini(Prompt, Context)
{
    ; ⚡ Switch back to 1.5-flash for higher rate limits (less 429 errors)
    URL := "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=" . GeminiKey
    
    ; --- 1. PREPARE INPUT ---
    FullText := "Context: " . Context . "`n`nInstruction: " . Prompt
    SafeText := StrReplace(FullText, "\", "\\")
    SafeText := StrReplace(SafeText, "`"", "\`"")
    SafeText := StrReplace(SafeText, "`n", "\n")
    SafeText := StrReplace(SafeText, "`r", "")
    
    Body := '{"contents": [{"parts": [{"text": "' . SafeText . '"}]}]}'

    ; --- 2. SEND REQUEST ---
    try {
        WebRequest := ComObject("WinHttp.WinHttpRequest.5.1")
        WebRequest.Open("POST", URL, true)
        WebRequest.SetRequestHeader("Content-Type", "application/json")
        WebRequest.Send(Body)
        WebRequest.WaitForResponse()
        ResultText := WebRequest.ResponseText
    } catch as e {
        return "⚠️ Network Error: " . e.Message
    }

    ; --- 3. ERROR HANDLING (The New Part) ---
    if InStr(ResultText, '"code": 429')
    {
        return "⏳ RATE LIMIT REACHED!`n`nYou are clicking too fast for the Free Tier.`nWait 60 seconds and try again."
    }
    if InStr(ResultText, '"error":')
    {
        return "⚠️ API Error.`n" . ResultText
    }

    ; --- 4. PARSE RESPONSE ---
    if RegExMatch(ResultText, '"text":\s*"((\\.|[^"\\])*)"', &Match)
    {
        Output := Match[1]
        Output := StrReplace(Output, "\n", "`n")
        Output := StrReplace(Output, "\`"", "`"")
        Output := StrReplace(Output, "\\", "\")
        
        ; Unescape Unicode (Fixes \u003e symbols)
        Pos := 1
        While Pos := RegExMatch(Output, "\\u([0-9a-fA-F]{4})", &Code, Pos)
        {
            Char := Chr("0x" . Code[1])
            Output := StrReplace(Output, Code[0], Char)
        }
        return Output
    }
    else
    {
        return "⚠️ Unknown Error.`nRaw: " . ResultText
    }
}



; =======================================================
; 🖱️ AUTO CLICKER (F9 to Toggle)
; =======================================================
F9::
{
    static Toggle := false ; Keeps track of on/off state
    Toggle := !Toggle      ; Switch the state

    if Toggle
    {
        ; START CLICKING
        SetTimer ClickLoop, 25 ; 25ms = approx 40 clicks per second
        SoundBeep 1000, 200
        ToolTip "🔥 AUTO CLICKER: ON"
    }
    else
    {
        ; STOP CLICKING
        SetTimer ClickLoop, 0 ; 0 turns the timer off
        SoundBeep 500, 200
        ToolTip ; Clears the tooltip
    }
}

; The function that actually clicks
ClickLoop()
{
    Click
}





; =======================================================
; 🤖 FACEBOOK SWEEPER - HIGH CONTRAST & FAKE DETECTOR
; =======================================================
#HotIf WinActive("ahk_exe chrome.exe")

F10::
{
    ; --- ⚙️ CONFIGURATION ---
    TargetColor := 0x54A7F5   ; The Blue Button Color
    Variation := 25           ; Tolerance
    ButtonW := 100            ; Width to skip after finding one
    RowH    := 80             ; Height of scanning strip
    
    ; --- 📏 SCAN AREA ---
    TopMargin    := 130       
    BottomMargin := 50        
    ; ------------------------

    ; Safety Check
    if !InStr(WinGetTitle("A"), "Facebook") && !InStr(WinGetTitle("A"), "Friends")
    {
        MsgBox "⚠️ Safety Stop: This doesn't look like Facebook.", "Aborted", "Icon!"
        return
    }

    CoordMode "Pixel", "Client"
    CoordMode "Mouse", "Client"
    WinGetClientPos &WinX, &WinY, &WinW, &WinH, "A"

    Targets := []    
    Markers := []   

    SoundBeep 1000, 100
    ToolTip "👀 SCANNING (Filtering Photos)..."

    CurrentY := TopMargin
    MaxScanY := WinH - BottomMargin

    Loop
    {
        if (CurrentY > MaxScanY)
            break
            
        CurrentX := 0 
        Loop
        {
            if (CurrentX > WinW)
                break

            ; 1. Find the first Blue Pixel
            if PixelSearch(&FoundX, &FoundY, CurrentX, CurrentY, WinW, CurrentY + RowH, TargetColor, Variation)
            {
                ; --- 🕵️ FAKE DETECTOR (The Fix) ---
                ; We found a blue pixel. But is it a button or a photo?
                ; We check 4 pixels to the Right and 4 pixels Down.
                ; If those aren't blue too, it's just a speck in a photo.
                
                IsSolid := False
                if PixelSearch(&_, &_, FoundX + 4, FoundY + 4, FoundX + 5, FoundY + 5, TargetColor, Variation)
                {
                    IsSolid := True
                }

                if (IsSolid = False)
                {
                    ; It's a fake! Skip ahead slightly and keep scanning.
                    CurrentX := FoundX + 10
                    continue 
                }
                ; ------------------------------------------

                ; If we survived the check, it's a real button.
                Targets.Push({x: FoundX, y: FoundY})
                
                ; 🟡 VISUAL MARKER (Yellow & Black)
                ClientToScreen(&FoundX, &FoundY) 
                
                Marker := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound")
                Marker.BackColor := "FFFF00" ; Bright Yellow
                Marker.SetFont("s12 cBlack w900", "Verdana") ; Thick Black Text
                Marker.Add("Text", "x0 y2 w30 h25 Center", Targets.Length)
                Marker.Show("x" . FoundX . " y" . FoundY . " w30 h25 NoActivate")
                WinSetTransparent(230, Marker.Hwnd) 
                
                Markers.Push(Marker) 
                ScreenToClient(&FoundX, &FoundY)
                
                ; Move past this button
                CurrentX := FoundX + ButtonW
            }
            else
            {
                break 
            }
        }
        CurrentY += RowH
    }
    
    ToolTip 

    ; --- STEP 2: USER CONFIRMATION ---
    if (Targets.Length = 0)
    {
        MsgBox "No buttons found.", "Result", "Icon!"
        return
    }

    Result := MsgBox("🎯 TARGETS LOCKED: " . Targets.Length . "`n`nCheck the YELLOW BOXES.`n(Photos should be ignored now)`n`nPress YES to execute.", "Confirm", "YesNo Icon?")

    if (Result = "No")
    {
        for M in Markers
            M.Destroy()
        return
    }

    ; --- STEP 3: EXECUTE ---
    ToolTip "🔥 EXECUTING..."
    
    for Index, Point in Targets
    {
        if GetKeyState("Shift", "P")
        {
            MsgBox "Stopped."
            break
        }

        MouseMove Point.x, Point.y
        Click
        try Markers[Index].Destroy()
        Sleep Random(300, 600)
    }

    for M in Markers
        try M.Destroy()
        
    ToolTip
    MsgBox "✅ Done.", "Done", "Iconi"
}

ClientToScreen(&x, &y)
{
    Point := Buffer(8)
    NumPut("int", x, "int", y, Point)
    DllCall("ClientToScreen", "Ptr", WinExist("A"), "Ptr", Point)
    x := NumGet(Point, 0, "int")
    y := NumGet(Point, 4, "int")
}

ScreenToClient(&x, &y)
{
    Point := Buffer(8)
    NumPut("int", x, "int", y, Point)
    DllCall("ScreenToClient", "Ptr", WinExist("A"), "Ptr", Point)
    x := NumGet(Point, 0, "int")
    y := NumGet(Point, 4, "int")
}
#HotIf
