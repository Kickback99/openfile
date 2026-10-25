#Requires AutoHotkey v2.0
#SingleInstance Force
#Include src\ConfigManager.ahk
#Include src\GuiManager.ahk
#Include "src\common\SettingsManager.ahk"

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

   ; 检查是否已有同名的且是 gui 类型的窗口
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

        ; 强制设置焦点到搜索框
        try {
            WinWaitActive(hwnd)
            Sleep(50)

            ; 方法 1：使用 ControlFocus 通过类名
            ; 搜索框通常是第一个 Edit 控件
            ControlFocus("Edit1", hwnd)

            ; 方法 2：如果 ControlFocus 不够，发送 Tab 键
            ; Sleep(10)
            ; ControlSend("{Tab}", , hwnd)

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
    ; 检查是否有 GUI 窗口在前台
    activeGuiHwnd := WinActive("ahk_class AutoHotkeyGUI")

    if (activeGuiHwnd) {
        ; 如果有 GUI 窗口在前台，最小化它
        WinMinimize(activeGuiHwnd)
    } else {
        ; 没有 GUI 窗口在前台，显示 GUI
        ShowGuiManager('openfile')
    }
}

; 脚本启动入口：初始化并注册热键
InitProgram(){
    ; 启动时注册热键
    RegisterMainShortcut()

    ; 搜索框 ↓ / 创建按钮 ↑ 的焦点转移
    GuiEventHandlers.RegisterArrowNavHotkeys()
}

; 执行初始化
InitProgram()
