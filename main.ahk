#Requires AutoHotkey v2.0
#SingleInstance Force
#Include src\ConfigManager.ahk
#Include src\GuiManager.ahk
#Include "src\common\SettingsManager.ahk"

; 显示管理器函数
ShowManager(configType) {

    ; 检查是否已有同名的窗口
    windowTitle := configType
    hwnd := WinExist(windowTitle)
    
    if (hwnd) {
        ; 如果窗口存在，激活它
        WinActivate(windowTitle)
        
        ; 如果窗口是最小化状态，恢复它
        if (WinGetMinMax(hwnd) = -1) {  ; -1 表示最小化
            WinRestore(windowTitle)
        }
        
        ; 确保窗口在最前面
        ; WinSetAlwaysOnTop(1, windowTitle)

        ; t_softmanager_settings：alwaysOnTop-get
        ; !!! 修改：不再直接设置置顶，而是根据配置设置
        isTop := SettingsManager.GetBool("AlwaysOnTop")
        if(isTop){
            try{
                ; WinSetAlwaysOnTop(1, windowTitle) ; 置顶
                ; 使用gui的Opt方法而不是WinSet
                guiManager.gui.Opt("+AlwaysOnTop")
            }catch {

            }
        } else {
            try{
                ; WinSetAlwaysOnTop(0, windowTitle) ; 取消置顶
                guiManager.gui.Opt("-AlwaysOnTop")
            }catch {

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
    ShowManager('software')
}
