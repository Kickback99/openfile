#Requires AutoHotkey v2.0
#SingleInstance Force
#Include src\ConfigManager.ahk
#Include src\GuiManager.ahk
#Include "src\common\SettingsManager.ahk"

; 入口文件顶部定义支持的配置类型数组
global SupportedConfigTypes := ["openfile", "ai", "dev"]

; 全局热键注册函数
RegisterMainShortcut() {
    ; 从配置文件中读取快捷键
    shortcut := SettingsManager.GetValue("Shortcuts")
    
    ; 如果没有设置或为空，使用默认值
    if (!shortcut || shortcut = "" || shortcut = "#q") {
        shortcut := "#q"
        SettingsManager.SetValue("Shortcuts", shortcut)
    }

    ; 先尝试移除已注册的热键
    try {
        Hotkey(shortcut, MainHotkeyHandler, "Off")
    }
    
    ; 注册热键
    try {
        Hotkey(shortcut, MainHotkeyHandler, "On")
    } catch as e {
        ; 如果注册失败，使用默认热键
        Hotkey("#q", MainHotkeyHandler, "On")
        MessageManager.ShowError("热键注册失败，已使用默认热键 Win+Q。`n错误信息: " e.Message, "警告", 0x30)
    }
}

; 显示管理器函数
ShowGuiManager(configType) {

   ; 检查是否已有同名的且是gui类型的窗口
    windowTitle := configType
    hwnd := WinExist(windowTitle " ahk_class AutoHotkeyGUI")
    
    if (hwnd) {
        ; 如果窗口存在，激活它
        WinActivate(hwnd)
        
        ; 如果窗口是最小化状态，恢复它
        if (WinGetMinMax(hwnd) = -1) {  ; -1 表示最小化
            WinRestore(hwnd)
        }

        ; t_openfile_settings：alwaysOnTop-get
        isTop := SettingsManager.GetBool("AlwaysOnTop", configType)

        if(isTop){
            try{
                GuiManager.gui.Opt("+AlwaysOnTop") ; 置顶 
            }
        }else{
            try{
                GuiManager.gui.Opt("-AlwaysOnTop") ; 取消置顶
            }
        }
        
        ; 强制设置焦点到搜索框
        try {
            WinWaitActive(hwnd)
            Sleep(50)
            
            ; 方法1：使用ControlFocus通过类名
            ; 搜索框通常是第一个Edit控件
            ControlFocus("Edit1", hwnd)
            
            ; 方法2：如果ControlFocus不够，发送Tab键
            ; Sleep(10)
            ; ControlSend("{Tab}", , hwnd)
            
        } catch as e {
            ; 忽略焦点设置错误
        }
        return
    }

    ; 创建对应类型的配置管理器
    configMgr := ConfigManager(configType)
    
    ; 创建GUI管理器
    guiMgr := GuiManager(configMgr)
    
    ; 显示文件列表
    guiMgr.ShowFileList()
}

; win+q事件
MainHotkeyHandler(*) {
    ShowGuiManager(SupportedConfigTypes[1])
}

!c::{
    IB := InputBox('请输入内容','AHKScript','w440 h150')

    IBv := IB.value 

    if(IB.Result == 'Cancel'){
        return
    }

    ; 检查是否在支持的类型中
    for configType in SupportedConfigTypes {
        if (IBv = configType) {
            ShowManager(configType)
            return
        }
    }
}

InitProgram(){
    ; 启动时注册热键
    RegisterMainShortcut()
}

; 执行初始化
InitProgram()