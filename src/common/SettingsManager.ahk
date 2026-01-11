; ==============================
; SettingsManager.ahk
; Settings.ini配置文件管理器
; ==============================
class SettingsManager {
    ; 静态属性：配置文件路径
    static ConfigPath := A_ScriptDir "\settings.ini"

    ; 配置段名称
    static SectionName := "General"

    ; 配置键的顺序（保持原有顺序）
    static ConfigOrder := ["AlwaysOnTop", "SortByAlphabet", "EnableExtension", "BatchThreshold", "ShowSuccessMsg"]

    ; t_openfile_settings：default
    ; 修改：添加默认section
    static DefaultConfig := Map(
        "Default", Map(  ; 默认section
            "AlwaysOnTop", "true",      ; 字符串
            "SortByAlphabet", "false",  ; 字符串
            "EnableExtension", "false", ; 字符串
            "BatchThreshold", "5",      ; 字符串
            "ShowSuccessMsg", "true"    ; 字符串
        )
    )

    ; 新增：获取指定section的默认配置
    static GetDefaultForSection(sectionName) {
        if (this.DefaultConfig.Has(sectionName)) {
            return this.DefaultConfig[sectionName]
        } else {
            return this.DefaultConfig["Default"]
        }
    }

    ; 读取指定section的配置到Map中
    static ReadSectionConfig(sectionName) {
        ; 先获取默认配置
        defaultConfig := this.GetDefaultForSection(sectionName)
        config := Map()
        
        ; 复制默认配置
        for key, value in defaultConfig {
            config[key] := value
        }
        
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
            inTargetSection := false
            
            for line in lines {
                line := Trim(line)
                
                ; 跳过注释和空行
                if (line = "" || SubStr(line, 1, 1) = ";") {
                    continue
                }
                
                ; 检查是否是段
                if (SubStr(line, 1, 1) = "[") {
                    ; 检查是否是目标section
                    if (line = "[" . sectionName . "]") {
                        inTargetSection := true
                    } else {
                        inTargetSection := false
                    }
                    continue
                }
                
                ; 如果在目标段中，解析配置
                if (inTargetSection && InStr(line, "=")) {
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

    ; 写入指定section的配置
    static WriteSectionConfig(sectionName, config) {
        try {
            settingsPath := this.ConfigPath
            
            ; 读取现有所有配置
            allConfig := this.ReadAllConfig()
            
            ; 更新指定section的配置
            allConfig[sectionName] := config
            
            ; 重新写入整个文件
            return this.WriteAllConfig(allConfig)
            
        } catch as e {
            ; MsgBox("写入配置时出错: " . e.Message)
            return false
        }
    }
    
    ; 读取整个配置文件的所有section
    static ReadAllConfig() {
        allConfig := Map()
        
        try {
            settingsPath := this.ConfigPath
            
            if (!FileExist(settingsPath)) {
                ; 文件不存在，返回空的Map
                return allConfig
            }
            
            ; 读取文件内容
            content := FileRead(settingsPath, "UTF-8")
            if (content = "") {
                content := FileRead(settingsPath, "CP0")
            }
            
            ; 解析内容
            lines := StrSplit(content, "`n", "`r")
            currentSection := ""
            
            for line in lines {
                line := Trim(line)
                
                ; 跳过注释和空行
                if (line = "" || SubStr(line, 1, 1) = ";") {
                    continue
                }
                
                ; 检查是否是section
                if (SubStr(line, 1, 1) = "[") {
                    endPos := InStr(line, "]")
                    if (endPos > 1) {
                        currentSection := SubStr(line, 2, endPos - 2)
                        if (!allConfig.Has(currentSection)) {
                            allConfig[currentSection] := Map()
                        }
                    }
                    continue
                }
                
                ; 解析key=value
                if (currentSection != "" && InStr(line, "=")) {
                    eqPos := InStr(line, "=")
                    key := Trim(SubStr(line, 1, eqPos - 1))
                    value := Trim(SubStr(line, eqPos + 1))
                    
                    ; 移除行末注释
                    if (InStr(value, ";")) {
                        parts := StrSplit(value, ";")
                        value := Trim(parts[1])
                    }
                    
                    ; 存储配置
                    allConfig[currentSection][key] := value
                }
            }
            
        } catch as e {
            ; 出错时返回空的Map
        }
        
        return allConfig
    }

    ; 重置指定section到默认值
    static ResetSectionToDefault(sectionName) {
        try {
            ; 获取默认配置
            defaultConfig := this.GetDefaultForSection(sectionName)
            
            ; 读取现有配置
            config := this.ReadSectionConfig(sectionName)
            
            ; 用默认值替换所有配置项
            for key, defaultValue in defaultConfig {
                config[key] := defaultValue
            }
            
            ; 写入配置
            return this.WriteSectionConfig(sectionName, config)
            
        } catch {
            return false
        }
    }
    
    ; 读取单个配置值
    static GetValue(key, sectionName := "Default") {
        config := this.ReadSectionConfig(sectionName)
    
        ; 如果配置中有这个键，返回它的值
        if (config.Has(key) && config[key] != "") {
            return config[key]
        }
    
        ; 否则返回DefaultConfig中的默认值
        defaultConfig := this.GetDefaultForSection(sectionName)
        return defaultConfig.Get(key, "")
    }
    
    ; 读取布尔值配置
    static GetBool(key, sectionName := "Default") {
        value := this.GetValue(key, sectionName)
        value := StrLower(Trim(value))
    
        return (value = "true" || value = "1" || value = "yes" || value = "on")
    }
    
    ; 读取整数值配置
    static GetInt(key, sectionName := "Default") {
        value := this.GetValue(key, sectionName)

        ; 如果获取的值为空，尝试从DefaultConfig获取默认值
        if (value = "") {
            defaultConfig := this.GetDefaultForSection(sectionName)
            value := defaultConfig.Get(key, "0")
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
    static SetValue(key, value, sectionName := "Default") {
        try {
            ; 先读取该section的现有配置
            config := this.ReadSectionConfig(sectionName)
            
            ; 更新值
            config[key] := String(value)
            
            ; 重新写入该section
            return this.WriteSectionConfig(sectionName, config)
            
        } catch {
            return false
        }
    }

    ; 重要：按照入口数组顺序写入配置文件
    ;!!! 修改：WriteAllConfig 方法也需要支持动态类型
    static WriteAllConfig(allConfig) {
        try {
            settingsPath := this.ConfigPath
            
            ; 构建文件内容
            content := ""
            
            ;!!! 修改：动态获取配置类型顺序
            configTypes := WindowConstants.GetConfigTypesWithFallback()
            
            ; 1. 按照动态获取的配置类型顺序写入section
            for configType in configTypes {
                if (allConfig.Has(configType)) {
                    content .= this.FormatSection(configType, allConfig[configType])
                }
            }
            
            ; 2. 写入其他不在数组中的section（保持兼容性）
            otherSections := []
            for sectionName, config in allConfig {
                ; 跳过已经在configTypes中的
                isInConfigTypes := false
                for configType in configTypes {
                    if (configType = sectionName) {
                        isInConfigTypes := true
                        break
                    }
                }
                
                if (!isInConfigTypes && !InStr(sectionName, ";")) {
                    otherSections.Push(sectionName)
                }
            }
            
            if (otherSections.Length > 0) {
                Sort(otherSections)  ; 按字母排序
                for sectionName in otherSections {
                    content .= this.FormatSection(sectionName, allConfig[sectionName])
                }
            }

            content := Trim(content, "`r`n") . "`r`n"  ; 移除末尾多余的空行
            
            ; 确保目录存在并写入文件
            SplitPath(settingsPath, , &configDir)
            if (!DirExist(configDir)) {
                DirCreate(configDir)
            }
            
            file := FileOpen(settingsPath, "w", "UTF-8-RAW")
            file.Write(content)
            file.Close()
            
            return true
            
        } catch {
            return false
        }
    }
    
    ; 检查是否是支持的配置类型
    ;!!! 修改：IsSupportedType 方法也要支持动态类型
    static IsSupportedType(sectionName) {
        configTypes := WindowConstants.GetConfigTypesWithFallback()
        return WindowConstants.HasValue(configTypes, sectionName)
    }
    
    ; 格式化section内容
    static FormatSection(sectionName, config) {
        content := "[" . sectionName . "]`r`n"
        
        for key in this.ConfigOrder {
            if (config.Has(key)) {
                value := config[key]
                
                if (Type(value) != "String") {
                    value := String(value)
                }
                
                content .= key . "=" . value . "`r`n"
            }
        }
        
        content .= "`r`n"
        return content
    }

    
    ; 检查并修复配置文件
    static EnsureConfigFile() {
        try {
            settingsPath := this.ConfigPath
            
            if (!FileExist(settingsPath)) {
                ; 创建默认配置文件
                return this.WriteAllConfig(this.DefaultConfig)
            }


            ;!!! 重构：使用WindowConstants获取支持的配置类型
            supportedTypes := WindowConstants.GetConfigTypesWithFallback()

            ;!!! 修改：动态获取支持的配置类型
            ; 注意：这里不能直接调用ConfigManager，需要特殊处理
            ; 先读取现有配置文件
            allConfig := this.ReadAllConfig()
            shouldWrite := false
            
            ; 检查现有配置文件中的每个section
            sectionsToRemove := []
            for sectionName, _ in allConfig {
                ; 跳过注释和空行
                if (sectionName = "" || InStr(sectionName, ";")) {
                    continue
                }
                
                isSupported := WindowConstants.HasValue(supportedTypes, sectionName)
                
                ; 如果不是支持的配置类型且不是注释段，标记为需要删除
                if (!isSupported && !InStr(sectionName, ";")) {
                    sectionsToRemove.Push(sectionName)
                }
            }
            
            ; 删除无效的配置段
            for sectionName in sectionsToRemove {
                allConfig.Delete(sectionName)
                shouldWrite := true
            }
            
            ; 确保所有支持的配置类型都有对应的section
            for configType in supportedTypes {
                if (!allConfig.Has(configType)) {
                    ; 创建默认配置
                    allConfig[configType] := this.GetDefaultForSection(configType)
                    shouldWrite := true
                }
            }
            
            ; 如果修改了配置，重新写入配置文件
            if (shouldWrite) {
                return this.WriteAllConfig(allConfig)
            }
            
            return true
            
        } catch {
            return false
        }
    }

    ; 获取指定section的所有配置键
    static GetAllKeys(sectionName) {
        config := this.ReadSectionConfig(sectionName)
        keys := []
        
        for key, _ in config {
            keys.Push(key)
        }
        
        return keys
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

    ; 检查配置是否存在
    static HasKey(key, sectionName) {
        config := this.ReadSectionConfig(sectionName)
        return config.Has(key)
    }
    
    ; 删除配置项
    static DeleteKey(key, sectionName) {
        try {
            config := this.ReadSectionConfig(sectionName)
            
            if (config.Has(key)) {
                config.Delete(key)
                return this.WriteSectionConfig(sectionName, config)
            }
            
            return true
            
        } catch {
            return false
        }
    }

    ;!!! 新增：重命名配置段
    static RenameConfigSection(oldSectionName, newSectionName) {
        try {
            settingsPath := this.ConfigPath
            
            ; 读取现有所有配置
            allConfig := this.ReadAllConfig()
            
            ; 检查旧配置段是否存在
            if (!allConfig.Has(oldSectionName)) {
                throw Error("原始配置段不存在: " oldSectionName)
            }
            
            ; 检查新配置段是否已存在
            if (allConfig.Has(newSectionName)) {
                throw Error("目标配置段已存在: " newSectionName)
            }
            
            ; 移动配置数据
            allConfig[newSectionName] := allConfig[oldSectionName]
            allConfig.Delete(oldSectionName)
            
            ; 重新写入整个文件
            return this.WriteAllConfig(allConfig)
            
        } catch as e {
            throw Error("重命名配置段失败: " e.Message)
        }
    }
}