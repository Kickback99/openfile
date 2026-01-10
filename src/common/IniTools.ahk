; ==============================
; IniTools.ahk
; INI文件处理工具类
; ==============================
class IniTools {
    ; 静态方法：连接数组
    static StrJoin(arr, delimiter) {
        result := ""
        for i, item in arr {
            if (i > 1) {
                result .= delimiter
            }
            result .= item
        }
        return result
    }

    ; ==================== 更新INI文件 ====================

    static UpdateIniFileWithRoot(guiManager, name, path, section, editMode) {
        try {
            ; 读取现有INI内容
            iniContent := ""
            if (FileExist(guiManager.configPath)) {
                iniContent := FileRead(guiManager.configPath)
            }
            
            ; 检查是否是Root section
            isRootSection := (StrLower(section) = "root")
            
            if (isRootSection) {
                ; >>> 处理Root section
                ; 检查是否已有Root section（不区分大小写）
                hasExistingRoot := false
                existingRootSectionName := ""
                
                ; 解析现有内容，查找Root section（不区分大小写）
                currentSection := ""
                Loop Parse, iniContent, "`n", "`r" {
                    line := Trim(A_LoopField)
                    
                    if (SubStr(line, 1, 1) = "[") {
                        currentSection := SubStr(line, 2, InStr(line, "]") - 2)
                        if (StrLower(currentSection) = "root") {
                            hasExistingRoot := true
                            existingRootSectionName := currentSection  ; 保留原始大小写
                            break
                        }
                    }
                }
                
                ; 构建Root section内容
                rootContent := ""
                if (editMode = "create" || editMode = "edit") {
                    ; >>> 使用用户输入的大小写
                    rootContent := "[" section . "]`r`n"
                    ; >>> name使用与section相同的大小写
                    rootContent .= "name=" section . "`r`n"
                    rootContent .= "path=" path . "`r`n"
                }
                
                if (hasExistingRoot) {
                    ; 已有Root，替换它
                    ; 构建正则表达式匹配Root section（不区分大小写）
                    ; 使用原始的大小写来匹配
                    rootPattern := "\[" existingRootSectionName "\][\s\S]*?(?=\n\[|$)"
                    if (RegExMatch(iniContent, rootPattern, &match)) {
                        iniContent := StrReplace(iniContent, match[0], rootContent)
                    } else {
                        ; 如果正则匹配失败，在文件顶部添加
                        iniContent := rootContent . "`r`n" . iniContent
                    }
                } else {
                    ; 没有Root，添加到文件顶部
                    iniContent := rootContent . (iniContent != "" ? "`r`n" : "") . iniContent
                }
                
            } else {
                ; >>> 处理普通section
                ; >>> 检查section是否已存在（区分大小写）
                sectionExists := false
                existingSectionName := ""
                currentSection := ""
                Loop Parse, iniContent, "`n", "`r" {
                    line := Trim(A_LoopField)
                    
                    if (SubStr(line, 1, 1) = "[") {
                        currentSection := SubStr(line, 2, InStr(line, "]") - 2)
                        if (currentSection = section) {
                            sectionExists := true
                            existingSectionName := currentSection
                            break
                        }
                    }
                }
                
                if (editMode = "create") {
                    if (sectionExists) {
                        ; section已存在，编辑模式处理
                        oldSectionPattern := "\[" existingSectionName "\][\s\S]*?(?=\n\[|$)"
                        if (RegExMatch(iniContent, oldSectionPattern, &match)) {
                            ; 构建新的section内容
                            newSectionContent := "[" section . "]`r`n"
                            newSectionContent .= "name=" name . "`r`n"
                            newSectionContent .= "path=" path . "`r`n"
                            
                            iniContent := StrReplace(iniContent, match[0], newSectionContent)
                        } else {
                            ; 如果没找到，追加到文件末尾
                            iniContent := RTrim(iniContent, "`r`n")
                            if (iniContent != "") {
                                iniContent .= "`r`n`r`n"
                            }
                            
                            iniContent .= "[" section . "]`r`n"
                            iniContent .= "name=" name . "`r`n"
                            iniContent .= "path=" path . "`r`n"
                        }
                    } else {
                        ; 创建模式：追加到文件末尾
                        ; 确保末尾有空行
                        iniContent := RTrim(iniContent, "`r`n")
                        if (iniContent != "") {
                            iniContent .= "`r`n`r`n"
                        }
                        
                        iniContent .= "[" section . "]`r`n"
                        iniContent .= "name=" name . "`r`n"
                        iniContent .= "path=" path . "`r`n"
                    }
                    
                } else if (editMode = "edit") {
                    ; 编辑模式：替换现有section
                    ; 查找并替换原来的section
                    oldSectionPattern := "\[" guiManager.currentEditSection "\][\s\S]*?(?=\n\[|$)"
                    if (RegExMatch(iniContent, oldSectionPattern, &match)) {
                        ; 构建新的section内容
                        newSectionContent := "[" section . "]`r`n"
                        newSectionContent .= "name=" name . "`r`n"
                        newSectionContent .= "path=" path . "`r`n"
                        
                        iniContent := StrReplace(iniContent, match[0], newSectionContent)
                    } else {
                        ; 如果没找到，当作创建处理
                        iniContent := RTrim(iniContent, "`r`n")
                        if (iniContent != "") {
                            iniContent .= "`r`n`r`n"
                        }
                        
                        iniContent .= "[" section . "]`r`n"
                        iniContent .= "name=" name . "`r`n"
                        iniContent .= "path=" path . "`r`n"
                    }
                }
            }
            
            ; 清理多余的空行
            iniContent := RegExReplace(iniContent, "(`r`n){3,}", "`r`n`r`n")
            iniContent := RTrim(iniContent, "`r`n")
            
            ; 写入文件
            FileDelete(guiManager.configPath)
            FileAppend(iniContent, guiManager.configPath, "UTF-8")
            
            ; 格式化文件
            this.FormatAndSaveIniFile(guiManager.configPath)
            
            return true
        } catch as e{
            MessageManager.ShowError("保存配置文件时出错：`n" e.Message)
            return false
        }
    }
    
