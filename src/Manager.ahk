/*
:title:     bug.n - tiling window management
:copyright: (c) 2022 joten <https://github.com/joten>
                2010 - 2021 https://github.com/fuhsjr00/bug.n/graphs/contributors
:license:  GNU General Public License version 3 (http://www.gnu.org/licenses/gpl-3.0.txt)

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/

Manager_init()
{
  Local doRestore

  Bar_getHeight()
  ; axes, dimensions, percentage, flipped, gapWidth
  Manager_layoutDirty := 0
  ; New/closed windows, active changed,
  Manager_windowsDirty := 0
  Manager_aMonitor := 1
  View_tiledWndId0 := 0

  doRestore := 0
  If (Config_autoSaveSession = "ask")
  {
    MsgBox, 0x4, , Would you like to restore an auto-saved session?
    IfMsgBox Yes
      doRestore := 1
  }
  Else If (Config_autoSaveSession = "auto")
  {
    doRestore := 1
  }

  mmngr1 := New MonitorManager()
  mmngr2 := ""
  SysGet, Manager_monitorCount, MonitorCount
  Loop, % Manager_monitorCount
  {
    Sleep, % Config_shellMsgDelay
    Monitor_init(A_Index, doRestore)
  }

  Manager_hideShow      := False
  Bar_hideTitleWndIds   := ""
  Manager_allWndIds     := ""
  Manager_managedWndIds := ""
  Manager_initial_sync(doRestore)

  Loop, % Manager_monitorCount
  {
    View_arrange(A_Index, Monitor_#%A_Index%_aView_#1)
    Bar_updateView(A_Index, Monitor_#%A_Index%_aView_#1)
  }

  Manager_registerShellHook()
  SetTimer, Manager_doMaintenance, %Config_maintenanceInterval%
}

Manager_activateMonitor(i, d = 0) {
  Local aView, aWndHeight, aWndId, aWndWidth, aWndX, aWndY, v, wndId

  If (Manager_monitorCount > 1) {
    aView := Monitor_#%Manager_aMonitor%_aView_#1
    WinGet, aWndId, ID, A
    If WinExist("ahk_id" aWndId) And InStr(View_#%Manager_aMonitor%_#%aView%_wndIds, aWndId ";") And Window_isProg(aWndId) {
      WinGetPos, aWndX, aWndY, aWndWidth, aWndHeight, ahk_id %aWndId%
      If (Monitor_get(aWndX + aWndWidth / 2, aWndY + aWndHeight / 2) = Manager_aMonitor)
        View_setActiveWindow(Manager_aMonitor, aView, aWndId)
    }

    ;; Manually set the active monitor.
    If (i = 0)
      i := Manager_aMonitor
    Manager_aMonitor := Manager_loop(i, d, 1, Manager_monitorCount)
    v := Monitor_#%Manager_aMonitor%_aView_#1
    wndId := View_getActiveWindow(Manager_aMonitor, v)
    Manager_winActivate(wndId)
  }
  ;; TODO: Indicate active monitor in bar.
}

Manager_applyRules(wndId, ByRef isManaged, ByRef m, ByRef tags, ByRef isFloating, ByRef isDecorated, ByRef hideTitle, ByRef action) {
  Local i, wndClass, wndTitle
  Local rule0, rule1, rule2, rule3, rule4, rule5, rule6, rule7, rule8, rule9, rule10

  isManaged   := True
  m           := 0
  tags        := 0
  isFloating  := False
  isDecorated := False
  hideTitle   := False
  action      := ""

  WinGetClass, wndClass, ahk_id %wndId%
  WinGetTitle, wndTitle, ahk_id %wndId%
  If (wndClass Or wndTitle) {
    Loop, % Config_ruleCount {
      ;; The rules are traversed in reverse order.
      i := Config_ruleCount - A_Index + 1
      StringSplit, rule, Config_rule_#%i%, `;
      If RegExMatch(wndClass . ";" . wndTitle, rule1 . ";" . rule2) And (rule3 = "" Or %rule3%(wndId)) {
        isManaged   := rule4
        m           := rule5
        tags        := rule6
        isFloating  := rule7
        isDecorated := rule8
        hideTitle   := rule9
        action      := rule10
        ;; The first matching rule is returned, i. e. the last in the original rder of Config_rule.
        Break
      }
    }
  } Else {
    isManaged := False
    If wndTitle
      hideTitle := True
  }
}

Manager_cleanup()
{
  Local aWndId, m, ncmSize, ncm, wndIds

  WinGet, aWndId, ID, A

  ;; Show borders and title bars.
  StringTrimRight, wndIds, Manager_managedWndIds, 1
  Manager_hideShow := True
  Loop, PARSE, wndIds, `;
  {
    Window_show(A_LoopField)
    Window_set(A_LoopField, "Style", "+0xC00000")
  }
  Manager_hideShow := False

  ;; Restore window positions and sizes.
  Loop, % Manager_monitorCount
  {
    m := A_Index
    Monitor_#%m%_showBar := False
    Monitor_getWorkArea(m)
    Loop, % Config_viewCount
    {
      View_arrange(m, A_Index)
    }
  }
  Window_set(aWndId, "AlwaysOnTop", "On")
  Window_set(aWndId, "AlwaysOnTop", "Off")

  DllCall("Shell32.dll\SHAppBarMessage", "UInt", (ABM_REMOVE := 0x1), "UInt", &Bar_appBarData)
  ;; SKAN: Crazy Scripting : Quick Launcher for Portable Apps (http://www.autohotkey.com/forum/topic22398.html)
}

Manager_closeWindow() {
  Local aWndId

  WinGet, aWndId, ID, A
  If Window_isProg(aWndId)
    Window_close(aWndId)
}

; Asynchronous management of various WM properties.
; We want to make sure that we can recover the layout and windows in the event of
; unexpected problems.
; Periodically check for changes to these things and save them somewhere (not over
; user-defined files).
Manager_doMaintenance:
  Critical

  ;; @TODO: Manager_sync?
  If Not (Config_autoSaveSession = "off") And Not (Config_autoSaveSession = "False")
    Manager_saveState()
Return

Manager_getWindowInfo() {
  Local aWndClass, aWndHeight, aWndId, aWndPId, aWndPName, aWndStyle, aWndTitle, aWndWidth, aWndX, aWndY, detectHiddenWnds, isHidden, text, v

  detectHiddenWnds := A_DetectHiddenWindows
  DetectHiddenWindows, On
  WinGet, aWndId, ID, A
  DetectHiddenWindows, %detectHiddenWnds%
  isHidden := Window_getHidden(aWndId, aWndClass, aWndTitle)
  WinGet, aWndPName, ProcessName, ahk_id %aWndId%
  WinGet, aWndPId, PID, ahk_id %aWndId%
  WinGet, aWndStyle, Style, ahk_id %aWndId%
  WinGet, aWndMinMax, MinMax, ahk_id %aWndId%
  WinGetPos, aWndX, aWndY, aWndWidth, aWndHeight, ahk_id %aWndId%
  text := "ID: " aWndId (isHidden ? " [hidden]" : "") "`nclass:`t" aWndClass "`ntitle:`t" aWndTitle
  If InStr(Bar_hideTitleWndIds, aWndId ";")
    text .= " [hidden]"
  text .= "`nprocess:`t" aWndPName " [" aWndPId "]`nstyle:`t" aWndStyle "`nmetrics:`tx: " aWndX ", y: " aWndY ", width: " aWndWidth ", height: " aWndHeight
  If InStr(Manager_managedWndIds, aWndId ";") {
    text .= "`ntags:`t" Window_#%aWndId%_tags
    If Window_#%aWndId%_isFloating
      text .= " [floating]"
  } Else
    text .= "`ntags:`t--"
  text .= "`n`nConfig_rule=" aWndClass ";" aWndTitle ";;" Manager_getWindowRule(aWndId)
  MsgBox, 260, bug.n: Window Information, % text "`n`nCopy text to clipboard?"
  IfMsgBox Yes
    Clipboard := text
}

Manager_getWindowList()
{
  Local text, v, aWndId, aWndTitle, wndIds, wndTitle

  v := Monitor_#%Manager_aMonitor%_aView_#1
  aWndId := View_getActiveWindow(Manager_aMonitor, v)
  WinGetTitle, aWndTitle, ahk_id %aWndId%
  text := "Active Window`n" aWndId ":`t" aWndTitle

  StringTrimRight, wndIds, View_#%Manager_aMonitor%_#%v%_wndIds, 1
  text .= "`n`nWindow List"
  Loop, PARSE, wndIds, `;
  {
    WinGetTitle, wndTitle, ahk_id %A_LoopField%
    text .= "`n" A_LoopField ":`t" wndTitle
  }

  MsgBox, 260, bug.n: Window List, % text "`n`nCopy text to clipboard?"
  IfMsgBox Yes
    Clipboard := text
}

Manager_getWindowRule(wndId) {
  Local rule, wndMinMax
  
  rule := ""
  WinGet, wndMinMax, MinMax, ahk_id %wndId%
  If InStr(Manager_managedWndIds, wndId ";") {
    rule .= "1;"
    If (Window_#%wndId%_monitor = "")
      rule .= "0;"
    Else
      rule .= Window_#%wndId%_monitor ";"
    If (Window_#%wndId%_tags = "")
      rule .= "0;"
    Else
      rule .= Window_#%wndId%_tags ";"
    If Window_#%wndId%_isFloating
      rule .= "1;"
    Else
      rule .= "0;"
    If Window_#%wndId%_isDecorated
      rule .= "1;"
    Else
      rule .= "0;"
  } Else
    rule .= "0;;;;;"
  If InStr(Bar_hideTitleWndIds, wndId ";")
    rule .= "1;"
  Else
    rule .= "0;"
  If (wndMinMax = 1)
    rule .= "maximize"
  
  Return, rule
}

Manager_lockWorkStation()
{
  Global Config_shellMsgDelay

  RegWrite, REG_DWORD, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Policies\System, DisableLockWorkstation, 0
  Sleep, % Config_shellMsgDelay
  DllCall("LockWorkStation")
  Sleep, % 4 * Config_shellMsgDelay
  RegWrite, REG_DWORD, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Policies\System, DisableLockWorkstation, 1
}
;; Unambiguous: Re-use WIN+L as a hotkey in bug.n (http://www.autohotkey.com/community/viewtopic.php?p=500903&sid=eb3c7a119259b4015ff045ef80b94a81#p500903)

Manager_loop(index, increment, lowerBound, upperBound) {
  If (upperBound <= 0) Or (upperBound < lowerBound) Or (upperBound = 0)
    Return, 0

  numberOfIndexes := upperBound - lowerBound + 1
  lowerBoundBasedIndex := index - lowerBound
  lowerBoundBasedIndex := Mod(lowerBoundBasedIndex + increment, numberOfIndexes)
  If (lowerBoundBasedIndex < 0)
    lowerBoundBasedIndex += numberOfIndexes

  Return, lowerBound + lowerBoundBasedIndex
}

Manager__setWinProperties(wndId, isManaged, m, tags, isDecorated, isFloating, hideTitle, action = "") {
  Local a := False

  If Not InStr(Manager_allWndIds, wndId ";")
    Manager_allWndIds .= wndId ";"

  If (isManaged) {
    If (action = "close" Or action = "maximize" Or action = "restore")
      Window_%action%(wndId)

    If Not InStr(Manager_managedWndIds, wndId ";")
      Manager_managedWndIds .= wndId ";"
    Window_#%wndId%_monitor     := m
    Window_#%wndId%_tags        := tags
    Window_#%wndId%_isDecorated := isDecorated
    Window_#%wndId%_isFloating  := isFloating
    Window_#%wndId%_isMinimized := False
    Window_#%wndId%_area        := 0

    If Not Window_#%wndId%_isDecorated
      Window_set(wndId, "Style", "-0xC00000")

    a := Window_#%wndId%_tags & (1 << (Monitor_#%m%_aView_#1 - 1))
    If a {
      ;; A newly created window defines the active monitor, if it is visible.
      Manager_aMonitor := m
      Manager_winActivate(wndId)
    } Else {
      Manager_hideShow := True
      Window_hide(wndId)
      Manager_hideShow := False
    }
  }
  If hideTitle And Not InStr(Bar_hideTitleWndIds, wndId ";")
    Bar_hideTitleWndIds .= wndId . ";"

  Return, a
}

;; Accept a window to be added to the system for management.
;; Provide a monitor and view preference, but don't override the config.
Manager_manage(preferredMonitor, preferredView, wndId, rule = "") {
  Local a, action, c0, hideTitle, i, isDecorated, isFloating, isManaged, l, m, n, replace, search, tags, body
  Local rule0, rule1, rule2, rule3, rule4, rule5, rule6, rule7
  Local wndControlList0, wndId0, wndIds, wndX, wndY, wndWidth, wndHeight

  ;; Manage any window only once.
  If InStr(Manager_allWndIds, wndId ";") And (rule = "")
    Return

  body := 0
  If Window_isGhost(wndId) {
    body := Window_findHung(wndId)
    If body {
      isManaged := InStr(Manager_managedWndIds, body ";")
      m := Window_#%body%_monitor
      tags := Window_#%body%_tags
      isDecorated := Window_#%body%_isDecorated
      isFloating := Window_#%body%_isFloating
      hideTitle := InStr(Bar_hideTitleWndIds, body ";")
      action := ""
    }
  }

  ;; Apply rules if the window is either a normal window or a ghost without a body.
  If (body = 0) {
    Manager_applyRules(wndId, isManaged, m, tags, isFloating, isDecorated, hideTitle, action)
    If Not (rule = "") {
      StringSplit, rule, rule, `;
      isManaged   := rule1
      m           := rule2
      tags        := rule3
      isFloating  := rule4
      isDecorated := rule5
      hideTitle   := rule6
      action      := rule7
    }
    If (m = 0)
      m := preferredMonitor
    If (m < 0)
      m := 1
    If (m > Manager_monitorCount)    ;; If the specified monitor is out of scope, set it to the max. monitor.
      m := Manager_monitorCount
    If (tags = 0)
      tags := 1 << (preferredView - 1)
  }

  a := Manager__setWinProperties(wndId, isManaged, m, tags, isDecorated, isFloating, hideTitle, action)

  ; Do view placement.
  If isManaged {
    Loop, % Config_viewCount
      If (Window_#%wndId%_tags & (1 << (A_Index - 1))) {
        If (body) {
          ; Try to position near the body.
          View_ghostWindow(m, A_Index, body, wndId)
        }
        Else
          View_addWindow(m, A_Index, wndId)
      }
  }

  Return, a
}

Manager_maximizeWindow() {
  Local aWndId

  WinGet, aWndId, ID, A
  If InStr(Manager_managedWndIds, aWndId ";") And Not Window_#%aWndId%_isFloating
    View_toggleFloatingWindow(aWndId)
  Window_set(aWndId, "Top", "")

  Window_move(aWndId, Monitor_#%Manager_aMonitor%_x, Monitor_#%Manager_aMonitor%_y, Monitor_#%Manager_aMonitor%_width, Monitor_#%Manager_aMonitor%_height)
}

Manager_minimizeWindow() {
  Local aView, aWndId

  WinGet, aWndId, ID, A
  aView := Monitor_#%Manager_aMonitor%_aView_#1
  StringReplace, View_#%Manager_aMonitor%_#%aView%_aWndIds, View_#%Manager_aMonitor%_#%aView%_aWndIds, % aWndId ";",, All
  If InStr(Manager_managedWndIds, aWndId ";") And Not Window_#%aWndId%_isFloating
    View_toggleFloatingWindow(aWndId)
  Window_set(aWndId, "Bottom", "")

  Window_minimize(aWndId)
}

Manager_moveWindow() {
  Local aWndId, SC_MOVE, WM_SYSCOMMAND

  WinGet, aWndId, ID, A
  If InStr(Manager_managedWndIds, aWndId . ";") And Not Window_#%aWndId%_isFloating
    View_toggleFloatingWindow(aWndId)
  Window_set(aWndId, "Top", "")

  WM_SYSCOMMAND = 0x112
  SC_MOVE       = 0xF010
  SendMessage, WM_SYSCOMMAND, SC_MOVE, , , ahk_id %aWndId%
}

Manager_onDisplayChange(a, wParam, uMsg, lParam) {
  Local doChange := (Config_monitorDisplayChangeMessages = "on")
  
  If !(Config_monitorDisplayChangeMessages = "on" || Config_monitorDisplayChangeMessages = "off" || Config_monitorDisplayChangeMessages = 0) {
    MsgBox, 291, , % "Would you like to reset the monitor configuration?`n'No' will only rearrange all active views.`n'Cancel' will result in no change."
    IfMsgBox Yes
      doChange := True
    Else IfMsgBox No
    {
      Loop, % Manager_monitorCount {
        View_arrange(A_Index, Monitor_#%A_Index%_aView_#1)
        Bar_updateView(A_Index, Monitor_#%A_Index%_aView_#1)
      }
    }
  }
  If (doChange) {
    Manager_resetMonitorConfiguration()
  }
}

/*
  Possible indications for a ...
    new window: 1 (started by Windows Explorer) or 6 (started by cmd, shell or Win+E).
      There doesn't seem to be a reliable way to get all application starts.
    closed window: 2 (always?) or 13 (ghost)
    focus change: 4 or 32772
    title change: 6 or 32774
*/
Manager_onShellMessage(wParam, lParam) {
  Local a, isChanged, aWndClass, aWndHeight, aWndId, aWndTitle, aWndWidth, aWndX, aWndY, i, m, t, wndClass, wndId, wndId0, wndIds, wndIsDesktop, wndIsHidden, wndTitle, x, y
  ;; HSHELL_* become global.

  ;; MESSAGE NAME AND         ... NUMBER    COMMENTS, POSSIBLE EVENTS
  HSHELL_WINDOWCREATED        :=  1         ;; window shown
  HSHELL_WINDOWDESTROYED      :=  2         ;; window hidden, destroyed or deactivated
  HSHELL_ACTIVATESHELLWINDOW  :=  3
  HSHELL_WINDOWACTIVATED      :=  4         ;; window title changed, window activated (by mouse, Alt+Tab or hotkey); alternative message: 32772
  HSHELL_GETMINRECT           :=  5
  HSHELL_REDRAW               :=  6         ;; window title changed
  HSHELL_TASKMAN              :=  7
  HSHELL_LANGUAGE             :=  8
  HSHELL_SYSMENU              :=  9
  HSHELL_ENDTASK              := 10
  HSHELL_ACCESSIBILITYSTATE   := 11
  HSHELL_APPCOMMAND           := 12
  ;; The following two are seen when a hung window recovers.
  HSHELL_WINDOWREPLACED       := 13         ;; hung window recovered and replaced the ghost window (lParam indicates the ghost window.)
  HSHELL_WINDOWREPLACING      := 14         ;; hung window recovered (lParam indicates the previously hung and now recovered window.)
  HSHELL_HIGHBIT              := 32768      ;; 0x8000
  HSHELL_FLASH                := 32774      ;; (HSHELL_REDRAW|HSHELL_HIGHBIT); window signalling an application update (The window is flashing due to some event, one message for each flash.)
  HSHELL_RUDEAPPACTIVATED     := 32772      ;; (HSHELL_WINDOWACTIVATED|HSHELL_HIGHBIT); full-screen app or root-privileged window activated? alternative message: 4
  ;; Any message may be missed, if bug.n is hung or they come in too quickly.

  SetFormat, Integer, hex
  lParam := lParam + 0
  SetFormat, Integer, d

  wndIsHidden := Window_getHidden(lParam, wndClass, wndTitle)
  If wndIsHidden {
    ;; If there is no window class or title, it is assumed that the window is not identifiable.
    ;;   The problem was, that i. a. claws-mail triggers Manager_sync, but the application window
    ;;   would not be ready for being managed, i. e. class and title were not available. Therefore more
    ;;   attempts were needed.
    Return
  }

  wndIsDesktop := (lParam = 0)
  If wndIsDesktop {
    WinGetClass, wndClass, A
    WinGetTitle, wndTitle, A
  }
  WinGet, aWndId, ID, A
  WinGetClass, aWndClass, ahk_id %aWndId%
  WinGetTitle, aWndTitle, ahk_id %aWndId%
  If ((wParam = 4 Or wParam = 32772) And (aWndClass = "WorkerW" And aWndTitle = "" Or lParam = 0 And aWndClass = "Progman" And aWndTitle = "Program Manager"))
  {
    MouseGetPos, x, y
    m := Monitor_get(x, y)
    ;; The current position of the mouse cursor defines the active monitor, if the desktop has been activated.
    If m
      Manager_aMonitor := m
  }

  ;; This was previously inactive due to `HSHELL_WINDOWREPLACED` not being defined in this function.
  ;; Afterwards it caused problems managing new windows, when messages come in too quickly.
;  If (wParam = HSHELL_WINDOWREPLACED)
;  {    ;; This shouldn't need a redraw because the window was supposedly replaced.
;    Manager_unmanage(lParam)
;  }

; If (wParam = 14)
; {    ;; Window recovered from being hung. Maybe force a redraw.
; }

  ;; @todo: There are two problems with the use of Manager_hideShow:
  ;;   1) If Manager_hideShow is set when we hit this block, we won't take some actions that should eventually be taken.
  ;;      This _may_ explain why some windows never get picked up when spamming Win+E
  ;;   2) There is a race condition between the time that Manager_hideShow is checked and any other action which we are
  ;;      trying to protect against. If another process (hotkey) enters a hideShow block after Manager_hideShow has
  ;;      been checked here, bad things could happen. I've personally observed that windows may be permanently hidden.
  ;;   Look into the use of AHK synchronization primitives.
  If (wParam = 1 Or wParam = 2 Or wParam = 4 Or wParam = 6 Or wParam = 32772) And lParam And Not Manager_hideShow
  {
    Sleep, % Config_shellMsgDelay
    wndIds := ""
    a := isChanged := Manager_sync(wndIds)
    If wndIds
      isChanged := False

    If isChanged
    {
      View_arrange(Manager_aMonitor, Monitor_#%Manager_aMonitor%_aView_#1)
      Bar_updateView(Manager_aMonitor, Monitor_#%Manager_aMonitor%_aView_#1)
    }

    If (Manager_monitorCount > 1 And a > -1)
    {
      WinGet, aWndId, ID, A
      WinGetPos, aWndX, aWndY, aWndWidth, aWndHeight, ahk_id %aWndId%
      m := Monitor_get(aWndX + aWndWidth / 2, aWndY + aWndHeight / 2)
      ;; The currently active window defines the active monitor.
      If m
        Manager_aMonitor := m
    }

    If wndIds
    {    ;; If there are new (unrecognized) windows, which are hidden ...
      If (Config_onActiveHiddenWnds = "view")
      {  ;; ... change the view to show the first hidden window
        wndId := SubStr(wndIds, 1, InStr(wndIds, ";") - 1)
        Loop, % Config_viewCount
        {
          If (Window_#%wndId%_tags & 1 << A_Index - 1)
          {
            ;; A newly created window defines the active monitor, if it is visible.
            Manager_aMonitor := Window_#%wndId%_monitor
            Monitor_activateView(A_Index)
            Break
          }
        }
      }
      Else
      {  ;; ... re-hide them
        StringTrimRight, wndIds, wndIds, 1
        StringSplit, wndId, wndIds, `;
        If (Config_onActiveHiddenWnds = "hide")
        {
          Loop, % wndId0
          {
            Window_hide(wndId%A_Index%)
          }
        }
        Else If (Config_onActiveHiddenWnds = "tag")
        {
          ;; ... or tag all of them for the current view.
          t := Monitor_#%Manager_aMonitor%_aView_#1
          Loop, % wndId0
          {
            wndId := wndId%A_Index%
            View_#%Manager_aMonitor%_#%t%_wndIds := wndId ";" View_#%Manager_aMonitor%_#%t%_wndIds
            View_setActiveWindow(Manager_aMonitor, t, wndId)
            Window_#%wndId%_tags += 1 << t - 1
          }
          Bar_updateView(Manager_aMonitor, t)
          View_arrange(Manager_aMonitor, t)
        }
      }
    }

    If InStr(Manager_managedWndIds, lParam ";") {
      WinGetPos, aWndX, aWndY, aWndWidth, aWndHeight, ahk_id %lParam%
      If (Monitor_get(aWndX + aWndWidth / 2, aWndY + aWndHeight / 2) = Manager_aMonitor)
        View_setActiveWindow(Manager_aMonitor, Monitor_#%Manager_aMonitor%_aView_#1, lParam)
      Else
        Manager_winActivate(View_getActiveWindow(Manager_aMonitor, Monitor_#%Manager_aMonitor%_aView_#1))
      If Window_#%lParam%_isMinimized {
        Window_#%lParam%_isFloating := False
        Window_#%lParam%_isMinimized := False
        View_arrange(Manager_aMonitor, Monitor_#%Manager_aMonitor%_aView_#1)
      }
    }

    ;; This is a workaround for a redrawing problem of the bug.n bar, which
    ;; seems to get lost, when windows are created or destroyed under the
    ;; following conditions.
    If (Manager_monitorCount > 1) And (Config_verticalBarPos = "tray") {
      Loop, % (Manager_monitorCount - 1) {
        i := A_Index + 1
        Bar_updateLayout(i)
        Loop, % Config_viewCount
          Bar_updateView(i, A_Index)
      }
    }
  }
}

Manager_override(rule = "") {
  Local aWndId, aWndMinMax
  
  WinGet, aWndId, ID, A
  If (rule = "") {
    rule := Manager_getWindowRule(aWndId)
    InputBox, rule, bug.n: Override, % "Which rule should be applied?`n`n<is managed>;<m>;<tags>;<is floating>;<is decorated>;<hide title>;<action>",, 483, 152,,,,, % rule
    If Not (ErrorLevel = 0)
      Return
  }
  Manager_manage(Manager_aMonitor, Monitor_#%Manager_aMonitor%_aView_#1, aWndId, rule)
  View_arrange(Manager_aMonitor, Monitor_#%Manager_aMonitor%_aView_#1)
  Bar_updateView(Manager_aMonitor, Monitor_#%Manager_aMonitor%_aView_#1)
}

Manager_registerShellHook() {
  Global Config_monitorDisplayChangeMessages
  
  WM_DISPLAYCHANGE := 126   ;; This message is sent when the display resolution has changed.
  Gui, +LastFound
  hWnd := WinExist()
  WinGetClass, wndClass, ahk_id %hWnd%
  WinGetTitle, wndTitle, ahk_id %hWnd%
  DllCall("RegisterShellHookWindow", "UInt", hWnd)    ;; Minimum operating systems: Windows 2000 (http://msdn.microsoft.com/en-us/library/ms644989(VS.85).aspx)
  msgNum := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
  OnMessage(msgNum, "Manager_onShellMessage")
  If !(Config_monitorDisplayChangeMessages = "off" || Config_monitorDisplayChangeMessages = 0)
    OnMessage(WM_DISPLAYCHANGE, "Manager_onDisplayChange")
}
;; SKAN: How to Hook on to Shell to receive its messages? (http://www.autohotkey.com/forum/viewtopic.php?p=123323#123323)

Manager_resetMonitorConfiguration() {
  Local GuiN, hWnd, i, j, m, mPrimary, wndClass, wndIds, wndTitle

  m := Manager_monitorCount
  SysGet, Manager_monitorCount, MonitorCount
  If (Manager_monitorCount < m) {
    ;; A monitor has been disconnected. Which one?
    i := Monitor_find(-1, m)
    If (i > 0) {
      SysGet, mPrimary, MonitorPrimary
      GuiN := (m - 1) + 1
      Gui, %GuiN%: Destroy
      Loop, % Config_viewCount {
        If View_#%i%_#%A_Index%_wndIds {
          View_#%mPrimary%_#%A_Index%_wndIds .= View_#%i%_#%A_Index%_wndIds
          StringTrimRight, wndIds, View_#%i%_#%A_Index%_wndIds, 1
          Loop, PARSE, wndIds, `;
          {
            Window_#%A_LoopField%_monitor := mPrimary
          }
          If (Manager_aMonitor = i)
            Manager_aMonitor := mPrimary
        }
      }
      Loop, % m - i {
        j := i + A_Index
        Monitor_moveToIndex(j, j - 1)
        Monitor_getWorkArea(j - 1)
        Bar_init(j - 1)
      }
    }
  } Else If (Manager_monitorCount > m) {
    ;; A monitor has been connected. Where has it been put?
    i := Monitor_find(+1, Manager_monitorCount)
    If (i > 0) {
      Loop, % Manager_monitorCount - i {
        j := Manager_monitorCount - A_Index
        Monitor_moveToIndex(j, j + 1)
        Monitor_getWorkArea(j + 1)
        Bar_init(j + 1)
      }
      Monitor_init(i, True)
    }
  } Else {
    ;; Has the resolution of a monitor been changed?
    mmngr2 := New MonitorManager()
    Loop, % Manager_monitorCount {
      Monitor_getWorkArea(A_Index)
      Bar_init(A_Index)
    }
  }
  Manager_saveState()
  Loop, % Manager_monitorCount {
    View_arrange(A_Index, Monitor_#%A_Index%_aView_#1)
    Bar_updateView(A_Index, Monitor_#%A_Index%_aView_#1)
  }
  Manager__restoreWindowState(Main.sessionWindowsFile)

  Gui, +LastFound
  hWnd := WinExist()
  WinGetClass, wndClass, ahk_id %hWnd%
  WinGetTitle, wndTitle, ahk_id %hWnd%
  DllCall("RegisterShellHookWindow", "UInt", hWnd)    ;; Minimum operating systems: Windows 2000 (http://msdn.microsoft.com/en-us/library/ms644989(VS.85).aspx)
}

;; Restore previously saved window state.
;; If the state is completely different, this function won't do much. However, if restoring from a crash
;; or simply restarting bug.n, it should completely recover the window state.
Manager__restoreWindowState(filename) {
  Local vidx, widx, i, j, m, v, candidate_set, detectHidden, view_set, excluded_view_set, view_m0, view_v0, view_list0, wnds0, items0, wndPName, view_var, isManaged, isFloating, isDecorated, hideTitle

  If Not FileExist(filename)
    Return

  widx := 1
  vidx := 1

  view_set := ""
  excluded_view_set := ""

  ;; Read all interesting things from the file.
  Loop, READ, %filename%
  {
    If (SubStr(A_LoopReadLine, 1, 5) = "View_") {
      i := InStr(A_LoopReadLine, "#")
      j := InStr(A_LoopReadLine, "_", false, i)
      m := SubStr(A_LoopReadLine, i + 1, j - i - 1)
      i := InStr(A_LoopReadLine, "#", false, j)
      j := InStr(A_LoopReadLine, "_", false, i)
      v := SubStr(A_LoopReadLine, i + 1, j - i - 1)

      i := InStr(A_LoopReadLine, "=", j + 1)


      If (m <= Manager_monitorCount) And ( v <= Config_viewCount ) {
        view_list%vidx% := SubStr(A_LoopReadLine, i + 1)
        view_m%vidx% := m
        view_v%vidx% := v
        view_set := view_set . view_list%vidx%
        vidx := vidx + 1
      } Else {
        excluded_view_set := excluded_view_set . view_list%vidx%
      }
    } Else If (SubStr(A_LoopReadLine, 1, 7) = "Window ") {
      wnds%widx% := SubStr(A_LoopReadLine, 8)
      widx := widx + 1
    }
  }

  candidate_set := ""

  ; Scan through all defined windows. Create a candidate set of windows based on whether the properties of existing windows match.
  Loop, % (widx - 1) {
    StringSplit, items, wnds%A_Index%, `;
    If (items0 < 9) {
      Continue
    }

    i := 1
    i := items%i%
    j := 2

    detectHidden := A_DetectHiddenWindows
    DetectHiddenWindows, On
    WinGet, wndPName, ProcessName, ahk_id %i%
    DetectHiddenWindows, %detectHidden%
    If Not ( items%j% = wndPName ) {
      Continue
    }

    j := 8
    isManaged := items%j%

    ; If Managed
    If ( items%j% ) {
      If ( InStr(view_set, i) = 0) {
        Continue
      }
    }

    ; Set up the window.

    j := 3
    m := items%j%
    j := 4
    v := items%j%
    j := 5
    isFloating := items%j%
    j := 6
    isDecorated := items%j%
    j := 7
    hideTitle := items%j%

    Manager__setWinProperties(i, isManaged, m, v, isDecorated, isFloating, hideTitle )
    ;Window_hide(i)

    candidate_set := candidate_set . i . ";"
  }

  ; Set up all views. Must filter the window list by those from the candidate set.
  Loop, % (vidx - 1) {
    StringSplit, items, view_list%A_Index%, `;
    view_set := ""
    Loop, % (items0 - 1) {
      If ( InStr(candidate_set, items%A_Index% ) > 0 )
        view_set := view_set . items%A_Index% . ";"
    }
    view_var := "View_#" . view_m%A_Index% . "_#" . view_v%A_Index% . "_wndIds"
    %view_var% := view_set
  }
}

Manager_saveState() {
  Critical
  Global Config_viewCount, Main, Manager_layoutDirty, Manager_monitorCount, Manager_windowsDirty

  ;; @TODO: Check for changes to the layout.
  ;If Manager_layoutDirty {
    Config_saveSession(Main.configFile, Main.sessionLayoutsFile)
    Manager_layoutDirty := 0
  ;}

  ;; @TODO: Check for changes to windows.
  ;If Manager_windowsDirty {
    Manager_saveWindowState(Main.sessionWindowsFile, Manager_monitorCount, Config_viewCount)
    Manager_windowsDirty := 0
  ;}
}

Manager_saveWindowState(filename, nm, nv) {
  Local allWndId0, allWndIds, detectHidden, wndPName, title, text, monitor, wndId, view, isManaged, isTitleHidden

  text := "; bug.n - tiling window management`n; @version " VERSION "`n`n"

  tmpfname := filename . ".tmp"
  FileDelete, %tmpfname%

  ; Dump window ID and process name. If these two don't match an existing process, we won't try
  ;   to recover that window.
  StringTrimRight, allWndIds, Manager_allWndIds, 1
  StringSplit, allWndId, allWndIds, `;
  detectHidden := A_DetectHiddenWindows
  DetectHiddenWindows, On
  Loop, % allWndId0 {
    wndId := allWndId%A_Index%
    WinGet, wndPName, ProcessName, ahk_id %wndId%
    ; Include title for informative reasons.
    WinGetTitle, title, ahk_id %wndId%

    ; wndId;processName;Tags;Floating;Decorated;HideTitle;Managed;Title

    isManaged := InStr(Manager_managedWndIds, wndId . ";")
    isTitleHidden := InStr(Bar_hideTitleWndIds, wndId . ";")

    text .= "Window " . wndId . ";" . wndPName . ";"
    If isManaged
      text .= Window_#%wndId%_monitor . ";" . Window_#%wndId%_tags . ";" . Window_#%wndId%_isFloating . ";" . Window_#%wndId%_isDecorated . ";"
    Else
      text .= ";;;;"
    text .= isTitleHidden . ";" . isManaged . ";" . title . "`n"
  }
  DetectHiddenWindows, %detectHidden%

  text .= "`n"

  ;; Dump window arrangements on every view. If some views or monitors have disappeared, leave their
  ;;   corresponding windows alone.

  Loop, % nm {
    monitor := A_Index
    Loop, % nv {
      view := A_Index
      ;; Dump all view window lists
      text .= "View_#" . monitor . "_#" . view . "_wndIds=" . View_#%monitor%_#%view%_wndIds . "`n"
    }
  }

  FileAppend, %text%, %tmpfname%
  If ErrorLevel {
    If FileExist(tmpfname)
      FileDelete, %tmpfname%
  } Else
    FileMove, %tmpfname%, %filename%, 1
}

Manager_setCursor(wndId) {
  Local wndHeight, wndWidth, wndX, wndY

  If Config_mouseFollowsFocus {
    If wndId {
      WinGetPos, wndX, wndY, wndWidth, wndHeight, ahk_id %wndId%
      DllCall("SetCursorPos", "Int", Round(wndX + wndWidth / 2), "Int", Round(wndY + wndHeight / 2))
    } Else
      DllCall("SetCursorPos", "Int", Round(Monitor_#%Manager_aMonitor%_x + Monitor_#%Manager_aMonitor%_width / 2), "Int", Round(Monitor_#%Manager_aMonitor%_y + Monitor_#%Manager_aMonitor%_height / 2))
  }
}

Manager_setViewMonitor(i, d = 0) {
  Local aView, aWndId, v, wndIds

  aView := Monitor_#%Manager_aMonitor%_aView_#1
  If (Manager_monitorCount > 1) And View_#%Manager_aMonitor%_#%aView%_wndIds {
    If (i = 0)
      i := Manager_aMonitor
    i := Manager_loop(i, d, 1, Manager_monitorCount)
    v := Monitor_#%i%_aView_#1
    View_#%i%_#%v%_wndIds := View_#%Manager_aMonitor%_#%aView%_wndIds View_#%i%_#%v%_wndIds

    StringTrimRight, wndIds, View_#%Manager_aMonitor%_#%aView%_wndIds, 1
    Loop, PARSE, wndIds, `;
    {
      Loop, % Config_viewCount {
        StringReplace, View_#%Manager_aMonitor%_#%A_Index%_wndIds, View_#%Manager_aMonitor%_#%A_Index%_wndIds, %A_LoopField%`;,
        StringReplace, View_#%Manager_aMonitor%_#%A_Index%_aWndIds, View_#%Manager_aMonitor%_#%A_Index%_aWndIds, %A_LoopField%`;,
      }
      Window_#%A_LoopField%_monitor := i
      Window_#%A_LoopField%_tags := 1 << v - 1
    }
    View_arrange(Manager_aMonitor, aView)
    Loop, % Config_viewCount {
      Bar_updateView(Manager_aMonitor, A_Index)
    }

    ;; Manually set the active monitor.
    Manager_aMonitor := i
    View_arrange(i, v)
    WinGet, aWndId, ID, A
    Manager_winActivate(aWndId)
    Bar_updateView(i, v)
  }
}

Manager_setWindowMonitor(i, d = 0) {
  Local aWndId, v

  WinGet, aWndId, ID, A
  If (Manager_monitorCount > 1 And InStr(Manager_managedWndIds, aWndId ";")) {
    Loop, % Config_viewCount {
      StringReplace, View_#%Manager_aMonitor%_#%A_Index%_wndIds, View_#%Manager_aMonitor%_#%A_Index%_wndIds, %aWndId%`;,
      StringReplace, View_#%Manager_aMonitor%_#%A_Index%_aWndIds, View_#%Manager_aMonitor%_#%A_Index%_aWndIds, %aWndId%`;, All
      Bar_updateView(Manager_aMonitor, A_Index)
    }
    View_arrange(Manager_aMonitor, Monitor_#%Manager_aMonitor%_aView_#1)

    ;; Manually set the active monitor.
    If (i = 0)
      i := Manager_aMonitor
    Manager_aMonitor := Manager_loop(i, d, 1, Manager_monitorCount)
    Window_#%aWndId%_monitor := Manager_aMonitor
    v := Monitor_#%Manager_aMonitor%_aView_#1
    Window_#%aWndId%_tags := 1 << v - 1
    View_#%Manager_aMonitor%_#%v%_wndIds := aWndId ";" View_#%Manager_aMonitor%_#%v%_wndIds
    View_setActiveWindow(Manager_aMonitor, v, aWndId)
    View_arrange(Manager_aMonitor, v)
    Manager_winActivate(aWndId)
    Bar_updateView(Manager_aMonitor, v)
  }
}

Manager_sizeWindow() {
  Local aWndId, SC_SIZE, WM_SYSCOMMAND

  WinGet, aWndId, ID, A
  If InStr(Manager_managedWndIds, aWndId . ";") And Not Window_#%aWndId%_isFloating
    View_toggleFloatingWindow(aWndId)
  Window_set(aWndId, "Top", "")

  WM_SYSCOMMAND = 0x112
  SC_SIZE       = 0xF000
  SendMessage, WM_SYSCOMMAND, SC_SIZE, , , ahk_id %aWndId%
}

;; No windows are known to the system yet.
;; Try to do something smart with the initial layout.
Manager_initial_sync(doRestore) {
  Local wndId, wndId0, wnd, wndX, wndY, wndW, wndH, x, y, m, len

  ;; Initialize lists
  ;; Note that these variables make this function non-reentrant.
  Loop, % Manager_monitorCount
    Manager_initial_sync_m#%A_Index%_wndList := ""

  ;; Use saved window placement settings to first determine
  ;;   which monitor/view a window should be attached to.
  If doRestore
    Manager__restoreWindowState(Main.sessionWindowsFile)

  ;; Check all remaining visible windows against the known windows
  WinGet, wndId, List, , ,
  Loop, % wndId {
    ;; Based on some analysis here, determine which monitors and layouts would best
    ;; serve existing windows. Do not override configuration settings.

    ;; Which monitor is it on?
    wnd := wndId%A_Index%
    WinGetPos, wndX, wndY, wndW, wndH, ahk_id %wnd%

    x := wndX + wndW/2
    y := wndY + wndH/2

    m := Monitor_get(x, y)
    If m > 0
      Manager_initial_sync_m#%m%_wndList .= wndId%A_Index% ";"

  }

  Loop, % Manager_monitorCount {
    m := A_Index
    StringTrimRight, wndIds, Manager_initial_sync_m#%m%_wndList, 1
    StringSplit, wndId, wndIds, `;
    Loop, % wndId0
      Manager_manage(m, 1, wndId%A_Index%)
  }
}

;; @todo: This constantly tries to re-add windows that are never going to be manageable.
;;   Manager_manage should probably ignore all windows that are already in Manager_allWndIds.
;;   The problem was, that i. a. claws-mail triggers Manager_sync, but the application window
;;   would not be ready for being managed, i. e. class and title were not available. Therefore more
;;   attempts were needed.
;;   Perhaps this method can be refined by not adding any window to Manager_allWndIds, but only
;;   those, which have at least a title or class.
Manager_sync(ByRef wndIds = "")
{
  Local a, flag, shownWndIds, v, visibleWndIds, wndId
  a := 0

  shownWndIds := ""
  Loop, % Manager_monitorCount
  {
    v := Monitor_#%A_Index%_aView_#1
    shownWndIds .= View_#%A_Index%_#%v%_wndIds
  }
  ;; Check all visible windows against the known windows
  visibleWndIds := ""
  WinGet, wndId, List, , ,
  Loop, % wndId
  {
    If Not InStr(shownWndIds, wndId%A_Index% ";")
    {
      If Not InStr(Manager_managedWndIds, wndId%A_Index% ";")
      {
        flag := Manager_manage(Manager_aMonitor, Monitor_#%Manager_aMonitor%_aView_#1, wndId%A_Index%)
        If flag
          a := 1
      }
      Else If Not Window_isHung(wndId%A_Index%)
      {
        ;; This is a window that is already managed but was brought into focus by something.
        ;; Maybe it would be useful to do something with it.
        wndIds .= wndId%A_Index% ";"
      }
    }
    visibleWndIds := visibleWndIds wndId%A_Index% ";"
  }

  ;; @todo-future: Find out why this unmanage code exists and if it's still needed.
  ;; check, if a window, that is known to be visible, is actually not visible
  StringTrimRight, shownWndIds, shownWndIds, 1
  Loop, PARSE, shownWndIds, `;
  {
    If Not InStr(visibleWndIds, A_LoopField)
    {
      flag := Manager_unmanage(A_LoopField)
      If (flag And a = 0)
        a := -1
    }
  }

  Return, a
}

Manager_unmanage(wndId) {
  Local a, aView

  aView := Monitor_#%Manager_aMonitor%_aView_#1

  a := Window_#%wndId%_tags & 1 << aView - 1
  Loop, % Config_viewCount {
    If (Window_#%wndId%_tags & 1 << A_Index - 1) {
      StringReplace, View_#%Manager_aMonitor%_#%A_Index%_wndIds, View_#%Manager_aMonitor%_#%A_Index%_wndIds, % wndId ";",, All
      StringReplace, View_#%Manager_aMonitor%_#%A_Index%_aWndIds, View_#%Manager_aMonitor%_#%A_Index%_aWndIds, % wndId ";",, All
      Bar_updateView(Manager_aMonitor, A_Index)
    }
  }
  Window_#%wndId%_monitor     :=
  Window_#%wndId%_tags        :=
  Window_#%wndId%_isDecorated :=
  Window_#%wndId%_isFloating  :=
  Window_#%wndId%_area        :=
  StringReplace, Bar_hideTitleWndIds, Bar_hideTitleWndIds, %wndId%`;,
  StringReplace, Manager_allWndIds, Manager_allWndIds, %wndId%`;,
  StringReplace, Manager_managedWndIds, Manager_managedWndIds, %wndId%`;, , All

  Return, a
}

Manager_winActivate(wndId) {
  Global Manager_aMonitor
  
  Manager_setCursor(wndId)
  If Not wndId {
    wndId := WinExist("bug.n_BAR_" . Manager_aMonitor)
  }

  If Window_activate(wndId)
    Return, 1
  Else {
    Return 0
  }
}

Manager_windowNotMaximized(width, height) {
  Global
  Return, (width < 0.99 * Monitor_#%Manager_aMonitor%_width Or height < 0.99 * Monitor_#%Manager_aMonitor%_height)
}

Manager_activateViewByMouse(d) {
	Local mousePositionX, mousePositionY, window, windowTitle
	MouseGetPos, mousePositionX, mousePositionY, window
	WinGetTitle windowTitle, ahk_id %Window%
	if( InStr(windowTitle, "bug.n_BAR_") = 1 ) {
		Monitor_activateView(0, d)
	}
}

/*
:title:     bug.n/monitormanager
:copyright: (c) 2019 by joten <https://github.com/joten>
:license:   GNU General Public License version 3

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.
*/

class MonitorManager {
  __New() {
    ;; enum _PROCESS_DPI_AWARENESS
    PROCESS_DPI_UNAWARE := 0
    PROCESS_SYSTEM_DPI_AWARE := 1
    PROCESS_PER_MONITOR_DPI_AWARE := 2
    ; DllCall("SHcore\SetProcessDpiAwareness", "UInt", PROCESS_PER_MONITOR_DPI_AWARE)
    ;; InnI: Get per-monitor DPI scaling factor (https://www.autoitscript.com/forum/topic/189341-get-per-monitor-dpi-scaling-factor/?tab=comments#comment-1359832)
    DPI_AWARENESS_CONTEXT_UNAWARE := -1
    DPI_AWARENESS_CONTEXT_SYSTEM_AWARE := -2
    DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE := -3
    DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 := -4
    DllCall("User32\SetProcessDpiAwarenessContext", "UInt" , DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)
    ;; pneumatic: -DPIScale not working properly (https://www.autohotkey.com/boards/viewtopic.php?p=241869&sid=abb2db983d2b3966bc040c3614c0971e#p241869)
    
    ptr := A_PtrSize ? "Ptr" : "UInt"
    this.monitors := []
    DllCall("EnumDisplayMonitors", ptr, 0, ptr, 0, ptr, RegisterCallback("MonitorEnumProc", "", 4, &this), "UInt", 0)
    ;; Solar: SysGet incorrectly identifies monitors (https://autohotkey.com/board/topic/66536-sysget-incorrectly-identifies-monitors/)
  }
}

MonitorEnumProc(hMonitor, hdcMonitor, lprcMonitor, dwData) {
  l := NumGet(lprcMonitor + 0,  0, "UInt")
  t := NumGet(lprcMonitor + 0,  4, "UInt")
  r := NumGet(lprcMonitor + 0,  8, "UInt")
  b := NumGet(lprcMonitor + 0, 12, "UInt")
  
  this := Object(A_EventInfo)
  ;; Helgef: Allow RegisterCallback with BoundFunc objects (https://www.autohotkey.com/boards/viewtopic.php?p=235243#p235243)
  this.monitors.push(New Monitor(hMonitor, l, t, r, b))
  
	Return, 1
}

class Monitor {
  __New(handle, left, top, right, bottom) {
    this.handle := handle
    this.left   := left
    this.top    := top
    this.right  := right
    this.bottom := bottom
    
    this.x      := left
    this.y      := top
    this.width  := right - left
    this.height := bottom - top
    
    dpi := this.getDpiForMonitor()
    this.dpiX := dpi.x
    this.dpiY := dpi.y
    this.scaleX := this.dpiX / 96
    this.scaleY := this.dpiY / 96
  }
  
  getDpiForMonitor() {
    ;; enum _MONITOR_DPI_TYPE
    MDT_EFFECTIVE_DPI := 0
    MDT_ANGULAR_DPI := 1
    MDT_RAW_DPI := 2
    MDT_DEFAULT := MDT_EFFECTIVE_DPI
    ptr := A_PtrSize ? "Ptr" : "UInt"
    dpiX := dpiY := 0
    DllCall("SHcore\GetDpiForMonitor", ptr, this.handle, "Int", MDT_DEFAULT, "UInt*", dpiX, "UInt*", dpiY)
    
    Return, {x: dpiX, y: dpiY}
  }
  ;; InnI: Get per-monitor DPI scaling factor (https://www.autoitscript.com/forum/topic/189341-get-per-monitor-dpi-scaling-factor/?tab=comments#comment-1359832)
}
