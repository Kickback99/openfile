; ==============================
; ContextMenuManager.ahk
; 右键菜单相关功能管理
; ==============================
class ContextMenuManager {
    ; ==================== 主窗口右键事件处理 ====================
    
    ; 复制功能（复用移动逻辑但保留原项）
    static HandleCopyTo(guiManager, targetConfigType) {
        ; 获取选中的文件
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)
        
        ; 检查是否有选中项
        if (selectedTexts.Length = 0) {
            MessageManager.ShowError("请先选择要复制的文件")
            return
        }
        
        ; 确认复制
        copyCount := selectedTexts.Length
        response := MessageManager.ShowConfirm("确定要将选中的 " copyCount " 个文件复制到 '" targetConfigType "' 吗？", "确认复制", "YesNo")
        if (response != "Yes") {
            return
        }
        
        ; 执行复制操作
        this.ExecuteCopyOrMove(guiManager, selectedTexts, targetConfigType, false)  ; false表示复制操作
    }

    ; 处理移动到目标配置
    static HandleMoveTo(guiManager, targetConfigType) {
        ; 获取选中的文件
        selectedTexts := ListBoxHelper.GetSelectedTexts(guiManager.listBox)
        
        ; 检查是否有选中项
        if (selectedTexts.Length = 0) {
            MessageManager.ShowError("请先选择要移动的文件")
            return
        }
        
        ; 确认移动
        moveCount := selectedTexts.Length
        response := MessageManager.ShowConfirm("确定要将选中的 " moveCount " 个文件移动到 '" targetConfigType "' 吗？", "确认移动", "YesNo")
        if (response != "Yes") {
            return
        }
        
        ; 执行移动操作
        this.ExecuteCopyOrMove(guiManager, selectedTexts, targetConfigType, true)  ; true表示移动操作
    }
    
    ; 创建移动用的TXT文件（支持temp目录）
    static CreateMoveTxtFile(guiManager, selectedTexts, outputPath) {
        content := ""
        
        ; 构建TXT内容
        for text in selectedTexts {
            if (guiManager.fileMap.Has(text)) {
                file := guiManager.fileMap[text]
                content .= file["name"] "`r`n"
                content .= file["path"] "`r`n"
            }
        }
        
        ; 检查是否有内容
        if (content = "") {
            return false
        }
        
        ; 写入临时文件
        try {
            ; 确保文件不存在
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
            MessageManager.ShowError("创建TXT文件失败: " e.Message "`n路径: " outputPath)
            return false
        }
    }
    
    ; 追加到目标配置（复用ImportExportManager）
    static AppendToConfig(targetConfigType, txtFilePath) {
        try {
            ; 检查文件是否存在
            if (!FileExist(txtFilePath)) {
                MessageManager.ShowError("临时TXT文件不存在: " txtFilePath)
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
            
            ; 复用ImportExportManager的追加逻辑
            ; 读取现有INI内容
            oldContent := FileRead(configPath)
            
            ; 读取要追加的TXT内容
            appendContent := FileRead(txtFilePath, "UTF-8")
            
            ; 验证追加内容
            /* if (!IniTools.ValidateTxtContent(appendContent, false, false, false)) {
                MessageManager.ShowError("追加内容验证失败")
                return false
            } */
            
            ; 解析要追加的TXT内容
            parsedData := ImportExportManager.ParseTxtContentWithRootLegacy(appendContent)
            
            ; 合并内容
            mergedContent := ImportExportManager.MergeIniContentWithRoot(oldContent, parsedData)
            
            ; 写入文件
            FileDelete(configPath)
            FileAppend(mergedContent, configPath, "UTF-8")

            ; 格式化文件
            IniTools.FormatAndSaveIniFile(configPath)
            
            return true
        } catch as e {
            MessageManager.ShowError("追加到目标配置失败: " e.Message)
            return false
        }
    }

    ; 统一的复制/移动执行方法
    static ExecuteCopyOrMove(guiManager, selectedTexts, targetConfigType, isMove) {
        ; 获取脚本所在目录（common目录的父目录）
        tempDir := this.EnsureTempDirectory()
        if (tempDir = false) {
            return  ; 目录创建失败，直接返回
        }
        
        ; 创建临时TXT文件
        timestamp := A_TickCount
        actionType := isMove ? "move" : "copy"
        ; 使用时间戳和随机数确保唯一性
        randomNum := Random(1000, 9999)
        tempTxtPath := tempDir . "\openfile_" actionType "_" timestamp "_" randomNum ".txt"
        
        if (!this.CreateMoveTxtFile(guiManager, selectedTexts, tempTxtPath)) {
            MessageManager.ShowError("创建" . (isMove ? "移动" : "复制") . "文件失败")
            return
        }
        
        ; 追加到目标配置
        if (this.AppendToConfig(targetConfigType, tempTxtPath)) {

            this.RefreshTargetGui(targetConfigType)

            ; 如果是移动操作才删除原项
            if (isMove) {
                ; 复用删除逻辑删除原项
                if (selectedTexts.Length = 1) {
                    GuiEventHandlers.HandleSingleDelete(guiManager, selectedTexts[1], true)  ; true表示是移动操作
                } else {
                    GuiEventHandlers.HandleMultipleDelete(guiManager, selectedTexts, true)  ; true表示是移动操作
                }
            }
            
            ; 显示成功消息
            itemCount := selectedTexts.Length
            actionText := isMove ? "移动" : "复制"
            if (itemCount = 1) {
                GuiEventHandlers.ShowToolTip(guiManager, actionText . "成功！", 1500)
            } else {
                GuiEventHandlers.ShowToolTip(guiManager, "成功" . actionText . " " itemCount " 个文件！", 1500)
            }
        } else {
            MessageManager.ShowError(actionText . "到目标配置失败")
        }

        ; 延迟删除临时文件（使用一次性定时器）
        SetTimer(() => this.DeleteTempFile(tempDir), -500)  ; 0.5秒后删除
    }

    ; 刷新目标配置的GUI
    static RefreshTargetGui(targetConfigType) {
        ; 查找是否已经存在目标配置的GUI窗口
        windowTitle := targetConfigType
        hwnd := WinExist(windowTitle " ahk_class AutoHotkeyGUI")
        
        if (hwnd) {
            ; 如果窗口存在，通过窗口句柄获取Gui对象
            try {
                targetGui := GuiFromHwnd(hwnd)
                    ; 获取GuiManager实例（需要从Gui对象中获取）
                    ; 这里假设GuiManager实例存储在Gui对象的guiManager属性中
                    if (targetGui && targetGui.HasProp("guiManager")) {
                        guiManager := targetGui.guiManager
                        ; 调用刷新方法
                        targetGui.guiManager.TriggerRefresh()
                    }
            } catch as e {
                ; 如果刷新失败，可以尝试重新打开窗口
                if (WindowConstants.DEBUG_MODE) {
                    ToolTip("刷新目标GUI失败: " e.Message)
                    SetTimer () => ToolTip(), -2000
                }
            }
        }
    }

    ; 确保temp目录存在的辅助方法
    static EnsureTempDirectory() {
        ; 获取用户家目录
        userHome := A_MyDocuments  ; 文档目录
        SplitPath(userHome, , &userHomeDir)
        
        ; 构建应用数据目录路径
        appTempDir := userHomeDir . "\openfile"
        
        ; 如果目录不存在，创建它
        if (!DirExist(appTempDir)) {
            try {
                DirCreate(appTempDir)
                ; 可以取消下面的注释查看调试信息
                if (WindowConstants.DEBUG_MODE) {
                    MessageManager.ShowSuccess("已创建应用临时目录: " appTempDir, "调试信息", 0x40)
                }
            } catch as e {
                MessageManager.ShowError("创建临时目录失败: " e.Message)
                return false
            }
        }
        
        return appTempDir
    }

    ; 删除临时文件
    static DeleteTempFile(filePath) {
        try {
            ; 先检查目录是否存在
            if (!FileExist(filePath)) {
                return true
            }
            
            ; 删除文件
            FileDelete(filePath)
            
            ; 验证是否删除成功
            if (FileExist(filePath)) {
                ; 删除失败，可能是文件被占用
                ; 静默失败，不显示错误信息
                return false
            }
            
            return true
        } catch as e {
            ; 静默失败，不显示错误信息
            return false
        }
    }

}