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

NAME  := "bug.n"
VERSION := "9.1.0"

;; Script settings
OnExit, Main_cleanup
SetBatchLines, -1
SetTitleMatchMode, 3
SetTitleMatchMode, fast
SetWinDelay, 10
#NoEnv
#SingleInstance force
;#Warn                         ; Enable warnings to assist with detecting common errors.
#WinActivateForce

;; Pseudo main function
  Main_appDir := ""
  If 0 = 1
    Main_appDir = %1%

  Main_setup()

 Config_filePath := Main_appDir "\Config.ini"
  Config_init()

  Menu, Tray, Tip, %NAME% %VERSION%
  If A_IsCompiled
    Menu, Tray, Icon, %A_ScriptFullPath%, -159
  If FileExist(A_ScriptDir . "\logo.ico")
    Menu, Tray, Icon, % A_ScriptDir . "\logo.ico"

  Manager_init()
Return          ;; end of the auto-execute section

;; Function & label definitions
Main_cleanup:
  ;; Config_autoSaveSession as False is deprecated.
  If Not (Config_autoSaveSession = "off") And Not (Config_autoSaveSession = "False")
    Manager_saveState()
  Manager_cleanup()
ExitApp

Main_evalCommand(command)
{
  type := SubStr(command, 1, 5)
  If (command = "Reload")
    Reload
  Else If (command = "ExitApp")
    ExitApp
  Else
  {
    i := InStr(command, "(")
    j := InStr(command, ")", False, i)
    If i And j
    {
      functionName := SubStr(command, 1, i - 1)
      functionArguments := SubStr(command, i + 1, j - (i + 1))
      StringReplace, functionArguments, functionArguments, %A_SPACE%, , All
      StringSplit, functionArgument, functionArguments, `,
      If (functionArgument0 = 0)
        %functionName%()
      Else If (functionArgument0 = 1)
        %functionName%(functionArguments)
      Else If (functionArgument0 = 2)
        %functionName%(functionArgument1, functionArgument2)
      Else If (functionArgument0 = 3)
        %functionName%(functionArgument1, functionArgument2, functionArgument3)
      Else If (functionArgument0 = 4)
        %functionName%(functionArgument1, functionArgument2, functionArgument3, functionArgument4)
    }
  }
}

;; Create bug.n-specific directories.
Main_makeDir(dirName) {
  IfNotExist, %dirName%
  {
    FileCreateDir, %dirName%
    If ErrorLevel
    {
      MsgBox, Error (%ErrorLevel%) when creating '%dirName%'. Aborting.
      ExitApp
    }
  }
  Else
  {
    FileGetAttrib, attrib, %dirName%
    IfNotInString, attrib, D
    {
      MsgBox, The file path '%dirName%' already exists and is not a directory. Aborting.
      ExitApp
    }
  }
}

Main_setup() {
  Local winAppDir

  Main_docDir := A_ScriptDir
  If (SubStr(A_ScriptDir, -3) = "\src")
    Main_docDir .= "\.."
  Main_docDir .= "\doc"

  Main_logFile := ""
  Main_dataDir := ""
  Main_autoLayout := ""
  Main_autoWindowState := ""

  EnvGet, winAppDir, APPDATA

  If (Main_appDir = "")
    Main_appDir := winAppDir . "\bug.n"
  Main_logFile := Main_appDir . "\log.txt"
  Main_dataDir := Main_appDir . "\data"
  Main_autoLayout := Main_dataDir . "\_Layout.ini"
  Main_autoWindowState := Main_dataDir . "\_WindowState.ini"

  Main_makeDir(Main_appDir)
  Main_makeDir(Main_dataDir)
}

#Include Bar.ahk
#Include Config.ahk
#Include Manager.ahk
#Include Monitor.ahk
#Include Tiler.ahk
#Include View.ahk
#Include Window.ahk
