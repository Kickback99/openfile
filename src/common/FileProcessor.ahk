; ==============================
; FileProcessor.ahk
; 文件处理工具类（批量创建、文件选择等）
; ==============================
class FileProcessor {
    ; ++++ 创建单个文件并返回名称（不显示进度条） ++++
    static CreateSingleFileAndReturnName(guiManager, filePath, enableExtension) {
        ; 首先检查文件是否存在
        if (!FileExist(filePath)) {
            ; 文件不存在，显示错误
            MessageManager.ShowError("文件不存在：`n" filePath,"错误")
            return ""
        }
        try {
            ; 解析文件名和路径
            SplitPath(filePath, &fileName, &fileDir, &fileExt, &fileNameNoExt)
            
            ; 确定显示名称
            displayName := ""
            if (enableExtension && fileExt != "") {
                displayName := fileName  ; 包含扩展名
            } else {
                displayName := fileNameNoExt  ; 不包含扩展名
            }
            
            ; 设置section名称
            sectionName := fileNameNoExt
            
            ; 检查是否已存在同名软件
            duplicateFound := false
            for existingName, software in guiManager.softwareMap {
                if (software["name"] = displayName) {
                    duplicateFound := true
                    response := MessageManager.ShowConfirm("已存在同名软件 '" . displayName . "'。是否覆盖？", "确认覆盖", "YesNo")
                    if (response != "Yes") {
                        return ""  ; 跳过这个文件
                    }
                    break
                }
            }
            
            ; 调用保存逻辑（使用GuiEventHandlers的方法）
            success := IniTools.UpdateIniFileWithRoot(guiManager, displayName, filePath, sectionName, "create")
            
            if (success) {
                ; 格式化文件
                IniTools.FormatAndSaveIniFile(guiManager.configPath)
                ; 显示单个文件的成功提示
                if (duplicateFound) {
                    GuiEventHandlers.ShowToolTip(guiManager, "已覆盖: " . displayName, 1500)
                } else {
                    GuiEventHandlers.ShowToolTip(guiManager, "已添加: " . displayName, 1500)
                }
                
                return displayName
            }
            
        } catch as e {
            ; 静默失败
        }
        
        return ""
    }
    
    ; ++++ 获取资源管理器中选中的所有文件（支持多选） ++++
    static GetSelectedFilesInExplorer(explorerHwnd) {
        selectedFiles := []
        
        try {
            shell := ComObject("Shell.Application")
            windows := shell.Windows
            
            loopCount := windows.Count
            Loop loopCount {
                try {
                    i := A_Index - 1
                    window := windows.Item(i)
                    
                    if (window && window.HWND = explorerHwnd) {
                        ; 获取所有选中的项目
                        selection := window.Document.SelectedItems
                        if (selection && selection.Count > 0) {
                            itemCount := selection.Count
                            Loop itemCount {
                                try {
                                    j := A_Index - 1
                                    item := selection.Item(j)
                                    if (item) {
                                        selectedFiles.Push(item.Path)
                                    }
                                }
                            }
                        }
                        break
                    }
                }
            }
        } catch as e {
            ; 静默失败
        }
        
        return selectedFiles
    }
    
