; ==============================
; SettingsManager.ahk
; Settings.ini配置文件管理器
; ==============================
class SettingsManager {
    ; 静态属性：配置文件路径
    ;!!! 修改：将配置文件路径改为用户家目录下的openfile/settings.ini
    static ConfigPath := ""

    ; 配置段名称
    static SectionName := "General"

    ; 配置键的顺序（保持原有顺序）
    static ConfigOrder := ["AlwaysOnTop", "SortByAlphabet", "EnableExtension", "BatchThreshold", "ShowSuccessMsg","Shortcuts","Link"]

    ; t_openfile_settings：default
    static DefaultConfig := Map(
        "AlwaysOnTop", "true",      ; 字符串
        "SortByAlphabet", "false",  ; 字符串
        "EnableExtension", "false", ; 字符串
        "BatchThreshold", "5",      ; 字符串
        "ShowSuccessMsg", "true",    ; 字符串
        "Shortcuts", "#q",      ; 字符串
        "Link",   "https://github.com/Kickback99/openfile" ; 字符串
    )

    ;!!! 新增：获取配置文件路径的静态方法
    static GetConfigPath() {
        if (this.ConfigPath = "") {
            ; 获取用户家目录
            userHome := A_MyDocuments  ; 文档目录
            SplitPath(userHome, , &userHomeDir)
            
            ; 构建应用数据目录路径
            appDataDir := userHomeDir "\openfile"
            this.ConfigPath := appDataDir "\settings.ini"
            
            ; 确保目录存在
            this.EnsureSettingsDirectory(appDataDir)
        }
        return this.ConfigPath
    }
    
    ;!!! 新增：确保设置目录存在的方法
    static EnsureSettingsDirectory(appDataDir) {
        if (!DirExist(appDataDir)) {
            try {
                DirCreate(appDataDir)
            } catch as e {
                MsgBox("创建设置目录失败: " e.Message)
            }
        }
    }
    
    ; 读取所有配置到Map中
    static ReadAllConfig() {
        ; 先创建默认配置
        config := this.CreateDefaultConfig()
        
        try {
            settingsPath := this.GetConfigPath()
            
            if (!FileExist(settingsPath)) {
                ; 文件不存在，返回默认配置
                return config
            }
            
            ; 读取文件内容
            content := FileRead(settingsPath)
            
            ; 尝试多种编码读取
            if (content = "") {
                ; 尝试 UTF-8 读取
                try {
                    content := FileRead(settingsPath, "UTF-8")
                }
                
                ; 如果还是空，尝试 ANSI
                if (content = "") {
                    content := FileRead(settingsPath, "CP0")
                }
            }
            
            ; 解析内容
            lines := StrSplit(content, "`n", "`r")
            inGeneralSection := false
            
            for line in lines {
                line := Trim(line)
                
                ; 跳过注释和空行
                if (line = "" || SubStr(line, 1, 1) = ";") {
                    continue
                }
                
                ; 检查是否是段
                if (SubStr(line, 1, 1) = "[") {
                    ; 使用 SectionName 变量
                    if (line = "[" . this.SectionName . "]") {
                        inGeneralSection := true
                    } else {
                        inGeneralSection := false
                    }
                    continue
                }
                
                ; 如果在 [General] 段中，解析配置
                if (inGeneralSection && InStr(line, "=")) {
                    eqPos := InStr(line, "=")
                    if (eqPos > 0) {
                        key := Trim(SubStr(line, 1, eqPos - 1))
                        value := Trim(SubStr(line, eqPos + 1))
                        
                        ; 移除行末注释
                        if (InStr(value, ";")) {
                            parts := StrSplit(value, ";")
                            value := Trim(parts[1])
                        }
                        
                        ; 存储配置
                        config[key] := value
                    }
                }
            }
            
        } catch as e {
            ; 出错时返回默认配置
            ; 可以取消下面的注释查看错误信息
            ; MsgBox("读取配置时出错: " . e.Message)
        }
        
        return config
    }

    ; 重置所有设置为默认值
    static ResetToDefault() {
        return this.WriteConfig(this.CreateDefaultConfig())
    }

    ; 获取默认值（单个键）
    static GetDefaultValue(key) {
       return this.DefaultConfig.Get(key, "")
    }
    
    ; 读取单个配置值
    static GetValue(key) {
        config := this.ReadAllConfig()
    
        ; 如果配置中有这个键，返回它的值
        if (config.Has(key) && config[key] != "") {
            return config[key]
        }
    
        ; 否则返回DefaultConfig中的默认值
        return this.DefaultConfig.Get(key, "")
    }
    