    ; 从INI文件中删除section
    static DeleteFromIniFile(guiManager, sectionName) {
        try {
            ; 读取整个INI文件
            content := FileRead(guiManager.configPath)
            
            ; 构建正则表达式匹配要删除的section
            pattern := "\[" sectionName "\][\s\S]*?(?=\n\[|$)"
            if (RegExMatch(content, pattern, &match)) {
                ; 删除该section
                content := StrReplace(content, match[0] "`r`n", "")
                content := StrReplace(content, match[0], "")
                
                ; 写回文件
                FileDelete(guiManager.configPath)
                FileAppend(content, guiManager.configPath, "UTF-8")

                ; 格式化文件
                this.FormatAndSaveIniFile(guiManager.configPath)
                
                return true
            } else {
                MessageManager.ShowError("在配置文件中未找到对应的section")
                return false
            }
        } catch as e {
            MessageManager.ShowError("删除配置文件时出错：`n" e.Message)
            return false
        }
    }

    ; 删除INI文件中的注释（以;开头的行）
    static RemoveCommentsFromIniFile(filePath) {
        try {
            if (!FileExist(filePath)) {
                return false
            }
            
            ; 读取文件内容
            content := FileRead(filePath)
            if (content = "") {
                return true
            }
            
            ; 分割为行
            lines := StrSplit(content, "`n", "`r")
            
            ; 构建新内容（不含注释行）
            newContent := ""
            for line in lines {
                trimmedLine := Trim(line)
                ; 跳过以分号开头的注释行
                if (SubStr(trimmedLine, 1, 1) != ";") {
                    newContent .= line "`n"
                }
            }
            
            ; 写入文件
            FileDelete(filePath)
            FileAppend(newContent, filePath, "UTF-8")
            
            return true
        } catch as e {
            ; 静默失败，返回false
            return false
        }
    }

