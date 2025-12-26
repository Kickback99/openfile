#Include src\ConfigManager.ahk
#Include src\GuiManager.ahk

; 显示管理器函数
ShowManager(configType) {
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
