; ==============================
; SettingsManager.ahk
; Settings.ini配置文件管理器
; ==============================
class SettingsManager {
    ; 静态属性：配置文件路径
    static ConfigPath := A_ScriptDir "\settings.ini"
    
    ; ++++ 读取所有配置到Map中 ++++
    static ReadAllConfig() {
        config := Map()
        
        ; t_softmanager_settings：default
        ; 设置默认值
        config["AlwaysOnTop"] := true
        config["SortByAlphabet"] := false
        config["EnableExtension"] := false
        config["BatchThreshold"] := 5
        config["ShowSuccessMsg"] := true
        
        try {
            settingsPath := this.ConfigPath
            
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
                    if (line = "[General]") {
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
    
    ; ++++ 读取单个配置值 ++++
    static GetValue(key, defaultValue := "") {
        config := this.ReadAllConfig()
        return config.Get(key, defaultValue)
    }
    
    ; ++++ 读取布尔值配置 ++++
    static GetBool(key, defaultValue := false) {
        value := this.GetValue(key, defaultValue ? "true" : "false")
        value := StrLower(Trim(value))
        
        return (value = "true" || value = "1" || value = "yes" || value = "on")
    }
    
    ; ++++ 读取整数值配置 ++++
    static GetInt(key, defaultValue := 0) {
        value := this.GetValue(key, defaultValue)
        
        try {
            ; 提取数字部分
            if (RegExMatch(value, "(\d+)", &match)) {
                return Integer(match[1])
            }
        }
        
        try {
            return Integer(value)
        } catch {
            return defaultValue
        }
    }
    
    ; ++++ 写入配置值 ++++
    static SetValue(key, value) {
        try {
            settingsPath := this.ConfigPath
            
            ; 先读取现有配置
            config := this.ReadAllConfig()
            
            ; 更新值
            config[key] := value
            
            ; 重新写入文件
            return this.WriteConfig(config)
            
        } catch {
            return false
        }
    }
    
    ; ++++ 写入所有配置到文件 ++++
    static WriteConfig(config) {
        try {
            settingsPath := this.ConfigPath
            
            ; 构建文件内容
            content := "[General]`r`n"
            
            for key, value in config {
                content .= key . "=" . value . "`r`n"
            }
            
            content .= "`r`n"
            
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
    
    ; ++++ 检查并修复配置文件 ++++
    static EnsureConfigFile() {
        try {
            settingsPath := this.ConfigPath
            
            if (!FileExist(settingsPath)) {
                ; 创建默认配置文件
                return this.CreateDefaultConfig()
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
                return this.CreateDefaultConfig()
            }
            
            return true
            
        } catch {
            return false
        }
    }
    
    ; ++++ 创建默认配置文件 ++++
    static CreateDefaultConfig() {
        try {
            ; 默认配置
            defaultConfig := Map()
            defaultConfig["EnableExtension"] := "false"
            defaultConfig["BatchThreshold"] := "5"
            
            return this.WriteConfig(defaultConfig)
            
        } catch {
            return false
        }
    }
    
    ; ++++ 检查内容是否乱码 ++++
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
    
    ; ++++ 获取所有配置键 ++++
    static GetAllKeys() {
        config := this.ReadAllConfig()
        keys := []
        
        for key, _ in config {
            keys.Push(key)
        }
        
        return keys
    }
    
    ; ++++ 检查配置是否存在 ++++
    static HasKey(key) {
        config := this.ReadAllConfig()
        return config.Has(key)
    }
    
    ; ++++ 删除配置项 ++++
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