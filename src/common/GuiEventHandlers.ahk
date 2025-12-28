; ==============================
; GuiEventHandlers.ahk
; GUI事件处理工具类
; ==============================
class GuiEventHandlers {
    ; ==================== 主窗口按钮事件处理 ====================
    
    ; 创建按钮点击事件处理
    static HandleCreateClick(guiManager) {
        ; 1. 检查是否存在资源管理器窗口
        if (!WinExist("ahk_class CabinetWClass")) {
            guiManager.editMode := "create"
            guiManager.currentEditSection := ""
            guiManager.ShowEditDialogGui("", "")
            return
        }
        
        ; 2. 获取第一个资源管理器窗口句柄
        explorerHwnd := WinExist("ahk_class CabinetWClass")
        
        ; 3. 检查资源管理器窗口是否最小化
        try {
            if (WinGetMinMax("ahk_id " . explorerHwnd) = -1) {
                ; 窗口最小化，直接显示编辑对话框
                guiManager.editMode := "create"
                guiManager.currentEditSection := ""
                guiManager.ShowEditDialogGui("", "")
                return
            }
        }
        
        ; 4. 窗口未最小化，尝试激活
        WinActivate("ahk_id " . explorerHwnd)
        Sleep(200)  ; 等待激活完成
        
        ; 5. 如果激活失败，显示编辑对话框
        if (!WinActive("ahk_id " . explorerHwnd)) {
            guiManager.editMode := "create"
            guiManager.currentEditSection := ""
            guiManager.ShowEditDialogGui("", "")
            return
        }
        
        ; 6. 获取所有选中的文件
        selectedFiles := FileProcessor.GetSelectedFilesInExplorer(explorerHwnd)
        
        ; 7. 重新激活我们的GUI窗口
        WinActivate(guiManager.gui.Hwnd)
        Sleep(100)
        
        ; 8. 根据结果处理
        if (selectedFiles.Length > 0) {
            enableExtension := SettingsManager.GetBool("EnableExtension", false)
            batchThreshold := SettingsManager.GetInt("BatchThreshold", 5)
            
            if (selectedFiles.Length >= batchThreshold) {
                ; 批量创建
                lastAddedName := FileProcessor.BatchCreateFromSelectedFiles(guiManager, selectedFiles, enableExtension)
                if (lastAddedName != "") {
                    this.RefreshAndSelect(guiManager, lastAddedName)
                }
            } else {
                ; 单个创建
                lastAddedName := ""
                for filePath in selectedFiles {
                    lastAddedName := FileProcessor.CreateSingleFileAndReturnName(guiManager, filePath, enableExtension)
                }
                if (lastAddedName != "") {
                    this.RefreshAndSelect(guiManager, lastAddedName)
                }
            }
        } else {
            ; 没有选中文件
            guiManager.editMode := "create"
            guiManager.currentEditSection := ""
            guiManager.ShowEditDialogGui("", "")
        }
    }
    
    ; 编辑按钮点击事件处理
    static HandleEditClick(guiManager) {
        selectedIndex := guiManager.listBox.Value
        if (selectedIndex <= 0) {
            MsgBox("请先选择一个要编辑的软件")
            return
        }
        
        selectedText := guiManager.listBox.Text
        if (!guiManager.softwareMap.Has(selectedText)) {
            MsgBox("未找到选中的软件信息")
            return
        }
        
        software := guiManager.softwareMap[selectedText]
        guiManager.editMode := "edit"
        guiManager.currentEditSection := software["section"]

        ; >>> 保存要编辑的软件名称，用于编辑后重新选中
        guiManager.softwareToSelectAfterEdit := software["name"]
        
        guiManager.ShowEditDialogGui(software["name"], software["path"])
    }
    
