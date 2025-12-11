; ==============================
; GuiEventHandlers.ahk
; GUI事件处理工具类
; ==============================
class GuiEventHandlers {

    ; ==================== 主窗口右键事件处理 ====================
    ; >>> 新增：处理移动到目标配置
    static HandleMoveTo(guiManager, targetConfigType) {
        ; 获取选中的软件
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)
        
        ; 检查是否有选中项
        if (selectedTexts.Length = 0) {
            MsgBox("请先选择要移动的软件")
            return
        }
        
        ; 确认移动
        moveCount := selectedTexts.Length
        response := MsgBox("确定要将选中的 " moveCount " 个软件移动到 '" targetConfigType "' 吗？", "确认移动", "YesNo")
        if (response != "Yes") {
            return
        }
        
        ; >>> 修改：使用当前目录下的temp目录
        ; 获取脚本所在目录（common目录的父目录）
        tempDir := this.EnsureTempDirectory()
        if (tempDir = false) {
            return  ; 目录创建失败，直接返回
        }
        
        ; 创建临时TXT文件
        tempTxtPath := tempDir . "\" A_TickCount "_move.txt"
        if (!this.CreateMoveTxtFile(guiManager, selectedTexts, tempTxtPath)) {
            MsgBox("创建移动文件失败")
            return
        }
        
        ; 追加到目标配置
        if (this.AppendToConfig(targetConfigType, tempTxtPath)) {
            ; 复用删除逻辑删除原项
            if (selectedTexts.Length = 1) {
                this.HandleSingleDelete(guiManager, selectedTexts[1], true)  ; true表示是移动操作
            } else {
                this.HandleMultipleDelete(guiManager, selectedTexts, true)  ; true表示是移动操作
            }
            
            ; 显示成功消息
            if (moveCount = 1) {
                this.ShowToolTip(guiManager, "移动成功！", 1500)
            } else {
                this.ShowToolTip(guiManager, "成功移动 " moveCount " 个软件！", 1500)
            }
        } else {
            MsgBox("移动到目标配置失败")
        }
        
