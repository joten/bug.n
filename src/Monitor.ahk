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
  Monitor_#%m%_taskBarId    := ""
  Loop, % Config_viewCount {
    View_init(m, A_Index)
  }
  If doRestore {
    Config_restoreLayout(Main.sessionLayoutsFile, m)
  } Else {
    Config_restoreLayout(Main.configFile, m)
  }
  Monitor_getWorkArea(m)
  Bar_init(m)
}

Monitor_get(x, y) {
  Local m

  m := 0
  Loop, % Manager_monitorCount {
    ;; Check if the window is on this monitor.
    If (x >= Monitor_#%A_Index%_x && x <= Monitor_#%A_Index%_x+Monitor_#%A_Index%_width && y >= Monitor_#%A_Index%_y && y <= Monitor_#%A_Index%_y+Monitor_#%A_Index%_height) {
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

  SysGet, monitor, Monitor, %m%
  wndClasses := "Shell_TrayWnd;Shell_SecondaryTrayWnd"
  Loop, PARSE, wndClasses, `;
  {
    WinGet, wndId, List, % "ahk_class " A_LoopField
    Loop, % wndId {
      wnd := wndId%A_Index%
      WinGetPos, wndX, wndY, wndWidth, wndHeight, ahk_id %wnd%
      x := wndX + wndWidth / 2
      y := wndY + wndHeight / 2
      If (x >= monitorLeft && x <= monitorRight && y >= monitorTop && y <= monitorBottom) {
        Monitor_#%m%_taskBarId := wnd
      }
    }
  }
  SysGet, monitor, MonitorWorkArea, %m%
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
}

Monitor_toggleBar() {
  Global

  Monitor_#%Manager_aMonitor%_showBar := Not Monitor_#%Manager_aMonitor%_showBar
  Bar_toggleVisibility(Manager_aMonitor)
  Manager_winActivate(Bar_aWndId)
}

Monitor__init(filename := "") {
  Global Monitor

  Monitor := {cache: []
            , filename: filename
            , indices: {}
            , primary: 0}

  ;; Set DPI awareness.
  DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 := -4
  PROCESS_PER_MONITOR_DPI_AWARE := 2
  result := DllCall("User32\SetThreadDpiAwarenessContext", "UInt" , DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)
  ;result := DllCall("Shcore.dll", "long", "SetProcessDpiAwareness", "int", PROCESS_PER_MONITOR_DPI_AWARE)
  ;; result := DllCall("SHcore\SetProcessDpiAwareness", "int", PROCESS_PER_MONITOR_DPI_AWARE)   ;; -> E_ACCESSDENIED
  ;; pneumatic: -DPIScale not working properly (https://www.autohotkey.com/boards/viewtopic.php?p=241869&sid=abb2db983d2b3966bc040c3614c0971e#p241869)
  ;; InnI: Get per-monitor DPI scaling factor (https://www.autoitscript.com/forum/topic/189341-get-per-monitor-dpi-scaling-factor/?tab=comments#comment-1359832)
  ;; Evaluating `DllCall("SHcore\SetProcessDpiAwareness", "UInt", const.PROCESS_PER_MONITOR_DPI_AWARE)` resulted in an access violation.
  ;; Setting `DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE` did work without errors, but does it have an effect?
  Logging_debug("Dll _User32\SetThreadDpiAwarenessContext_ called with result ``" . result . "``.", "Monitor__init")
  
  ;; Enumerate and synchronizing display/ AutoHotkey monitors.
  Monitor_enumAutoHotkeyMonitors()
  ptr := A_PtrSize ? "Ptr" : "UInt"
  DllCall("EnumDisplayMonitors", ptr, 0, ptr, 0, ptr, RegisterCallback("Monitor_enumDisplayMonitorsProc", "", 4), "UInt", 0)
  ;; Solar: SysGet incorrectly identifies monitors (https://autohotkey.com/board/topic/66536-sysget-incorrectly-identifies-monitors/)
  
  Logging_info("Monitor" . (Monitor.cache.Length() == 1 ? "" : "s") . " initialized; count: ``" . Monitor.cache.Length() . "``.", "Monitor__init")
}

Monitor_enumAutoHotkeyMonitors() {
  ;; Enumerate the monitors as found by AutoHotkey.
  Global Monitor
  
  SysGet, n, MonitorCount
  Logging_debug(n . " monitor" . (n == 1 ? "" : "s") . " found by _AutoHotkey_.", "Monitor_enumAutoHotkeyMonitors")
  Loop, % n {
    SysGet, name, MonitorName, % A_Index
    SysGet, rect, Monitor, % A_Index
    
    key := rectLeft . "-" . rectTop . "-" . rectRight . "-" . rectBottom
    Monitor.indices[key] := A_Index
    Monitor.cache[A_Index] := Monitor_getObject(A_Index, rectLeft, rectTop, rectRight, rectBottom)

    ;; Supplementing information.
    Monitor.cache[A_Index].aIndex := A_Index
    Monitor.cache[A_Index].name   := name
    SysGet, rect, MonitorWorkArea, % A_Index
    Monitor.cache[A_Index].monitorWorkArea := {x: rectLeft, y: rectTop, w: rectRight - rectLeft, h: rectBottom - rectTop}
  }
  SysGet, i, MonitorPrimary
  Monitor.cache[i].isPrimary := True
  Monitor.primary := i
}

Monitor_enumDisplayMonitorsProc(hMonitor, hdcMonitor, lprcMonitor, dwData) {
  ;; Appending additional monitors not previously found by AutoHotkey,
  ;; synchronizing indices and supplementing information to screen objects.
  Global Monitor

  handle := Format("0x{:x}", Abs(hMonitor))
  rectLeft    := NumGet(lprcMonitor + 0,  0, "UInt")
  rectTop     := NumGet(lprcMonitor + 0,  4, "UInt")
  rectRight   := NumGet(lprcMonitor + 0,  8, "UInt")
  rectBottom  := NumGet(lprcMonitor + 0, 12, "UInt")
  
  ;; Synchronizing indices.
  key := rectLeft . "-" . rectTop . "-" . rectRight . "-" . rectBottom
  If (Monitor.indices.HasKey(key)) {
    i := Monitor.indices[key]
    Logging_debug("Adding handle ``" . handle . "`` and DPI/ scaling information to monitor with key ``" . key . "``.", "Monitor_enumDisplayMonitorsProc")
  } Else {
    ;; Appending additional monitors not previously found.
    Logging_debug("Additional monitor with key ``" . key . "`` found.", "Monitor_enumDisplayMonitorsProc")
    i := Monitor.cache.Length() + 1
    Monitor.indices[key] := i
    Monitor.cache[i] := Monitor_getObject(i, rectLeft, rectTop, rectRight, rectBottom)
  }
  ;; Supplementing information to screen objects.
  Monitor.cache[i].handle := handle
  Monitor_getDpi(i)
  
	Return, 1
}

Monitor_getDpi(i) {
  Global Monitor

  If (Monitor.cache[i].handle != 0) {
    x := y := 0
    ptr := A_PtrSize ? "Ptr" : "UInt"
    MDT_DEFAULT := MDT_EFFECTIVE_DPI := 0
    DllCall("SHcore\GetDpiForMonitor", ptr, Monitor.cache[i].handle, "Int", MDT_DEFAULT, "UInt*", x, "UInt*", y)

    Monitor.cache[i].dpiX := x
    Monitor.cache[i].dpiY := y
    Monitor.cache[i].scaleX := x / 96
    Monitor.cache[i].scaleY := y / 96
  }
}
;; InnI: Get per-monitor DPI scaling factor (https://www.autoitscript.com/forum/topic/189341-get-per-monitor-dpi-scaling-factor/?tab=comments#comment-1359832)

Monitor_getObject(index, rectLeft, rectTop, rectRight, rectBottom) {
  Return, {handle: ""
         , index: index
         , aIndex: 0
         , isPrimary: False
         , key: rectLeft . "-" . rectTop . "-" . rectRight . "-" . rectBottom
         , name: ""
         , trayWnd: ""
         , monitorWorkArea: {}
  
         , x: rectLeft
         , y: rectTop
         , w: rectRight - rectLeft
         , h: rectBottom - rectTop
  
         , dpiX: 0
         , dpiY: 0
         , scaleX: 0
         , scaleY: 0}
}

Monitor_writeCacheToFile(overwrite := False) {
  Global Monitor

  If (Monitor.filename != "") {
    text := "                                                              DPI -      Scale -    Work Area -                  Monitor -`n"
    text .= "idx AHK  Handle              Monitor Key  Primary?  Taskbar   |  X    Y  |  X    Y  |    X      Y  Width Height  |    X      Y  Width Height  Display Name`n"
    text .= "=== ===  ==========  ===================  ========  ========  ==== ====  ==== ====  ====== ====== ====== ======  ====== ====== ====== ======  ============`n"
    For i, item in Monitor.cache {
      ;; index, aIndex, handle, key, isPrimary, trayWnd, dpiX, dpiY, scaleX, scaleY, monitorWorkArea.{x, y, w, h}, x, y, w, h, name
      text .= Format("{:3}",   item.index) . " "
            . Format("{:3}",   item.aIndex) . "  "
            . Format("{:-10}", item.handle) . "  "
            . Format("{:19}",  item.key) . "  "
            . Format("{:-8}",  item.isPrimary ? "Yes" : "No") . "  "
            . Format("{:-8}",  item.trayWnd) . "  "
            . Format("{:4}",   item.dpiX) . " "
            . Format("{:4}",   item.dpiY) . "  "
            . Format("{:-4}",  SubStr(item.scaleX, 1, 4)) . " "
            . Format("{:-4}",  SubStr(item.scaleY, 1, 4)) . "  "
            . Format("{:6}",   item.monitorWorkArea.x) . " "
            . Format("{:6}",   item.monitorWorkArea.y) . " "
            . Format("{:6}",   item.monitorWorkArea.w) . " "
            . Format("{:6}",   item.monitorWorkArea.h) . "  "
            . Format("{:6}",   item.x) . " "
            . Format("{:6}",   item.y) . " "
            . Format("{:6}",   item.w) . " "
            . Format("{:6}",   item.h) . "  "
            . item.name . "`n"
    }
    If (overwrite) {
      FileDelete, % Monitor.filename
    }
    FileAppend, % text, % Monitor.filename
  }
}