    ; ++++ 批量从选中的文件创建软件条目 ++++
    static BatchCreateFromSelectedFiles(guiManager, filePaths, enableExtension) {

        ; 首先过滤掉不存在的文件
        validFiles := []
        for filePath in filePaths {
            if (FileExist(filePath)) {
                validFiles.Push(filePath)
            } else {
                ; 可以在这里记录日志或提示用户
                ; 文件不存在，显示错误
                MessageManager.ShowError("文件不存在：`n" filePath)
                return ""
            }
        }
        
        if (validFiles.Length = 0) {
            MessageManager.ShowError("没有有效的文件可以处理")
            return ""
        }

        lastAddedName := ""
        successCount := 0
        ; totalCount := filePaths.Length
        totalCount := validFiles.Length  ; 使用有效文件的数量

        ;!!! 添加：创建中止标志变量
        isCancelled := false
        
        ; 显示批量操作进度
        progressGui := Gui()
        progressGui.Title := "批量创建中..."
        progressGui.Opt("+AlwaysOnTop +ToolWindow")
        progressGui.Add("Text", "w300 Center", "正在批量创建软件条目...")
        progressText := progressGui.Add("Text", "w300 Center", "准备开始 (0/" . totalCount . ")")

        ;!!! 添加：创建中止按钮
        cancelBtn := progressGui.Add("Button", "x250 y5 w60", "中止")
    
        ;!!! 添加：中止按钮点击事件
        cancelBtn.OnEvent("Click", (*) => isCancelled := true)
        
        ; 计算窗口位置：屏幕顶部居中
        screenWidth := A_ScreenWidth
        screenHeight := A_ScreenHeight
        
        ; 设置窗口大小
        windowWidth := 320
        
        ; 计算位置：屏幕顶部居中，尽量靠上
        windowX := (screenWidth - windowWidth) // 2
        windowY := 20
        
        ; 显示窗口在指定位置
        progressGui.Show("x" . windowX . " y" . windowY . " w" . windowWidth)
        
        ; 添加延迟确保窗口完全显示
        Sleep(100)
        
        try {
            for i, filePath in validFiles {
                ;!!! 添加：检查中止标志
                if (isCancelled) {
                    progressText.Value := "已中止 - 已处理 " . successCount . "/" . totalCount
                    Sleep(500)  ; 让用户看到中止状态
                    break
                }

                try {
                    ; 更新进度显示 - 添加适当延迟让用户能看到变化
                    progressText.Value := "正在处理: " . (i) . "/" . totalCount
                    Sleep(100)  ; 让用户能看到进度变化
                    
                    ; 解析文件名和路径
                    SplitPath(filePath, &fileName, &fileDir, &fileExt, &fileNameNoExt)
                    
                    ; 确定显示名称
                    displayName := ""
                    if (enableExtension && fileExt != "") {
                        displayName := fileName  ; 包含扩展名
                    } else {
                        displayName := fileNameNoExt  ; 不包含扩展名
                    }
                    
                    ; 设置section名称
                    sectionName := fileNameNoExt
                    
                    ; 检查是否已存在同名软件
                    duplicateFound := false
                    for existingName, software in guiManager.softwareMap {
                        if (software["name"] = displayName) {
                            duplicateFound := true
                            
                            ; 批量模式下，如果已存在同名软件，询问是否覆盖
                            response := MessageManager.ShowConfirm("已存在同名软件 '" . displayName . "'。是否覆盖？", "确认覆盖", "YesNo")
                            if (response != "Yes") {
                                ; 跳过这个文件
                                continue
                            }
                            break
                        }
                    }
                    
                    ; 调用保存逻辑（使用GuiEventHandlers的方法）
                    success := GuiEventHandlers.UpdateIniFileWithRoot(guiManager, displayName, filePath, sectionName, "create")
                    
                    if (success) {
                        successCount++
                        lastAddedName := displayName  ; 记录最后添加的项
                        
                        ; 立即刷新列表，让softwareMap保持最新
                        guiManager.RefreshList()
                        
                        ; 添加短暂延迟让用户感知到处理完成
                        Sleep(50)
                    }
                    
                } catch as e {
                    ; 单个文件失败，继续处理下一个
                    continue
                }
            }
            
            ; 进度完成后保持显示一小段时间
            ;!!! 修改：处理完成或中止后的逻辑
            if (!isCancelled && successCount > 0) {
                ; 格式化文件
                IniTools.FormatAndSaveIniFile(guiManager.configPath)
                progressText.Value := "处理完成: " . successCount . "/" . totalCount
                Sleep(500)  ; 让用户看到完成状态
            }
            
            ; 关闭进度窗口
            progressGui.Destroy()
            
            ; 显示批量操作结果
            if (isCancelled) {
                GuiEventHandlers.ShowToolTip(guiManager, "批量创建已中止，已处理 " . successCount . " 个文件", 2000)
            } else if (successCount > 0) {
                if (successCount = totalCount) {
                    GuiEventHandlers.ShowToolTip(guiManager, "批量创建完成，共添加 " . successCount . " 个文件", 2000)
                } else {
                    GuiEventHandlers.ShowToolTip(guiManager, "批量创建完成，成功 " . successCount . "/" . totalCount, 2000)
                }
            } else {
                MessageManager.ShowError("批量创建失败，请检查配置")
            }
            
        } catch as e {
            progressGui.Destroy()
            MessageManager.ShowError("批量创建过程中出错：`n" . e.Message)
        }
        
        return lastAddedName
    }
    
}