    ; 删除按钮点击事件处理
    static HandleDeleteClick(guiManager) {
        selectedIndex := guiManager.listBox.Value
        if (selectedIndex <= 0) {
            MsgBox("请先选择一个要删除的软件")
            return
        }
        
        selectedText := guiManager.listBox.Text
        if (!guiManager.softwareMap.Has(selectedText)) {
            MsgBox("未找到选中的软件信息")
            return
        }
        
        software := guiManager.softwareMap[selectedText]
        
        ; 确认删除
        response := MsgBox("确定要删除 '" software["name"] "' 吗？", "确认删除", "YesNo")
        if (response != "Yes") {
            return
        }

        ; >>> 获取当前选中项之后的一项（如果有的话）
        nextItemText := ""
        try {
            ; 尝试获取下一项的文本
            guiManager.listBox.Value := selectedIndex + 1
            nextItemText := guiManager.listBox.Text
            ; 恢复原来的选中
            guiManager.listBox.Value := selectedIndex
        } catch {
            ; 没有下一项，尝试获取上一项
            if (selectedIndex > 1) {
                try {
                    guiManager.listBox.Value := selectedIndex - 1
                    nextItemText := guiManager.listBox.Text
                    guiManager.listBox.Value := selectedIndex
                } catch {
                    ; 也没有上一项
                }
            }
        }
        
        ; 从INI文件中删除
        if (!this.DeleteFromIniFile(guiManager,software["section"])) {
            MsgBox("删除失败，无法更新配置文件")
            return
        }
        
        ; 刷新列表
        guiManager.RefreshList()

        ; >>> 删除后尝试选中之前找到的下一项/上一项
        if (nextItemText != "") {
            this.SelectItemByText(guiManager, nextItemText)
        }
        
        MsgBox("删除成功！")
    }
    
    ; ==================== 刷新按钮事件处理 ====================
    
    ; 刷新按钮点击事件处理（特别注意userWasInSearchBox处理）
    static HandleRefreshClick(guiManager) {
        ; >>> 保存刷新前的状态
        searchBoxWasEmpty  := guiManager.searchBox.Value
        wasInSearchBox  := guiManager.userWasInSearchBox
        
        ; >>> 执行刷新
        guiManager.RefreshList()
        
        ; >>> 关键逻辑：如果应该跳过自动选中，确保不选中
        if (wasInSearchBox && searchBoxWasEmpty = '') {
            guiManager.listBox.Value := 0
            
            ; 尝试设置焦点
            try {
                ControlFocus(guiManager.searchBox, guiManager.gui)
            } catch as e {
                MsgBox("ControlFocus失败: " e.Message)
            }
        } else {
            ; >>> 只有条件不满足时才清除标记
            guiManager.userWasInSearchBox := false
        }
    }
    
    ; ==================== 定位按钮事件处理 ====================
    
    ; 定位按钮点击事件处理
    static HandleLocateClick(guiManager) {
        ; >>> 使用PathUtils工具类的SmartLocate方法
        if (guiManager.listBox.Value > 0) {
            ; 如果选择了软件
            selectedText := guiManager.listBox.Text
            if (!guiManager.softwareMap.Has(selectedText)) {
                return
            }
            software := guiManager.softwareMap[selectedText]
            PathUtils.LocateFile(software["path"])
            return
        }
        
        ; 没有选择软件，智能定位
        PathUtils.SmartLocate("", guiManager.rootPath)
    }
    
    ; ==================== 更多按钮事件处理 ====================
    
    ; 更多按钮点击事件处理
    static HandleMoreClick(guiManager) {
        ; 创建更多对话框
        moreGui := Gui()
        moreGui.Title := "更多操作 - " guiManager.configType
        moreGui.Opt("+AlwaysOnTop")

        ; 移除最小化按钮
        try {
           WinSetStyle("-0x00020000", moreGui.Hwnd)
        }
        
        ; 设置字体
        moreGui.SetFont("s9", "JetBrains Mono")

        ; 设置边距，减少顶部间距
        moreGui.MarginY := 5
        
        ; 添加说明
        moreGui.Add("Text", "w380 Center", "配置管理操作")
        moreGui.Add("Text", "w380 Center cGray", "管理" guiManager.configType ".ini 配置文件")

        ; 创建按钮 - 计算居中位置
        buttonWidth := 80
        buttonSpacing := 10
        totalWidth := (buttonWidth * 4) + (buttonSpacing * 3)
        dialogWidth := 400  ; 增加对话框宽度
        startX := (dialogWidth - totalWidth) // 2
        
        ; 创建按钮
        btnImport := moreGui.Add("Button", "x" startX " y+30 w80", "导入")
        btnExport := moreGui.Add("Button", "x+10 w80", "导出")
        btnAppend := moreGui.Add("Button", "x+10 w80", "追加")
        btnCancel := moreGui.Add("Button", "x+10 w80", "取消")
        
        ; 绑定事件
        btnImport.OnEvent("Click", (btnCtrl, info) => guiManager.HandleImport(moreGui))
        btnExport.OnEvent("Click", (btnCtrl, info) => guiManager.HandleExport(moreGui))
        btnAppend.OnEvent("Click", (btnCtrl, info) => guiManager.HandleAppend(moreGui))
        btnCancel.OnEvent("Click", (*) => moreGui.Destroy())
        
        moreGui.Show()
    }
    
