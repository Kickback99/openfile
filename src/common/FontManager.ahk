class FontManager {
    ; 释放到临时目录后以进程私有方式加载，避免安装字体
    static Load() {
        fontPath := A_Temp "\OpenFile\fonts\JetBrainsMono-Regular.ttf"
        DirCreate(A_Temp "\OpenFile\fonts")
        try {
            FileInstall("src\assets\fonts\JetBrainsMono-Regular.ttf", fontPath, 1)
        }
        return DllCall("AddFontResourceExW", "Str", fontPath, "UInt", 0x10, "Ptr", 0, "Int")
    }

    ; 从低到高设置，最后设置的 JetBrains Mono 优先
    static ApplyTo(gui) {
        gui.SetFont("s9", "Courier New")
        gui.SetFont(, "Consolas")
        gui.SetFont(, "Source Code Pro")
        gui.SetFont(, "Cascadia Code")
        gui.SetFont(, "Fira Code")
        gui.SetFont(, "JetBrains Mono")
    }
}
