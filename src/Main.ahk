/*
:title:     bug.n - tiling window management
:copyright: (c) 2022 joten <https://github.com/joten>
                2010 - 2021 https://github.com/fuhsjr00/bug.n/graphs/contributors
:license:  GNU General Public License version 3 (http://www.gnu.org/licenses/gpl-3.0.txt)

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/

NAME := "bug.n"
VERSION := "redux v0.0.1-alpha.1"

;; script settings
#NoEnv                        ;; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn                       ;; Enable warnings to assist with detecting common errors.
SendMode Input                ;; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%   ;; Ensures a consistent starting directory.
#Persistent                   ;;
#SingleInstance Force
#WinActivateForce
DetectHiddenText, Off         ;;
DetectHiddenWindows, Off      ;;
OnExit("Main_cleanup")
SetBatchLines,    -1
SetControlDelay,   0          ;;
SetMouseDelay,     0          ;;
SetTitleMatchMode, 3          ;; `TitleMatchMode` may be set to `RegEx` to enable a wider search, but should be reset afterwards.
SetWinDelay,      10          ;; `WinDelay` may be set to a different value e.g. 10, if necessary to prevent timing issues, but should be reset to 0 afterwards.

;; pseudo main function
  Main := {appDir: "", configFile: "", loggingFile: "", layoutsFile: "", windowsFile: ""}
  Main_setup()
  Config_init()

  Menu, Tray, Tip, % NAME . " " . VERSION
  If (A_IsCompiled) {
    Menu, Tray, Icon, % A_ScriptFullPath, -159
  }
  ;; Allow overwriting the icon, if using the executable.
  If (FileExist(A_ScriptDir . "\logo.ico")) {
    Menu, Tray, Icon, % A_ScriptDir . "\logo.ico"
  }

  Manager_init()
  Logging_write(NAME . " started.", "Main")
Return
;; end of the auto-execute section

;; function, label & object definitions
Main_cleanup() {
  Global Config_autoSaveSession

  If (Config_autoSaveSession != "off") {
    Manager_saveState()
  }
  Manager_cleanup()
}

Main_evalCommand(cmd) {
  If (cmd == "Reload") {
    Reload
  } Else If (cmd == "ExitApp") {
    ExitApp
  } Else {
    i := InStr(cmd, "(")
    j := InStr(cmd, ")", False, i)
    If (i && j) {
      funcName := SubStr(cmd, 1, i - 1)
      funcArgs := SubStr(cmd, i + 1, j - (i + 1))
      funcArgs := StrSplit(funcArgs, ",", A_Space)
      If (funcArgs.Length() == 0) {
        %funcName%()
      } Else If (funcArgs.Length() == 1) {
        %funcName%(funcArgs[1])
      } Else If (funcArgs.Length() == 2) {
        %funcName%(funcArgs[1], funcArgs[2])
      } Else If (funcArgs.Length() == 3) {
        %funcName%(funcArgs[1], funcArgs[2], funcArgs[3])
      } Else If (funcArgs.Length() == 4) {
        %funcName%(funcArgs[1], funcArgs[2], funcArgs[3], funcArgs[4])
      }
    }
  }
}

Main_makeDir(dirName) {
  attrib := FileExist(dirName)
  If (attrib == "") {
    FileCreateDir, %dirName%
    If (ErrorLevel) {
      MsgBox, % "Error (" . ErrorLevel . ") creating '" . dirName . "'. Aborting."
      ExitApp
    }
  } Else {
    If (!InStr(attrib, "D")) {
      MsgBox, % "File path '" . dirName . "' already exists and is not a directory. Aborting."
      ExitApp
    }
  }
}

Main_setup() {
  Global Logging, Main

  If (A_Args.Length() == 1) {
    Main.appDir := A_Args[1]
  } Else {
    EnvGet, appDataDir, APPDATA
    Main.appDir := appDataDir . "\bug.n"
  }
  Main_makeDir(Main.appDir)

  Main.sessionLayoutsFile := Main.appDir . "\_layouts.ini"
  Main.sessionWindowsFile := Main.appDir . "\_windows.ini"
  Main.configFile := Main.appDir . "\config.ini"

  Logging__init(filename := Main.appDir . "\_logging.md")
  Logging_writeCacheToFile(overwrite := True)
  SetTimer, Logging_writeCacheToFile, % Logging.interval
}

#Include, %A_ScriptDir%\Bar.ahk
#Include, %A_ScriptDir%\Config.ahk
#Include, %A_ScriptDir%\logging.ahk
#Include, %A_ScriptDir%\Manager.ahk
#Include, %A_ScriptDir%\Monitor.ahk
#Include, %A_ScriptDir%\Tiler.ahk
#Include, %A_ScriptDir%\View.ahk
#Include, %A_ScriptDir%\Window.ahk
