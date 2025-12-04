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
    
    ; configs目录就在当前目录下
    configsDir := scriptDir "\configs"

    ; 自动构建配置文件路径：configs\{configType}.ini
    if (configType = "") {
        configType := "software"  ; 默认使用software
    }

    this.configPath := configsDir "\" configType ".ini"
    this.configType := configType

    
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

            ; 跳过Root项
            if (section = "Root") {
                continue
            }

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

    ; 获取Root路径
    GetRootPath() {
        if (this.data.Has("Root") && this.data["Root"].Has("path")) {
            return this.data["Root"]["path"]
        }
        return ""
    }   
}