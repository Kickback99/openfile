; main.ahk - 使用不同变量名
#SingleInstance Force
#Requires AutoHotkey v2.0

#Include ConfigManager.ahk
#Include GuiManager.ahk

; 使用不同的变量名避免冲突
myConfigMgr := ConfigManager()
myGuiMgr := GuiManager(myConfigMgr)

!2:: {
    myGuiMgr.ShowSoftwareList()
}

^!q::ExitApp
^!r::Reload