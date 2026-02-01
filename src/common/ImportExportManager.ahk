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
        ; moreGui.Destroy()

        if(guiManager.showingPrompt){
            MessageManager.ShowError("请先创建文件","提示")
            return
        }

        SettingsDialogManager.HandleMoreGuiClose(guiManager,moreGui)

        ; >>> 保存当前选择的文本
        selectedText := guiManager.listBox.Text
        
        ; ++++ 关键：临时启用OwnDialogs ++++
        if(guiManager.isTop){
            guiManager.gui.Opt("+OwnDialogs")
        }

        ; 自动填充文件名
        defaultFileName := this.configType ".txt"
        exportPath := FileSelect("S16", defaultFileName, "导出配置文件", "文本文件 (*.txt)")

        ; 用户取消选择
        if (exportPath = "") {
            if(guiManager.isTop){
                ImportExportManager.HandleUserCancel(guiManager,selectedText)
            }
            return false
        }
        
        ; 确保扩展名
        if (!RegExMatch(exportPath, "\.txt$")) {
            exportPath .= ".txt"
        }

        ; >>> 使用统一的文件名校验
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

            ; >>> 修改点：先删除文件，再写入，确保覆盖而不是追加
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
                ; >>> 重置当前条目的name和path
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
                    ; >>> 重要：如果name与section不一致，使用section名
                    /* if (currentSection != "" && currentName != currentSection) {
                        currentName := currentSection
                    } */
                } else if (key = "path") {
                    currentPath := value
                    
                    ; 当获取到path时，保存条目
                    ;!!! 排除Root节（不区分大小写）
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
        
        ;!!! 只导出非Root节的条目
        for item in allItems {
            ; 验证条目数据
            tempTxtForItem := item["name"] "`r`n" item["path"]
            if (IniTools.ValidateTxtContent(tempTxtForItem, true,true)) {
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
        ; moreGui.Destroy()
        SettingsDialogManager.HandleMoreGuiClose(guiManager,moreGui)

        ; >>> 保存当前选择的文本
        selectedText := guiManager.listBox.Text
        
        ; ++++ 关键：临时启用OwnDialogs ++++
        if(guiManager.isTop){
            guiManager.gui.Opt("+OwnDialogs")
        }

        importPath := FileSelect(1, , "选择要导入的配置文件", "文本文件 (*.txt)")
        if (importPath = "" || !FileExist(importPath)) {
            if(guiManager.isTop){
                ImportExportManager.HandleUserCancel(guiManager,selectedText)
            }
            return false
        }

        ; >>> 使用统一的文件名校验
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
            
            ; 验证TXT文件内容
            if (!IniTools.ValidateTxtContent(content, false, false)) {
                return false
            }
            
            ; 解析TXT内容
            lines := StrSplit(content, "`n", "`r")
            nonEmptyLines := []
            
            ; 过滤空行
            for line in lines {
                trimmedLine := Trim(line)
                if (trimmedLine != "") {
                    nonEmptyLines.Push(trimmedLine)
                }
            }
            
            ; 解析所有条目
            allItems := []
            rootItem := Map()
            
            ; 逐对处理（名称+路径）
            for i in ImportExportManager.Range(1, nonEmptyLines.Length, 2) {
                if (i + 1 <= nonEmptyLines.Length) {
                    itemName := nonEmptyLines[i]
                    itemPath := nonEmptyLines[i + 1]
                    
                    ; 验证这对数据
                    tempTxtForItem := itemName "`r`n" itemPath
                    if (IniTools.ValidateTxtContent(tempTxtForItem, true,true)) {
                        item := Map()
                        
                        ; >>> 如果是Root（不区分大小写）
                        if (StrLower(itemName) = "root") {
                            ; 保持原始大小写
                            item["section"] := itemName
                            item["name"] := itemName  ; name与section保持一致
                            item["path"] := itemPath
                            rootItem := item
                        } else {
                            ; >>> 普通条目：section和name使用相同的值
                            ; section使用去除扩展名的名称
                            sectionName := itemName
                            ; 检查是否有扩展名
                            if (InStr(sectionName, ".")) {
                                ; 去除最后一个扩展名
                                dotPos := InStr(sectionName, ".", , -1)
                                if (dotPos > 1) {
                                    sectionName := SubStr(sectionName, 1, dotPos - 1)
                                }
                            }
                            
                            item["section"] := sectionName
                            item["name"] := itemName    ; name保持TXT中的原样（有扩展名）
                            item["path"] := itemPath
                            allItems.Push(item)
                        }
                    }
                }
            }
            
            ; 构建INI内容
            iniLines := []
            
            ; >>> 添加Root section（如果有）
            if (rootItem.Count > 0) {
                ; >>> section名使用Root的原始大小写
                iniLines.Push("[" rootItem["section"] "]")
                ; >>> name值与section名保持一致
                iniLines.Push("name=" rootItem["name"])
                iniLines.Push("path=" rootItem["path"])
                
                ; 只有在有后续内容时才添加空行
                if (allItems.Length > 0) {
                    iniLines.Push("")  ; 空行分隔
                }
            }
            
            ; 添加其他section
            for i, item in allItems {
                ; >>> section名使用原始大小写
                iniLines.Push("[" item["section"] "]")
                ; >>> name值与section名保持一致
                iniLines.Push("name=" item["name"])
                iniLines.Push("path=" item["path"])
                
                ; 如果不是最后一个，添加空行分隔
                if (i < allItems.Length) {
                    iniLines.Push("")
                }
            }
            
            ; 写入文件
            if (iniLines.Length > 0) {
                iniContent := IniTools.StrJoin(iniLines, "`r`n") . "`r`n"
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

    ; >>> 修改Range函数，添加步长参数
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
        ; moreGui.Destroy()
        SettingsDialogManager.HandleMoreGuiClose(guiManager,moreGui)

        ; >>> 保存当前选择的文本
        selectedText := guiManager.listBox.Text
        
        if (!FileExist(this.configPath)) {
            MessageManager.ShowError("配置文件不存在，无法追加！")
            return false
        }

        ; ++++ 关键：临时启用OwnDialogs ++++
        if(guiManager.isTop){
            guiManager.gui.Opt("+OwnDialogs")
        }
        
        appendPath := FileSelect(1, , "选择要追加的配置文件", "文本文件 (*.txt)")
        if (appendPath = "" || !FileExist(appendPath)) {
            if(guiManager.isTop){
                ImportExportManager.HandleUserCancel(guiManager,selectedText)
            }
            return false
        }

        ; >>> 使用统一的文件名校验
        /* if (!IniTools.ValidateFileName(appendPath, this.configType)) {
            return false
        } */

        result := this.AppendFromTxtWithRoot(appendPath)
        if (result) {
            MessageManager.ShowSuccessDelayed("追加成功！",100)
        } else {
            MessageManager.ShowError("追加失败！")
        }
        return result
    }
    
    ; 从TXT追加
    AppendFromTxtWithRoot(filePath) {
        try {
            ; 读取现有INI内容
            oldContent := FileRead(this.configPath)
            
            ; 读取要追加的TXT内容
            appendContent := FileRead(filePath, "UTF-8")
            
            ; >>> 使用ValidateTxtContent验证追加内容
            if (!IniTools.ValidateTxtContent(appendContent,false,false)) {
                return false
            }
            
            ; 解析要追加的TXT内容（包含Root处理）
            parsedData := ImportExportManager.ParseTxtContentWithRoot(appendContent)
            
            ; 合并内容（支持Root覆盖）
            mergedContent := ImportExportManager.MergeIniContentWithRoot(oldContent, parsedData)
            
            ; 写入文件
            FileDelete(this.configPath)
            FileAppend(mergedContent, this.configPath, "UTF-8")

            ; 格式化文件
            IniTools.FormatAndSaveIniFile(this.configPath)
            
            return true
        } catch Error as e {
            MessageManager.ShowError("追加错误: " e.Message)
            return false
        }
    }
    
    ; 解析TXT中的section，支持Root
    static ParseTxtContentWithRoot(txtContent) {
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
                if (IniTools.ValidateTxtContent(tempTxtForItem, true,true)) {
                    item := Map()
                    
                    ; >>> 如果是Root（不区分大小写）
                    if (StrLower(itemName) = "root") {
                        ; 保持原始大小写
                        item["section"] := itemName
                        item["name"] := itemName  ; name与section保持一致
                        item["path"] := itemPath
                        rootItem := item
                    } else {
                        ; >>> 普通条目：section和name使用相同的值
                        ; section使用去除扩展名的名称
                        sectionName := itemName
                        ; 检查是否有扩展名
                        if (InStr(sectionName, ".")) {
                            ; 去除最后一个扩展名
                            dotPos := InStr(sectionName, ".", , -1)
                            if (dotPos > 1) {
                                sectionName := SubStr(sectionName, 1, dotPos - 1)
                            }
                        }
                        
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
    ; >>> 修改点2: 重构MergeIniContentWithRoot函数，支持不区分大小写的匹配
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
        
        ; >>> 第一次遍历：建立不区分大小写的section映射
        Loop Parse, oldContent, "`n", "`r" {
            currentLineNumber++
            line := Trim(A_LoopField)
            
            if (SubStr(line, 1, 1) = "[") {
                if (currentSection != "") {
                    ; 保存上一个section的信息
                    oldSectionLines[currentSection] := Map("start", sectionStartLine, "end", currentLineNumber - 1)
                }
                
                currentSection := SubStr(line, 2, InStr(line, "]") - 2)
                ; >>> 以小写为key存储，值为原始大小写
                oldSections[StrLower(currentSection)] := currentSection
                sectionStartLine := currentLineNumber
            }
        }
        
        ; 保存最后一个section的信息
        if (currentSection != "") {
            oldSectionLines[currentSection] := Map("start", sectionStartLine, "end", currentLineNumber)
        }
        
        ; >>> 处理Root：如果有新的Root，就替换或添加
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
        
        ; >>> 处理普通section：不区分首字母大小写的匹配
        for i, newSection in newSections {
            sectionName := newSection["section"]
            sectionNameLower := StrLower(sectionName)
            
            ; >>> 查找是否存在匹配的section（不区分大小写）
            existingSectionName := ""
            
            ; 直接查找匹配的section
            if (oldSections.Has(sectionNameLower)) {
                existingSectionName := oldSections[sectionNameLower]
            }
            
            if (existingSectionName != "") {
                ; >>> 替换现有section
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

    ; >>> 新增辅助函数：按行号移除section
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

    ; >>> 修改ReplaceSection函数，支持不区分大小写的section名称
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

    ; +++ 新增辅助函数：追加section到文件末尾
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
    
    ; >>> 新增：处理用户取消选择的通用逻辑
    static HandleUserCancel(guiManager, selectedText) {
        ; 恢复Owner关系
        guiManager.gui.Opt("-OwnDialogs")
        
        ; 恢复选择
        if (selectedText != '') {
            ; 恢复选中项
            GuiEventHandlers.SelectItemInListBox(guiManager, selectedText)
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

        ; ++++ 关键：临时启用OwnDialogs ++++
        if(guiManager.isTop){
            guiManager.gui.Opt("+OwnDialogs")
        }

        
        ; 显示文件选择对话框（支持多选，只能选择文件）
        fileDialog := FileSelect("M", , "选择要载入的文件", "所有文件 (*.*)")
        
        if (fileDialog = "") {
            return false
        }
        
        ; 如果有选中的文件，进行处理
        if (fileDialog.Length > 0) {
            ; 复用 HandleCreateClick 的处理逻辑
            ; 重新激活我们的GUI窗口
            WinActivate(guiManager.gui.Hwnd)
            Sleep(100)
            
            ; 获取设置
            enableExtension := SettingsManager.GetBool("EnableExtension")
            batchThreshold := SettingsManager.GetInt("BatchThreshold")
            
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
}