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

    ; 新增：统一的复制/移动执行方法
    static ExecuteCopyOrMove(guiManager, selectedTexts, targetConfigType, isMove) {
        ; 获取脚本所在目录（common目录的父目录）
        tempDir := this.EnsureTempDirectory()
        if (tempDir = false) {
            return  ; 目录创建失败，直接返回
        }
        
        ; 创建临时TXT文件
        tempTxtPath := tempDir . "\" A_TickCount (isMove ? "_move" : "_copy") ".txt"
        if (!this.CreateMoveTxtFile(guiManager, selectedTexts, tempTxtPath)) {
            MessageManager.ShowError("创建" . (isMove ? "移动" : "复制") . "文件失败")
            return
        }
        
        ; 追加到目标配置
        if (this.AppendToConfig(targetConfigType, tempTxtPath)) {
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

        ; 延迟删除整个temp文件夹（使用一次性定时器）
        SetTimer(() => this.DeleteTempDirectory(tempDir), -500)  ; 0.5秒后删除
    }

    ; 确保temp目录存在的辅助方法
    static EnsureTempDirectory() {
        scriptDir := A_ScriptDir
        tempDir := scriptDir . "\temp"
        
        ; 如果目录不存在，创建它
        if (!DirExist(tempDir)) {
            try {
                DirCreate(tempDir)
                ; MsgBox("已创建临时目录: " tempDir)  ; 调试信息，可以注释掉
            } catch as e {
                MessageManager.ShowError("创建临时目录失败: " e.Message)
                return false
            }
        }
        
        return tempDir
    }

    ; 删除temp目录及其所有内容
    static DeleteTempDirectory(tempDir) {
        try {
            ; 先检查目录是否存在
            if (!DirExist(tempDir)) {
                return true
            }
            
            ; 删除目录及其所有内容
            DirDelete(tempDir, true)
            
            ; 验证是否删除成功
            if (DirExist(tempDir)) {
                ; 删除失败，可能是文件被占用，不显示错误避免干扰用户
                return false
            }
            
            return true
        } catch as e {
            ; 静默失败，不显示错误信息
            return false
        }
    }

}