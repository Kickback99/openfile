; ==============================
; ConfigManager.ahk
; 支持动态配置文件的INI管理器
; ==============================
class ConfigManager {
__New(configType := "") {
    ; 使用 A_LineFile 获取ConfigManager.ahk的完整路径
    configManagerPath := A_LineFile  ; 这是ConfigManager.ahk的完整路径
    
    ; 从完整路径提取目录
    SplitPath(configManagerPath, , &scriptDir)
    
    ; 现在 scriptDir 是 ConfigManager.ahk 所在的目录
    ; 应该是：L:\AutoHotkey\projects\software\src
    
    /* MsgBox("调试信息：`n"
        . "ConfigManager.ahk路径: " configManagerPath "`n"
        . "ConfigManager目录: " scriptDir "`n"
        . "配置类型: " configType) */
    
    /*
        调试信息：
        ConfigManager.ahk路径l:AutoHotkey\projects\software\src\ConfigManager.ahk
        ConfigManagerl目录：l:\AutoHotkey\projects\software\src
        配置类型：software
    */
    
    ; configs目录就在当前目录下
    configsDir := scriptDir "\configs"
    
    /* MsgBox("configs目录: " configsDir "`n"
        . "目录是否存在: " (DirExist(configsDir) ? "是" : "否")) */
    ;configs:l:\AutoHotkey\projects\software\src\configs 目录是否存在：是
    
    ; 构建配置文件路径
    if (configType = "ai") {
        this.configPath := configsDir "\ai.ini"
        this.configType := "ai"
    } else if (configType = "software") {
        this.configPath := configsDir "\software.ini"
        this.configType := "software"
    } else {
        this.configPath := configsDir "\software.ini"
        this.configType := "software"
    }
    
   /*  MsgBox("配置文件路径: " this.configPath "`n"
        . "文件是否存在: " (FileExist(this.configPath) ? "是" : "否")) */
    ;配置文件路径：l\AutoHotkey\projects\software\src\configs\software.ini 文件是否存在：是
    
    ; 检查配置文件是否存在
    if (!FileExist(this.configPath)) {
        MsgBox("❌ 配置文件不存在：`n" this.configPath)
        this.data := Map()
        this.softwareList := []
        return
    }
    
    ; 加载配置
    this.data := this.LoadConfig()
    this.softwareList := this.GetSoftwareList()
}
    
    ; 加载配置文件
    LoadConfig() {
        configData := Map()
        currentSection := ""
        
        Loop Read, this.configPath
        {
            line := Trim(A_LoopReadLine)
            
            ; 跳过注释和空行
            if (line == "" || SubStr(line, 1, 1) == ";")
                continue
            
            ; 解析section
            if (SubStr(line, 1, 1) == "[") {
                endPos := InStr(line, "]")
                if (endPos > 1) {
                    currentSection := SubStr(line, 2, endPos - 2)
                    configData[currentSection] := Map()
                }
                continue
            }
            
            ; 解析key=value
            if (currentSection != "" && InStr(line, "=")) {
                eqPos := InStr(line, "=")
                key := Trim(SubStr(line, 1, eqPos - 1))
                value := Trim(SubStr(line, eqPos + 1))
                
                if (key != "") {
                    configData[currentSection][key] := value
                }
            }
        }
        
        return configData
    }
    
    ; 获取所有软件列表
    GetSoftwareList() {
        softwareList := []
        
        for section, sectionData in this.data {
            if (sectionData.Has("name") && sectionData.Has("path")) {
                softwareInfo := Map()
                softwareInfo["name"] := sectionData["name"]
                softwareInfo["path"] := sectionData["path"]
                softwareInfo["section"] := section
                softwareList.Push(softwareInfo)
            }
        }
        
        return softwareList
    }
    
    ; 获取软件列表（供外部调用）
    GetSoftwareListArray() {
        return this.softwareList
    }
    
    ; 获取配置类型
    GetConfigType() {
        return this.configType
    }
    
    ; 获取配置文件路径
    GetConfigPath() {
        return this.configPath
    }
}