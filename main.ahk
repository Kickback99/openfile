;@Ahk2Exe-ExeName OpenFile.exe             ; 设置输出文件名
;@Ahk2Exe-SetCopyright Kickback枫枫         ; 设置版权信息
;@Ahk2Exe-SetVersion 1.1.0                 ; 设置版本号
;@Ahk2Exe-SetMainIcon lib\openfile.ico     ; 设置图标
;@Ahk2Exe-AddResource lib\py-master\lib\dll_64\cpp2ahk.dll, DLL64

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include src\ConfigManager.ahk
#Include src\GuiManager.ahk
#Include "src\common\SettingsManager.ahk"

; 在程序开头添加调试
if (A_IsCompiled && WindowConstants.DEBUG_MODE) {
    ; 检查资源是否存在 - 使用正确的名称和类型
    if (buf := ResourceLoad("DLL64", 10)) {
        size := buf.Size
        MsgBox("✅ DLL资源嵌入成功！`n名称: DLL64`n类型: 10`n大小: " size " 字节", "调试信息", 0x40)
    } else {
        MsgBox("❌ DLL资源未找到！`n尝试查找: DLL64, 类型: 10", "错误", 0x30)
    }
}

ResourceLoad(Key, Type := 10) {
    if !A_IsCompiled
        return false
    
    hMod := DllCall("GetModuleHandle", "Ptr", 0, "Ptr")
    if !hMod
        return false
    
    hRes := DllCall("FindResource", "Ptr", hMod, "Str", Key, "UInt", Type, "Ptr")
    if !hRes
        return false
    
    hData := DllCall("LoadResource", "Ptr", hMod, "Ptr", hRes, "Ptr")
    if !hData
        return false
    
    pData := DllCall("LockResource", "Ptr", hData, "Ptr")
    if !pData
        return false
    
    nSize := DllCall("SizeofResource", "Ptr", hMod, "Ptr", hRes)
    if !nSize
        return false
    
    buf := Buffer(nSize)
    DllCall("RtlMoveMemory", "Ptr", buf, "Ptr", pData, "Ptr", nSize)
    return buf
}

; 验证拼音库是否工作
VerifyPinyin() {
    try {
        testResult := py.initials_muti("测试")
        MsgBox("✅ 拼音库工作正常！`n测试结果: " testResult)
    } catch as e {
        MsgBox("❌ 拼音库初始化失败！`n错误: " e.Message)
    }
}

; 程序启动时验证
if(WindowConstants.DEBUG_MODE){
    VerifyPinyin()
}

; 支持的配置类型数组（从ConfigManager动态获取）
global ConfigTypes := []

