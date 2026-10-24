;@Ahk2Exe-ExeName OpenFile.exe             ; 设置输出文件名
;@Ahk2Exe-SetDescription 软件管理器          ; 设置文件描述
;@Ahk2Exe-SetCopyright Kickback枫枫         ; 设置版权信息
;@Ahk2Exe-SetVersion 1.0.0                 ; 设置版本号
;@Ahk2Exe-SetCompanyName Kickback枫枫       ; 设置公司名
;@Ahk2Exe-SetMainIcon lib\OpenFile.ico     ; 设置图标
;@Ahk2Exe-AddResource lib\py-master\lib\dll_64\cpp2ahk.dll, DLL64

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include src\ConfigManager.ahk
#Include src\common\FontManager.ahk
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

; 支持的配置类型数组（从 ConfigManager 动态获取）
global ConfigTypes := []

; 初始化时加载配置类型
InitConfigTypes() {
    global ConfigTypes

    ; 直接从 ConfigManager 获取配置类型
    ConfigTypes := ConfigManager.GetAllConfigTypes()

    ; 如果获取为空，使用默认值
    if (ConfigTypes.Length = 0) {
        ConfigTypes := [SettingsManager.DEFAULT_CONFIG_TYPE]
    }

    ; 确保 ConfigManager section 存在
    SettingsManager.EnsureConfigFile()
}

; 刷新配置类型列表（供外部调用）
RefreshConfigTypes() {
    InitConfigTypes()
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
    ; 使用 GetValue 读取 TypeHotkey
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

   ; 检查是否已有同名的且是 gui 类型的窗口
    ; WinExist 标题匹配区分大小写，须用显示名
    windowTitle := ConfigManager.GetDisplayType(configType)
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

        ; 获取该窗口对应的 GuiManager 实例
        try {
            ; 通过窗口句柄获取 Gui 对象
            guiObj := GuiFromHwnd(hwnd)
            if (guiObj && guiObj.HasProp("guiManager")) {
                ; 等待窗口完全激活
                WinWaitActive(hwnd)
                Sleep(50)  ; 短暂等待确保窗口状态稳定

                ; 获取 GuiManager 实例并设置焦点到搜索框
                guiMgr := guiObj.guiManager
                if (guiMgr.HasProp("searchBox") && guiMgr.searchBox) {
                    ; 方法 1：直接调用 Focus 方法
                    guiMgr.searchBox.Focus()

                    ; 方法 2：如果 Focus 方法不够稳定，可以发送一个空字符来确保焦点
                    ; guiMgr.searchBox.Value := guiMgr.searchBox.Value  ; 触发更新

                    ; 方法 3：发送 Tab 键两次确保焦点在正确的控件
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

    ; 创建 GUI 管理器
    guiMgr := GuiManager(configMgr)

    ; 显示文件列表
    guiMgr.ShowFileList()
}

; win+q 事件
MainHotkeyHandler(*) {
    ; 获取所有 GUI 窗口列表
    guiWindows := WinGetList("ahk_class AutoHotkeyGUI")

    ; 获取当前前台窗口
    activeHwnd := WinActive("A")
    activeClass := WinGetClass(activeHwnd)
    activeTitle := WinGetTitle(activeHwnd)

    ; 检查是否有任何未最小化的 GUI 窗口
    hasVisibleGui := false
    for hwnd in guiWindows {
        if (WinGetMinMax(hwnd) != -1) {
            hasVisibleGui := true
            break
        }
    }

    ; 检查前台窗口是否是 GUI 窗口
    isGuiActive := (activeClass = "AutoHotkeyGUI")

    ; 获取激活的配置类型
    activeType := SettingsManager.GetValue("ActiveConfig", "Global")

    ; 检查 ActiveConfig 窗口是否存在
    activeConfigHwnd := 0
    for hwnd in guiWindows {
        if (WinGetTitle(hwnd) = activeType) {
            activeConfigHwnd := hwnd
            break
        }
    }

    ; 检查前台窗口是否是 ActiveConfig 的 GUI 窗口
    isActiveConfigGuiActive := (isGuiActive && activeTitle = activeType)

    if (hasVisibleGui) {
        if (isActiveConfigGuiActive) {
            ; 情况 1：前台是 ActiveConfig 的 GUI 窗口，最小化所有 GUI 窗口
            for hwnd in guiWindows {
                if (WinGetMinMax(hwnd) != -1) {  ; 如果窗口未最小化
                    WinMinimize(hwnd)
                }
            }
            return
        } else if (isGuiActive) {
            ; 情况 2：前台是其他 GUI 窗口（如 dev）
            ; 先检查 ActiveConfig 窗口是否存在
            if (activeConfigHwnd) {
                ; 先最小化其他非 ActiveConfig 的 GUI 窗口
                for hwnd in guiWindows {
                    if (hwnd != activeConfigHwnd && WinGetMinMax(hwnd) != -1) {
                        WinMinimize(hwnd)
                    }
                }

                ; 然后激活 ActiveConfig 窗口
                if (WinGetMinMax(activeConfigHwnd) = -1) {
                    WinRestore(activeConfigHwnd)
                }
                WinActivate(activeConfigHwnd)
            } else {
                ; ActiveConfig 窗口不存在，先最小化所有窗口，再创建新窗口
                for hwnd in guiWindows {
                    if (WinGetMinMax(hwnd) != -1) {
                        WinMinimize(hwnd)
                    }
                }
                ShowGuiManager(activeType)
            }
            return
        } else {
            ; 情况 3：有未最小化的 GUI 窗口，但没有 GUI 在前台
            if (activeConfigHwnd) {
                ; 最小化其他 GUI 窗口
                for hwnd in guiWindows {
                    if (hwnd != activeConfigHwnd && WinGetMinMax(hwnd) != -1) {
                        WinMinimize(hwnd)
                    }
                }

                ; 激活 ActiveConfig 窗口
                if (WinGetMinMax(activeConfigHwnd) = -1) {
                    WinRestore(activeConfigHwnd)
                }
                WinActivate(activeConfigHwnd)

            } else {
                ; ActiveConfig 窗口不存在，创建并显示
                ShowGuiManager(activeType)
            }
            return
        }
    }
    ; 情况 4：没有未最小化的 GUI 窗口（全部最小化或没有窗口），显示 ActiveConfig 窗口
     ShowGuiManager(activeType)
}

; alt+c 事件
TypeHotkeyHandler(*){
    isManagerActive := WinActive("ahk_class AutoHotkeyGUI")

    ; 预先声明变量
    parentGui := ""

    if(isManagerActive){
        ; 获取当前激活的 GUI 对象
        parentHwnd := WinGetID("A")
        parentGui := GuiFromHwnd(parentHwnd)

        if(parentGui){
            ; 临时为该 GUI 设置+OwnDialogs
            parentGui.Opt("+OwnDialogs")
        }
    }

    activeType := SettingsManager.GetValue("ActiveConfig", "Global")

    IB := InputBox('请输入配置类型', ConfigManager.GetDisplayType(activeType) ,'w440 h150')

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

; 脚本启动入口：初始化并注册热键
InitProgram(){
    ; 先加载私有字体，再创建任何 GUI
    FontManager.Load()

    ; 初始化配置类型
    InitConfigTypes()

    ; 在脚本启动时注册两个热键
    RegisterMainShortcut()
    RegisterTypeHotkey()

    ; 搜索框 ↓ / 创建按钮 ↑ 的焦点转移
    GuiEventHandlers.RegisterArrowNavHotkeys()
}

; 执行初始化
InitProgram()
