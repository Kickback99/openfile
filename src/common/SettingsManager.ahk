; ==============================
; SettingsManager.ahk
; Settings.ini配置文件管理器
; ==============================
class SettingsManager {
    ; 静态属性：配置文件路径
    static ConfigPath := A_ScriptDir "\settings.ini"

    ; 配置段名称
    static SectionName := "General"

    ; 新增：配置管理相关常量
    static DEFAULT_CONFIG_TYPE := "openfile"
    static CONFIG_MANAGER_SECTION := "Global"
    static ACTIVE_CONFIG_KEY := "ActiveConfig"

    ;!!! 修改：Global配置键和默认值Map
    static GlobalConfigKeys := Map(
        this.ACTIVE_CONFIG_KEY, this.DEFAULT_CONFIG_TYPE,
        "MainHotkey", "#q",
        "TypeHotkey", "!c",
        "Link", "https://github.com/Kickback99/openfile"
        ; 未来扩展示例:
        ; "DebugMode", "false",
        ; "AutoStart", "true"
    )

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
        ;!!! 修改：Global节使用GlobalConfigKeys的默认值
        if (sectionName = this.CONFIG_MANAGER_SECTION) {
            ; 返回GlobalConfigKeys的副本作为默认配置
            globalDefaults := Map()
            for key, defaultValue in this.GlobalConfigKeys {
                globalDefaults[key] := defaultValue
            }
            return globalDefaults
        }
        
