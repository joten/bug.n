/*
  bug.n -- tiling window management
  Copyright (c) 2010-2019 Joshua Fuhs, joten

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  @license GNU General Public License version 3
           ../LICENSE.md or <http://www.gnu.org/licenses/>

  @version 9.1.0
*/

Bar_init(m) {
  Local appBarMsg, anyText, color, color0, GuiN, h1, h2, i, id, id0, text, text0, trayWndId, w, wndId, wndTitle, wndWidth, x1, x2, y1, y2

  If (SubStr(Config_barWidth, 0) = "%") {
    StringTrimRight, wndWidth, Config_barWidth, 1
    wndWidth := Round(Monitor_#%m%_width * wndWidth / 100)
  } Else
    wndWidth := Config_barWidth

  wndWidth := Round(wndWidth / mmngr1.monitors[m].scaleX)
  If (Config_verticalBarPos = "tray" And Monitor_#%m%_taskBarClass) {
    Bar_ctrlHeight := Round(Bar_ctrlHeight / mmngr1.monitors[m].scaleY)
    Bar_height := Round(Bar_height / mmngr1.monitors[m].scaleY)
  }

  Monitor_#%m%_barWidth := wndWidth
  h1 := Bar_ctrlHeight
  x1 := 0
  x2 := wndWidth
  y1 := 0
  y2 := (Bar_ctrlHeight - Bar_textHeight) / 2
  h2 := Bar_textHeight

  ;; Create the GUI window
  wndTitle := "bug.n_BAR_" m
  GuiN := (m - 1) + 1
  Gui, %GuiN%: Default
  Gui, Destroy
  Gui, +AlwaysOnTop -Caption +LabelBar_Gui +LastFound +ToolWindow
  Gui, Color, %Config_backColor_#1_#3%
  Gui, Font, c%Config_fontColor_#1_#3% s%Config_fontSize%, %Config_fontName%

  ;; Views
  Loop, % Config_viewCount {
    w := Bar_getTextWidth(" " Config_viewNames_#%A_Index% " ")
    Bar_addElement(m, "view_#" A_Index, " " Config_viewNames_#%A_Index% " ", x1, y1, w, Config_backColor_#1_#1, Config_foreColor_#1_#1, Config_fontColor_#1_#1)
    x1 += w
  }
  ;; Layout
  w := Bar_getTextWidth(" ?????? ")
  Bar_addElement(m, "layout", " ?????? ", x1, y1, w, Config_backColor_#1_#2, Config_foreColor_#1_#2, Config_fontColor_#1_#2)
  x1 += w

  If Not Config_singleRowBar {
    x1 := 0
    y1 += h1
    y2 += h1
  }

  If (Config_horizontalBarPos = "left")
    x1 := 0
  Else If (Config_horizontalBarPos = "right")
    x1 := Monitor_#%m%_width - wndWidth * mmngr1.monitors[m].scaleX
  Else If (Config_horizontalBarPos = "center")
    x1 := (Monitor_#%m%_width - wndWidth * mmngr1.monitors[m].scaleX) / 2
  Else If (Config_horizontalBarPos >= 0)
    x1 := Config_horizontalBarPos
  Else If (Config_horizontalBarPos < 0)
    x1 := Monitor_#%m%_width - wndWidth * mmngr1.monitors[m].scaleX + Config_horizontalBarPos
  If Not (Config_verticalBarPos = "tray" And Monitor_#%m%_taskBarClass)
    x1 += Monitor_#%m%_x
  x1 := Round(x1)

  Monitor_#%m%_barX := x1
  y1 := Monitor_#%m%_barY

  If Monitor_#%m%_showBar
    Gui, Show, NoActivate x%x1% y%y1% w%wndWidth% h%Bar_height%, %wndTitle%
  Else
    Gui, Show, NoActivate Hide x%x1% y%y1% w%wndWidth% h%Bar_height%, %wndTitle%
  WinSet, Transparent, %Config_barTransparency%, %wndTitle%
  wndId := WinExist(wndTitle)
  Bar_appBarData := ""
  If (Config_verticalBarPos = "tray" And Monitor_#%m%_taskBarClass) {
    trayWndId := WinExist("ahk_class " Monitor_#%m%_taskBarClass)
    DllCall("SetParent", "UInt", wndId, "UInt", trayWndId)
  } Else {
    appBarMsg := DllCall("RegisterWindowMessage", Str, "AppBarMsg")

    ;; appBarData: http://msdn2.microsoft.com/en-us/library/ms538008.aspx
    VarSetCapacity(Bar_appBarData, 36, 0)
    offset := NumPut(             36, Bar_appBarData)
    offset := NumPut(          wndId, offset+0)
    offset := NumPut(      appBarMsg, offset+0)
    offset := NumPut(              1, offset+0)
    offset := NumPut(             x1, offset+0)
    offset := NumPut(             y1, offset+0)
    offset := NumPut(  x1 + wndWidth, offset+0)
    offset := NumPut(y1 + Bar_height, offset+0)
    offset := NumPut(              1, offset+0)

    DllCall("Shell32.dll\SHAppBarMessage", "UInt", (ABM_NEW := 0x0)     , "UInt", &Bar_appBarData)
    DllCall("Shell32.dll\SHAppBarMessage", "UInt", (ABM_QUERYPOS := 0x2), "UInt", &Bar_appBarData)
    DllCall("Shell32.dll\SHAppBarMessage", "UInt", (ABM_SETPOS := 0x3)  , "UInt", &Bar_appBarData)
    ;; SKAN: Crazy Scripting : Quick Launcher for Portable Apps (http://www.autohotkey.com/forum/topic22398.html)
  }
}

Bar_addElement(m, id, text, x, y1, width, backColor, foreColor, fontColor) {
  Local y2

  y2 := y1 + (Bar_ctrlHeight - Bar_textHeight) / 2
  Gui, Add, Text, x%x% y%y1% w%width% h%Bar_ctrlHeight% BackgroundTrans vBar_#%m%_%id%_event gBar_GuiClick,
  Gui, Add, Progress, x%x% y%y1% w%width% h%Bar_ctrlHeight% Background%backColor% c%foreColor% vBar_#%m%_%id%_highlighted
  GuiControl, , Bar_#%m%_%id%_highlighted, 100
  Gui, Font, c%fontColor%
  Gui, Add, Text, x%x% y%y2% w%width% h%Bar_textHeight% BackgroundTrans Center vBar_#%m%_%id%, %text%
}

Bar_getHeight()
{
  Global Bar_#0_#1, Bar_#0_#1H, Bar_#0_#2, Bar_#0_#2H, Bar_ctrlHeight, Bar_height, Bar_textHeight
  Global Config_fontName, Config_fontSize, Config_singleRowBar, Config_spaciousBar, Config_verticalBarPos

  wndTitle := "bug.n_BAR_0"
  Gui, 99: Default
  Gui, Font, s%Config_fontSize%, %Config_fontName%
  Gui, Add, Text, x0 y0 vBar_#0_#1, |
  GuiControlGet, Bar_#0_#1, Pos
  Bar_textHeight := Bar_#0_#1H
  If Config_spaciousBar
  {
    Gui, Add, ComboBox, r9 x0 y0 vBar_#0_#2, |
    GuiControlGet, Bar_#0_#2, Pos
    Bar_ctrlHeight := Bar_#0_#2H
  }
  Else
    Bar_ctrlHeight := Bar_textHeight
  Gui, Destroy

  Bar_height := Bar_ctrlHeight
  If Not Config_singleRowBar
    Bar_height *= 2
  If (Config_verticalBarPos = "tray")
  {
    WinGetPos, , , , buttonH, Start ahk_class Button
    WinGetPos, , , , barH, ahk_class Shell_TrayWnd
    If WinExist("Start ahk_class Button") And (buttonH < barH)
      Bar_height := buttonH
    Else
      Bar_height := barH
    Bar_ctrlHeight := Bar_height
    If Not Config_singleRowBar
      Bar_ctrlHeight := Bar_height / 2
  }
}

Bar_getTextWidth(x, reverse=False)
{
  Global Config_fontSize

  If reverse
  {    ;; 'reverse' calculates the number of characters to a given width.
    w := x
    i := w / (Config_fontSize - 1)
    If (Config_fontSize = 7 Or (Config_fontSize > 8 And Config_fontSize < 13))
      i := w / (Config_fontSize - 2)
    Else If (Config_fontSize > 12 And Config_fontSize < 18)
      i := w / (Config_fontSize - 3)
    Else If (Config_fontSize > 17)
      i := w / (Config_fontSize - 4)
    textWidth := i
  }
  Else
  {    ;; 'else' calculates the width to a given string.
    textWidth := StrLen(x) * (Config_fontSize - 1)
    If (Config_fontSize = 7 Or (Config_fontSize > 8 And Config_fontSize < 13))
      textWidth := StrLen(x) * (Config_fontSize - 2)
    Else If (Config_fontSize > 12 And Config_fontSize < 18)
      textWidth := StrLen(x) * (Config_fontSize - 3)
    Else If (Config_fontSize > 17)
      textWidth := StrLen(x) * (Config_fontSize - 4)
  }

  Return, textWidth
}

Bar_GuiClick:
  Manager_winActivate(Bar_aWndId)
  If (A_GuiEvent = "Normal") {
    If Not (SubStr(A_GuiControl, 6, InStr(A_GuiControl, "_", False, 6) - 6) = Manager_aMonitor)
      Manager_activateMonitor(SubStr(A_GuiControl, 6, InStr(A_GuiControl, "_", False, 6) - 6))
    If (SubStr(A_GuiControl, -12) = "_layout_event")
      View_setLayout(-1)
    Else If InStr(A_GuiControl, "_view_#") And (SubStr(A_GuiControl, -5) = "_event")
      Monitor_activateView(SubStr(A_GuiControl, InStr(A_GuiControl, "_view_#", False, 0) + 7, 1))
  }
Return

Bar_GuiContextMenu:
  Manager_winActivate(Bar_aWndId)
  If (A_GuiEvent = "RightClick") {
    If (SubStr(A_GuiControl, -12) = "_layout_event") {
      If Not (SubStr(A_GuiControl, 6, InStr(A_GuiControl, "_", False, 6) - 6) = Manager_aMonitor)
        Manager_activateMonitor(SubStr(A_GuiControl, 6, InStr(A_GuiControl, "_", False, 6) - 6))
      View_setLayout(0, +1)
    } Else If InStr(A_GuiControl, "_view_#") And (SubStr(A_GuiControl, -5) = "_event") {
      If Not (SubStr(A_GuiControl, 6, InStr(A_GuiControl, "_", False, 6) - 6) = Manager_aMonitor)
        Manager_setWindowMonitor(SubStr(A_GuiControl, 6, InStr(A_GuiControl, "_", False, 6) - 6))
      Monitor_setWindowTag(SubStr(A_GuiControl, InStr(A_GuiControl, "_view_#", False, 0) + 7, 1))
    }
  }
Return

Bar_move(m)
{
  Local wndTitle, x, y

  x := Monitor_#%m%_barX
  y := Monitor_#%m%_barY

  wndTitle := "bug.n_BAR_" m
  WinMove, %wndTitle%, , %x%, %y%
}

Bar_toggleVisibility(m)
{
  Local GuiN

  GuiN := (m - 1) + 1
  If Monitor_#%m%_showBar
  {
    Gui, %GuiN%: Show
  }
  Else
    Gui, %GuiN%: Cancel
}

Bar_updateLayout(m) {
  Local aView, GuiN

  aView := Monitor_#%m%_aView_#1
  GuiN := (m - 1) + 1
  GuiControl, %GuiN%: , Bar_#%m%_layout, % View_#%m%_#%aView%_layoutSymbol
  ;; TODO: Change layout symbol, if window is floating.
}

Bar_updateView(m, v) {
  Local managedWndId0, wndId0, wndIds

  GuiN := (m - 1) + 1
  Gui, %GuiN%: Default

  StringTrimRight, wndIds, Manager_managedWndIds, 1
  StringSplit, managedWndId, wndIds, `;

  If (v = Monitor_#%m%_aView_#1) {
    ;; Set foreground/background colors if the view is the current view.
    GuiControl, +Background%Config_backColor_#2_#1% +c%Config_foreColor_#2_#1%, Bar_#%m%_view_#%v%_highlighted
    GuiControl, +c%Config_fontColor_#2_#1%, Bar_#%m%_view_#%v%
  } Else {
    ;; Set foreground/background colors.
    GuiControl, +Background%Config_backColor_#1_#1% +c%Config_foreColor_#1_#1%, Bar_#%m%_view_#%v%_highlighted
    GuiControl, +c%Config_fontColor_#1_#1%, Bar_#%m%_view_#%v%
  }

  Loop, % Config_viewCount {
    StringTrimRight, wndIds, View_#%m%_#%A_Index%_wndIds, 1
    StringSplit, wndId, wndIds, `;
    GuiControl, , Bar_#%m%_view_#%A_Index%_highlighted, % wndId0 / managedWndId0 * 100    ;; Update the percentage fill for the view.
    GuiControl, , Bar_#%m%_view_#%A_Index%, % Config_viewNames_#%A_Index%                 ;; Refresh the number on the bar.
  }
}
