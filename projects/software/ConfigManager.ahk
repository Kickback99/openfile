; ==============================
; ConfigManager.ahk
; INI配置文件管理器
; ==============================
class ConfigManager {
    __New(configPath := "") {
        ; 如果没有指定路径，使用默认路径
        if (configPath == "") {
            ; 获取当前脚本所在目录
            scriptDir := A_ScriptDir
            this.configPath := scriptDir "\config.ini"
        } else {
            this.configPath := configPath
        }
        
        ; 加载配置
        this.data := this.LoadConfig()
        this.softwareList := this.GetSoftwareList()
    }
    
    ; 加载配置文件
    LoadConfig() {
        if !FileExist(this.configPath) {
            MsgBox("配置文件不存在: " this.configPath)
            return Map()
        }
        
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
    
    ; 根据名称获取软件信息
    GetSoftwareByName(softwareName) {
        for software in this.softwareList {
            if (software["name"] == softwareName) {
                return software
            }
        }
        return Map() ; 返回空Map表示未找到
    }
    
    ; 根据section获取软件信息
    GetSoftwareBySection(sectionName) {
        if (this.data.Has(sectionName)) {
            sectionData := this.data[sectionName]
            if (sectionData.Has("name") && sectionData.Has("path")) {
                return Map(
                    "name", sectionData["name"],
                    "path", sectionData["path"],
                    "section", sectionName
                )
            }
        }
        return Map()
    }
}