; 初始化时加载配置类型
InitConfigTypes() {
    global ConfigTypes
    
    ; 直接从ConfigManager获取配置类型
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

; 初始化托盘菜单
InitTrayMenu() {
    ; 创建托盘菜单
    A_TrayMenu.Delete()  ; 删除默认菜单
    A_TrayMenu.Add("开机自启", ToggleAutoStart)
    A_TrayMenu.Add("退出", (*) => ExitApp())
    A_TrayMenu.Default := "开机自启"

    ; 设置托盘图标消息处理
    OnMessage(0x404, TrayIconHandler)

    TrayIconHandler(wParam, lParam, msg, hwnd) {
        switch lParam {
            case 0x201:  ; WM_LBUTTONDOWN - 左键单击
                activeType := SettingsManager.GetValue("ActiveConfig", "Global")
                ShowGuiManager(activeType)
            case 0x203:  ; WM_LBUTTONDBLCLK - 左键双击
                activeType := SettingsManager.GetValue("ActiveConfig", "Global")
                ShowGuiManager(activeType)
                
            case 0x205:  ; WM_RBUTTONUP - 右键释放（显示菜单）
                ; 默认行为已经会显示菜单，这里不需要额外处理
        }
    }
}

; 启用自启动
EnableAutoStart() {
    appName := "OpenFile"  ; 你的应用名称
    exePath := A_ScriptFullPath
    
    ; 如果是未编译的脚本，需要包含解释器路径
    if !A_IsCompiled {
        exePath := A_AhkPath ' "' A_ScriptFullPath '"'
    }
    
    try {
        RegWrite(exePath, "REG_SZ", "HKCU\Software\Microsoft\Windows\CurrentVersion\Run", appName)
    }
}

; 禁用自启动
DisableAutoStart() {
    appName := "OpenFile"
    try {
        RegDelete("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", appName)
    }
}

; 检查自启动状态
IsAutoStartEnabled() {
    appName := "OpenFile"
    try {
        value := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", appName)
        return value != ""
    }
    return false
}

; 切换自启动状态
ToggleAutoStart(*) {
    configAutoStart := SettingsManager.GetBool("AutoStartEnabled", "Global")
    
    if (configAutoStart) {
        ; 当前是开启状态，切换为关闭
        DisableAutoStart()
        SettingsManager.SetValue("AutoStartEnabled", "false", "Global")
        A_TrayMenu.Uncheck("开机自启")
        ; MsgBox("已关闭开机自启", "提示", "T2")
    } else {
        ; 当前是关闭状态，切换为开启
        EnableAutoStart()
        SettingsManager.SetValue("AutoStartEnabled", "true", "Global")
        A_TrayMenu.Check("开机自启")
        ; MsgBox("已开启开机自启", "提示", "T2")
    }
}


; 检查并设置自启动（现在主要用于最终验证）
CheckAndSetAutoStart() {
    ; 这里只做最终的验证和确保一致
    configAutoStart := SettingsManager.GetBool("AutoStartEnabled", "Global")
    registryAutoStart := IsAutoStartEnabled()
    
    ; 确保两者一致（以配置文件为准）
    if (configAutoStart && !registryAutoStart) {
        EnableAutoStart()
    } else if (!configAutoStart && registryAutoStart) {
        DisableAutoStart()
    }
}

; 初始化版本配置
InitVersionConfig(){
    ; 1. 检查配置版本，如果需要则重置
    configReset := SettingsManager.CheckAndResetConfig()
    
    ; 2. 读取配置文件的设置
    configAutoStart := SettingsManager.GetBool("AutoStartEnabled", "Global")
    
    ; 3. 检查注册表状态
    registryAutoStart := IsAutoStartEnabled()
    
    ; 4. 以配置文件为准，确保两者一致
    if (configAutoStart && !registryAutoStart) {
        ; 配置文件说启用，但注册表没有，启用它
        EnableAutoStart()
        registryAutoStart := true
    } else if (!configAutoStart && registryAutoStart) {
        ; 配置文件说禁用，但注册表有，禁用它
        DisableAutoStart()
        registryAutoStart := false
    }
    
    ; 5. 更新托盘菜单状态
    if (configAutoStart) {
        A_TrayMenu.Check("开机自启")
    } else {
        A_TrayMenu.Uncheck("开机自启")
    }
    
    ; 6. 显示重置提示（如果需要）
    if (configReset && WindowConstants.DEBUG_MODE) {
        MsgBox("配置已更新到新版本，自启动设置已应用。", "提示", "T2")
    }
    
    ; 7. 记录日志（调试用）
    if (WindowConstants.DEBUG_MODE) {
        MsgBox("自启动初始化完成`n配置文件: " (configAutoStart ? "启用" : "禁用") 
            . "`n注册表: " (registryAutoStart ? "启用" : "禁用"), "调试信息", "T2")
    }
}

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

; 全局类型热键注册函数
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

        WinActivate(hwnd)

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

; alt+c事件
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
    ; 初始化托盘菜单
    InitTrayMenu()

    ; 初始化配置类型
    InitConfigTypes()
    
    ; 初始化版本配置
    InitVersionConfig()

    ; 在脚本启动时注册两个热键
    RegisterMainShortcut()
    RegisterTypeHotkey()

    ; 最终验证自启动状态
    CheckAndSetAutoStart()

    ; 自动启动应用程序
    activeType := SettingsManager.GetValue("ActiveConfig", "Global")
    ShowGuiManager(activeType)
}

; 执行初始化
InitProgram()