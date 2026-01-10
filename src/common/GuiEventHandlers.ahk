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
            ; t_softmanager_settings：enableExtension-get
            ; t_softmanager_settings：batchThreshold-get
            enableExtension := SettingsManager.GetBool("EnableExtension")
            batchThreshold := SettingsManager.GetInt("BatchThreshold")
            
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

        ; 直接获取选中的文本（因为按钮启用时一定是单选）
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)
        
        ; 检查是否有选中项
        if (selectedTexts.Length = 0) {
            MessageManager.ShowError("请先选择要编辑的文件","提示")
            return
        }

        ; 取第一个选中项（如果是多选，按钮会被禁用，所以这里应该是单选）
        selectedText := selectedTexts[1]
        
        if (!guiManager.fileMap.Has(selectedText)) {
            MessageManager.ShowError("未找到选中的文件信息","提示")
            return
        }
        
        file := guiManager.fileMap[selectedText]
        guiManager.editMode := "edit"
        guiManager.currentEditSection := file["section"]

        ; >>> 保存要编辑的文件名称，用于编辑后重新选中
        guiManager.fileToSelectAfterEdit := file["name"]
        
        guiManager.ShowEditDialogGui(file["name"], file["path"])
    }

    ; 处理editGui关闭
    static HandleEditGuiClose(guiManager, editGui) {
        ; 恢复主窗口
        guiManager.gui.Opt("-Disabled")

        ; 销毁moreGui
        editGui.Destroy()

        ; 让搜索框进入焦点
        /* if(guiManager.listBox.Value = 0){
             guiManager.searchBox.Focus()
             guiManager.userWasInSearchBox := true
        } */

    }
    
    ; 删除按钮点击事件处理
    static HandleBulkDeleteClick(guiManager) {
        ; 获取选中的文本数组
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)
        
        ; 检查是否有选中项
        if (selectedTexts.Length = 0) {
            MessageManager.ShowError("请先选择要删除的文件","提示")
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
    static HandleMultipleDelete(guiManager, selectedTexts) {
        ; 确认删除
        response := MessageManager.ShowError("确定要删除选中的 " selectedTexts.Length " 个文件吗？", "确认删除", "YesNo")
        if (response != "Yes") {
            return
        }
        
        ; 获取要删除的section列表
        sectionsToDelete := []
        for text in selectedTexts {
            if (guiManager.fileMap.Has(text)) {
                file := guiManager.fileMap[text]
                sectionsToDelete.Push(file["section"])
            }
        }
        
        ; >>> 在删除前获取关键信息
        totalItems := guiManager.allFileList.Length  ; 删除前的总项目数
        
        ; >>> 边界情况：如果要删除所有项目
        if (sectionsToDelete.Length >= totalItems) {
            ; 确认是否删除所有项目
            ; confirmResponse := MsgBox("确定要删除所有文件吗？这将清空整个列表。", "确认删除所有", 0x24)
            confirmResponse := MessageManager.ShowConfirm(
                "确定要删除所有文件吗？这将清空整个列表。", 
                "确认删除所有"
            )
            if (confirmResponse != "Yes") {
                return
            }
            
            ; 逐个删除选中的文件
            deletedCount := 0
            for section in sectionsToDelete {
                if (IniTools.DeleteFromIniFile(guiManager, section)) {
                    deletedCount++
                }
            }
            
            ; 刷新列表（此时列表会为空）
            guiManager.RefreshList()
            
            ; 显示删除成功消息
            if (deletedCount > 0) {
                this.ShowToolTip(guiManager, "已清空所有文件！", 1500)
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
                    if (sortedIndices[1] <= guiManager.allFileList.Length) {
                        guiManager.listBox.Value := sortedIndices[1]
                        nextItemText := ListBoxHelper.GetListBoxText(guiManager.listBox)
                    }
                } catch {
                    ; 如果还失败，尝试第一个有效项
                    for i in guiManager.allFileList {
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
        
        ; 逐个删除选中的文件
        deletedCount := 0
        for section in sectionsToDelete {
            if (IniTools.DeleteFromIniFile(guiManager, section)) {
                deletedCount++
            }
        }
        
        ; 刷新列表
        guiManager.RefreshList()
        
        ; 智能选择删除后的项（添加边界检查）
        if (nextItemText != "" && guiManager.allFileList.Length > 0) {
            ; 使用新的选择方法，正确处理多选和单选
            this.SelectItemInListBox(guiManager, nextItemText)
        }
        
        ; 显示删除成功消息
        if (deletedCount > 0) {
            if (deletedCount = 1) {
                this.ShowToolTip(guiManager, "删除成功！", 1500)
            } else {
                this.ShowToolTip(guiManager, "成功删除 " deletedCount " 个文件！", 1500)
            }
        }
    }
    
    ; >>> 修改：处理单个删除
    static HandleSingleDelete(guiManager, selectedText) {
        if (!guiManager.fileMap.Has(selectedText)) {
            MessageManager.ShowError("未找到选中的文件信息","提示")
            return
        }
        
        file := guiManager.fileMap[selectedText]
        
        ; 确认删除
        response := MessageManager.ShowConfirm("确定要删除 '" file["name"] "' 吗？", "确认删除")
        if (response != "Yes") {
            return
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
        totalItems := guiManager.allFileList.Length
        if (totalItems == 0) {
            return
        }
        
        ; >>> 边界情况：如果只有一个项目
        if (totalItems == 1) {
            ; 从INI文件中删除
            if (!IniTools.DeleteFromIniFile(guiManager, file["section"])) {
                MessageManager.ShowError("删除失败，无法更新配置文件")
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
        if (!IniTools.DeleteFromIniFile(guiManager, file["section"])) {
            MessageManager.ShowError("删除失败，无法更新配置文件")
            return
        }
        
        ; 刷新列表
        guiManager.RefreshList()

        ; >>> 删除后尝试选中合适的项（添加边界检查）
        if (guiManager.allFileList.Length > 0) {  ; 确保删除后还有项目
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
                        if (guiManager.allFileList.Length > 0) {
                            guiManager.listBox.Value := guiManager.allFileList.Length
                        }
                    } catch {
                        ; 如果还失败，就什么都不做
                    }
                }
            }
        }
        
        this.ShowToolTip(guiManager, "删除成功！", 1500)
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
                    MessageManager.ShowError("ControlFocus失败: " e.Message)
                }
            } else {
                ; >>> 只有条件不满足时才清除标记
                guiManager.userWasInSearchBox := false
            }
        }
    
    ; ==================== 定位按钮事件处理 ====================
    
    ; 定位按钮点击事件处理
    static HandleLocateClick(guiManager) {
        ; >>> 修改：按钮已被禁用时不会执行到这里，所以直接处理单选
        ; 获取选中的文本
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)
        
        ; 检查是否有选中项
        if (selectedTexts.Length = 0) {
            ; 没有选择文件，智能定位
            PathUtils.SmartLocate("", guiManager.rootPath)
            return
        }
        
        ; 取第一个选中项（如果是多选，按钮会被禁用，所以这里应该是单选）
        selectedText := selectedTexts[1]
        
        if (!guiManager.fileMap.Has(selectedText)) {
            return
        }
        
        file := guiManager.fileMap[selectedText]
        PathUtils.LocateFile(file["path"])
    }
    
    ; ==================== 设置按钮事件处理 ====================
    
    ; 设置按钮点击事件处理
    static HandleSettingClick(guiManager) {
        SettingsDialogManager.ShowSettingsDialog(guiManager)
    }

    
    ; ==================== 打开文件事件处理 ====================
    
    ; 打开文件事件处理（支持多选，保持原有选中状态）
    static HandleOpenFile(guiManager) {
        ; 获取所有选中的文件
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)
        
        ; 检查是否有选中项
        if (selectedTexts.Length = 0) {
            MessageManager.ShowError("请先选择文件","提示")
            return
        }
        
        ; 判断是单选还是多选
        if (selectedTexts.Length == 1) {
            ; 单选情况：使用原有的单选逻辑
            this.HandleOpenFileSingle(guiManager)
            return
        }
        
        ; 多选情况：打开所有选中文件，保持原有选中状态
        openedCount := 0
        failedCount := 0
        
        ; 逐个打开选中的文件
        for text in selectedTexts {
            if (!guiManager.fileMap.Has(text)) {
                failedCount++
                continue
            }
            
            file := guiManager.fileMap[text]
            path := file["path"]
            
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
                this.ShowToolTip(guiManager, "已打开 1 个文件", 1500)
            } else {
                this.ShowToolTip(guiManager, "已打开 " openedCount " 个文件", 1500)
            }
        }
        
        ; >>> 重要：多选时不修改任何选中状态
        
        ; 如果有失败的情况，显示错误信息
        if (failedCount > 0) {
            if (failedCount == 1) {
                MessageManager.ShowError("有 1 个文件打开失败，请检查路径是否正确")
            } else {
                MessageManager.ShowError("有 " failedCount " 个文件打开失败，请检查路径是否正确")
            }
        }
    }
    
    ; 处理单选打开（保持原有逻辑）
    static HandleOpenFileSingle(guiManager) {
        ; 获取选中的文本
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)
        
        ; 检查是否有选中项
        if (selectedTexts.Length = 0) {
            MessageManager.ShowError("请先选择一个文件")
            return
        }

        ; 检查是否是提示项（列表为空时显示的提示信息）
        if (guiManager.listEmptyPrompt && guiManager.showingPrompt) {
            ; 是列表完全为空的提示项，执行载入操作
            guiManager.importExportMgr.HandleLoad("", guiManager)
            return
        }
        
        ; 取第一个选中项
        selectedText := selectedTexts[1]
        
        if (!guiManager.fileMap.Has(selectedText)) {
            return
        }
        
        file := guiManager.fileMap[selectedText]
        path := file["path"]
        
        ; >>> 使用PathUtils工具类
        result := PathUtils.RunProgram(path)
        if (result !== true) {
            MessageManager.ShowError(result) ; 显示错误信息
            return
        }
        
        ; 显示打开成功提示
        this.ShowToolTip(guiManager, "已打开 " file["name"], 1500)
        
        ; ==================== 打开文件后的业务 ====================
        if (guiManager.searchBox.Value != "") {
            ; >>> 情况1：搜索框有值，清空并设置焦点
            guiManager.searchBox.Value := ""
            guiManager.ShowAllFile()
            guiManager.listBox.Value := 0
            try {
                guiManager.searchBox.Focus()
                guiManager.userWasInSearchBox := true
            } catch {
                try {
                    ControlFocus(guiManager.searchBox, guiManager.gui)
                    guiManager.userWasInSearchBox := true
                } catch as e {
                    MessageManager.ShowError("ControlFocus失败: " e.Message)
                }
            }
        } else {
            ; >>> 情况2：搜索框没值，保持选中刚才打开的项
            this.SelectItemByText(guiManager, file["name"])
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
        if (ListBoxHelper.GetSelectedIndices(guiManager.listBox).Length = 0) {
            ; 不是提示消息，设置为选中项
        ;    if(!guiManager.IsFirstItemPrompt()){
                guiManager.listBox.Value := 1
        ;    }
        }
    }

    ; ==================== 保存文件事件处理 ====================
    
    ; 保存文件按钮点击事件处理
    static HandleSaveClick(editGui, guiManager, name, path, section, chkBatchAdd := "") {
        ; >>> 保存旧的选择信息
        oldSelectedText := ""
        isEditingMode := (guiManager.editMode = "edit")
        if (isEditingMode && ListBoxHelper.GetListBoxText(guiManager.listBox) != "") {
            oldSelectedText := guiManager.listBox.Text
        }

        ; 输入验证
        if (name = "") {
            MessageManager.ShowError("文件名称不能为空", "提示", ,editGui.Hwnd)
            return
        }
        
        if (path = "") {
             MessageManager.ShowError("文件路径不能为空", "提示", ,editGui.Hwnd)
            return
        }
        
        if (section = "") {
            MessageManager.ShowError("Section名称不能为空", "提示", ,editGui.Hwnd)
            return
        }

        ; >>> 使用统一的名称和路径校验
        if (!IniTools.IsValidName(name, 0, true)) {
            MessageManager.ShowError(
                "文件名称包含非法字符！`n`n"
                . "名称不能包含：\ / : * ? " . Chr(34) . " < > |`n"
                . "且不能以点开头或结尾", "提示", , editGui.Hwnd
            )
            return
        }

        if (!IniTools.IsValidPath(path, 0, true)) {
            MessageManager.ShowError(
                "文件路径格式不正确！`n`n"
                . "路径必须包含：`n"
                . "1. 盘符（如C:）`n"
                . "2. 路径分隔符（\或/）`n"
                . "3. 不能包含非法字符：* ? " . Chr(34) . " < > |", "提示", , editGui.Hwnd
            )
            return
        }

        ; 编辑模式下不允许创建Root
         if (guiManager.editMode = "edit") {
            if (section = "Root" || section = "root" || StrLower(section) = "root") {
                MessageManager.ShowError(
                    "编辑模式不允许使用'Root'作为Section名称", "提示", , editGui.Hwnd
                )
                return
            }
        }

        ; ==================== 重名检查逻辑 ====================
        
        if (guiManager.editMode = "edit") {
            ; ************** 编辑模式检查逻辑 **************
            
            ; 检查新的section名称是否已存在（排除自身）
            if (section != guiManager.currentEditSection) {
                for displayName, file in guiManager.fileMap {
                    ; 跳过自己（当前正在编辑的section）
                    if (file["section"] = guiManager.currentEditSection) {
                        continue
                    }

                    ; 如果尝试编辑为Root，不允许
                    if (StrLower(section) = "root" && StrLower(file["section"]) = "root") {
                        MessageManager.ShowError(
                            "Root section已存在，请使用其他名称", "提示", , editGui.Hwnd
                        )
                        return
                    }
                    
                    ; 检查其他文件是否有相同的section
                    if (file["section"] = section) {
                        MessageManager.ShowError(
                           "Section名称已存在，请使用其他名称", "提示", , editGui.Hwnd 
                        )
                        return
                    }
                }
            }
            
            ; 检查新的文件名称是否已存在（排除自身）
            for displayName, file in guiManager.fileMap {
                ; 跳过自己（当前正在编辑的文件）
                if (file["section"] = guiManager.currentEditSection) {
                    continue
                }
                
                ; 检查其他文件是否有相同的名称
                if (file["name"] = name) {
                    MessageManager.ShowError(
                        "文件名称已存在，请使用其他名称", "提示", , editGui.Hwnd
                    )
                    return
                }
            }
            
        } else if (guiManager.editMode = "create") {
            ; ************** 创建模式检查逻辑 **************
            
            ; >>> 修改：创建模式允许Root，但要检查唯一性
            if (StrLower(section) = "root") {
                ; 检查Root是否已存在
                for displayName, file in guiManager.fileMap {
                    if (StrLower(file["section"]) = "root") {
                        ; Root已存在，覆盖是允许的
                        ; 这里不阻止，因为用户可能想要覆盖现有的Root
                        ; 只需要在更新INI时特殊处理
                        break
                    }
                }
            } else {
                ; 非Root项的正常检查
                ; 检查文件名称是否已存在
                for displayName, file in guiManager.fileMap {
                    if (file["name"] = name) {
                        MessageManager.ShowError(
                            "文件名称已存在，请使用其他名称", "提示", , editGui.Hwnd
                        )
                        return
                    }
                }
                
                ; 检查section是否已存在
                for displayName, file in guiManager.fileMap {
                    if (file["section"] = section) {
                        MessageManager.ShowError(
                            "Section名称已存在，请使用其他名称", "提示", , editGui.Hwnd
                        )
                        return
                    }
                }
            }
        }
        
        ; ==================== 更新INI文件 ====================
        
        ; 更新INI文件（用于：1.编辑模式但section未变化 2.创建模式）
        if (!IniTools.UpdateIniFileWithRoot(guiManager, name, path, section, guiManager.editMode)) {
            MessageManager.ShowError(
                "保存失败，无法更新配置文件", "错误", , editGui.Hwnd
            )
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
            ; editGui.Destroy()
            this.HandleEditGuiClose(guiManager,editGui)
            
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

    ; ==================== 拖拽事件处理 ====================

    ; 新增：处理拖放文件到编辑对话框的事件
    ; 拖放文件回调
    static OnDropFilesCallback(guiObj, ctrlObj, filesArray, x, y) {
        try {
            if (filesArray.Length > 0) {
                filePath := filesArray[1]

                ; 判断拖拽到哪个控件
                local targetControl := ctrlObj
                local isNameControl := false
                local isPathControl := false
                
                if (targetControl && guiObj) {
                    ; 检查是否是名称控件
                    if (guiObj.ctlName && targetControl.Hwnd == guiObj.ctlName.Hwnd) {
                        isNameControl := true
                    }
                    ; 检查是否是路径控件
                    else if (guiObj.ctlPath && targetControl.Hwnd == guiObj.ctlPath.Hwnd) {
                        isPathControl := true
                    }
                }

                ; 使用统一的方法更新文件路径和名称
                GuiEventHandlers.UpdateFilePathAndName(guiObj, filePath,true,isNameControl, isPathControl, targetControl)
            }
        } catch {
            ; 静默处理
        }
    }

    ; ==================== 文件路径更新处理 ====================
    
    ; 统一的文件路径更新方法
    static UpdateFilePathAndName(editGui, filePath,fromDrag := false,isNameControl := false, isPathControl := false, targetControl := 0) {
        try {
            if (!editGui || !filePath) {
                return
            }
            
            ; 更新路径控件
            if (editGui.ctlPath) {
                editGui.ctlPath.Value := filePath
            }
            
            ; 更新文件名
            if (editGui.ctlName) {
                enableExtension := SettingsManager.GetBool("EnableExtension")
                SplitPath(filePath, &fileName, &fileDir, &fileExt, &fileNameNoExt)
                
                displayName := enableExtension ? fileName : fileNameNoExt
                editGui.ctlName.Value := displayName
                
                /* if (editGui.ctlSection) {
                    editGui.ctlSection.Value := displayName
                } */
            }

            ; 如果是拖拽操作，处理焦点和光标位置
            if (fromDrag) {
                ; 根据拖拽的目标控件设置焦点
                if (isNameControl && editGui.ctlName.Hwnd) {
                    editGui.ctlName.Focus()
                    ; 设置光标在末尾而不选中文本
                    SendMessage(0x00B1, -1, -1, editGui.ctlName) ; EM_SETSEL 消息，-1 表示末尾
                }
                else if (isPathControl && editGui.ctlPath.Hwnd) {
                    editGui.ctlPath.Focus()
                    ; 设置光标在末尾而不选中文本
                    SendMessage(0x00B1, -1, -1, editGui.ctlPath) ; EM_SETSEL 消息，-1 表示末尾
                }
                ; 如果拖拽到窗口但没指定控件，默认焦点到名称控件
                else if (!isNameControl && !isPathControl && editGui.ctlName.Hwnd) {
                    editGui.ctlName.Focus()
                    SendMessage(0x00B1, -1, -1, editGui.ctlName) ; EM_SETSEL 消息，-1 表示末尾
                }
            }

            ; 手动调用HandleNameChangeForEditGui来处理section逻辑
            if (editGui.ctlName) {
                GuiEventHandlers.HandleNameChangeForEditGui(editGui)
            }

        } catch Error as e {
            ; 静默处理错误
        }
    }
    
    ; ==================== 浏览文件按钮事件处理 ====================
    
    ; 浏览文件按钮点击事件处理
    static HandleBrowseClick(pathControl,editGui,isTop) {
        ; >>> 使用PathUtils工具类
        selectedFile := PathUtils.BrowseForExecutable(pathControl.Value,editGui,isTop)
        if (selectedFile != "" && editGui) {
            ; 使用统一的方法更新文件路径和名称
            GuiEventHandlers.UpdateFilePathAndName(editGui, selectedFile,false)
        } else if (selectedFile != "") {
            ; 如果没有提供 editGui，只更新路径
            pathControl.Value := selectedFile
        }
    }
    
    ; ==================== 编辑对话框名称变化事件处理 ====================
    
    ; 编辑对话框名称变化事件处理
    static HandleNameChangeForEditGui(editGui, *) {
        nameValue := editGui.ctlName.Value
        pathValue := editGui.ctlPath.Value
        
        ; 检查路径是否为空
        if (pathValue = "") {
            ; 如果路径为空，直接使用名称作为section
            editGui.ctlSection.Value := nameValue
            return
        }
        
        ; 从路径中提取文件名（包含扩展名）
        pathFileName := ""
        try {
            ; 获取路径的文件名部分
            SplitPath(pathValue, &pathFileName)
        } catch {
            pathFileName := ""
        }
        
        ; 比较名称和路径文件名
        if (pathFileName != "" && nameValue = pathFileName) {
            ; 情况1：名称与路径文件名完全相同（包含扩展名）
            ; 去除扩展名作为section
            if (InStr(nameValue, ".")) {
                dotPos := InStr(nameValue, ".", , -1)
                if (dotPos > 1) {
                    editGui.ctlSection.Value := SubStr(nameValue, 1, dotPos - 1)
                    return
                }
            }
        }
        
        ; 其他情况：直接使用名称作为section
        editGui.ctlSection.Value := nameValue
    }


    ; ==================== 工具方法 ====================
    
    ; 刷新列表并选择指定项
    static RefreshAndSelect(guiManager, itemNameToSelect := "") {
        ; 保存要选择的项名称
        guiManager.itemToSelectAfterRefresh := itemNameToSelect
        
        ; 重新加载配置
        configMgr := ConfigManager(guiManager.configType)
        guiManager.configManager := configMgr
        guiManager.fileList := configMgr.GetFileListArray()
        guiManager.rootPath := configMgr.GetRootPath()
        
        ; 重新填充原始列表
        guiManager.allFileList := guiManager.fileList
        
        ; 根据当前搜索文本重新过滤
        if (HasProp(guiManager, "searchBox") && guiManager.searchBox.Value != "") {
            guiManager.HandleSearchChange()
        } else {
            guiManager.ShowAllFile()
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
        for index in guiManager.allFileList {
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