    ; 静态方法：格式化INI文件内容
    static FormatIniContent(iniContent) {
        ; 如果内容为空，直接返回
        if (iniContent = "") {
            return iniContent
        }
        
        ; 按行分割
        lines := StrSplit(iniContent, "`n", "`r")
        formattedLines := []
        
        for i, line in lines {
            trimmedLine := Trim(line)
            
            ; 如果是section行 ([xxx])
            if (SubStr(trimmedLine, 1, 1) = "[") {
                ; 检查前一行是否为空行
                if (i > 1 && Trim(lines[i - 1]) != "") {
                    ; 前一行不为空，添加一个空行
                    formattedLines.Push("")
                }
            }
            
            formattedLines.Push(line)
        }
        
        ; 重新组合并确保以换行符结尾
        formattedContent := this.StrJoin(formattedLines, "`r`n")
        
        ; 清理连续的空行（最多保留一个）
        formattedContent := RegExReplace(formattedContent, "(`r`n){3,}", "`r`n`r`n")
        
        ; 确保以换行符结尾
        formattedContent := RTrim(formattedContent, "`r`n") . "`r`n"
        
        return formattedContent
    }
    
    ; 静态方法：格式化并保存INI文件
    static FormatAndSaveIniFile(configPath) {

        ; 格式化之前先删除注释
        this.RemoveCommentsFromIniFile(configPath)

        try {
            ; 读取当前INI文件内容
            content := FileRead(configPath)
            
            ; 格式化内容
            formattedContent := this.FormatIniContent(content)
            
            ; 写回文件
            FileDelete(configPath)
            FileAppend(formattedContent, configPath, "UTF-8")
            
            return true
        } catch as e {
            ; 格式化失败不影响主要功能
            return false
        }
    }
    
    ; +++ 新增函数：文件名校验
    static ValidateFileName(filePath, expectedConfigType) {
        SplitPath(filePath, , , , &fileNameNoExt)
        ; >>> 严格检查：文件名必须完全等于当前configType
        if (fileNameNoExt != expectedConfigType) {
            MessageManager.ShowError(
                "请选择 " expectedConfigType ".txt 文件进行操作！`n`n"
                        . "当前选择的是: " fileNameNoExt ".txt`n"
                        . "当前配置类型是: " expectedConfigType, "文件不匹配"
            )
            return false
        }
        return true
    }

    ; >>> 新增：智能校验TXT文件内容格式
    static ValidateTxtContent(content, skipFirstPairCheck := false, skipMsgBox := false) {
        ; 分割成行并过滤空行
        lines := StrSplit(content, "`n", "`r")
        nonEmptyLines := []
        
        for line in lines {
            if (Trim(line) != "") {
                nonEmptyLines.Push(Trim(line))
            }
        }
        
        ; 检查是否有内容
        if (nonEmptyLines.Length = 0) {
            if (!skipMsgBox && !skipFirstPairCheck) {
                MessageManager.ShowError("文件内容为空，请检查文件！", "格式错误")
            }
            return false
        }
        
        ; 如果skipFirstPairCheck为true，则跳过行数奇偶性检查
        if (!skipFirstPairCheck && Mod(nonEmptyLines.Length, 2) != 0) {
            if (!skipMsgBox) {
                MessageManager.ShowError(
                  "文件格式不正确！`n`n"
                    . "有效内容行数应为偶数（名称+路径成对出现）", "格式错误"  
                )
            }
            return false
        }
        
        ; 逐对检查：奇数行（名称）+ 偶数行（路径）
        for i, line in nonEmptyLines {
            if (!skipFirstPairCheck) {
                if (Mod(i, 2) = 1) {  ; 奇数行：第1、3、5...行（i=1,3,5...）
                    ; 检查是否是合法的文件名
                    if (RegExMatch(line, '[\\/:*?"<>|]')) {
                        if (!skipMsgBox) {
                            MessageManager.ShowError(
                                "第 " i " 行包含非法字符：`n`n" line "`n`n"
                                . "文件名不能包含：\ / : * ? " . Chr(34) . " < > |", "格式错误"
                            )
                        }
                        return false
                    }
                    
                    ; 不能以点开头或结尾
                    if (SubStr(line, 1, 1) = "." || SubStr(line, 0, 1) = ".") {
                        if (!skipMsgBox) {
                            MessageManager.ShowError(
                                "第 " i " 行格式错误：`n`n" line "`n`n"
                                . "文件名不能以点开头或结尾", "格式错误"
                            )
                        }
                        return false
                    }
                } else {  ; 偶数行：第2、4、6...行（i=2,4,6...）
                    ; 检查是否是合法的路径
                    if (!this.IsValidPath(line, i, skipMsgBox)) {
                        return false
                    }
                }
            } else {
                ; 对于单个条目验证，根据位置判断是名称还是路径
                if (Mod(i, 2) = 1) {
                    ; 奇数位置视为名称
                    if (RegExMatch(line, '[\\/:*?"<>|]')) {
                        return false
                    }
                    if (SubStr(line, 1, 1) = "." || SubStr(line, 0, 1) = ".") {
                        return false
                    }
                } else {
                    ; 偶数位置视为路径
                    if (!this.IsValidPath(line, i, true)) {
                        return false
                    }
                }
            }
        }
        
        return true
    }