        ; >>> 修改：清理临时文件但不删除目录（保留temp目录）
        try {
            FileDelete(tempTxtPath)
        } catch as e {
            ; 忽略错误，只是临时文件清理失败不影响主要功能
            ; MsgBox("清理临时文件失败: " e.Message)  ; 可以注释掉，不显示错误
        }
    }
    
    ; >>> 修改：创建移动用的TXT文件（支持temp目录）
    static CreateMoveTxtFile(guiManager, selectedTexts, outputPath) {
        content := ""
        
        ; 构建TXT内容
        for text in selectedTexts {
            if (guiManager.softwareMap.Has(text)) {
                software := guiManager.softwareMap[text]
                content .= software["name"] "`r`n"
                content .= software["path"] "`r`n"
            }
        }
        
        ; 检查是否有内容
        if (content = "") {
            return false
        }
        
        ; 写入临时文件
        try {
            ; >>> 确保文件不存在
            if (FileExist(outputPath)) {
                FileDelete(outputPath)
            }
            
            ; 写入内容
            FileAppend(content, outputPath, "UTF-8")
            
            ; 验证文件是否创建成功
            if (!FileExist(outputPath)) {
                return false
            }
            
            return true
        } catch as e {
            ; 输出错误信息便于调试
            ; MsgBox("创建TXT文件失败: " e.Message "`n路径: " outputPath)
            return false
        }
    }
    
    ; >>> 修改：追加到目标配置（复用ImportExportManager）
    static AppendToConfig(targetConfigType, txtFilePath) {
        try {
            ; 检查文件是否存在
            if (!FileExist(txtFilePath)) {
                MsgBox("临时TXT文件不存在: " txtFilePath)
                return false
            }
            
            ; 获取目标配置的完整路径
            configMgr := ConfigManager(targetConfigType)
            configPath := configMgr.GetConfigPath()
            
            ; 检查目标配置文件是否存在
            if (!FileExist(configPath)) {
                ; 如果不存在，创建空文件
                FileAppend("", configPath, "UTF-8")
            }
            
            ; 创建ImportExportManager实例并调用追加方法
            importExportMgr := ImportExportManager(targetConfigType, configPath)
            
            ; >>> 复用ImportExportManager的追加逻辑
            ; 读取现有INI内容
            oldContent := FileRead(configPath)
            
            ; 读取要追加的TXT内容
            appendContent := FileRead(txtFilePath, "UTF-8")
            
            ; 验证追加内容
            if (!IniTools.ValidateTxtContent(appendContent, false, false)) {
                MsgBox("追加内容验证失败")
                return false
            }
            
            ; 解析要追加的TXT内容
            parsedData := ImportExportManager.ParseTxtContentWithRoot(appendContent)
            
            ; 合并内容
            mergedContent := ImportExportManager.MergeIniContentWithRoot(oldContent, parsedData)
            
            ; 写入文件
            FileDelete(configPath)
            FileAppend(mergedContent, configPath, "UTF-8")

            ; 格式化文件
            IniTools.FormatAndSaveIniFile(configPath)
            
            return true
        } catch as e {
            MsgBox("追加到目标配置失败: " e.Message)
            return false
        }
    }

    ; >>> 新增：确保temp目录存在的辅助方法
    static EnsureTempDirectory() {
        scriptDir := A_ScriptDir
        tempDir := scriptDir . "\temp"
        
        ; 如果目录不存在，创建它
        if (!DirExist(tempDir)) {
            try {
                DirCreate(tempDir)
                ; MsgBox("已创建临时目录: " tempDir)  ; 调试信息，可以注释掉
            } catch as e {
                MsgBox("创建临时目录失败: " e.Message)
                return false
            }
        }
        
        return tempDir
    }

    ; ==================== 主窗口按钮事件处理 ====================
    
    ; 创建按钮点击事件处理
    static HandleCreateClick(guiManager) {
        guiManager.editMode := "create"
        guiManager.currentEditSection := ""
        guiManager.ShowEditDialogGui("", "")
    }
    
    ; 编辑按钮点击事件处理
    static HandleEditClick(guiManager) {

        ; 直接获取选中的文本（因为按钮启用时一定是单选）
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)
        
        ; 检查是否有选中项
        if (selectedTexts.Length = 0) {
            MsgBox("请先选择一个要编辑的软件")
            return
        }

        ; 取第一个选中项（如果是多选，按钮会被禁用，所以这里应该是单选）
        selectedText := selectedTexts[1]
        
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
    static HandleBulkDeleteClick(guiManager) {
        ; 获取选中的文本数组
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)
        
        ; 检查是否有选中项
        if (selectedTexts.Length = 0) {
            MsgBox("请先选择要删除的软件")
            return
        }
        
        ; 判断是单选还是多选
        if (selectedTexts.Length = 1) {
            ; 单选情况：使用原有的删除逻辑
            this.HandleSingleDelete(guiManager, selectedTexts[1])
        } else {
            ; 多选情况：批量删除
            this.HandleMultipleDelete(guiManager, selectedTexts)
        }
    }

    ; >>> 修改：处理批量删除（同时处理单选和多选的数据类型）
    static HandleMultipleDelete(guiManager, selectedTexts,isMove := false) {
        ; 如果不是移动操作，显示确认对话框
        if (!isMove) {
            response := MsgBox("确定要删除选中的 " selectedTexts.Length " 个软件吗？", "确认删除", "YesNo")
            if (response != "Yes") {
                return
            }
        }
        
        ; 获取要删除的section列表
        sectionsToDelete := []
        for text in selectedTexts {
            if (guiManager.softwareMap.Has(text)) {
                software := guiManager.softwareMap[text]
                sectionsToDelete.Push(software["section"])
            }
        }
        
        ; >>> 在删除前获取关键信息
        totalItems := guiManager.allSoftwareList.Length  ; 删除前的总项目数
        
        ; >>> 边界情况：如果要删除所有项目
        if (sectionsToDelete.Length >= totalItems) {
            ; 如果不是移动操作，显示确认对话框
            if (!isMove) {
                ; 确认是否删除所有项目
                confirmResponse := MsgBox("确定要删除所有软件吗？这将清空整个列表。", "确认删除所有", 0x24)
                if (confirmResponse != "Yes") {
                    return
                }
            }
            
            ; 逐个删除选中的软件
            deletedCount := 0
            for section in sectionsToDelete {
                if (this.DeleteFromIniFile(guiManager, section)) {
                    deletedCount++
                }
            }
            
            ; 刷新列表（此时列表会为空）
            guiManager.RefreshList()
            
            ; 如果不是移动操作，显示删除成功消息
            if (!isMove && deletedCount > 0) {
                if (deletedCount = 1) {
                    this.ShowToolTip(guiManager, "删除成功！", 1500)
                } else {
                    this.ShowToolTip(guiManager, "成功删除 " deletedCount " 个软件！", 1500)
                }
            }
            
            return  ; 不需要尝试选择任何项
        }
        
        ; >>> 正常情况：不是删除所有项目
        selectedIndices := ListBoxHelper.GetSelectedIndices(guiManager.listBox)  ; 选中的索引
        
        ; >>> 智能查找删除后应该选中的项（改进版）
        nextItemText := ""
        
        if (selectedIndices.Length > 0) {
            ; 对索引进行排序（升序）
            sortedIndices := this.SimpleBubbleSort(selectedIndices.Clone())
            
            ; 获取最大的索引（排序后的最后一个）
            maxIndex := sortedIndices[sortedIndices.Length]
            
            ; >>> 判断是否包含最后一项
            containsLastItem := (maxIndex == totalItems)
            
            ; >>> 改进的智能选择逻辑（添加边界检查）
            try {
                if (containsLastItem) {
                    ; 如果包含最后一项，向上找
                    if (sortedIndices[1] > 1) {
                        ; 尝试选择第一个选中项的前一项
                        guiManager.listBox.Value := sortedIndices[1] - 1
                        nextItemText := ListBoxHelper.GetListBoxText(guiManager.listBox)
                    }
                } else {
                    ; 不包含最后一项，向下找
                    guiManager.listBox.Value := maxIndex + 1
                    nextItemText := ListBoxHelper.GetListBoxText(guiManager.listBox)
                }
            } catch {
                ; 如果上述方法失败，尝试备选方案
                try {
                    ; 尝试选择第一个选中项的位置（如果可行）
                    if (sortedIndices[1] <= guiManager.allSoftwareList.Length) {
                        guiManager.listBox.Value := sortedIndices[1]
                        nextItemText := ListBoxHelper.GetListBoxText(guiManager.listBox)
                    }
                } catch {
                    ; 如果还失败，尝试第一个有效项
                    for i in guiManager.allSoftwareList {
                        try {
                            guiManager.listBox.Value := A_Index
                            nextItemText := ListBoxHelper.GetListBoxText(guiManager.listBox)
                            break
                        } catch {
                            ; 继续尝试
                        }
                    }
                }
            }
        }
        
        ; 逐个删除选中的软件
        deletedCount := 0
        for section in sectionsToDelete {
            if (this.DeleteFromIniFile(guiManager, section)) {
                deletedCount++
            }
        }
        
        ; 刷新列表
        guiManager.RefreshList()
        
        ; 智能选择删除后的项（添加边界检查）
        if (nextItemText != "" && guiManager.allSoftwareList.Length > 0) {
            ; 使用新的选择方法，正确处理多选和单选
            this.SelectItemInListBox(guiManager, nextItemText)
        }
        
        ; 显示删除成功消息
        if (deletedCount > 0) {
            if (deletedCount = 1) {
                this.ShowToolTip(guiManager, "删除成功！", 1500)
            } else {
                this.ShowToolTip(guiManager, "成功删除 " deletedCount " 个软件！", 1500)
            }
        }
    }
    
    ; >>> 修改：处理单个删除
    static HandleSingleDelete(guiManager, selectedText,isMove := false) {
        if (!guiManager.softwareMap.Has(selectedText)) {
            MsgBox("未找到选中的软件信息")
            return
        }
        
        software := guiManager.softwareMap[selectedText]
        
        ; 如果不是移动操作，显示确认对话框
        if (!isMove) {
            software := guiManager.softwareMap[selectedText]
            response := MsgBox("确定要删除 '" software["name"] "' 吗？", "确认删除", "YesNo")
            if (response != "Yes") {
                return
            }
        }

        ; >>> 获取选中索引（正确处理多选和单选的数据类型）
        selectedIndices := ListBoxHelper.GetSelectedIndices(guiManager.listBox)
        selectedIndex := 0
        
        if (selectedIndices.Length > 0) {
            if (Type(selectedIndices[1]) = "Integer") {
                selectedIndex := selectedIndices[1]
            }
        }
        
        ; >>> 先获取总项目数
        totalItems := guiManager.allSoftwareList.Length
        if (totalItems == 0) {
            return
        }
        
        ; >>> 边界情况：如果只有一个项目
        if (totalItems == 1) {
            ; 从INI文件中删除
            if (!this.DeleteFromIniFile(guiManager, software["section"])) {
                MsgBox("删除失败，无法更新配置文件")
                return
            }
            
            ; 刷新列表（此时列表会为空）
            guiManager.RefreshList()
            
            this.ShowToolTip(guiManager, "删除成功！列表已清空", 1500)
            return  ; 不需要尝试选择任何项
        }
        
        ; 判断是否是最后一个项目
        isLastItem := (selectedIndex == totalItems)
        
        ; 从INI文件中删除
        if (!this.DeleteFromIniFile(guiManager, software["section"])) {
            MsgBox("删除失败，无法更新配置文件")
            return
        }
        
        ; 刷新列表
        guiManager.RefreshList()

        ; >>> 删除后尝试选中合适的项（添加边界检查）
        if (guiManager.allSoftwareList.Length > 0) {  ; 确保删除后还有项目
            if (isLastItem) {
                ; 删除的是最后一个项目，选择上一个（倒数第二个）
                try {
                    guiManager.listBox.Value := totalItems - 1
                } catch {
                    ; 如果失败，尝试选择第一个
                    try {
                        guiManager.listBox.Value := 1
                    } catch {
                        ; 如果还失败，就什么都不做
                    }
                }
            } else {
                ; 删除的不是最后一个项目，尝试保持当前位置
                ; 注意：删除后列表会缩短，所以selectedIndex可能超出范围
                try {
                    ; 先尝试选择原来的位置
                    guiManager.listBox.Value := selectedIndex
                } catch {
                    ; 如果超出范围，选择最后一个
                    try {
                        ; 获取删除后的总项目数
                        if (guiManager.allSoftwareList.Length > 0) {
                            guiManager.listBox.Value := guiManager.allSoftwareList.Length
                        }
                    } catch {
                        ; 如果还失败，就什么都不做
                    }
                }
            }
        }
        
        ; 如果不是移动操作，显示删除成功消息
        if (!isMove) {
            this.ShowToolTip(guiManager, "删除成功！", 1500)
        }
    }


    ; 简单的冒泡排序实现
    static SimpleBubbleSort(arr) {
        
        ; 如果数组只有一个元素或为空，直接返回
        if (arr.Length <= 1) {
            return arr
        }

        n := arr.Length
        Loop n {
            swapped := false
            Loop n - 1 {
                j := A_Index
                if (arr[j] > arr[j + 1]) {
                    temp := arr[j]
                    arr[j] := arr[j + 1]
                    arr[j + 1] := temp
                    swapped := true
                }
            }
            if (!swapped) {
                break
            }
        }
        return arr
    }

    ; 在ListBox中选中指定文本的项
    static SelectItemInListBox(guiManager, textToSelect) {
        if (textToSelect = "" || guiManager.showingPrompt) {
            return
        }
        
        ; >>> 简化逻辑：直接遍历查找
        ; 从第1项开始查找
        index := 1
        found := false
        
        while (true) {
            try {
                ; 临时选中该项以获取文本
                guiManager.listBox.Value := index
                
                ; 获取选中项的文本
                selectedText := ListBoxHelper.GetListBoxText(guiManager.listBox)
                
                ; 检查是否匹配
                if (selectedText = textToSelect) {
                    found := true
                    ; 保持选中状态
                    break
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
            ; 重新创建右键菜单
            guiManager.CreateContextMenu()
        }
    
    ; ==================== 定位按钮事件处理 ====================
    
    ; 定位按钮点击事件处理
    static HandleLocateClick(guiManager) {
        ; >>> 修改：按钮已被禁用时不会执行到这里，所以直接处理单选
        ; 获取选中的文本
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)
        
        ; 检查是否有选中项
        if (selectedTexts.Length = 0) {
            ; 没有选择软件，智能定位
            PathUtils.SmartLocate("", guiManager.rootPath)
            return
        }
        
        ; 取第一个选中项（如果是多选，按钮会被禁用，所以这里应该是单选）
        selectedText := selectedTexts[1]
        
        if (!guiManager.softwareMap.Has(selectedText)) {
            return
        }
        
        software := guiManager.softwareMap[selectedText]
        PathUtils.LocateFile(software["path"])
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
    
    ; 打开软件事件处理（支持多选，保持原有选中状态）
    static HandleOpenSoftware(guiManager) {
        ; 获取所有选中的软件
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)
        
        ; 检查是否有选中项
        if (selectedTexts.Length = 0) {
            MsgBox("请先选择一个软件")
            return
        }
        
        ; 判断是单选还是多选
        if (selectedTexts.Length == 1) {
            ; 单选情况：使用原有的单选逻辑
            this.HandleOpenSoftwareSingle(guiManager)
            return
        }
        
        ; 多选情况：打开所有选中软件，保持原有选中状态
        openedCount := 0
        failedCount := 0
        
        ; 逐个打开选中的软件
        for text in selectedTexts {
            if (!guiManager.softwareMap.Has(text)) {
                failedCount++
                continue
            }
            
            software := guiManager.softwareMap[text]
            path := software["path"]
            
            ; >>> 使用PathUtils工具类
            result := PathUtils.RunProgram(path)
            if (result = true) {
                openedCount++
            } else {
                failedCount++
            }
        }
        
        ; 显示打开结果
        if (openedCount > 0) {
            if (openedCount == 1) {
                this.ShowToolTip(guiManager, "已打开 1 个软件", 1500)
            } else {
                this.ShowToolTip(guiManager, "已打开 " openedCount " 个软件", 1500)
            }
        }
        
        ; >>> 重要：多选时不修改任何选中状态
        
        ; 如果有失败的情况，显示错误信息
        if (failedCount > 0) {
            if (failedCount == 1) {
                MsgBox("有 1 个软件打开失败，请检查路径是否正确")
            } else {
                MsgBox("有 " failedCount " 个软件打开失败，请检查路径是否正确")
            }
        }
    }
    
    ; 处理单选打开（保持原有逻辑）
    static HandleOpenSoftwareSingle(guiManager) {
        ; 获取选中的文本
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)
        
        ; 检查是否有选中项
        if (selectedTexts.Length = 0) {
            MsgBox("请先选择一个软件")
            return
        }
        
        ; 取第一个选中项
        selectedText := selectedTexts[1]
        
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
        
        ; 显示打开成功提示
        this.ShowToolTip(guiManager, "已打开 " software["name"], 1500)
        
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
                    ; 忽略焦点设置失败
                }
            }
        } else {
            ; >>> 情况2：搜索框没值，保持选中刚才打开的项
            this.SelectItemByText(guiManager, software["name"])
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
        if (isEditingMode && ListBoxHelper.GetListBoxText(guiManager.listBox) != "") {
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
    
    ; >>> 修改：根据文本选择列表项（处理单选和多选的数据类型）
    static SelectItemByText(guiManager, textToSelect) {
        if (textToSelect = "" || guiManager.showingPrompt) {
            return
        }

        ; 初始化 found 变量
        found := false
        
        ; 遍历ListBox中的所有项
        for index in guiManager.allSoftwareList {
            try {
                ; 选中当前项
                guiManager.listBox.Value := A_Index
                
                ; 获取选中项的文本
                currentText := ListBoxHelper.GetListBoxText(guiManager.listBox)
                
                ; 检查是否匹配
                if (currentText = textToSelect) {
                    ; 找到匹配项，保持选中状态
                    found := true
                    break
                }
            } catch {
                ; 继续下一项
                continue
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