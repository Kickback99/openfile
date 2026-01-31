#Include "../lib/py-master/lib/py.ahk"
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
        ; 应该是：E:\release\openfile\src
        
        ; configs目录就在当前目录下
        configsDir := scriptDir "\configs"

        ; 自动构建配置文件路径：configs\{configType}.ini
        if (configType = "") {
            configType := "openfile"  ; 默认使用openfile
        }

        this.configPath := configsDir "\" configType ".ini"
        this.configType := configType

        
        ; 检查配置文件是否存在
        /* if (!FileExist(this.configPath)) {
            MsgBox("❌ 配置文件不存在：`n" this.configPath)
            this.data := Map()
            this.fileList := []
            return
        } */

        ; 确保目录存在
        this.EnsureConfigDirectory(configsDir)
        
        ; 确保配置文件存在（如果不存在则创建空文件）
        this.EnsureConfigFileExists()
        
        ; 加载配置
        this.data := this.LoadConfig()
        this.fileList := this.GetFileList()
    }

    ; 确保配置目录存在
    EnsureConfigDirectory(configsDir) {
        if (!DirExist(configsDir)) {
            try {
                DirCreate(configsDir)
            } catch as e {
                MessageManager.ShowError("创建配置目录失败: " e.Message)
            }
        }
    }

    ; 确保配置文件存在
    EnsureConfigFileExists() {
        ; 如果文件不存在，创建空文件
        if (!FileExist(this.configPath)) {
            try {
                ; 创建一个基本的INI文件结构 - 使用字符串连接
                basicContent := "[Root]`r`n" 
                    . "name=root`r`n" 
                    . "path=" this.configPath "`r`n`r`n" 
                    . "; 在此处添加你的文件配置`r`n" 
                    . "; 示例：`r`n" 
                    . "; [FileName]`r`n" 
                    . "; name=文件显示名称`r`n" 
                    . "; path=C:\path\to\file.exe`r`n"
                
                FileAppend(basicContent, this.configPath,"UTF-8")
            } catch as e {
                MessageManager.ShowError("创建配置文件失败: " e.Message)
            }
        }
    }
    
    ; 加载配置文件（支持两种模式）
    ; t_openfile_settings：sortByAlphabet-get
    LoadConfig() {
        configData := Map()
        
        ; 读取排序配置
        ; 修改：使用当前configType作为section读取排序配置
        sortByAlphabet := SettingsManager.GetBool("SortByAlphabet", this.configType)
        
        if (sortByAlphabet) {
            ; v1模式：使用传统方式
            return this.LoadConfigBasic()
        } else {
            ; v2模式：使用顺序记录方式
            return this.LoadConfigWithOrder()
        }
    }
    
    ; 基础加载（不记录顺序）
    LoadConfigBasic() {
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

    ; 顺序记录加载（v2模式）
    LoadConfigWithOrder() {
        configData := Map()
        ; configData["_sectionsInOrder"] := []  ; 记录section顺序
        sectionOrder := []  ; 使用简化的变量名 记录section顺序
        
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
                     sectionOrder.Push(currentSection)  ; 记录顺序到简化变量
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
        ; 将顺序数组存入配置数据
        configData["_sectionsInOrder"] := sectionOrder
        return configData
    }
    
    ; V1模式：获取文件列表并按拼音智能排序
    GetFileListSortedByPinyin() {
        fileList := []
        
        ; 收集所有文件
        for section, sectionData in this.data {
            if (section = "Root") {
                continue
            }
            
            if (sectionData.Has("name") && sectionData.Has("path")) {
                fileList.Push(Map(
                    "name", sectionData["name"],
                    "path", sectionData["path"],
                    "section", section
                ))
            }
        }
        
        ; 如果文件数量大于1才需要排序
        if (fileList.Length > 1) {
            fileList := this.SimpleBubbleSort(fileList)
        }
        
        return fileList
    }
    
    ; 简化版冒泡排序
    SimpleBubbleSort(arr) {
        count := arr.Length
        
        Loop count {  ; 外层循环
            outer := A_Index
            Loop count - outer {  ; 内层循环
                current := A_Index
                next := current + 1
                
                ; 修正：Map访问应该使用中括号，不是点号
                name1 := arr[current]["name"]
                name2 := arr[next]["name"]
                
                if (this.CompareNames(name1, name2) > 0) {
                    ; 交换位置
                    temp := arr[current]
                    arr[current] := arr[next]
                    arr[next] := temp
                }
            }
        }
        
        return arr
    }
    
    ; 简化版名称比较函数
    CompareNames(name1, name2) {
        ; 转换为小写进行不区分大小写比较
        lower1 := StrLower(name1)
        lower2 := StrLower(name2)
        
        ; 尝试获取拼音首字母进行比较
        try {
            py1 := py.initials_muti(lower1)
            py2 := py.initials_muti(lower2)
            
            ; 比较拼音首字母
            result := StrCompare(py1, py2, "Locale")
            if (result != 0) {
                return result
            }
        }
        
        ; 拼音相同或拼音库失败，比较整个名称
        return StrCompare(lower1, lower2, "Locale")
    }

    ; V2模式：按文件顺序获取文件列表
    GetFileListByFileOrder() {
        fileList := []
        
        ; 按照文件中的顺序遍历sections
        if (this.data.Has("_sectionsInOrder")) {
            sectionOrder := this.data["_sectionsInOrder"]  ; 获取顺序数组
            for section in sectionOrder {
                ; 跳过Root项和顺序标记本身
                if (section = "Root") {
                    continue
                }
                
                sectionData := this.data[section]
                if (sectionData.Has("name") && sectionData.Has("path")) {
                    fileInfo := Map()
                    fileInfo["name"] := sectionData["name"]
                    fileInfo["path"] := sectionData["path"]
                    fileInfo["section"] := section
                    fileList.Push(fileInfo)
                }
            }
        }
        
        return fileList
    }
    
    ; 获取所有文件列表（根据配置选择排序方式）
    ; t_openfile_settings：sortByAlphabet-get
    GetFileList() {
        ; 检查是否启用了字母排序
        if (SettingsManager.GetBool("SortByAlphabet", this.configType)) {
            ; v1模式：使用拼音库进行智能排序
            return this.GetFileListSortedByPinyin()
        } else {
            ; v2模式：按文件顺序
            return this.GetFileListByFileOrder()
        }
    }
    
    ; 获取文件列表（供外部调用）
    GetFileListArray() {
        return this.fileList
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

    ; 获取所有可用的配置类型（排除当前类型）
    ;!!! 重构：兼容 v1 和 v2 调用的 GetAllConfigTypes 方法
    static GetAllConfigTypes(excludeType := "") {
        ; 参数说明：
        ; excludeType: 可选参数，要排除的配置类型名称
        ; 1. 如果没传参，获取所有类型
        ; 2. 如果传参了，排除指定类型
        
        ; 获取 configs 目录
        configManagerPath := A_LineFile
        SplitPath(configManagerPath, , &scriptDir)
        configsDir := scriptDir "\configs"
        
        ; 查找所有 .ini 文件
        configTypes := []

        ; 检查目录是否存在
        if (!DirExist(configsDir)) {
            return configTypes
        }

        Loop Files, configsDir "\*.ini" {
            ; 提取文件名（不含扩展名）
            SplitPath(A_LoopFileName, , , , &nameOnly)
            
            ;!!! 新逻辑：如果传了参数且匹配，则排除；否则都添加
            if (excludeType != "" && nameOnly = excludeType) {
                continue  ; 排除指定类型
            }
            
            configTypes.Push(nameOnly)
        }
        
        return configTypes
    }

    ; 新增：删除配置文件
    static DeleteConfigFile(configType) {
        try {
            ; 获取configs目录路径（复用现有逻辑）
            configManagerPath := A_LineFile
            SplitPath(configManagerPath, , &scriptDir)
            configsDir := scriptDir "\configs"
            
            ; 构建配置文件路径
            configPath := configsDir "\" configType ".ini"
            
            ; 检查文件是否存在
            if (FileExist(configPath)) {
                FileDelete(configPath)
                return true
            }
            return false
        } catch as e {
            throw Error("删除配置文件失败: " e.Message)
        }
    }

    ; 新增：获取configs目录路径
    static GetConfigsDir() {
        configManagerPath := A_LineFile
        SplitPath(configManagerPath, , &scriptDir)
        return scriptDir "\configs"
    }

    ; 新增：重命名配置文件
    static RenameConfigFile(oldConfigType, newConfigType) {
        try {
            ; 获取configs目录路径
            configManagerPath := A_LineFile
            SplitPath(configManagerPath, , &scriptDir)
            configsDir := scriptDir "\configs"
            
            ; 构建旧文件路径和新文件路径
            oldPath := configsDir "\" oldConfigType ".ini"
            newPath := configsDir "\" newConfigType ".ini"
            
            ; 检查旧文件是否存在
            if (!FileExist(oldPath)) {
                throw Error("原始配置文件不存在: " oldConfigType)
            }
            
            ; 检查新文件是否已存在
            if (FileExist(newPath)) {
                throw Error("目标配置文件已存在: " newConfigType)
            }
            
            ;!!! 读取原始文件（UTF-8编码）
            fileContent := FileRead(oldPath, "UTF-8")
            
            ;!!! 替换路径中的文件名部分
            ; 方法1：简单替换（处理大多数情况）
            oldFileName := oldConfigType ".ini"
            newFileName := newConfigType ".ini"
            updatedContent := StrReplace(fileContent, oldFileName, newFileName)
            
            ;!!! 方法2：如果简单替换没生效，使用正则表达式
            /* if (updatedContent = fileContent) {
                ; 匹配格式：path=[任意字符]oldConfigType.ini
                pattern := "path=.*\K\Q" . oldConfigType . "\E\.ini"
                updatedContent := RegExReplace(fileContent, pattern, newFileName)
            } */
            
            ; 再次检查是否真的需要替换
            /* if (updatedContent = fileContent) {
                ; 可能格式不同，尝试更通用的替换
                oldFullPath := configsDir "\" oldFileName
                newFullPath := configsDir "\" newFileName
                updatedContent := StrReplace(fileContent, oldFullPath, newFullPath)
            } */
            
            ;!!! 写入新文件（UTF-8编码）
            FileAppend(updatedContent, newPath, "UTF-8")
            
            ;!!! 删除旧文件（操作已完成，可以安全删除）
            FileDelete(oldPath)
            
            return true
            
        } catch as e {
            ; 错误处理
            try {
                if (FileExist(newPath)) {
                    FileDelete(newPath)
                }
            }
            throw Error("重命名配置文件失败: " e.Message)
        }
    }   
}