    ; ==================== 打开软件事件处理 ====================
    
    ; 打开软件事件处理
    static HandleOpenSoftware(guiManager) {
        selectedIndex := guiManager.listBox.Value
        if (selectedIndex <= 0) {
            MsgBox("请先选择一个软件")
            return
        }
        
        selectedText := guiManager.listBox.Text
        if (!guiManager.softwareMap.Has(selectedText)) {
            return
        }
        
        software := guiManager.softwareMap[selectedText]
        path := software["path"]
        
        ; >>> 使用PathUtils工具类
        result := PathUtils.RunProgram(path)
        if (result !== true) {
            MsgBox(result)  ; 显示错误信息
            return
        }
        
        ; ==================== 打开软件后的业务 ====================
        if (guiManager.searchBox.Value != "") {
            ; >>> 情况1：搜索框有值，清空并设置焦点
            guiManager.searchBox.Value := ""
            guiManager.ShowAllSoftware()
            guiManager.listBox.Value := 0
            try {
                guiManager.searchBox.Focus()
                guiManager.userWasInSearchBox := true
            } catch {
                try {
                    ControlFocus(guiManager.searchBox, guiManager.gui)
                    guiManager.userWasInSearchBox := true
                } catch as e {
                    MsgBox("ControlFocus失败: " e.Message)
                }
            }
        } else {
            ; >>> 情况2：搜索框没值，保持选中刚才打开的项
            this.SelectItemInListBox(guiManager,software["name"])
        }
    }
    
    ; ==================== 搜索框事件处理 ====================
    
    ; 搜索框获得焦点事件处理
    static HandleSearchBoxFocus(guiManager) {
        guiManager.searchBoxHasFocus := true
        guiManager.userWasInSearchBox := true
        
        ; 如果搜索框为空，清除ListBox选中项
        if (guiManager.searchBox.Value = "") {
            guiManager.listBox.Value := 0
        }
    }
    
    ; 搜索框失去焦点事件处理
    static HandleSearchBoxLoseFocus(guiManager) {
        guiManager.searchBoxHasFocus := false

        ; >>> 延迟检查用户是否离开了搜索框
        SetTimer(() => guiManager.CheckIfUserLeftSearchBox(), -100)
    }
    
    ; ==================== ListBox事件处理 ====================
    
