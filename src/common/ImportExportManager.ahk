; ==============================
; ImportExportManager.ahk
; 导入导出管理类
; ==============================
class ImportExportManager {
    ; 构造函数
    __New(configType, configPath) {
        this.configType := configType
        this.configPath := configPath
    }
    
    ; t_openfile_settings：alwaysOnTop-multi
    ; ==================== 导出相关方法 ====================
    
    ; 导出配置（主方法）
    ExportConfig(moreGui,guiManager) {

        if(guiManager.showingPrompt){
            MessageManager.ShowError("请先创建文件","提示")
            return
        }

        SettingsDialogManager.HandleMoreGuiClose(guiManager,moreGui)

        ; 保存当前选择的文本数组
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)
        
        ; 临时启用OwnDialogs
        if(guiManager.isTop){
            guiManager.gui.Opt("+OwnDialogs")
        }

        ; 自动填充文件名
        defaultFileName := this.configType ".txt"
        exportPath := FileSelect("S16", defaultFileName, "导出配置文件", "文本文件 (*.txt)")

        ; 用户取消选择
        if (exportPath = "") {
            ImportExportManager.HandleUserCancel(guiManager,selectedTexts)
            return false
        }
        
        ; 确保扩展名
        if (!RegExMatch(exportPath, "\.txt$")) {
            exportPath .= ".txt"
        }

        ; 使用统一的文件名校验
        /* if (!IniTools.ValidateFileName(exportPath, this.configType)) {
            return false
        } */
        