    ; 读取布尔值配置
    static GetBool(key) {
            value := this.GetValue(key)
            value := StrLower(Trim(value))
    
        return (value = "true" || value = "1" || value = "yes" || value = "on")
    }
    
    ; 读取整数值配置
    static GetInt(key) {
        value := this.GetValue(key)

        ; 如果获取的值为空，尝试从DefaultConfig获取默认值
        if (value = "") {
            value := this.DefaultConfig.Get(key, "0")
        }
        
        try {
            ; 提取数字部分
            if (RegExMatch(value, "(\d+)", &match)) {
                return Integer(match[1])
            }
        }
        
        try {
            return Integer(value)
        } catch {
            return 0
        }
    }
    
    ; 写入配置值
    static SetValue(key, value) {
        try {
            settingsPath := this.GetConfigPath()
            
            ; 先读取现有配置
            config := this.ReadAllConfig()
            
            ; 更新值
            config[key] := String(value)
            
            ; 重新写入文件
            return this.WriteConfig(config)
            
        } catch {
            return false
        }
    }
    
    ; 写入所有配置到文件
    static WriteConfig(config) {
        try {
            settingsPath := this.GetConfigPath()
            
            ; 构建文件内容，使用 SectionName 变量
            content := "[" . this.SectionName . "]`r`n"
            
            ; 按照指定顺序写入
            for key in this.ConfigOrder {
                if (config.Has(key)) {
                    value := config[key]
                    
                    ; 由于现在所有值都是字符串，直接写入
                    ; 但为了安全，确保是字符串
                    if (Type(value) != "String") {
                        value := String(value)
                    }
                    
                    content .= key . "=" . value . "`r`n"
                }
            }
            
            ; 确保目录存在
            SplitPath(settingsPath, , &configDir)
            if (!DirExist(configDir)) {
                DirCreate(configDir)
            }
            
            ; 写入文件
            file := FileOpen(settingsPath, "w", "UTF-8-RAW")
            file.Write(content)
            file.Close()
            
            return true
            
        } catch as e {
            ; MsgBox("写入配置时出错: " . e.Message)
            return false
        }
    }
    
    ; 检查并修复配置文件
    static EnsureConfigFile() {
        try {
            settingsPath := this.GetConfigPath()
            
            if (!FileExist(settingsPath)) {
                ; 创建默认配置文件
                 return this.ResetToDefault()
            }
            
            ; 检查文件内容是否正常
            content := ""
            try {
                content := FileRead(settingsPath, "UTF-8")
            } catch {
                try {
                    content := FileRead(settingsPath, "CP0")
                }
            }
            
            ; 检查是否是乱码（常见的中文乱码特征）
            if (this.IsCorruptedContent(content)) {
                ; 乱码，重新创建
                FileDelete(settingsPath)
                return this.ResetToDefault()
            }
            
            return true
            
        } catch {
            return false
        }
    }
    
    ; 创建默认配置文件
    static CreateDefaultConfig() {
        config := Map()
        
        ; 按照ConfigOrder顺序添加默认值
        for key in this.ConfigOrder {
            if (this.DefaultConfig.Has(key)) {
                ; 直接使用字符串值
                config[key] := this.DefaultConfig[key]
            }
        }
        
        return config
    }
    
    ; 检查内容是否乱码
    static IsCorruptedContent(content) {
        ; 检查常见的中文乱码模式
        patterns := ["锟斤拷", "艳码辣", "阁变", "禄剧码", "伴权惧琅", "歙"]
        
        for pattern in patterns {
            if (InStr(content, pattern)) {
                return true
            }
        }
        
        ; 检查是否包含基本的INI结构
        if (!InStr(content, "[") || !InStr(content, "]") || !InStr(content, "=")) {
            return true
        }
        
        return false
    }
    
    ; 获取所有配置键
    static GetAllKeys() {
        config := this.ReadAllConfig()
        keys := []
        
        for key, _ in config {
            keys.Push(key)
        }
        
        return keys
    }
    
    ; 检查配置是否存在
    static HasKey(key) {
        config := this.ReadAllConfig()
        return config.Has(key)
    }
    
    ; 删除配置项
    static DeleteKey(key) {
        try {
            config := this.ReadAllConfig()
            
            if (config.Has(key)) {
                config.Delete(key)
                return this.WriteConfig(config)
            }
            
            return true
            
        } catch {
            return false
        }
    }
}