;@Ahk2Exe-ExeName OpenFile.exe             ; 设置输出文件名
;@Ahk2Exe-SetDescription 软件管理器          ; 设置文件描述
;@Ahk2Exe-SetCopyright Kickback枫枫         ; 设置版权信息
;@Ahk2Exe-SetVersion 1.1.0                 ; 设置版本号
;@Ahk2Exe-SetCompanyName Kickback枫枫       ; 设置公司名
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
    ; 检查是否有GUI窗口在前台
    activeGuiHwnd := WinActive("ahk_class AutoHotkeyGUI")
    
    if (activeGuiHwnd) {
        ; 如果有GUI窗口在前台，最小化它
        WinMinimize(activeGuiHwnd)
    } else {
        ; 没有GUI窗口在前台，显示GUI
        ShowGuiManager('openfile')
    }
}

InitProgram(){
    ; 启动时注册热键
    RegisterMainShortcut()
}

; 执行初始化
InitProgram()
