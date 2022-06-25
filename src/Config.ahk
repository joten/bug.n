/*
:title:     bug.n - tiling window management
:copyright: (c) 2022 joten <https://github.com/joten>
                2010 - 2021 https://github.com/fuhsjr00/bug.n/graphs/contributors
:license:  GNU General Public License version 3 (http://www.gnu.org/licenses/gpl-3.0.txt)

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/

Config_init() {
  Local i, key, layout0, layout1, layout2, vNames0, vNames1, vNames2, vNames3, vNames4, vNames5, vNames6, vNames7, vNames8, vNames9

  ;; Status bar
  Config_showBar           := True
  Config_horizontalBarPos  := "left"
  Config_barWidth          := "100%"
  Config_singleRowBar      := True
  Config_fontName          := "Lucida Console"
  Config_fontSize          := 10
  Config_scalingFactor     := 96 / A_ScreenDPI            ;; Undocumented. It should not be set manually by the user,
                                                          ;; but is dependant on the setting in the `Display control panel` of Windows under `Appearance and Personalization`.
  Config_barTransparency   := "off"
  Config_backColor_#1 := "000000;000000;0;0;0;0;0;0;0"    ;; 1: <view>;<layout>   ;<title>;<shebang>;<time>;<date>;<anyText>;<batteryStatus>;<volumeLevel>
  Config_foreColor_#1 := "000000;000000;0;0;0;0;0;0;0"
  Config_fontColor_#1 := "ffffff;ffffff;0;0;0;0;0;0;0"
  Config_backColor_#2 := "000000;;;;;;;0;0"               ;; 2: <active view>;    ;;;;;;<discharging battery>;<muted volume>
  Config_foreColor_#2 := "000000;;;;;;;0;0"
  Config_fontColor_#2 := "ffc000;;;;;;;0;0"
  Config_backColor_#3 := ";;;;;;;0;"                      ;; 3: ;                 ;;;;;;<low battery>;
  Config_foreColor_#3 := ";;;;;;;0;"
  Config_fontColor_#3 := ";;;;;;;0;"
  
  ;; Window arrangement
  Config_viewNames          := "1;2;3;4;5;6;7;8;9"
  Config_layout_#1          := "[]=;tile"
  Config_layout_#2          := "[M];monocle"
  Config_layout_#3          := "><>;"
  Config_layoutCount        := 3
  Config_layoutAxis_#1      := 1
  Config_layoutAxis_#2      := 2
  Config_layoutAxis_#3      := 2
  Config_layoutGapWidth     := 0
  Config_layoutMFactor      := 0.6
  Config_ghostWndSubString  := " (Not Responding)"
  Config_mFactCallInterval  := 700
  Config_mouseFollowsFocus  := True
  Config_newWndPosition     := "top"
  Config_onActiveHiddenWnds := "view"
  Config_shellMsgDelay      := 350
  Config_syncMonitorViews   := 0
  Config_viewFollowsTagged  := False
  Config_viewMargins        := "0;0;0;0"

  ;; Config_rule_#<i> := "<class>;<title>;<function name>;<is managed>;<m>;<tags>;<is floating>;<is decorated>;<hide title>;<action>"
  Config_rule_#1   := ".*;.*;;1;0;0;0;0;0;"
  Config_rule_#2   := ".*;.*;Window_isChild;0;0;0;1;1;1;"
  Config_rule_#3   := ".*;.*;Window_isPopup;0;0;0;1;1;1;"
  Config_rule_#4   := "QWidget;.*;;1;0;0;0;0;0;"
  Config_rule_#5   := "SWT_Window0;.*;;1;0;0;0;0;0;"
  Config_rule_#6   := "Xming;.*;;1;0;0;0;0;0;"
  Config_rule_#7   := "MsiDialog(No)?CloseClass;.*;;1;0;0;1;1;0;"
  Config_rule_#8   := "AdobeFlashPlayerInstaller;.*;;1;0;0;1;0;0;"
  Config_rule_#9   := "CalcFrame;.*;;1;0;0;1;1;0;"
  Config_rule_#10  := "CabinetWClass;.*;;1;0;0;0;1;0;"
  Config_rule_#11  := "OperationStatusWindow;.*;;0;0;0;1;1;0;"
  Config_rule_#12  := "Chrome_WidgetWin_1;.*;;1;0;0;0;1;0;"
  Config_rule_#13  := "Chrome_WidgetWin_1;.*;Window_isPopup;0;0;0;1;1;0;"
  Config_rule_#14  := "Chrome_RenderWidgetHostHWND;.*;;0;0;0;1;1;0;"
  Config_rule_#15  := "IEFrame;.*Internet Explorer;;1;0;0;0;1;0;"
  Config_rule_#16  := "MozillaWindowClass;.*Mozilla Firefox;;1;0;0;0;1;0;"
  Config_rule_#17  := "MozillaDialogClass;.*;;1;0;0;1;1;0;"
  Config_rule_#18  := "ApplicationFrameWindow;.*Edge;;1;0;0;0;1;0;"
  Config_ruleCount := 18  ;; This variable has to be set to the total number of active rules above.

  ;; Configuration management
  Config_autoSaveSession := "auto"                ;; "off" | "auto" | "ask"; `Config_autoSaveSession := False` is deprecated.
  Config_maintenanceInterval := 5000
  Config_monitorDisplayChangeMessages := "ask"    ;; "off" | "on" | "ask"

  Config_hotkeyCount := 0
  Config_restoreConfig(Main.configFile)
  
  Loop, 3 {
    StringSplit, Config_backColor_#%A_Index%_#, Config_backColor_#%A_Index%, `;
    StringSplit, Config_foreColor_#%A_Index%_#, Config_foreColor_#%A_Index%, `;
    StringSplit, Config_fontColor_#%A_Index%_#, Config_fontColor_#%A_Index%, `;
  }
  Loop, % Config_layoutCount {
    StringSplit, layout, Config_layout_#%A_Index%, `;
    Config_layoutFunction_#%A_Index% := layout2
    Config_layoutSymbol_#%A_Index%   := layout1
  }
  StringSplit, vNames, Config_viewNames, `;
  If vNames0 > 9
    Config_viewCount := 9
  Else
    Config_viewCount := vNames0
  Loop, % Config_viewCount
    Config_viewNames_#%A_Index% := vNames%A_Index%
}

Config_edit() {
  Global Main
  
  If Not FileExist(Main.configFile)
    Config_UI_saveSession()
  Run, % "edit " . Main.configFile
}

Config_hotkeyLabel:
  Config_redirectHotkey(A_ThisHotkey)
Return

Config_redirectHotkey(key)
{
  Global

  Loop, % Config_hotkeyCount
  {
    If (key = Config_hotkey_#%A_index%_key)
    {
      Main_evalCommand(Config_hotkey_#%A_index%_command)
      Break
    }
  }
}

Config_restoreConfig(filename)
{
  Local cmd, i, key, type, val, var

  If Not FileExist(filename)
    Return

  Loop, READ, %filename%
    If (SubStr(A_LoopReadLine, 1, 7) = "Config_")
    {
      ;Log_msg("Processing line: " . A_LoopReadLine)
      i := InStr(A_LoopReadLine, "=")
      var := SubStr(A_LoopReadLine, 1, i - 1)
      val := SubStr(A_LoopReadLine, i + 1)
      type := SubStr(var, 1, 13)
      If (type = "Config_hotkey")
      {
        i := InStr(val, "::")
        key := SubStr(val, 1, i - 1)
        cmd := SubStr(val, i + 2)
        If Not cmd
          Hotkey, %key%, Off
        Else
        {
          Config_hotkeyCount += 1
          Config_hotkey_#%Config_hotkeyCount%_key := key
          Config_hotkey_#%Config_hotkeyCount%_command := cmd
          Hotkey, %key%, Config_hotkeyLabel
        }
      }
      Else If (type = "Config_rule")
      {
        i := 0
        If InStr(var, "Config_rule_#")
          i := SubStr(var, 14)
        If (i = 0 Or i > Config_ruleCount)
        {
          Config_ruleCount += 1
          i := Config_ruleCount
        }
        var := "Config_rule_#" i
      }
      %var% := val
    }
}

Config_restoreLayout(filename, m) {
  Local i, var, val

  If Not FileExist(filename)
    Return

  Loop, READ, %filename%
    If (SubStr(A_LoopReadLine, 1, 10 + StrLen(m)) = "Monitor_#" m "_" Or SubStr(A_LoopReadLine, 1, 8 + StrLen(m)) = "View_#" m "_#") {
      i := InStr(A_LoopReadLine, "=")
      var := SubStr(A_LoopReadLine, 1, i - 1)
      val := SubStr(A_LoopReadLine, i + 1)
      %var% := val
    }
}

Config_saveSession(original, target)
{
  Local m, text, tmpfilename

  tmpfilename := target . ".tmp"
  FileDelete, %tmpfilename%

  text := "; bug.n - tiling window management`n; @version " VERSION "`n`n"
  If FileExist(original)
  {
    Loop, READ, %original%
    {
      If (SubStr(A_LoopReadLine, 1, 7) = "Config_")
        text .= A_LoopReadLine "`n"
    }
    text .= "`n"
  }

  Loop, % Manager_monitorCount
  {
    m := A_Index
    If Not (Monitor_#%m%_aView_#1 = 1)
      text .= "Monitor_#" m "_aView_#1=" Monitor_#%m%_aView_#1 "`n"
    If Not (Monitor_#%m%_aView_#2 = 1)
      text .= "Monitor_#" m "_aView_#2=" Monitor_#%m%_aView_#2 "`n"
    If Not (Monitor_#%m%_showBar = Config_showBar)
      text .= "Monitor_#" m "_showBar=" Monitor_#%m%_showBar "`n"
    Loop, % Config_viewCount
    {
      If Not (View_#%m%_#%A_Index%_layout_#1 = 1)
        text .= "View_#" m "_#" A_Index "_layout_#1=" View_#%m%_#%A_Index%_layout_#1 "`n"
      If Not (View_#%m%_#%A_Index%_layout_#2 = 1)
        text .= "View_#" m "_#" A_Index "_layout_#2=" View_#%m%_#%A_Index%_layout_#2 "`n"
      If Not (View_#%m%_#%A_Index%_layoutAxis_#1 = Config_layoutAxis_#1)
        text .= "View_#" m "_#" A_Index "_layoutAxis_#1=" View_#%m%_#%A_Index%_layoutAxis_#1 "`n"
      If Not (View_#%m%_#%A_Index%_layoutAxis_#2 = Config_layoutAxis_#2)
        text .= "View_#" m "_#" A_Index "_layoutAxis_#2=" View_#%m%_#%A_Index%_layoutAxis_#2 "`n"
      If Not (View_#%m%_#%A_Index%_layoutAxis_#3 = Config_layoutAxis_#3)
        text .= "View_#" m "_#" A_Index "_layoutAxis_#3=" View_#%m%_#%A_Index%_layoutAxis_#3 "`n"
      If Not (View_#%m%_#%A_Index%_layoutGapWidth = Config_layoutGapWidth)
        text .= "View_#" m "_#" A_Index "_layoutGapWidth=" View_#%m%_#%A_Index%_layoutGapWidth "`n"
      If Not (View_#%m%_#%A_Index%_layoutMFact = Config_layoutMFactor)
        text .= "View_#" m "_#" A_Index "_layoutMFact=" View_#%m%_#%A_Index%_layoutMFact "`n"
      If Not (View_#%m%_#%A_Index%_layoutMX = 1)
        text .= "View_#" m "_#" A_Index "_layoutMX=" View_#%m%_#%A_Index%_layoutMX "`n"
      If Not (View_#%m%_#%A_Index%_layoutMY = 1)
        text .= "View_#" m "_#" A_Index "_layoutMY=" View_#%m%_#%A_Index%_layoutMY "`n"
    }
  }

  ;; The FileMove below is an all-or-nothing replacement of the file.
  ;; We don't want to leave this half-finished.
  FileAppend, %text%, %tmpfilename%
  If ErrorLevel And Not (original = Main.configFile And target = Main.configFile And Not FileExist(original)) {
    If FileExist(tmpfilename)
      FileDelete, %tmpfilename%
  } Else
    FileMove, %tmpfilename%, %target%, 1
}

Config_UI_saveSession() {
  Global Main

  Config_saveSession(Main.configFile, Main.configFile)
}

#MaxHotkeysPerInterval 200
;; shadyalfred: Fix MaxHotkeysPerInterval when scrolling (https://github.com/fuhsjr00/bug.n/commit/db3cc3c08c09881073eca6638e54c6d4335f0179)

;; Key definitions
;; Window management
#Down::View_activateWindow(0, +1)
#Up::View_activateWindow(0, -1)
#+Down::View_shuffleWindow(0, +1)
#+Up::View_shuffleWindow(0, -1)
#+Enter::View_shuffleWindow(1)
#c::Manager_closeWindow()
#+d::Window_toggleDecor()
#+f::View_toggleFloatingWindow()
#+m::Manager_moveWindow()
#^m::Manager_minimizeWindow()
#+s::Manager_sizeWindow()
#+x::Manager_maximizeWindow()
#i::Manager_getWindowInfo()
#+i::Manager_getWindowList()

;; Layout management
#Tab::View_setLayout(-1)
#f::View_setLayout(3)
#m::View_setLayout(2)
#t::View_setLayout(1)
#Left::View_setLayoutProperty("MFactor", 0, -0.05)
#Right::View_setLayoutProperty("MFactor", 0, +0.05)
#^t::View_setLayoutProperty("Axis", 0, +1, 1)
#^Enter::View_setLayoutProperty("Axis", 0, +2, 1)
#^Tab::View_setLayoutProperty("Axis", 0, +1, 2)
#^+Tab::View_setLayoutProperty("Axis", 0, +1, 3)
#^Up::View_setLayoutProperty("MY", 0, +1)
#^Down::View_setLayoutProperty("MY", 0, -1)
#^Right::View_setLayoutProperty("MX", 0, +1)
#^Left::View_setLayoutProperty("MX", 0, -1)
#+Left::View_setLayoutProperty("GapWidth", 0, -2)
#+Right::View_setLayoutProperty("GapWidth", 0, +2)
#^Backspace::View_resetTileLayout()

;; View/Tag management
#+n::View_toggleMargins()
#BackSpace::Monitor_activateView(-1)
#+0::Monitor_setWindowTag(10)
#1::Monitor_activateView(1)
#+1::Monitor_setWindowTag(1)
#^1::Monitor_toggleWindowTag(1)
#2::Monitor_activateView(2)
#+2::Monitor_setWindowTag(2)
#^2::Monitor_toggleWindowTag(2)
#3::Monitor_activateView(3)
#+3::Monitor_setWindowTag(3)
#^3::Monitor_toggleWindowTag(3)
#4::Monitor_activateView(4)
#+4::Monitor_setWindowTag(4)
#^4::Monitor_toggleWindowTag(4)
#5::Monitor_activateView(5)
#+5::Monitor_setWindowTag(5)
#^5::Monitor_toggleWindowTag(5)
#6::Monitor_activateView(6)
#+6::Monitor_setWindowTag(6)
#^6::Monitor_toggleWindowTag(6)
#7::Monitor_activateView(7)
#+7::Monitor_setWindowTag(7)
#^7::Monitor_toggleWindowTag(7)
#8::Monitor_activateView(8)
#+8::Monitor_setWindowTag(8)
#^8::Monitor_toggleWindowTag(8)
#9::Monitor_activateView(9)
#+9::Monitor_setWindowTag(9)
#^9::Monitor_toggleWindowTag(9)
~WheelUp::Manager_activateViewByMouse(-1)
~WheelDown::Manager_activateViewByMouse(+1)

;; Monitor management
#.::Manager_activateMonitor(0, +1)
#,::Manager_activateMonitor(0, -1)
#+.::Manager_setWindowMonitor(0, +1)
#+,::Manager_setWindowMonitor(0, -1)
#^+.::Manager_setViewMonitor(0, +1)
#^+,::Manager_setViewMonitor(0, -1)

;; GUI management
#+Space::Monitor_toggleBar()

;; Administration
#^e::Config_edit()
#^s::Config_UI_saveSession()
#^r::Reload
#^q::ExitApp
