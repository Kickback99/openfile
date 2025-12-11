#Requires AutoHotkey v2.0
#SingleInstance Force
#Include src\ConfigManager.ahk
#Include src\GuiManager.ahk

; 显示管理器函数
ShowManager(configType) {

    ; 检查是否已有同名的窗口
    windowTitle := configType
    hwnd := WinExist(windowTitle " ahk_class AutoHotkeyGUI")
    
    if (hwnd) {
        ; 如果窗口存在，激活它
        WinActivate(hwnd)
        
        ; 如果窗口是最小化状态，恢复它
        if (WinGetMinMax(hwnd) = -1) {  ; -1 表示最小化
            WinRestore(hwnd)
        }
        
        ; 确保窗口在最前面
        WinSetAlwaysOnTop(1, windowTitle)
        WinSetAlwaysOnTop(0, windowTitle)  ; 临时置顶然后取消，确保在前面
        
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
    ShowManager('openfile')
}

!c::{
    IB := InputBox('请输入内容','AHKScript','w440 h150')

    IBv := IB.value 

    if(IB.Result == 'Cancel'){
        return
    }

    ;openfile
    switch IBv{
        case 'openfile':
        ShowManager(IBv)
        case 'ai':
        ShowManager(IBv)
        case 'developer':
        ShowManager(IBv)   
    }

}