        if (this.DefaultConfig.Has(sectionName)) {
            return this.DefaultConfig[sectionName]
        } else {
            return this.DefaultConfig["Default"]
        }
    }

    ; 重构：检查数组是否包含某个值
    static HasValue(arr, value) {
        for item in arr {
            if (item = value) {
                return true
            }
        }
        return false
    }

    ; 新增：创建默认settings.ini文件
    static CreateDefaultSettingsFile() {
        try {
            settingsPath := this.ConfigPath
            SplitPath(settingsPath, , &configDir)
            
            if (!DirExist(configDir)) {
                DirCreate(configDir)
            }
            
            ; 获取所有配置类型
            configTypes := ConfigManager.GetAllConfigTypes()
            
            ;!!! 修改：直接使用GlobalConfigKeys构建内容
            ; 构建文件内容
            content := "[" . this.CONFIG_MANAGER_SECTION . "]`r`n"
            
            ; 写入所有Global配置键
            for key, defaultValue in this.GlobalConfigKeys {
                ; 特殊处理ActiveConfig
                if (key = this.ACTIVE_CONFIG_KEY) {
                    content .= key . "=" . (configTypes.Length > 0 ? configTypes[1] : defaultValue) . "`r`n"
                } else {
                    content .= key . "=" . defaultValue . "`r`n"
                }
            }
            content .= "`r`n"
            
            ; 为每个配置类型添加默认配置
            if (configTypes.Length = 0) {
                configTypes := [this.DEFAULT_CONFIG_TYPE]
            }
            
            for configType in configTypes {
                ; 使用现有DefaultConfig作为模板
                defaultConfig := this.DefaultConfig["Default"].Clone()
                content .= "[" . configType . "]`r`n"
                
                ; 写入所有配置键
                for key in this.ConfigOrder {
                    if (defaultConfig.Has(key)) {
                        content .= key . "=" . defaultConfig[key] . "`r`n"
                    }
                }
                
                content .= "`r`n"
            }
            
            ; 写入文件
            file := FileOpen(settingsPath, "w", "UTF-8-RAW")
            file.Write(content)
            file.Close()
            return true
            
        } catch {
            return false
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
    ; 修改：WriteAllConfig 方法也需要支持动态类型
    ; 重构：WriteAllConfig方法（简化版，避免递归）
    static WriteAllConfig(allConfig) {
        try {
            settingsPath := this.ConfigPath
            
            ; 构建文件内容
            content := ""
            
            ; 1. 首先写入Global section（放在最顶部）
            if (allConfig.Has(this.CONFIG_MANAGER_SECTION)) {
                configManagerSection := allConfig[this.CONFIG_MANAGER_SECTION]
                content .= "[" . this.CONFIG_MANAGER_SECTION . "]`r`n"
                
                ; 确保Global节包含所有必要的键
                for key, defaultValue in this.GlobalConfigKeys {
                    if (configManagerSection.Has(key)) {
                        value := configManagerSection[key]
                    } else {
                        value := defaultValue
                    }
                    content .= key . "=" . value . "`r`n"
                }
                content .= "`r`n"
            }
            
            ; 2. 写入其他section
            ; 获取所有配置类型
            configTypes := ConfigManager.GetAllConfigTypes()
            
            ; 先写入支持的配置类型
            for configType in configTypes {
                if (allConfig.Has(configType) && configType != this.CONFIG_MANAGER_SECTION) {
                    content .= this.FormatSection(configType, allConfig[configType])
                }
            }
            
            ; 写入其他section
            otherSections := []
            for sectionName, config in allConfig {
                if (sectionName != this.CONFIG_MANAGER_SECTION && 
                    !this.HasValue(configTypes, sectionName) && 
                    !InStr(sectionName, ";")) {
                    otherSections.Push(sectionName)
                }
            }
            
            if (otherSections.Length > 0) {
                Sort(otherSections)
                for sectionName in otherSections {
                    content .= this.FormatSection(sectionName, allConfig[sectionName])
                }
            }
            
            content := Trim(content, "`r`n") . "`r`n"
            
            ; 写入文件
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
    ; 修改：IsSupportedType 方法也要支持动态类型
    static IsSupportedType(sectionName) {
        configTypes := ConfigManager.GetAllConfigTypes()
        return this.HasValue(configTypes, sectionName)
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

    static EnsureConfigManagerSection() {
        try {
            settingsPath := this.ConfigPath
            
            ; 如果文件不存在，调用 CreateDefaultSettingsFile
            if (!FileExist(settingsPath)) {
                return this.CreateDefaultSettingsFile()
            }
            
            ; 快速检查文件是否包含 Global
            file := FileOpen(settingsPath, "r", "UTF-8-RAW")
            hasConfigManager := false
            
            Loop 10 {
                if (file.AtEOF) {
                    break
                }
                line := Trim(file.ReadLine())
                if (line = "[" . this.CONFIG_MANAGER_SECTION . "]") {
                    hasConfigManager := true
                    break
                }
            }
            file.Close()
            
            ; 如果已经包含 ConfigManager，直接返回
            if (hasConfigManager) {
                return true
            }
            
            ; 文件存在但不包含 ConfigManager，读取整个文件
            content := FileRead(settingsPath, "UTF-8")
            if (content = "") {
                content := FileRead(settingsPath, "CP0")
            }
            
            ; 获取配置类型
            existingTypes := []
            try {
                existingTypes := ConfigManager.GetAllConfigTypes()
            } catch {
                ; 忽略错误
            }
            
            ; 在前面添加 Global section
            newContent := "[" . this.CONFIG_MANAGER_SECTION . "]`r`n"
            
            ; 写入所有Global配置键
            for key, defaultValue in this.GlobalConfigKeys {
                if (key = this.ACTIVE_CONFIG_KEY) {
                    ; 特殊处理ActiveConfig
                    activeConfig := existingTypes.Length > 0 ? existingTypes[1] : defaultValue
                    newContent .= key . "=" . activeConfig . "`r`n"
                } else {
                    newContent .= key . "=" . defaultValue . "`r`n"
                }
            }
            newContent .= "`r`n"
            newContent .= content
            
            ; 写入文件
            SplitPath(settingsPath, , &configDir)
            if (!DirExist(configDir)) {
                DirCreate(configDir)
            }
            
            file := FileOpen(settingsPath, "w", "UTF-8-RAW")
            file.Write(newContent)
            file.Close()
            return true
            
        } catch {
            return false
        }
    }

    
    ; 检查并修复配置文件
    ; 重构：EnsureConfigFile方法（简化版，避免递归）
    static EnsureConfigFile() {
        try {
            ; 1. 首先确保 Global section 存在
            if (!this.EnsureConfigManagerSection()) {
                return false
            }
            
            ; 2. 获取实际存在的配置类型
            existingTypes := []
            try {
                existingTypes := ConfigManager.GetAllConfigTypes()
            } catch {
                ; 如果获取失败，直接返回
                return true
            }
            
            ; 3. 使用现有方法读取配置
            allConfig := this.ReadAllConfig()
            shouldWrite := false
            
            ; 4. 清理无效的配置段
            sectionsToRemove := []
            for sectionName, config in allConfig {
                ; 跳过 Global 和注释
                if (sectionName = this.CONFIG_MANAGER_SECTION || 
                    sectionName = "" || InStr(sectionName, ";")) {
                    continue
                }
                
                ; 如果配置类型不存在于实际配置文件中，标记为需要删除
                if (!this.HasValue(existingTypes, sectionName)) {
                    sectionsToRemove.Push(sectionName)
                }
            }
            
            ; 执行清理
            for sectionName in sectionsToRemove {
                allConfig.Delete(sectionName)
                shouldWrite := true
            }
            
            ; 5. 添加缺失的配置段
            for configType in existingTypes {
                if (!allConfig.Has(configType)) {
                    allConfig[configType] := this.GetDefaultForSection(configType)
                    shouldWrite := true
                }
            }
            
            ; 6. 验证并修复Global节配置
            if (allConfig.Has(this.CONFIG_MANAGER_SECTION)) {
                configManagerSection := allConfig[this.CONFIG_MANAGER_SECTION]
                
                ; 确保所有Global配置键都存在且有效
                for key, defaultValue in this.GlobalConfigKeys {
                    if (!configManagerSection.Has(key)) {
                        configManagerSection[key] := defaultValue
                        shouldWrite := true
                    } else if (key = this.ACTIVE_CONFIG_KEY) {
                        ; 特殊验证ActiveConfig
                        currentActiveConfig := configManagerSection[key]
                        if (currentActiveConfig = "" || !this.HasValue(existingTypes, currentActiveConfig)) {
                            configManagerSection[key] := existingTypes.Length > 0 ? existingTypes[1] : defaultValue
                            shouldWrite := true
                        }
                    }
                }
            }
            
            ; 7. 如果有修改，写入配置
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

    ; 新增：重命名配置段
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