#Requires AutoHotkey v2.0
#SingleInstance Force
#Include src\ConfigManager.ahk
#Include src\GuiManager.ahk
#Include "src\common\SettingsManager.ahk"

; 显示管理器函数
ShowManager(configType) {

   ; 检查是否已有同名的且是gui类型的窗口
    windowTitle := configType . "-manager"
    hwnd := WinExist(windowTitle " ahk_class AutoHotkeyGUI")
    
    if (hwnd) {
        ; 如果窗口存在，激活它
        WinActivate(hwnd)
        
        ; 如果窗口是最小化状态，恢复它
        if (WinGetMinMax(hwnd) = -1) {  ; -1 表示最小化
            WinRestore(hwnd)
        }

        ; t_softmanager_settings：alwaysOnTop-get
        isTop := SettingsManager.GetBool("AlwaysOnTop")

        if(isTop){
            try{
                GuiManager.gui.Opt("+AlwaysOnTop") ; 置顶 
            }
        }else{
            try{
                GuiManager.gui.Opt("-AlwaysOnTop") ; 取消置顶
            }
        }
        
        return
    }

    ; 创建对应类型的配置管理器
    configMgr := ConfigManager(configType)
    
    ; 创建GUI管理器
    guiMgr := GuiManager(configMgr)
    
    ; 显示软件列表
    guiMgr.ShowSoftwareList()
}

#q::{
    ShowManager('soft')
}
