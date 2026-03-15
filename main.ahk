#Requires AutoHotkey v2.0
#SingleInstance Force
#Include src\ConfigManager.ahk
#Include src\GuiManager.ahk
#Include "src\common\SettingsManager.ahk"

; 支持的配置类型数组（改为空数组，从ConfigManager动态获取）
global ConfigTypes := []  ; 修改：改为空数组，从ConfigManager动态获取

; 初始化时加载配置类型
InitConfigTypes() {
    global ConfigTypes
    
    ; 修改：直接从ConfigManager获取配置类型
    ConfigTypes := ConfigManager.GetAllConfigTypes()
    
    ; 如果获取为空，使用默认值
    if (ConfigTypes.Length = 0) {
        ConfigTypes := [SettingsManager.DEFAULT_CONFIG_TYPE]
    }
    
    ; 确保ConfigManager section存在
    SettingsManager.EnsureConfigFile()
}

; 刷新配置类型列表（供外部调用）
RefreshConfigTypes() {
    InitConfigTypes()
}

; !!! 新增：启动时清理配置
; SettingsManager.EnsureConfigFile()

; 全局热键注册函数
RegisterMainShortcut() {
    ; 从配置文件中读取快捷键
    shortcut := SettingsManager.GetValue("MainHotkey", "Global")

    ; 如果没有设置或为空，使用默认值
    if (!shortcut || shortcut = "" || shortcut = "#q") {
        shortcut := "#q"
        SettingsManager.SetValue("MainHotkey", shortcut, "Global")
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

;!!! 修改：RegisterTypeHotkey函数
RegisterTypeHotkey() {
    ; 使用GetValue读取TypeHotkey
    shortcut := SettingsManager.GetValue("TypeHotkey", "Global")
    
    ; 如果没有设置或为空，使用默认值
    if (!shortcut || shortcut = "" || shortcut = "!c" ) {
        shortcut := "!c"
        SettingsManager.SetValue("TypeHotkey", shortcut, "Global")
    }
    
    try {
        ; 先尝试移除已注册的热键
        Hotkey(shortcut, TypeHotkeyHandler, "Off")
        
        ; 注册新的热键
        Hotkey(shortcut, TypeHotkeyHandler, "On")
    } catch as e {
        ; 如果注册失败，使用默认热键
        Hotkey("!c", TypeHotkeyHandler, "On")
        MessageManager.ShowError("类型热键注册失败，已使用默认热键 Alt+C。`n错误信息: " e.Message, "警告", 0x30)
    }
}

; 显示管理器函数
ShowGuiManager(configType) {

    ; 管理器加载时清理一次配置
    SettingsManager.EnsureConfigFile()

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
        
        ; 获取该窗口对应的GuiManager实例
        try {
            ; 通过窗口句柄获取Gui对象
            guiObj := GuiFromHwnd(hwnd)
            if (guiObj && guiObj.HasProp("guiManager")) {
                ; 等待窗口完全激活
                WinWaitActive(hwnd)
                Sleep(50)  ; 短暂等待确保窗口状态稳定
                
                ; 获取GuiManager实例并设置焦点到搜索框
                guiMgr := guiObj.guiManager
                if (guiMgr.HasProp("searchBox") && guiMgr.searchBox) {
                    ; 方法1：直接调用Focus方法
                    guiMgr.searchBox.Focus()
                    
                    ; 方法2：如果Focus方法不够稳定，可以发送一个空字符来确保焦点
                    ; guiMgr.searchBox.Value := guiMgr.searchBox.Value  ; 触发更新
                    
                    ; 方法3：发送Tab键两次确保焦点在正确的控件
                    ; ControlSend("{Tab}{Tab}", , hwnd)
                }
            }
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
    ; 获取所有GUI窗口列表
    guiWindows := WinGetList("ahk_class AutoHotkeyGUI")
    
    ; 获取当前前台窗口
    activeHwnd := WinActive("A")
    activeClass := WinGetClass(activeHwnd)
    activeTitle := WinGetTitle(activeHwnd)
    
    ; 检查是否有任何未最小化的GUI窗口
    hasVisibleGui := false
    for hwnd in guiWindows {
        if (WinGetMinMax(hwnd) != -1) {
            hasVisibleGui := true
            break
        }
    }
    
    ; 检查前台窗口是否是GUI窗口
    isGuiActive := (activeClass = "AutoHotkeyGUI")
    
    ; 获取激活的配置类型
    activeType := SettingsManager.GetValue("ActiveConfig", "Global")
    
    ; 检查ActiveConfig窗口是否存在
    activeConfigHwnd := 0
    for hwnd in guiWindows {
        if (WinGetTitle(hwnd) = activeType) {
            activeConfigHwnd := hwnd
            break
        }
    }
    
    ; 检查前台窗口是否是ActiveConfig的GUI窗口
    isActiveConfigGuiActive := (isGuiActive && activeTitle = activeType)
    
    if (hasVisibleGui) {
        if (isActiveConfigGuiActive) {
            ; 情况1：前台是ActiveConfig的GUI窗口，最小化所有GUI窗口
            for hwnd in guiWindows {
                if (WinGetMinMax(hwnd) != -1) {  ; 如果窗口未最小化
                    WinMinimize(hwnd)
                }
            }
            return
        } else if (isGuiActive) {
            ; 情况2：前台是其他GUI窗口（如dev）
            ; 先检查ActiveConfig窗口是否存在
            if (activeConfigHwnd) {                
                ; 先最小化其他非ActiveConfig的GUI窗口
                for hwnd in guiWindows {
                    if (hwnd != activeConfigHwnd && WinGetMinMax(hwnd) != -1) {
                        WinMinimize(hwnd)
                    }
                }

                ; 然后激活ActiveConfig窗口
                if (WinGetMinMax(activeConfigHwnd) = -1) {
                    WinRestore(activeConfigHwnd)
                }
                WinActivate(activeConfigHwnd)
            } else {
                ; ActiveConfig窗口不存在，先最小化所有窗口，再创建新窗口
                for hwnd in guiWindows {
                    if (WinGetMinMax(hwnd) != -1) {
                        WinMinimize(hwnd)
                    }
                }
                ShowGuiManager(activeType)
            }
            return
        } else {
            ; 情况3：有未最小化的GUI窗口，但没有GUI在前台
            if (activeConfigHwnd) {                
                ; 最小化其他GUI窗口
                for hwnd in guiWindows {
                    if (hwnd != activeConfigHwnd && WinGetMinMax(hwnd) != -1) {
                        WinMinimize(hwnd)
                    }
                }

                ; 激活ActiveConfig窗口
                if (WinGetMinMax(activeConfigHwnd) = -1) {
                    WinRestore(activeConfigHwnd)
                }
                WinActivate(activeConfigHwnd)

            } else {
                ; ActiveConfig窗口不存在，创建并显示
                ShowGuiManager(activeType)
            }
            return
        }
    }
    ; 情况4：没有未最小化的GUI窗口（全部最小化或没有窗口），显示ActiveConfig窗口
     ShowGuiManager(activeType)
}

TypeHotkeyHandler(*){
    isManagerActive := WinActive("ahk_class AutoHotkeyGUI")
    
    ; 预先声明变量
    parentGui := ""
    
    if(isManagerActive){
        ; 获取当前激活的GUI对象
        parentHwnd := WinGetID("A")
        parentGui := GuiFromHwnd(parentHwnd)
        
        if(parentGui){
            ; 临时为该GUI设置+OwnDialogs
            parentGui.Opt("+OwnDialogs")
        }
    }

    activeType := SettingsManager.GetValue("ActiveConfig", "Global")
    
    IB := InputBox('请输入配置类型', activeType ,'w440 h150')
    
    ; 如果设置了+OwnDialogs，恢复原状
    if(parentGui){
        parentGui.Opt("-OwnDialogs")
    }
    
    userInput := IB.value 

    if(IB.Result == 'Cancel'){
        return
    }

    ; 检查是否在支持的类型中
    for configType in ConfigTypes {
        if (userInput = configType) {
            ShowGuiManager(configType)
            return
        }
    }
}

InitProgram(){
    ; 初始化配置类型
    InitConfigTypes()

    ;!!! 修改：在脚本启动时注册两个热键
    RegisterMainShortcut()
    RegisterTypeHotkey()
}

; 执行初始化
InitProgram()