    ; >>> 新增辅助函数：验证名称是否合法
    static IsValidName(name, lineNumber := 0, skipMsgBox := false) {
        ; 检查是否是合法的文件名
        ; 文件名不能包含：\ / : * ? " < > |
        if (RegExMatch(name, '[\\/:*?"<>|]')) {
            if (!skipMsgBox) {
                MessageManager.ShowError(
                    "第 " lineNumber " 行包含非法字符：`n`n" name "`n`n"
                    . "文件名不能包含：\ / : * ? " . Chr(34) . " < > |", "格式错误"
                )
            }
            return false
        }
        
        ; 不能以点开头或结尾
        if (SubStr(name, 1, 1) = "." || SubStr(name, 0, 1) = ".") {
            if (!skipMsgBox) {
                MessageManager.ShowError(
                    "第 " lineNumber " 行格式错误：`n`n" name "`n`n"
                    . "文件名不能以点开头或结尾", "格式错误"
                )
            }
            return false
        }
        
        ; >>> 新增：不允许为空
        if (name = "") {
            if (!skipMsgBox) {
                MessageManager.ShowError(
                    "第 " lineNumber " 行：名称不能为空", "格式错误"
                )
            }
            return false
        }
        
        return true
    }

    ; >>> 新增辅助函数：验证路径是否合法
    static  IsValidPath(path, lineNumber := 0, skipMsgBox := false) {
        ; 必须包含多个\或/（至少一个）
        backslashCount := 0
        slashCount := 0
        colonCount := 0
        
        ; 统计字符数量
        Loop Parse, path {
            switch A_LoopField {
                case "\": backslashCount++
                case "/": slashCount++
                case ":": colonCount++
            }
        }
        
        ; 条件1：必须包含多个\或者多个/（至少一个）
        if (backslashCount = 0 && slashCount = 0) {
            if (!skipMsgBox) {
                MessageManager.ShowError(
                    "第 " lineNumber " 行不是有效的路径：`n`n" path "`n`n"
                    . "路径必须包含路径分隔符（\或/）", "格式错误"
                )
            }
            return false
        }
        
        ; 条件2：必须只包含一个:
        if (colonCount != 1) {
            if (!skipMsgBox) {
                msg := "第 " lineNumber " 行不是有效的路径：`n`n" path "`n`n"
                if (colonCount = 0) {
                    msg .= "路径缺少盘符（如C:）"
                } else {
                    msg .= "路径只能包含一个盘符（:），当前包含 " colonCount " 个"
                }
                MessageManager.ShowError(
                    msg, "格式错误"
                )
            }
            return false
        }
        
        ; 检查其他非法字符
        if (RegExMatch(path, '[*?"<>|]')) {
            if (!skipMsgBox) {
                MessageManager.ShowError(
                    "第 " lineNumber " 行包含非法字符：`n`n" path "`n`n"
                    . "路径不能包含：* ? " . Chr(34) . " < > |", "格式错误"
                )
            }
            return false
        }
        
        ; >>> 新增：不允许为空
        if (path = "") {
            if (!skipMsgBox) {
                MessageManager.ShowError(
                    "第 " lineNumber " 行：路径不能为空", "格式错误"
                )
            }
            return false
        }
        
        return true
    }

}