    ; ListBox获得焦点事件处理
    static HandleListBoxFocus(guiManager) {
        ; 只有当ListBox当前没有选中项时，才设置选中第一项
        if (guiManager.listBox.Value = 0) {
            ; 不是提示消息，设置为选中项
           if(!guiManager.IsFirstItemPrompt()){
                guiManager.listBox.Value := 1
           }
        }
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
            IniTools.FormatAndSaveIniFile(guiManager.configPath)
            
            return true
        } catch as e{
            MsgBox("保存配置文件时出错：`n" e.Message)
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
                IniTools.FormatAndSaveIniFile(guiManager.configPath)
                
                return true
            } else {
                MsgBox("在配置文件中未找到对应的section")
                return false
            }
        } catch as e {
            MsgBox("删除配置文件时出错：`n" e.Message)
            return false
        }
    }


    ; ==================== 保存软件事件处理 ====================
    
    ; 保存软件按钮点击事件处理
    static HandleSaveClick(editGui, guiManager, name, path, section, chkBatchAdd := "") {
        ; >>> 保存旧的选择信息
        oldSelectedText := ""
        isEditingMode := (guiManager.editMode = "edit")
        if (isEditingMode && guiManager.listBox.Value > 0) {
            oldSelectedText := guiManager.listBox.Text
        }

        ; 输入验证
        if (name = "") {
            MsgBox("软件名称不能为空", "提示", "Owner" editGui.Hwnd)
            return
        }
        
        if (path = "") {
             MsgBox("软件路径不能为空", "提示", "Owner" editGui.Hwnd)
            return
        }
        
        if (section = "") {
            MsgBox("Section名称不能为空", "提示", "Owner" editGui.Hwnd)
            return
        }

        ; >>> 使用统一的名称和路径校验
        if (!IniTools.IsValidName(name, 0, true)) {
            MsgBox("软件名称包含非法字符！`n`n"
                . "名称不能包含：\ / : * ? " . Chr(34) . " < > |`n"
                . "且不能以点开头或结尾", "提示", "Owner" editGui.Hwnd)
            return
        }

        if (!IniTools.IsValidPath(path, 0, true)) {
            MsgBox("软件路径格式不正确！`n`n"
                . "路径必须包含：`n"
                . "1. 盘符（如C:）`n"
                . "2. 路径分隔符（\或/）`n"
                . "3. 不能包含非法字符：* ? " . Chr(34) . " < > |", "提示", "Owner" editGui.Hwnd)
            return
        }

        ; 编辑模式下不允许创建Root
         if (guiManager.editMode = "edit") {
            if (section = "Root" || section = "root" || StrLower(section) = "root") {
                MsgBox("编辑模式不允许使用'Root'作为Section名称", "提示", "Owner" editGui.Hwnd)
                return
            }
        }

        ; ==================== 重名检查逻辑 ====================
        
        if (guiManager.editMode = "edit") {
            ; ************** 编辑模式检查逻辑 **************
            
            ; 检查新的section名称是否已存在（排除自身）
            if (section != guiManager.currentEditSection) {
                for displayName, software in guiManager.softwareMap {
                    ; 跳过自己（当前正在编辑的section）
                    if (software["section"] = guiManager.currentEditSection) {
                        continue
                    }

                    ; 如果尝试编辑为Root，不允许
                    if (StrLower(section) = "root" && StrLower(software["section"]) = "root") {
                        MsgBox("Root section已存在，请使用其他名称", "提示", "Owner" editGui.Hwnd)
                        return
                    }
                    
                    ; 检查其他软件是否有相同的section
                    if (software["section"] = section) {
                        MsgBox("Section名称已存在，请使用其他名称", "提示", "Owner" editGui.Hwnd)
                        return
                    }
                }
            }
            
            ; 检查新的软件名称是否已存在（排除自身）
            for displayName, software in guiManager.softwareMap {
                ; 跳过自己（当前正在编辑的软件）
                if (software["section"] = guiManager.currentEditSection) {
                    continue
                }
                
                ; 检查其他软件是否有相同的名称
                if (software["name"] = name) {
                    MsgBox("软件名称已存在，请使用其他名称", "提示", "Owner" editGui.Hwnd)
                    return
                }
            }
            
        } else if (guiManager.editMode = "create") {
            ; ************** 创建模式检查逻辑 **************
            
            ; >>> 修改：创建模式允许Root，但要检查唯一性
            if (StrLower(section) = "root") {
                ; 检查Root是否已存在
                for displayName, software in guiManager.softwareMap {
                    if (StrLower(software["section"]) = "root") {
                        ; Root已存在，覆盖是允许的
                        ; 这里不阻止，因为用户可能想要覆盖现有的Root
                        ; 只需要在更新INI时特殊处理
                        break
                    }
                }
            } else {
                ; 非Root项的正常检查
                ; 检查软件名称是否已存在
                for displayName, software in guiManager.softwareMap {
                    if (software["name"] = name) {
                        MsgBox("软件名称已存在，请使用其他名称", "提示", "Owner" editGui.Hwnd)
                        return
                    }
                }
                
                ; 检查section是否已存在
                for displayName, software in guiManager.softwareMap {
                    if (software["section"] = section) {
                        MsgBox("Section名称已存在，请使用其他名称", "提示", "Owner" editGui.Hwnd)
                        return
                    }
                }
            }
        }
        
        ; ==================== 更新INI文件 ====================
        
        ; 更新INI文件（用于：1.编辑模式但section未变化 2.创建模式）
        if (!this.UpdateIniFileWithRoot(guiManager, name, path, section, guiManager.editMode)) {
            MsgBox("保存失败，无法更新配置文件", "错误", "Owner" editGui.Hwnd)
            return
        }

        ; 显示保存成功提示
        this.ShowToolTip(guiManager, "保存成功！", 1500)
        
        ; 检查是否批量添加模式（只针对创建模式）
        isBatchMode := false
        if (guiManager.editMode = "create" && chkBatchAdd && chkBatchAdd != false && chkBatchAdd.Value = 1) {
            isBatchMode := true
        }
        
        if (!isBatchMode) {
            ; 非批量模式，关闭编辑窗口
            editGui.Destroy()
            
            ; >>> 刷新列表并根据模式选择相应的项
            if (guiManager.editMode = "edit") {
                ; 编辑模式：重新选中编辑的项（或新名称）
                this.RefreshAndSelect(guiManager,name)
            } else {
                ; 创建模式：选中新增的项
                this.RefreshAndSelect(guiManager,name)
            }
        } else {
            ; 批量模式，清空表单但不关闭窗口
            editGui.ctlName.Value := ""
            editGui.ctlPath.Value := ""
            editGui.ctlSection.Value := ""
            ; 将焦点设置到名称输入框，方便继续输入
            editGui.ctlName.Focus()
            
            ; >>> 刷新列表并选中新增的项
            this.RefreshAndSelect(guiManager,name)
        }
    }
    
    ; ==================== 浏览文件按钮事件处理 ====================
    
    ; 浏览文件按钮点击事件处理
    static HandleBrowseClick(pathControl) {
        ; >>> 使用PathUtils工具类
        selectedFile := PathUtils.BrowseForExecutable(pathControl.Value)
        if (selectedFile != "") {
            pathControl.Value := selectedFile
        }
    }
    
    ; ==================== 编辑对话框名称变化事件处理 ====================
    
    ; 编辑对话框名称变化事件处理
    static HandleNameChangeForEditGui(editGui, *) {
        editGui.ctlSection.Value := editGui.ctlName.Value
    }


    ; ==================== 工具方法 ====================
    
    ; 刷新列表并选择指定项
    static RefreshAndSelect(guiManager, itemNameToSelect := "") {
        ; 保存要选择的项名称
        guiManager.itemToSelectAfterRefresh := itemNameToSelect
        
        ; 重新加载配置
        configMgr := ConfigManager(guiManager.configType)
        guiManager.configManager := configMgr
        guiManager.softwareList := configMgr.GetSoftwareListArray()
        guiManager.rootPath := configMgr.GetRootPath()
        
        ; 重新填充原始列表
        guiManager.allSoftwareList := guiManager.softwareList
        
        ; 根据当前搜索文本重新过滤
        if (HasProp(guiManager, "searchBox") && guiManager.searchBox.Value != "") {
            guiManager.HandleSearchChange()
        } else {
            guiManager.ShowAllSoftware()
        }
        
        ; 如果有指定要选择的项，尝试选中它
        if (itemNameToSelect != "") {
            this.SelectItemByText(guiManager, itemNameToSelect)
        }
        
        ; 清除临时变量
        guiManager.itemToSelectAfterRefresh := ""
    }
    
    ; 根据文本选择列表项
    static SelectItemByText(guiManager, textToSelect) {
        if (textToSelect = "" || guiManager.showingPrompt) {
            return
        }
        
        ; 遍历所有软件项，查找匹配的文本
        for i in guiManager.allSoftwareList {
            if (i["name"] = textToSelect) {
                ; 找到了匹配的项，现在需要在ListBox中找到它
                this.SelectItemInListBox(guiManager, textToSelect)
                return
            }
        }
    }
    
    ; 在ListBox中选中指定文本的项
    static SelectItemInListBox(guiManager, textToSelect) {
        if (textToSelect = "" || guiManager.showingPrompt) {
            return
        }
        
        ; 先检查当前选中的项
        if (guiManager.listBox.Value > 0 && guiManager.listBox.Text = textToSelect) {
            return  ; 已经是选中的项
        }
        
        ; 从第1项开始查找
        index := 1
        found := false
        
        while (true) {
            try {
                guiManager.listBox.Value := index
                if (guiManager.listBox.Text = textToSelect) {
                    found := true
                    break  ; 找到了
                }
                index++
            } catch {
                break  ; 超出范围
            }
        }
        
        ; 如果没找到，清除选中状态
        if (!found) {
            try {
                guiManager.listBox.Value := 0
            } catch {
                ; 如果清除失败，不做处理
            }
        }
    }
    
    ; 显示工具提示的方法
    static ShowToolTip(guiManager, message, duration := 1500) {
        ; 在保存按钮位置显示提示
        ToolTip(message)
        SetTimer () => ToolTip(), -duration
    }
}