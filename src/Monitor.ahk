/*
:title:     bug.n - tiling window management
:copyright: (c) 2022 joten <https://github.com/joten>
                2010 - 2021 https://github.com/fuhsjr00/bug.n/graphs/contributors
:license:  GNU General Public License version 3 (http://www.gnu.org/licenses/gpl-3.0.txt)

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/

Monitor_init(m, doRestore) {
  Global

  Monitor_#%m%_aView_#1 := 1
  Monitor_#%m%_aView_#2 := 1
  Monitor_#%m%_showBar  := Config_showBar
  Monitor_#%m%_taskBarClass := ""           ;; @TODO Is this needed any longer?
  Monitor_#%m%_taskBarId    := ""
  Monitor_#%m%_taskBarPos   := ""           ;; @TODO Is this needed any longer?
  Loop, % Config_viewCount
    View_init(m, A_Index)
  If doRestore
    Config_restoreLayout(Main.sessionLayoutsFile, m)
  Else
    Config_restoreLayout(Main.configFile, m)
  SysGet, Monitor_#%m%_name, MonitorName, %m%
  Monitor_getWorkArea(m)
  Bar_init(m)
}

Monitor_get(x, y)
{
  Local m

  m := 0
  Loop, % Manager_monitorCount
  {    ;; Check if the window is on this monitor.
    If (x >= Monitor_#%A_Index%_x && x <= Monitor_#%A_Index%_x+Monitor_#%A_Index%_width && y >= Monitor_#%A_Index%_y && y <= Monitor_#%A_Index%_y+Monitor_#%A_Index%_height)
    {
      m := A_Index
      Break
    }
  }

  Return, m
}

Monitor_getWorkArea(m) {
  Local bHeight, bTop, x, y
  Local monitor, monitorBottom, monitorLeft, monitorRight, monitorTop
  Local wndClasses, wndHeight, wndId, wndWidth, wndX, wndY

  ;; @TODO Could we just ask for MonitorWorkArea and remove the code regarding positioning and Monitor_setWorkArea below?
  SysGet, monitor, Monitor, %m%
  
  wndClasses := "Shell_TrayWnd;Shell_SecondaryTrayWnd"
  ;; @TODO What about third and so forth TrayWnd?
  ;; A third TrayWnd would have the window class "Shell_SecondaryTrayWnd".
  Loop, PARSE, wndClasses, `;
  {
    WinGet, wndId, List, % "ahk_class " A_LoopField
    Loop, % wndId {
      wnd := wndId%A_Index%
      WinGetPos, wndX, wndY, wndWidth, wndHeight, ahk_id %wnd%
      x := wndX + wndWidth / 2
      y := wndY + wndHeight / 2
      If (x >= monitorLeft && x <= monitorRight && y >= monitorTop && y <= monitorBottom) {
        Monitor_#%m%_taskBarClass := A_LoopField    ;; @TODO Is taskBarClass needed any longer, with taskBarId set?
        Monitor_#%m%_taskBarId    := wnd
        
        If (wndHeight < wndWidth) {
          ;; Horizontal
          If (wndY <= monitorTop) {
            ;; Top
            wndHeight += wndY - monitorTop
            monitorTop += wndHeight
            Monitor_#%m%_taskBarPos := "top"        ;; @TODO Is taskBarPos needed any longer?
          } Else {
            ;; Bottom
            wndHeight := monitorBottom - wndY
            monitorBottom -= wndHeight
          }
        } Else {
          ;; Vertical
          If (wndX <= monitorLeft) {
            ;; Left
            wndWidth += wndX
            monitorLeft += wndWidth
          } Else {
            ;; Right
            wndWidth := monitorRight - wndX
            monitorRight -= wndWidth
          }
        }
      }
    }
  }
  bHeight := Round(Bar_height / Config_scalingFactor)
  bTop := 0
  If Not Monitor_#%m%_taskBarId {
    bTop := monitorTop
    Monitor_#%m%_showBar := False
  }

  Monitor_#%m%_height := monitorBottom - monitorTop
  Monitor_#%m%_width  := monitorRight - monitorLeft
  Monitor_#%m%_x      := monitorLeft
  Monitor_#%m%_y      := monitorTop
  Monitor_#%m%_barY   := bTop

  Monitor_setWorkArea(monitorLeft, monitorTop, monitorRight, monitorBottom)
}

Monitor_setWorkArea(left, top, right, bottom) {
   VarSetCapacity(area, 16)
   NumPut(left,   area,  0)
   NumPut(top,    area,  4)
   NumPut(right,  area,  8)
   NumPut(bottom, area, 12)
   DllCall("SystemParametersInfo", UInt, 0x2F, UInt, 0, UInt, &area, UInt, 0)   ; 0x2F = SPI_SETWORKAREA
}
;; flashkid: Send SetWorkArea to second Monitor (http://www.autohotkey.com/board/topic/42564-send-setworkarea-to-second-monitor/)

Monitor_toggleBar()
{
  Global

  Monitor_#%Manager_aMonitor%_showBar := Not Monitor_#%Manager_aMonitor%_showBar
  Bar_toggleVisibility(Manager_aMonitor)
  Monitor_getWorkArea(Manager_aMonitor)
  View_arrange(Manager_aMonitor, Monitor_#%Manager_aMonitor%_aView_#1)
  Manager_winActivate(Bar_aWndId)
}