        ; 导出配置
        if (this.ExportToTxt(exportPath)) {
            MessageManager.ShowSuccess("导出成功！`n文件保存到: " exportPath)
            return true
        } else {
            MessageManager.ShowError("导出失败！")
            return false
        }
    }

    ; 导出为TXT格式
    ExportToTxt(filePath) {
        try {
            ; 读取INI文件（自动处理编码）
            content := FileRead(this.configPath)
            txtContent := this.IniToTxt(content)

            ; 先删除文件，再写入，确保覆盖而不是追加
            if (FileExist(filePath)) {
                FileDelete(filePath)
            }
            
            ; 写入UTF-8文件
            FileAppend(txtContent, filePath, "UTF-8")
            return true
        } catch {
            return false
        }
    }
    
    ; INI转TXT格式 排除Root节导出
    IniToTxt(iniContent) {
        ; 存储条目的数组
        allItems := []
        currentSection := ""
        
        ; 解析INI内容
        Loop Parse, iniContent, "`n", "`r" {
            line := Trim(A_LoopField)
            
            ; 跳过注释和空行
            if (line = "" || SubStr(line, 1, 1) = ";") {
                continue
            }
            
            ; 解析section
            if (SubStr(line, 1, 1) = "[") {
                currentSection := SubStr(line, 2, InStr(line, "]") - 2)
                ; 重置当前条目的name和path
                currentName := ""
                currentPath := ""
                continue
            }
            
            ; 解析key=value
            if (InStr(line, "=")) {
                pos := InStr(line, "=")
                key := Trim(SubStr(line, 1, pos - 1))
                value := Trim(SubStr(line, pos + 1))
                
                if (key = "name") {
                    currentName := value
                    ; 重要：如果name与section不一致，使用section名
                    /* if (currentSection != "" && currentName != currentSection) {
                        currentName := currentSection
                    } */
                } else if (key = "path") {
                    currentPath := value
                    
                    ; 当获取到path时，保存条目
                    ; 排除Root节（不区分大小写）
                    if (currentSection != "" && currentName != "" && currentPath != ""  && StrLower(currentSection) != "root") {
                        item := Map()
                        item["section"] := currentSection
                        item["name"] := currentName
                        item["path"] := currentPath
                        allItems.Push(item)
                    }
                }
            }
        }
        
        ; 构建TXT内容
        txtLines := []
        
        ; 只导出非Root节的条目
        for item in allItems {
            ; 验证条目数据
            tempTxtForItem := item["name"] "`r`n" item["path"]
            if (IniTools.ValidateTxtContent(tempTxtForItem, true,true,true)) {
                ; 导出时使用name字段
                txtLines.Push(item["name"])
                txtLines.Push(item["path"])
                txtLines.Push("")  ; 空行分隔
            }
        }
        
        ; 清理末尾多余的空行
        while (txtLines.Length > 0 && txtLines[txtLines.Length] = "") {
            txtLines.Pop()
        }
        
        ; 确保最后有一个换行符
        return IniTools.StrJoin(txtLines, "`r`n") . (txtLines.Length > 0 ? "`r`n" : "")
    }
    
    ; ==================== 导入相关方法 ====================
    
    ; 导入配置（主方法）
    ImportConfig(moreGui,guiManager) {

        SettingsDialogManager.HandleMoreGuiClose(guiManager,moreGui)

        ; 保存当前选择的文本数组
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)
        
        ; 临时启用OwnDialogs
        if(guiManager.isTop){
            guiManager.gui.Opt("+OwnDialogs")
        }

        importPath := FileSelect(1, , "选择要导入的配置文件", "文本文件 (*.txt)")
        if (importPath = "" || !FileExist(importPath)) {
            ImportExportManager.HandleUserCancel(guiManager,selectedTexts)
            return false
        }

        ; 使用统一的文件名校验
        /* if (!IniTools.ValidateFileName(importPath, this.configType)) {
            return false
        } */
        
        result := this.ImportFromTxtWithRoot(importPath)
        if (result) {
            MessageManager.ShowSuccessDelayed("导入成功！",100)
        } else {
            MessageManager.ShowError("导入失败！")
        }

        return result

    }
    
    ; 从TXT导入 支持Root导入的TXT导入函数
    ImportFromTxtWithRoot(filePath) {
        try {
            ; 读取TXT文件
            content := FileRead(filePath, "UTF-8")
            
            ; 使用增强的ValidateTxtContent（包含重复校验）
            if (!IniTools.ValidateTxtContent(content, false, false, false)) {
                return false
            }
            
            ; 使用新的智能解析方法
            parseResult := IniTools.ParseTxtContentWithSmartSections(content, 
                objBindMethod(ImportExportManager, "GetSmartSectionName"))
            
            if (!parseResult.success) {
                ; 错误信息已经在ValidateTxtContent中显示
                return false
            }
            
            ; 获取处理后的条目
            allItems := parseResult.items
            txtRootItem := Map()
            txtNormalItems := []
            
            ; 分离Root和其他条目
            for item in allItems {
                if (item.Has("isRoot") && item["isRoot"] = true) {
                    txtRootItem := item
                } else {
                    txtNormalItems.Push(item)
                }
            }
            
            ; 智能Root处理逻辑 - 读取现有INI只是为了检查Root
            existingRootItem := Map()
            
            if (FileExist(this.configPath)) {
                existingContent := FileRead(this.configPath)
                
                ; 只解析现有INI的Root section（如果存在）
                currentSection := ""
                currentName := ""
                currentPath := ""
                
                Loop Parse, existingContent, "`n", "`r" {
                    line := Trim(A_LoopField)
                    
                    if (SubStr(line, 1, 1) = "[") {
                        ; 如果之前解析的是Root，保存它
                        if (currentSection != "" && StrLower(currentSection) = "root") {
                            existingRootItem["section"] := currentSection
                            existingRootItem["name"] := currentName
                            existingRootItem["path"] := currentPath
                            existingRootItem["isRoot"] := true
                        }
                        
                        currentSection := SubStr(line, 2, InStr(line, "]") - 2)
                        currentName := ""
                        currentPath := ""
                    } else if (InStr(line, "=")) {
                        pos := InStr(line, "=")
                        key := Trim(SubStr(line, 1, pos - 1))
                        value := Trim(SubStr(line, pos + 1))
                        
                        if (key = "name") {
                            currentName := value
                        } else if (key = "path") {
                            currentPath := value
                        }
                    }
                }
                
                ; 检查最后一个section是否是Root
                if (currentSection != "" && StrLower(currentSection) = "root") {
                    existingRootItem["section"] := currentSection
                    existingRootItem["name"] := currentName
                    existingRootItem["path"] := currentPath
                    existingRootItem["isRoot"] := true
                }
            }
            
            ; 智能Root处理逻辑（不再合并现有非Root条目）
            ; 规则：TXT有Root则用TXT的Root，否则保留现有Root
            finalRootItem := Map()
            
            if (txtRootItem.Count > 0) {
                ; 情况1：TXT有Root → 使用TXT的Root
                finalRootItem := txtRootItem
            } else if (existingRootItem.Count > 0) {
                ; 情况2：TXT无Root，但原INI有Root → 保留原Root
                finalRootItem := existingRootItem
            }
            
            ; 构建INI内容 - 不再合并现有条目
            iniLines := []
            
            ; 添加Root section（如果有）
            if (finalRootItem.Count > 0) {
                iniLines.Push("[" finalRootItem["section"] "]")
                iniLines.Push("name=" finalRootItem["name"])
                iniLines.Push("path=" finalRootItem["path"])
                
                ; 只有在有后续内容时才添加空行
                if (txtNormalItems.Length > 0) {
                    iniLines.Push("")  ; 空行分隔
                }
            }
            
            ; 只添加TXT中的非Root条目（已处理section重复）
            for i, item in txtNormalItems {
                iniLines.Push("[" item["section"] "]")
                iniLines.Push("name=" item["name"])
                iniLines.Push("path=" item["path"])
                
                ; 如果不是最后一个，添加空行分隔
                if (i < txtNormalItems.Length) {
                    iniLines.Push("")
                }
            }
            
            ; 写入文件
            if (iniLines.Length > 0) {
                iniContent := IniTools.StrJoin(iniLines, "`r`n") . "`r`n"
                ; 删除旧文件，完全重新写入
                FileDelete(this.configPath)
                FileAppend(iniContent, this.configPath, "UTF-8")
                
                ; 格式化文件
                IniTools.FormatAndSaveIniFile(this.configPath)
                return true
            } else {
                MessageManager.ShowError("导入失败：没有有效数据可以导入！")
                return false
            }
            
        } catch Error as e {
            MessageManager.ShowError("导入错误: " e.Message "`n位置: " e.What " 行: " e.Line)
            return false
        }
    }

    ; Range函数，添加步长参数
    static Range(start, end, step := 1) {
        arr := []
        if (step > 0) {
            Loop (Ceil((end - start + 1) / step)) {
                currentValue := start + (A_Index - 1) * step
                if (currentValue <= end) {
                    arr.Push(currentValue)
                }
            }
        }
        return arr
    }

    
    ; ==================== 追加相关方法 ====================
    
    ; 追加配置（主方法）
    AppendConfig(moreGui,guiManager) {
        SettingsDialogManager.HandleMoreGuiClose(guiManager,moreGui)

        ; 保存当前选择的文本数组
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)
        
        if (!FileExist(this.configPath)) {
            MessageManager.ShowError("配置文件不存在，无法追加！")
            return false
        }

        ; 临时启用OwnDialogs
        if(guiManager.isTop){
            guiManager.gui.Opt("+OwnDialogs")
        }
        
        appendPath := FileSelect(1, , "选择要追加的配置文件", "文本文件 (*.txt)")
        if (appendPath = "" || !FileExist(appendPath)) {
            ImportExportManager.HandleUserCancel(guiManager,selectedTexts)
            return false
        }

        ; 使用统一的文件名校验
        /* if (!IniTools.ValidateFileName(appendPath, this.configType)) {
            return false
        } */

        result := this.AppendFromTxtWithRoot(appendPath,guiManager)
        if (result) {
            MessageManager.ShowSuccessDelayed("追加成功！",100)
        } else {
            MessageManager.ShowError("追加失败！")
            ; 恢复选择
            ImportExportManager.HandleUserCancel(guiManager, selectedTexts)
        }
        return result
    }
    
    ; 从TXT追加
    AppendFromTxtWithRoot(filePath,guiManager :="") {
        try {
            ; 读取现有INI内容
            oldContent := FileRead(this.configPath)
            
            ; 读取要追加的TXT内容
            appendContent := FileRead(filePath, "UTF-8")
            
            ; 使用增强的ValidateTxtContent（包含基本重复校验）
            ; 这里skipDuplicateCheck=false启用重复校验
            if (!IniTools.ValidateTxtContent(appendContent, false, false, false)) {
                return false
            }
            
            ; 调用ParseTxtContentWithRoot（只处理特殊重复校验）
            parsedData := ImportExportManager.ParseTxtContentWithRoot(appendContent)

            ; 检查是否解析成功（空数据可能表示校验失败）
            if (parsedData["sections"].Length = 0 && parsedData["root"].Count = 0) {
                ; ParseTxtContentWithRoot内部已经处理了错误信息
                    MessageManager.ShowError("TXT内容解析失败，可能存在section重复问题")
                    return false
            }
            
            ; 合并内容（支持Root覆盖）
            mergedContent := ImportExportManager.MergeIniContentWithRoot(oldContent, parsedData)
            
            ; 写入文件
            FileDelete(this.configPath)
            FileAppend(mergedContent, this.configPath, "UTF-8")

            ; 格式化文件
            IniTools.FormatAndSaveIniFile(this.configPath)

            ; 选中最后一项
            this.SelectLastItemInternal(guiManager,appendContent)
            
            return true
        } catch Error as e {
            MessageManager.ShowError("追加错误: " e.Message)
            return false
        }
    }
    
    ; 内部选中最后一项的实现
    SelectLastItemInternal(guiManager, txtContent := "") {
        ; 重新加载列表
        guiManager.RefreshList()
        
        ; 如果提供了TXT内容，解析并获取最后一个文件名称
        if (txtContent != "") {
            ; 解析TXT内容，获取最后一个非Root的section名称
            parsedData := ImportExportManager.ParseTxtContentWithRoot(txtContent)
            newSections := parsedData["sections"]
            
            ; 获取最后一个section的文件名称
            if (newSections.Length > 0) {
                lastSection := newSections[newSections.Length]
                lastFileName := lastSection["name"]  ; 这是TXT中的文件名称
                
                ; 在ListBox中查找并选中该项
                GuiEventHandlers.SelectItemByText(guiManager, lastFileName)
                return
            }
        }
    }
    
    ; 解析TXT中的section，支持Root
    static ParseTxtContentWithRoot(txtContent) {
        ; 使用智能解析方法（包含特殊重复校验）
        parseResult := IniTools.ParseTxtContentWithSmartSections(txtContent,
            objBindMethod(ImportExportManager, "GetSmartSectionName"))
        
        if (!parseResult.success) {
            ; 解析失败，返回空数据
            return Map("root", Map(), "sections", [])
        }
        
        ; 转换格式以保持向后兼容
        result := Map()
        rootItem := Map()
        sections := []
        
        for item in parseResult.items {
            if (item.Has("isRoot") && item["isRoot"] = true) {
                rootItem := item
            } else {
                sections.Push(item)
            }
        }
        
        result["root"] := rootItem
        result["sections"] := sections

        return result
    }

    ; 用于ContextMenuManager调用
    static ParseTxtContentWithRootLegacy(txtContent) {
        result := Map()
        sections := []
        rootItem := Map()

        ; 解析TXT内容
        lines := StrSplit(txtContent, "`n", "`r")
        nonEmptyLines := []

        ; 过滤空行
        for line in lines {
            trimmedLine := Trim(line)
            if (trimmedLine != "") {
                nonEmptyLines.Push(trimmedLine)
            }
        }

        ; 逐对处理（名称+路径）
        for i in this.Range(1, nonEmptyLines.Length, 2) {
            if (i + 1 <= nonEmptyLines.Length) {
                itemName := nonEmptyLines[i]
                itemPath := nonEmptyLines[i + 1]
                
                ; 验证这对数据
                tempTxtForItem := itemName "`r`n" itemPath
                if (IniTools.ValidateTxtContent(tempTxtForItem, true,true,true)) {
                    item := Map()
                    
                    ; 如果是Root（不区分大小写）
                    if (StrLower(itemName) = "root") {
                        ; 保持原始大小写
                        item["section"] := itemName
                        item["name"] := itemName  ; name与section保持一致
                        item["path"] := itemPath
                        rootItem := item
                    } else {
                        ; 普通条目：section和name使用相同的值
                        ; 处理section-智能去除扩展名
                        sectionName := ImportExportManager.GetSmartSectionName(itemName, itemPath)
                        item["section"] := sectionName
                        item["name"] := itemName    ; name保持TXT中的原样（有扩展名）
                        item["path"] := itemPath
                        sections.Push(item)
                    }
                }
            }
        }

        result["root"] := rootItem
        result["sections"] := sections

        return result
    }
    
    ; 合并INI内容，支持Root覆盖
    ; 重构MergeIniContentWithRoot函数，支持不区分大小写的匹配
    static MergeIniContentWithRoot(oldContent, newData) {
        newRoot := newData["root"]
        newSections := newData["sections"]
        
        ; 解析旧内容中的sections（建立不区分大小写的映射）
        oldSections := Map()  ; 存储section名称 -> 原始大小写
        oldSectionLines := Map()  ; 存储section名称 -> 对应的行数索引
        sectionLines := []
        
        currentSection := ""
        currentLineNumber := 0
        sectionStartLine := 0
        
        ; 第一次遍历：建立不区分大小写的section映射
        Loop Parse, oldContent, "`n", "`r" {
            currentLineNumber++
            line := Trim(A_LoopField)
            
            if (SubStr(line, 1, 1) = "[") {
                if (currentSection != "") {
                    ; 保存上一个section的信息
                    oldSectionLines[currentSection] := Map("start", sectionStartLine, "end", currentLineNumber - 1)
                }
                
                currentSection := SubStr(line, 2, InStr(line, "]") - 2)
                ; 以小写为key存储，值为原始大小写
                oldSections[StrLower(currentSection)] := currentSection
                sectionStartLine := currentLineNumber
            }
        }
        
        ; 保存最后一个section的信息
        if (currentSection != "") {
            oldSectionLines[currentSection] := Map("start", sectionStartLine, "end", currentLineNumber)
        }
        
        ; 处理Root：如果有新的Root，就替换或添加
        if (newRoot.Count > 0) {
            ; 如果旧内容中有Root（不区分大小写），先移除
            rootKey := StrLower("Root")
            if (oldSections.Has(rootKey)) {
                rootSectionName := oldSections[rootKey]
                ; 移除Root section
                oldContent := ImportExportManager.RemoveSectionByLines(oldContent, oldSectionLines[rootSectionName]["start"], oldSectionLines[rootSectionName]["end"])
                ; 从映射中移除
                oldSections.Delete(rootKey)
            }
            
            ; 将新的Root section添加到文件顶部
            rootContent := ""
            if (oldContent = "" || Trim(oldContent) = "") {
                ; 如果是空文件，直接添加Root
                rootContent := "[" newRoot["section"] . "]`r`n"
                rootContent .= "name=" newRoot["name"] . "`r`n"
                rootContent .= "path=" newRoot["path"] . "`r`n"
                
                if (newSections.Length > 0) {
                    rootContent .= "`r`n"  ; 如果有其他section，加空行
                }
                oldContent := rootContent
            } else {
                ; 在非空文件中插入Root到顶部
                rootContent := "[" newRoot["section"] . "]`r`n"
                rootContent .= "name=" newRoot["name"] . "`r`n"
                rootContent .= "path=" newRoot["path"] . "`r`n"
                rootContent .= "`r`n"  ; 添加空行分隔
                
                oldContent := rootContent . oldContent
            }
        }
        
        ; 处理普通section：不区分首字母大小写的匹配
        for i, newSection in newSections {
            sectionName := newSection["section"]
            sectionNameLower := StrLower(sectionName)
            
            ; 查找是否存在匹配的section（不区分大小写）
            existingSectionName := ""
            
            ; 直接查找匹配的section
            if (oldSections.Has(sectionNameLower)) {
                existingSectionName := oldSections[sectionNameLower]
            }
            
            if (existingSectionName != "") {
                ; 替换现有section
                oldContent := ImportExportManager.ReplaceSection(oldContent, existingSectionName, newSection)
            } else {
                ; 追加新的section
                oldContent := ImportExportManager.AppendSection(oldContent, newSection)
            }
        }
        
        ; 清理多余空行
        oldContent := RegExReplace(oldContent, "(`r`n){3,}", "`r`n`r`n")
        oldContent := RTrim(oldContent, "`r`n")
        
        ; 确保最后有一个换行符
        return oldContent . "`r`n"
    }

    ; 按行号移除section
    static RemoveSectionByLines(content, startLine, endLine) {
        lines := StrSplit(content, "`n", "`r")
        newLines := []
        
        for i, line in lines {
            if (i < startLine || i > endLine) {
                newLines.Push(line)
            }
        }
        
        ; 重新组合并清理空行
        result := IniTools.StrJoin(newLines, "`r`n")
        result := RegExReplace(result, "(`r`n){3,}", "`r`n`r`n")
        result := RTrim(result, "`r`n")
        
        return result
    }

    ; 支持不区分大小写的section名称
    static ReplaceSection(content, existingSectionName, newSectionData) {
        ; 构建正则表达式，匹配原始大小写的section
        escapedSectionName := RegExReplace(existingSectionName, "[.*+?^${}()|[\]\\]", "\$0")
        pattern := "\[" escapedSectionName "\][\s\S]*?(?=\n\[|$)"
        
        if (RegExMatch(content, pattern, &match)) {
            ; 构建新的section内容
            newSectionContent := "[" newSectionData["section"] . "]`r`n"
            newSectionContent .= "name=" newSectionData["name"] . "`r`n"
            newSectionContent .= "path=" newSectionData["path"] . "`r`n"
            
            content := StrReplace(content, match[0], newSectionContent)
            
            ; 清理可能产生的连续空行
            content := RegExReplace(content, "(`r`n){3,}", "`r`n`r`n")
            content := RTrim(content, "`r`n")
            
            ; 如果内容不为空，确保有换行符
            if (content != "") {
                content .= "`r`n"
            }
        }
        
        return content
    }

    ; 辅助函数：追加section到文件末尾
    static AppendSection(content, sectionData) {
        ; 清理末尾多余的空行
        content := RTrim(content, "`r`n")
        
        ; 如果不是空文件，添加空行分隔
        if (content != "") {
            content .= "`r`n`r`n"
        }
        
        ; 添加新的section
        content .= "[" sectionData["section"] . "]`r`n"
        content .= "name=" sectionData["name"] . "`r`n"
        content .= "path=" sectionData["path"] . "`r`n"
        
        return content
    }
    
    ; 处理用户取消选择的通用逻辑
    static HandleUserCancel(guiManager, selectedTexts) {
        ; 恢复Owner关系
        if(guiManager.isTop){
            guiManager.gui.Opt("-OwnDialogs")
        }

        ; 恢复选择
        if (selectedTexts.Length > 0) {
            ; 恢复选中项（只恢复第一项，因为实际是单选）
            GuiEventHandlers.SelectItemInListBox(guiManager, selectedTexts[1])

            ; 即使选中的是提示文本，也要恢复选中项
            ; 检查是否为提示文本
            firstText := selectedTexts[1]
            isPrompt := guiManager.showingPrompt || 
                    guiManager.listEmptyPrompt || 
                    (InStr(firstText, ">>>") && InStr(firstText, "<<<"))
            if (isPrompt) {
                ; 如果是提示文本，恢复选中项
                guiManager.listBox.Value := 1
            }

        } else {
            ; 如果没有选中项，就让搜索框进入焦点
            guiManager.searchBox.Focus()
            guiManager.userWasInSearchBox := true
        }
    }

    ; ==================== 载入相关方法 ====================
    HandleLoad(moreGui,guiManager) {
        ; 如果传入了 moreGui，才需要关闭对话框
        if(moreGui != ""){
            ; 关闭设置对话框
            SettingsDialogManager.HandleMoreGuiClose(guiManager,moreGui)
        }

        ; 保存当前选择的文本数组
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)

        ; 临时启用OwnDialogs
        if(guiManager.isTop){
            guiManager.gui.Opt("+OwnDialogs")
        }

        
        ; 显示文件选择对话框（支持多选，只能选择文件）
        fileDialog := FileSelect("M", , "选择要载入的文件", "所有文件 (*.*)")
        
        if (Type(fileDialog) = "Array" && fileDialog.Length = 0) {
            ImportExportManager.HandleUserCancel(guiManager,selectedTexts)
            return false
        }
        
        ; 如果有选中的文件，进行处理
        if (fileDialog.Length > 0) {
            ; 复用 HandleCreateClick 的处理逻辑
            ; 重新激活我们的GUI窗口
            WinActivate(guiManager.gui.Hwnd)
            Sleep(100)
            
            ; 获取设置
            enableExtension := SettingsManager.GetBool("EnableExtension",guiManager.configType)
            batchThreshold := SettingsManager.GetInt("BatchThreshold",guiManager.configType)
            
            if (fileDialog.Length >= batchThreshold) {
                ; 批量创建
                lastAddedName := FileProcessor.BatchCreateFromSelectedFiles(guiManager, fileDialog, enableExtension)
                if (lastAddedName != "") {
                    GuiEventHandlers.RefreshAndSelect(guiManager, lastAddedName)
                }
            } else {
                ; 单个创建
                lastAddedName := ""
                for filePath in fileDialog {
                    lastAddedName := FileProcessor.CreateSingleFileAndReturnName(guiManager, filePath, enableExtension)
                }
                if (lastAddedName != "") {
                    GuiEventHandlers.RefreshAndSelect(guiManager, lastAddedName)
                }
            }
            return true
        }
    
        return false
    }

    ; ==================== 处理section-智能去除扩展名 ====================

    ; 智能判断是否去除扩展名的方法（与HandleNameChangeForEditGui逻辑一致）
    static ShouldRemoveExtension(itemName, itemPath) {
        ; 检查路径是否为空
        if (itemPath = "") {
            return false
        }
        
        ; 从路径中提取文件名（包含扩展名）
        pathFileName := ""
        try {
            SplitPath(itemPath, &pathFileName)
        } catch {
            pathFileName := ""
        }
        
        ; 比较名称和路径文件名
        if (pathFileName != "" && itemName = pathFileName) {
            ; 名称与路径文件名完全相同（包含扩展名）
            if (InStr(itemName, ".")) {
                return true
            }
        }
        
        return false
    }
    
    ; 智能处理section名称的方法
    static GetSmartSectionName(itemName, itemPath) {

        ; 如果应该去除扩展名
        if (ImportExportManager.ShouldRemoveExtension(itemName, itemPath)) {
            ; 去除扩展名作为section
            dotPos := InStr(itemName, ".", , -1)
            if (dotPos > 1) {
                return SubStr(itemName, 1, dotPos - 1)
            }
        }
        
        ; 其他情况：直接使用名称作为section
        return itemName
    }
}