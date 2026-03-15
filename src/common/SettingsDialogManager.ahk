; ==============================
; SettingsDialogManager.ahk
; 设置对话框相关功能管理
; ==============================
class SettingsDialogManager {
    ; ==================== 设置按钮事件处理 ====================
    
    ; 设置按钮点击事件处理
    ; t_openfile_settings：get&set
    static ShowSettingsDialog(guiManager) {
        ; 检查最小宽度
        if (WindowConstants.MORE_GUI_WIDTH < 100) {
            MessageManager.ShowWarning("对话框宽度太小，无法正确显示所有按钮。`n请增加 MORE_GUI_WIDTH 的值。", "布局错误")
            return  ; 直接返回，不创建对话框
        }
        ; 创建设置对话框
        moreGui := Gui()
        moreGui.Title := "设置操作 - " guiManager.configType
        
        ; 总是设置 Owner 关系
        moreGui.Opt("+Owner" guiManager.gui.Hwnd)

        ; 根据配置决定是否置顶
        if(SettingsManager.GetBool("AlwaysOnTop",guiManager.configType)){
            moreGui.Opt("+AlwaysOnTop")
        }

        ; 关键：禁用主窗口（灰色不可操作）
        guiManager.gui.Opt("+Disabled")

        ; 移除最小化按钮
        try {
        WinSetStyle("-0x00020000", moreGui.Hwnd)
        }
        
        ; 设置字体
        moreGui.SetFont("s9")  ; 先重置为默认字体
        moreGui.SetFont("s10", "Microsoft YaHei")  ; 最低优先级
        moreGui.SetFont("s10", "Consolas")         ; 中等优先级  
        moreGui.SetFont("s9", "JetBrains Mono")   ; 最高优先级（最后设置）

        ; 设置边距，减少顶部间距
        moreGui.MarginY := 12
        
        ; 添加说明
        ; moreGui.Add("Text", "w" WindowConstants.MORE_GUI_WIDTH " Center cGray", "管理" guiManager.configType ".ini 配置文件")
        
        ; moreGui关闭时恢复主窗口
        moreGui.OnEvent("Close", (*) => this.HandleMoreGuiClose(guiManager, moreGui))
        moreGui.OnEvent("Escape", (*) => this.HandleMoreGuiClose(guiManager, moreGui))

        ; 创建按钮布局
        buttonLayout := this.CreateButtonLayout()

        ; 创建设置按钮并获取按钮引用
        btnRefs := this.CreateSettingButtonsWithLayout(moreGui, guiManager, buttonLayout)

        this.BindSettingButtonEvents(btnRefs, guiManager, moreGui)

        ; 添加分割线
        if (WindowConstants.SHOW_DIVIDER_LINE) {
            this.AddDividerLine(moreGui)
        }
                
        ; 调用 CreateRegularButtonsWithGui 方法
        this.CreateRegularButtonsWithGui(moreGui, guiManager)
        
        ; 计算并设置窗口尺寸和位置
        this.CalculateAndPositionWindow(moreGui, guiManager, buttonLayout.Length)
        
        return moreGui
    }

    ; 根据布局创建设置按钮的方法
    static CreateSettingButtonsWithLayout(moreGui, guiManager, buttonLayout) {
        btnRefs := Map()
        dialogWidth := WindowConstants.MORE_GUI_WIDTH
        btnSpacing := WindowConstants.BUTTON_SPACING
        
        for rowIndex, rowButtons in buttonLayout {
            ; 计算当前行的总宽度
            rowTotalWidth := 0
            firstBtnWidth := true
            
            for btnName in rowButtons {
                btnWidth := WindowConstants.GetButtonWidth(btnName)
                if (firstBtnWidth) {
                    rowTotalWidth := btnWidth
                    firstBtnWidth := false
                } else {
                    rowTotalWidth += btnSpacing + btnWidth
                }
            }
            
            ; 计算起始X位置
            rowStartX := (dialogWidth - rowTotalWidth) // 2 + WindowConstants.SETTING_BUTTON_HORIZONTAL_OFFSET
            if (rowStartX < 5) {
                rowStartX := 5
            }
            
            ; 创建当前行的按钮
            currentX := rowStartX
            for btnIndex, btnName in rowButtons {
                btnWidth := WindowConstants.GetButtonWidth(btnName)
                btnText := this.GetButtonTextInternal(btnName,guiManager)
                
                ; 确定按钮位置参数
                positionParams := ""
                if (rowIndex = 1 && btnIndex = 1) {
                    positionParams := "x" currentX
                } else if (btnIndex = 1) {
                    positionParams := "x" currentX " y+10"
                } else {
                    positionParams := "x+" btnSpacing
                }
                
                ; 创建按钮
                btn := moreGui.Add("Button", positionParams " w" btnWidth, btnText)
                btnRefs[btnName] := btn
                
                currentX += btnWidth + btnSpacing
            }
        }
        
        return btnRefs
    }

    ; 创建按钮布局的方法
    static CreateButtonLayout() {
        buttonLayout := []
        currentRow := []
        currentRowWidth := 0
        maxRowWidth := WindowConstants.SETTING_MAX_ROW_WIDTH - 20
        
        for btnName in WindowConstants.SETTING_BUTTON_ORDER {
            btnWidth := WindowConstants.GetButtonWidth(btnName)
            
            if (currentRow.Length = 0) {
                currentRow.Push(btnName)
                currentRowWidth := btnWidth
            } else {
                neededWidth := currentRowWidth + WindowConstants.BUTTON_SPACING + btnWidth
                
                if (neededWidth <= maxRowWidth) {
                    currentRow.Push(btnName)
                    currentRowWidth := neededWidth
                } else {
                    buttonLayout.Push(currentRow.Clone())
                    currentRow := [btnName]
                    currentRowWidth := btnWidth
                }
            }
        }
        
        if (currentRow.Length > 0) {
            buttonLayout.Push(currentRow.Clone())
        }
        
        return buttonLayout
    }

    ; 添加分割线的方法
    static AddDividerLine(moreGui) {
        dividerLineWidth := WindowConstants.MORE_GUI_WIDTH * WindowConstants.DIVIDER_LINE_WIDTH_PERCENT // 100
        
        if (WindowConstants.DIVIDER_LINE_WIDTH_PERCENT == 100) {
            dividerPosition := "xm"
        } else {
            dividerStartX := (WindowConstants.MORE_GUI_WIDTH - dividerLineWidth) // 2 + WindowConstants.DIVIDER_LINE_HORIZONTAL_OFFSET
            if (dividerStartX < 0) {
                dividerStartX := 0
            }
            dividerPosition := "x" dividerStartX
        }
        
        moreGui.Add("Text", dividerPosition " y+" WindowConstants.DIVIDER_LINE_TOP_MARGIN " w" dividerLineWidth " 0x10")
    }

    ; 更新 CreateRegularButtons 方法，添加 guiManager 参数
    static CreateRegularButtonsWithGui(moreGui, guiManager) {
        dialogWidth := WindowConstants.MORE_GUI_WIDTH
        normalBtnWidth := WindowConstants.BUTTON_WIDTH
        normalBtnCount := WindowConstants.MORE_GUI_BUTTON_COUNT
        btnSpacing := WindowConstants.BUTTON_SPACING
        normalTotalWidth := (normalBtnWidth * normalBtnCount) + (btnSpacing * (normalBtnCount - 1))
        
        ; 确定分割线后的位置
        if (WindowConstants.SHOW_DIVIDER_LINE) {
            yPosition := "y+" WindowConstants.DIVIDER_LINE_BOTTOM_MARGIN
        } else {
            yPosition := "y+10"
        }
        
        ; 根据对话框宽度选择布局策略
        if (dialogWidth >= 300) {
            ; 水平排列
            normalStartX := (dialogWidth - normalTotalWidth) // 2 + WindowConstants.MORE_GUI_BUTTON_HORIZONTAL_OFFSET
            if (normalStartX < 0) {
                normalStartX := 0
            }
            
            btnImport := moreGui.Add("Button", "xm+" normalStartX " " yPosition " w" normalBtnWidth, "导入")
            btnExport := moreGui.Add("Button", "x+" btnSpacing " w" normalBtnWidth, "导出")
            btnAppend := moreGui.Add("Button", "x+" btnSpacing " w" normalBtnWidth, "追加")
            btnLoad   := moreGui.Add("Button", "x+" btnSpacing " w" normalBtnWidth, "载入")
            
        } else if (dialogWidth >= 100) {
            ; 垂直排列
            if (dialogWidth < 200 && WindowConstants.DEBUG_MODE) {
                MessageManager.ShowInfo("对话框宽度较小(" dialogWidth "px)，已自动切换为垂直布局")
            }
            
            buttonX := (dialogWidth - normalBtnWidth) // 2 + WindowConstants.MORE_GUI_BUTTON_HORIZONTAL_OFFSET
            if (buttonX < 10) {
                buttonX := 10
            }
            
            ; 确定第一个按钮的Y位置
            if (WindowConstants.SHOW_DIVIDER_LINE) {
                firstButtonY := "y+" WindowConstants.DIVIDER_LINE_BOTTOM_MARGIN
            } else {
                firstButtonY := "y+15"
            }
            
            btnImport := moreGui.Add("Button", "x" buttonX " " firstButtonY " w" normalBtnWidth, "导入")
            btnExport := moreGui.Add("Button", "xp y+10 w" normalBtnWidth, "导出")
            btnAppend := moreGui.Add("Button", "xp y+10 w" normalBtnWidth, "追加")
            btnLoad   := moreGui.Add("Button", "xp y+10 w" normalBtnWidth, "载入")
        }
        
        ; 绑定事件（与原始代码保持一致）
        btnImport.OnEvent("Click", (btnCtrl, info) => guiManager.HandleImport(moreGui))
        btnExport.OnEvent("Click", (btnCtrl, info) => guiManager.HandleExport(moreGui))
        btnAppend.OnEvent("Click", (btnCtrl, info) => guiManager.HandleAppend(moreGui))
        btnLoad.OnEvent("Click", (btnCtrl, info) => guiManager.HandleLoad(moreGui))
    }
    
    ; 计算并定位窗口的方法
    static CalculateAndPositionWindow(moreGui, guiManager, buttonLayoutRows) {
        estimatedHeight := WindowConstants.CalculateEmpiricalHeight(buttonLayoutRows)

        ; 检查高度模式是否应该切换
        if (WindowConstants.MORE_GUI_HEIGHT < estimatedHeight && WindowConstants.HEIGHT_MODE != "auto") {
            WindowConstants.HEIGHT_MODE := "auto"
            if (WindowConstants.DEBUG_MODE) {
                tip := "当前高度小于计算高度，已为你切换到auto模式`n"
                tip .= "当前高度为：" . WindowConstants.MORE_GUI_HEIGHT . "`n"
                tip .= "计算高度为：" . estimatedHeight . "`n"
                tip .= "如果需要调整偏移：`n"
                tip .= "请调整WindowConstants.MORE_GUI_ADJUST_LEFT和WindowConstants.MORE_GUI_ADJUST_TOP"
                MessageManager.ShowInfo(tip)
            }
        }
        
        ; 根据高度模式决定最终高度
        switch WindowConstants.HEIGHT_MODE {
            case "fixed":
                WindowPositionUtils.CenterChildWindow(
                    guiManager.gui.Hwnd,
                    moreGui,
                    WindowConstants.MORE_GUI_WIDTH,
                    WindowConstants.MORE_GUI_HEIGHT,
                    WindowConstants.MORE_GUI_ADJUST_LEFT,
                    WindowConstants.MORE_GUI_ADJUST_TOP
                )
            case "auto":
                WindowPositionUtils.CenterChildWindowWithConstants(
                    guiManager.gui.Hwnd,
                    moreGui,
                    WindowConstants.MORE_GUI_WIDTH,
                    estimatedHeight,
                    WindowConstants.MORE_GUI_ADJUST_LEFT,
                    WindowConstants.MORE_GUI_ADJUST_TOP
                )
            case "max":
                if (WindowConstants.MORE_GUI_HEIGHT > estimatedHeight) {
                    WindowPositionUtils.CenterChildWindow(
                        guiManager.gui.Hwnd,
                        moreGui,
                        WindowConstants.MORE_GUI_WIDTH,
                        WindowConstants.MORE_GUI_HEIGHT,
                        WindowConstants.MORE_GUI_ADJUST_LEFT,
                        WindowConstants.MORE_GUI_ADJUST_TOP
                    )
                } else {
                    WindowPositionUtils.CenterChildWindowWithConstants(
                        guiManager.gui.Hwnd,
                        moreGui,
                        WindowConstants.MORE_GUI_WIDTH,
                        estimatedHeight,
                        WindowConstants.MORE_GUI_ADJUST_LEFT,
                        WindowConstants.MORE_GUI_ADJUST_TOP
                    )
                }
            default:
                WindowPositionUtils.CenterChildWindowWithConstants(
                    guiManager.gui.Hwnd,
                    moreGui,
                    WindowConstants.MORE_GUI_WIDTH,
                    WindowConstants.MORE_GUI_HEIGHT,
                    WindowConstants.MORE_GUI_ADJUST_LEFT,
                    WindowConstants.MORE_GUI_ADJUST_TOP
                )
        }
    }

    ; 添加高度计算辅助函数
    static CalculateDynamicHeight(buttonLayout, dialogWidth) {
        baseHeight := 30  ; 说明文本高度
        
        ; 设置按钮区域高度
        settingsHeight := buttonLayout.Length * 35  ; 每行约35像素
        
        ; 分割线区域高度
        dividerHeight := 15
        
        ; 常规按钮区域高度
        if (dialogWidth >= 300) {
            buttonAreaHeight := 35  ; 水平布局
        } else {
            buttonAreaHeight := 35 + 30 * 3  ; 垂直布局：第一个按钮高度 + 3个按钮*30像素间距
        }
        
        ; 边距
        margin := 20
        
        return baseHeight + settingsHeight + dividerHeight + buttonAreaHeight + margin
    }

    ; 更新 BindSettingButtonEvents 方法
    static BindSettingButtonEvents(btnRefs, guiManager, moreGui) {
        ; 绑定各个按钮事件
        if (btnRefs.Has("AlwaysOnTop")) {
            btnRefs["AlwaysOnTop"].OnEvent("Click", (*) => this.HandleSettingToggle("AlwaysOnTop", btnRefs["AlwaysOnTop"], guiManager, moreGui))
        }
        if (btnRefs.Has("SortByAlphabet")) {
            btnRefs["SortByAlphabet"].OnEvent("Click", (*) => this.HandleSettingToggle("SortByAlphabet", btnRefs["SortByAlphabet"], guiManager, moreGui))
        }
        if (btnRefs.Has("EnableExtension")) {
            btnRefs["EnableExtension"].OnEvent("Click", (*) => this.HandleSettingToggle("EnableExtension", btnRefs["EnableExtension"], guiManager, moreGui))
        }
        if (btnRefs.Has("BatchThreshold")) {
            btnRefs["BatchThreshold"].OnEvent("Click", (*) => this.HandleBatchThresholdClick(guiManager, btnRefs["BatchThreshold"], moreGui))
        }
        if (btnRefs.Has("ShowSuccessMsg")) {
            btnRefs["ShowSuccessMsg"].OnEvent("Click", (*) => this.HandleSettingToggle("ShowSuccessMsg", btnRefs["ShowSuccessMsg"], guiManager, moreGui))
        }
        if (btnRefs.Has("ResetSettings")) {
            btnRefs["ResetSettings"].OnEvent("Click", (*) => this.HandleResetSettings(
                btnRefs.Get("AlwaysOnTop", ""), 
                btnRefs.Get("SortByAlphabet", ""), 
                btnRefs.Get("EnableExtension", ""), 
                btnRefs.Get("BatchThreshold", ""), 
                btnRefs.Get("ShowSuccessMsg", ""), 
                guiManager,
                moreGui
            ))
        }

        ; 新增：绑定配置类型按钮事件
        if (btnRefs.Has("ConfigTypes")) {
            btnRefs["ConfigTypes"].OnEvent("Click", (*) => this.HandleConfigTypesClick(guiManager, moreGui))
        }
        
        ; 绑定快捷键按钮事件
        if (btnRefs.Has("Shortcuts")) {
            btnRefs["Shortcuts"].OnEvent("Click", (*) => this.HandleShortcutsClick(guiManager, moreGui))
        }

        ; 绑定快捷键按钮事件
        if (btnRefs.Has("Contact")) {
            btnRefs["Contact"].OnEvent("Click", (*) => this.HandleContactClick(guiManager, moreGui))
        }
    }

    static GetButtonTextInternal(btnName,guiManager) {
        switch btnName {
            case "AlwaysOnTop":
                return this.GetAlwaysOnTopButtonText(guiManager)
            case "SortByAlphabet":
                return this.GetSortAlphabetButtonText(guiManager)
            case "EnableExtension":
                return this.GetShowExtensionButtonText(guiManager)
            case "BatchThreshold":
                return this.GetBatchThresholdButtonText(guiManager)
            case "ShowSuccessMsg":
                return this.GetShowSuccessMsgButtonText(guiManager)
            case "ResetSettings":
                return "重置"
            case "ConfigTypes":      ; 新增：配置类型按钮文本
            return "配置类型"
            case "Shortcuts":
                return "快捷键"
            case "Contact":
                return "联系"
            default:
                return btnName
        }
    }
    
    ; 调试方法
    static DebugLayoutInfo(buttonLayout, dialogWidth) {
        debugMsg := "=== 布局调试信息 ===`n"
        debugMsg .= "对话框宽度：" dialogWidth "px`n"
        debugMsg .= "按钮间距：" WindowConstants.BUTTON_SPACING "px`n"
        debugMsg .= "最大行宽度：" WindowConstants.SETTING_MAX_ROW_WIDTH "px`n"
        debugMsg .= "设置按钮总数：" WindowConstants.SETTING_BUTTON_ORDER.Length "`n"
        debugMsg .= "实际布局行数：" buttonLayout.Length "`n`n"
        
        ; 显示布局详情
        for rowIndex, rowButtons in buttonLayout {
            debugMsg .= "【第" rowIndex "行】`n"
            
            ; 计算行总宽度
            rowWidth := 0
            for btnIndex, btnName in rowButtons {
                btnWidth := WindowConstants.GetButtonWidth(btnName)
                if (btnIndex = 1) {
                    rowWidth := btnWidth
                } else {
                    rowWidth += WindowConstants.BUTTON_SPACING + btnWidth
                }
                
                ; 显示按钮信息
                debugMsg .= "  " btnIndex ". " btnName " (" btnWidth "px)"
                
                ; 如果是窄按钮或宽按钮
                if (btnName = "AlwaysOnTop" || btnName = "ResetSettings") {
                    debugMsg .= " [窄按钮]"
                } else {
                    debugMsg .= " [宽按钮]"
                }
                debugMsg .= "`n"
            }
            
            ; 计算居中位置
            centerX := (dialogWidth - rowWidth) // 2
            offsetX := centerX + WindowConstants.SETTING_BUTTON_HORIZONTAL_OFFSET
            
            debugMsg .= "  行总宽度：" rowWidth "px`n"
            debugMsg .= "  理论居中X：" centerX "px`n"
            debugMsg .= "  实际起始X：" offsetX "px`n"
            
            ; 检查是否超出边界
            if (rowWidth > WindowConstants.SETTING_MAX_ROW_WIDTH) {
                debugMsg .= "  ⚠️ 警告：行宽度超出最大限制！`n"
            }
            
            debugMsg .= "`n"
        }
        
        ; 添加常规按钮信息
        debugMsg .= "=== 常规按钮信息 ===`n"
        normalBtnWidth := WindowConstants.BUTTON_WIDTH
        normalBtnCount := WindowConstants.MORE_GUI_BUTTON_COUNT
        normalTotalWidth := (normalBtnWidth * normalBtnCount) + 
                        (WindowConstants.BUTTON_SPACING * (normalBtnCount - 1))
        
        debugMsg .= "按钮宽度：" normalBtnWidth "px`n"
        debugMsg .= "按钮数量：" normalBtnCount "`n"
        debugMsg .= "总宽度：" normalTotalWidth "px`n"
        
        if (dialogWidth >= 300) {
            debugMsg .= "布局模式：水平排列`n"
        } else if (dialogWidth >= 100) {
            debugMsg .= "布局模式：垂直排列`n"
        } else {
            debugMsg .= "布局模式：宽度过小，可能出错`n"
        }
        
        MessageManager.ShowInfo(debugMsg, "布局调试")
    }

    ; 获取置顶按钮文本
    static GetAlwaysOnTopButtonText(guiManager) {
        isOnTop := SettingsManager.GetBool("AlwaysOnTop",guiManager.configType)
        return "置顶: " . (isOnTop ? "✅" : "❌")
    }
    
    ; 获取字母排序按钮文本
    static GetSortAlphabetButtonText(guiManager) {
        isSorted := SettingsManager.GetBool("SortByAlphabet",guiManager.configType)
        return "字母排序: " . (isSorted ? "✅" : "❌")
    }
    
    ; 获取扩展名按钮文本
    static GetShowExtensionButtonText(guiManager) {
        showExt := SettingsManager.GetBool("EnableExtension",guiManager.configType)
        return "显示扩展名: " . (showExt ? "✅" : "❌")
    }

    ; 获取批量阈值按钮文本
    static GetBatchThresholdButtonText(guiManager) {
        threshold := SettingsManager.GetInt("BatchThreshold",guiManager.configType)
        return "批量阈值: " . threshold
    }
    
    ; 获取成功消息按钮文本
    static GetShowSuccessMsgButtonText(guiManager) {
        showMsg := SettingsManager.GetBool("ShowSuccessMsg",guiManager.configType)
        return "成功消息: " . (showMsg ? "✅" : "❌")
    }
    
    ; 处理设置切换
    static HandleSettingToggle(settingKey, buttonCtrl, guiManager,moreGui) {
        ; 获取当前值并切换
        currentValue := SettingsManager.GetBool(settingKey,guiManager.configType)
        newValue := !currentValue
        
        ; 更新配置文件
        if (SettingsManager.SetValue(settingKey, newValue ? "true" : "false",guiManager.configType)) {
            ; 更新按钮文本
            switch settingKey {
                case "AlwaysOnTop":
                    buttonCtrl.Text := this.GetAlwaysOnTopButtonText(guiManager)
                    ; 更新主窗口置顶状态
                    guiManager.isTop := newValue
                    if (newValue) {
                        guiManager.gui.Opt("+AlwaysOnTop")
                    } else {
                        guiManager.gui.Opt("-AlwaysOnTop")
                    }
                    
                case "SortByAlphabet":
                    buttonCtrl.Text := this.GetSortAlphabetButtonText(guiManager)
                    ; 刷新列表以应用新的排序方式
                    SetTimer(() => guiManager.RefreshList(), -100)
                    
                case "EnableExtension":
                    buttonCtrl.Text := this.GetShowExtensionButtonText(guiManager)
                    ; 扩展名设置可能在显示时用到，需要时可以刷新
                    ; SetTimer(() => guiManager.RefreshList(), -100)

                case "ShowSuccessMsg":
                    buttonCtrl.Text := this.GetShowSuccessMsgButtonText(guiManager)
                    ; 成功消息设置影响MessageManager，但不需要立即刷新界面

            }
            
            ; 显示成功提示
            MessageManager.ShowSuccessDelayed("设置已更新: " . settingKey . " = " . (newValue ? "true" : "false"),,moreGui.Hwnd)
        } else {
            MessageManager.ShowError("更新设置失败",,,moreGui.Hwnd)
        }
    }

    ; 处理批量阈值点击
    static HandleBatchThresholdClick(guiManager,btnBatchThreshold,parentGui) {
        ; 创建输入对话框
        inputGui := Gui()
        inputGui.Title := "设置批量阈值"
        inputGui.Opt("+Owner" parentGui.Hwnd)
        if (guiManager.isTop) {
            inputGui.Opt("+AlwaysOnTop")
        }
        ;  关键：禁用主窗口（灰色不可操作）
        parentGui.Opt("+Disabled")

        ; 移除最小化按钮
        try {
            WinSetStyle("-0x00020000",inputGui.Hwnd)
        }
        
        ; 获取当前值
        currentValue := SettingsManager.GetInt("BatchThreshold",guiManager.configType)
        
        ; 添加控件
        inputGui.SetFont("s9")  ; 先重置为默认字体
        inputGui.SetFont("s10", "Microsoft YaHei")  ; 最低优先级
        inputGui.SetFont("s10", "Consolas")         ; 中等优先级  
        inputGui.SetFont("s9", "JetBrains Mono")   ; 最高优先级（最后设置）
        inputGui.Add("Text", "w" (WindowConstants.BATCH_THRESHOLD_WIDTH), "批量操作阈值：")
        inputGui.Add("Text", "w" (WindowConstants.BATCH_THRESHOLD_WIDTH) " cGray", "选中文件数量达到此值时显示进度条")

        ; 使用 Edit 控件作为 UpDown 的伙伴控件
        ; 创建 Edit 控件（用于显示和输入）
        ctlEdit := inputGui.Add("Edit", "w100 Number")
        ; 创建 UpDown 控件并绑定到 Edit
        ctlUpDown := inputGui.Add("UpDown", "Range1-1000", currentValue)
        
        ; 设置 Edit 控件的内容为当前值
        ctlEdit.Value := currentValue
        
        ; UpDown 的 Change 事件处理
        ctlUpDown.OnEvent("Change", (*) => this.ValidateUpDownInput(ctlUpDown, ctlEdit))
        
        ; 添加按钮
        btnSave := inputGui.Add("Button", "w80", "保存")
        btnCancel := inputGui.Add("Button", "x+10 w80", "取消")
        
        ;  修正：定义单独的函数
        ; btnSave.OnEvent("Click", this.HandleBatchThresholdSave.Bind(this, ctlThreshold, btnBatchThreshold,inputGui,parentGui))
        btnSave.OnEvent("Click", (*) => this.HandleBatchThresholdSave(ctlUpDown, btnBatchThreshold, inputGui, parentGui,guiManager))
        ; btnCancel.OnEvent("Click", (*) => inputGui.Destroy())
        ; 然后在其他关闭方式中调用同一个函数：
        btnCancel.OnEvent("Click", (*) => this.HandleInputGuiClose(inputGui, parentGui))
        inputGui.OnEvent("Close", (*) => this.HandleInputGuiClose(inputGui, parentGui))
        inputGui.OnEvent('Escape',(*) => this.HandleInputGuiClose(inputGui, parentGui))
        
        ; 居中显示
        ; inputGui.Show("w320 h150 Center")
        
        WindowPositionUtils.CenterChildWindowWithConstants(
            parentGui.Hwnd,                           ; 父窗口句柄
            inputGui,                                 ; 子窗口对象
            WindowConstants.BATCH_THRESHOLD_WIDTH,    ; 对话框宽度
            WindowConstants.BATCH_THRESHOLD_HEIGHT,   ; 对话框高度
            WindowConstants.BATCH_THRESHOLD_ADJUST_LEFT,   ; 水平微调
            WindowConstants.BATCH_THRESHOLD_ADJUST_TOP     ; 垂直微调
        )
    }
    
    ; 处理批量阈值保存
    static HandleBatchThresholdSave(ctlUpDown, btnBatchThreshold,inputGui,parentGui,guiManager) {
        ; 直接从 UpDown 控件获取值（确保在范围内）
        value := ctlUpDown.Value
        
        ; 验证范围（UpDown 已经自动限制，但双重检查）
        if (value < 1 || value > 1000) {
            MessageManager.ShowError("请输入1-1000之间的数字",,,parentGui.Hwnd)
            return
        }
        
        ; 保存配置
        if (SettingsManager.SetValue("BatchThreshold", value,guiManager.configType)) {
            MessageManager.ShowSuccessDelayed("批量阈值已更新: " . value,,parentGui.Hwnd)
            btnBatchThreshold.Text := this.GetBatchThresholdButtonText(guiManager)
            ;  统一恢复和关闭
            this.HandleInputGuiClose(inputGui, parentGui)
        } else {
            MessageManager.ShowError("更新失败",,,parentGui.Hwnd)
        }
    }

    ; 处理 UpDown 控件的 Change 事件
    static ValidateUpDownInput(updownCtrl, editCtrl) {
        ; 从 UpDown 获取当前值并同步到 Edit 控件
        editCtrl.Value := updownCtrl.Value
    }
    
    ; 简单的关闭处理
    static HandleInputGuiClose(inputGui, parentGui) {
        ; 恢复主窗口
        parentGui.Opt("-Disabled")
        
        ; 关闭输入窗口
        inputGui.Destroy()
    }

    ; 处理moreGui关闭
    static HandleMoreGuiClose(guiManager, moreGui) {
        ; 恢复主窗口
        guiManager.gui.Opt("-Disabled")
        
        ; 销毁moreGui
        moreGui.Destroy()
    }

    ; 处理重置设置到默认值
    static HandleResetSettings(btnAlwaysOnTop, btnSortAlphabet, btnShowExtension, btnBatchThreshold, btnShowSuccessMsg, guiManager,moreGui) {
        ; 简单确认
        result := MessageManager.ShowConfirm("确定要重置所有设置到默认值吗？", "重置设置确认",,moreGui.Hwnd)
        
        if (result = "Yes") {
            ; 使用 ResetToDefault 方法重置
            if (SettingsManager.ResetSectionToDefault(guiManager.configType)) {
                ; 直接调用现有的按钮文本函数更新所有按钮
                btnAlwaysOnTop.Text := this.GetAlwaysOnTopButtonText(guiManager)
                btnSortAlphabet.Text := this.GetSortAlphabetButtonText(guiManager)
                btnShowExtension.Text := this.GetShowExtensionButtonText(guiManager)
                btnBatchThreshold.Text := this.GetBatchThresholdButtonText(guiManager)
                btnShowSuccessMsg.Text := this.GetShowSuccessMsgButtonText(guiManager)
                
                ; 置顶状态会自动通过 GetBool 读取
                newAlwaysOnTop := SettingsManager.GetBool("AlwaysOnTop",guiManager.configType)
                guiManager.isTop := newAlwaysOnTop
                guiManager.gui.Opt((newAlwaysOnTop ? "+" : "-") . "AlwaysOnTop")
                
                ; 刷新列表
                SetTimer(() => guiManager.RefreshList(), -100)
                
                MessageManager.ShowSuccessDelayed("所有设置已重置到默认值",,moreGui.Hwnd)
            } else {
                MessageManager.ShowError("重置设置失败",,,moreGui.Hwnd)
            }
        }
    }

    ; 新增：处理配置类型按钮点击
    static HandleConfigTypesClick(guiManager, moreGui) {
        ; 创建配置类型管理对话框
        configTypesGui := Gui()
        configTypesGui.Title := "配置类型管理 - " guiManager.configType
        
        ; 设置Owner关系
        configTypesGui.Opt("+Owner" moreGui.Hwnd)
        
        ; 根据配置决定是否置顶
        if (SettingsManager.GetBool("AlwaysOnTop", guiManager.configType)) {
            configTypesGui.Opt("+AlwaysOnTop")
        }
        
        ; 禁用父窗口
        moreGui.Opt("+Disabled")
        
        ; 移除最小化按钮
        try {
            WinSetStyle("-0x00020000", configTypesGui.Hwnd)
        }
        
        ; 设置字体
        configTypesGui.SetFont("s9")  ; 先重置为默认字体
        configTypesGui.SetFont("s10", "Microsoft YaHei")  ; 最低优先级
        configTypesGui.SetFont("s10", "Consolas")         ; 中等优先级  
        configTypesGui.SetFont("s9", "JetBrains Mono")   ; 最高优先级（最后设置）
        
        ; 设置边距
        configTypesGui.MarginX := 20
        configTypesGui.MarginY := 10

        ; 计算可用宽度（减去边距）
        contentWidth := WindowConstants.CONFIG_TYPES_GUI_WIDTH
        
        ; 添加标题
        /* configTypesGui.Add("Text", "w300 Center", "配置类型管理")
        configTypesGui.Add("Text", "w300 Center cGray", "管理不同类型的配置文件") */
        
        ; 获取所有配置类型（包括当前类型）
        allConfigTypes := ConfigManager.GetAllConfigTypes()
        
        ; 创建下拉列表框
        configTypesGui.Add("Text", "w" contentWidth, "可用的配置类型:")
        comboBox := configTypesGui.Add("ComboBox", "w" contentWidth, allConfigTypes)

        ; 新增：自动选中当前配置类型
        currentConfigType := guiManager.configType
        if (this.HasValue(allConfigTypes, currentConfigType)) {
            comboBox.Text := currentConfigType
        }
        
        ; 创建输入框用于新增
        configTypesGui.Add("Text", "w" contentWidth " y+10", "新增/修改配置类型:")
        inputBox := configTypesGui.Add("Edit", "w" contentWidth, "")
        
        ; 创建按钮
        btnAdd := configTypesGui.Add("Button", "w80", "新增")
        btnModify := configTypesGui.Add("Button", "x+10 w80", "修改")
        btnDelete := configTypesGui.Add("Button", "x+10 w80", "删除")
        btnActivate := configTypesGui.Add("Button", "x+10 w80", "激活")
        
        ; 事件处理函数
        btnAdd.OnEvent("Click", (*) => this.HandleAddConfigType(configTypesGui, inputBox, comboBox, guiManager))
        btnModify.OnEvent("Click", (*) => this.HandleModifyConfigType(configTypesGui, inputBox, comboBox, guiManager)) 
        btnDelete.OnEvent("Click", (*) => this.HandleDeleteConfigType(configTypesGui, comboBox, guiManager))
        btnActivate.OnEvent("Click", (*) => this.HandleActivateConfigType(configTypesGui, comboBox, guiManager,moreGui))
        configTypesGui.OnEvent("Close", (*) => this.HandleConfigTypesGuiClose(configTypesGui, moreGui))
        configTypesGui.OnEvent("Escape", (*) => this.HandleConfigTypesGuiClose(configTypesGui, moreGui))
        
        ; 使用WindowPositionUtils居中显示
        WindowPositionUtils.CenterChildWindowWithConstants(
            moreGui.Hwnd,
            configTypesGui,
            WindowConstants.CONFIG_TYPES_GUI_WIDTH,
            WindowConstants.CONFIG_TYPES_GUI_HEIGHT,
            WindowConstants.CONFIG_TYPES_ADJUST_LEFT,
            WindowConstants.CONFIG_TYPES_ADJUST_TOP
        )
    }

    ; 新增：处理新增配置类型
    static HandleAddConfigType(configTypesGui, inputBox, comboBox, guiManager) {
        newType := Trim(inputBox.Value)
        
        if (newType = "") {
            MessageManager.ShowWarning("请输入配置类型名称", , , configTypesGui.Hwnd)
            return
        }
        
        ; 检查是否已存在
        allConfigTypes := ConfigManager.GetAllConfigTypes()
        if (this.HasValue(allConfigTypes, newType)) {
            MessageManager.ShowWarning("配置类型 '" newType "' 已存在", , , configTypesGui.Hwnd)
            return
        }
        
        ; 检查名称是否有效
        if (!IniTools.IsValidName(newType, 0, true)) {
            MessageManager.ShowWarning(
                "配置类型名称包含非法字符！`n`n"
                . "名称不能包含：\ / : * ? " . Chr(34) . " < > |`n"
                . "且不能以点开头或结尾", , , configTypesGui.Hwnd
            )
            return
        }

        ; 长度限制（最多15个字符）
        if (StrLen(newType) > 15) {
            MessageManager.ShowWarning(
                "配置类型名称不能超过15个字符！`n`n"
                . "当前长度：" StrLen(newType) " 个字符", , , configTypesGui.Hwnd
            )
            return
        }
        
        ; 创建对应的INI文件
        try {

            ; 修改：直接创建ConfigManager实例来自动创建配置文件
            configMgr := ConfigManager(newType)  ; 这会自动创建配置文件和目录

            ; 在settings.ini中添加对应的配置段
            SettingsManager.EnsureConfigFile()
            
            ; 刷新下拉列表框
            allConfigTypes := ConfigManager.GetAllConfigTypes()
            comboBox.Delete()
            comboBox.Add(allConfigTypes)
            comboBox.Text := newType  ; 选中新增的类型
            
            ; 清空输入框
            inputBox.Value := ""
            
            ; 更新全局ConfigTypes数组（通过main.ahk的函数）
            RefreshConfigTypes()
            
            MessageManager.ShowSuccessDelayed("配置类型 '" newType "' 创建成功", , configTypesGui.Hwnd)

            ;!!! 更新主窗口的上下文菜单
            guiManager.CreateContextMenu()
            
        } catch as e {
            MessageManager.ShowError("创建配置类型失败: " e.Message, , , configTypesGui.Hwnd)
        }

    }

    ; 新增：处理修改配置类型
    static HandleModifyConfigType(configTypesGui, inputBox, comboBox,guiManager) {
        selectedType := Trim(comboBox.Text)
        
        if (selectedType = "") {
            MessageManager.ShowWarning("请选择要修改的配置类型", , , configTypesGui.Hwnd)
            return
        }

        ; 新增：检查是否是当前类型，如果是则不允许修改
        if (selectedType = guiManager.configType) {
            MessageManager.ShowWarning("不能修改当前正在使用的配置类型", , , configTypesGui.Hwnd)
            return
        }

        newType := Trim(inputBox.Value)
        
        ; 检查是否为空
        if (newType = "") {
            MessageManager.ShowWarning("新类型名称不能为空", , , configTypesGui.Hwnd)
            return
        }
        
        ; 检查是否与原名相同
        if (newType = selectedType) {
            MessageManager.ShowWarning("配置类型 '" newType "' 已存在", , , configTypesGui.Hwnd)
            return
        }
        
        ; 校验名称是否有效
        if (!IniTools.IsValidName(newType, 0, true)) {
            MessageManager.ShowWarning(
                "配置类型名称包含非法字符！`n`n"
                . "名称不能包含：\ / : * ? " . Chr(34) . " < > |`n"
                . "且不能以点开头或结尾", , , configTypesGui.Hwnd
            )
            return
        }

        ; 长度限制（最多15个字符）
        if (StrLen(newType) > 15) {
            MessageManager.ShowWarning(
                "配置类型名称不能超过15个字符！`n`n"
                . "当前长度：" StrLen(newType) " 个字符", , , configTypesGui.Hwnd
            )
            return
        }
        
        ; 执行修改
        try {
            ; 1. 重命名配置文件
            ConfigManager.RenameConfigFile(selectedType, newType)
            
            ; 2. 重命名settings.ini中的配置段
            SettingsManager.RenameConfigSection(selectedType, newType)
            
            ; 3. 更新下拉列表框
            newTypes := ConfigManager.GetAllConfigTypes()
            comboBox.Delete()
            comboBox.Add(newTypes)
            comboBox.Text := newType  ; 选中修改后的类型
            
            ; 4. 更新全局配置类型列表
            try {
                RefreshConfigTypes()
            }

            ; 5. 清空输入框
            inputBox.Value := ""
            
            MessageManager.ShowSuccessDelayed("配置类型修改成功: " selectedType " -> " newType, ,configTypesGui.Hwnd)

            ;!!! 更新主窗口的上下文菜单
            guiManager.CreateContextMenu()
            
        } catch as e {
            MessageManager.ShowError("修改配置类型失败: " e.Message, , , configTypesGui.Hwnd)
        }
    }

    ; 新增：处理删除配置类型
    static HandleDeleteConfigType(configTypesGui, comboBox, guiManager) {
        selectedType := Trim(comboBox.Text)
        
        if (selectedType = "") {
            MessageManager.ShowWarning("请选择要删除的配置类型", , , configTypesGui.Hwnd)
            return
        }
        
        ; 检查是否是当前类型
        if (selectedType = guiManager.configType) {
            MessageManager.ShowWarning("不能删除当前正在使用的配置类型", , , configTypesGui.Hwnd)
            return
        }
        
        ; 显示确认对话框
        result := MessageManager.ShowConfirm(
            "确定要删除配置类型 '" selectedType "' 吗？`n`n" 
            "这将会删除以下文件：`n" 
            "1. configs\" selectedType ".ini`n"
            "2. settings.ini中的[" selectedType "]配置段",
            "删除确认", , configTypesGui.Hwnd)
        
        if (result != "Yes") {
            return
        }
        
        try {

            ; 获取当前所有配置类型
            oldTypes := ConfigManager.GetAllConfigTypes()  ; 直接重新获取

            ; 查找当前选中项的索引
            currentIndex := 0
            for i, type in oldTypes {
                if (type = selectedType) {
                    currentIndex := i
                    break
                }
            }

            if (currentIndex = 0) {
                throw Error("未找到要删除的配置类型")
            }

            ; 1. 删除配置文件（复用ConfigManager的方法）
            ConfigManager.DeleteConfigFile(selectedType)
            
            ; 2. 同步settings.ini
            SettingsManager.EnsureConfigFile()
                
            ; 3. 获取新的配置类型列表
            newTypes := ConfigManager.GetAllConfigTypes()
        
            ; 4. 智能选择新选项
            newSelectedType := ""
            if (newTypes.Length > 0) {
                if (currentIndex >= newTypes.Length) {
                    ; 删除的是最后一个，向上选择
                    newSelectedType := newTypes[newTypes.Length]
                } else {
                    ; 删除的不是最后一个，保持相同索引位置
                    newSelectedType := newTypes[currentIndex]
                }
            }
            
            ; 5. 刷新下拉列表框
            comboBox.Delete()
            comboBox.Add(newTypes)
            if (newSelectedType != "") {
                comboBox.Text := newSelectedType
            }
            
            ; 6. 更新全局配置
            try {
                RefreshConfigTypes()
            }
            MessageManager.ShowSuccessDelayed("配置类型 '" selectedType "' 删除成功", , configTypesGui.Hwnd)

            ;!!! 更新主窗口的上下文菜单
            guiManager.CreateContextMenu()
            
        } catch as e {
            MessageManager.ShowError("删除配置类型失败: " e.Message, , , configTypesGui.Hwnd)
        }
    }

    ; 新增：处理激活配置类型
    static HandleActivateConfigType(configTypesGui, comboBox, guiManager,moreGui) {
        selectedType := Trim(comboBox.Text)
        
        if (selectedType = "") {
            MessageManager.ShowWarning("请选择要激活的配置类型", , , configTypesGui.Hwnd)
            return
        }
        
        ; 获取当前激活的配置
        /* currentActive := SettingsManager.GetValue("MainHotkey", "Global")
        
        ; 如果已经是激活配置，提示用户
        if (selectedType = currentActive) {
            MessageManager.ShowInfo(
                "配置类型 '" selectedType "' 已经是激活配置",
                "提示",
                , 
                configTypesGui.Hwnd
            )
            return
        } */

        ; 关闭配置类型Gui
        this.HandleConfigTypesGuiClose(configTypesGui,moreGui)

        ; 关闭设置Gui
        this.HandleMoreGuiClose(guiManager,moreGui)
        
        ; 设置激活配置
        if (SettingsManager.SetValue("ActiveConfig", selectedType, "Global")) {
            ; 弹出成功消息，提示重启生效
            MessageManager.ShowInfo(
                "已将 '" selectedType "' 设置为激活配置`n`n" 
                "重启软件后生效",
                "激活成功"
            )
        } else {
            MessageManager.ShowError("设置激活配置失败")
        }
    }

    ; 新增：关闭配置类型管理对话框
    static HandleConfigTypesGuiClose(configTypesGui, parentGui) {
        ; 恢复父窗口
        parentGui.Opt("-Disabled")
        
        ; 关闭配置类型管理对话框
        configTypesGui.Destroy()
    }

    ; 新增：辅助函数 - 检查数组是否包含某个值
    static HasValue(arr, value) {
        for item in arr {
            if (item = value) {
                return true
            }
        }
        return false
    }

    ; 处理快捷键按钮点击
    static HandleShortcutsClick(guiManager, parentGui) {
        ; 创建设置快捷键的GUI
        hotkeyGui := Gui()
        hotkeyGui.Opt("+Owner" parentGui.Hwnd) ; 设置为模态窗口
        if (guiManager.isTop) {
            hotkeyGui.Opt("+AlwaysOnTop")
        }
        ; 关键：禁用主窗口（灰色不可操作）
        parentGui.Opt("+Disabled")

        ; 设置字体
        hotkeyGui.SetFont("s9")  ; 先重置为默认字体
        hotkeyGui.SetFont("s10", "Microsoft YaHei")  ; 最低优先级
        hotkeyGui.SetFont("s10", "Consolas")         ; 中等优先级  
        hotkeyGui.SetFont("s9", "JetBrains Mono")   ; 最高优先级（最后设置）
        hotkeyGui.Title := "设置快捷键"
        
        ; 获取当前快捷键
        currentMainHotkey := SettingsManager.GetValue("MainHotkey", "Global")
        currentTypeHotkey := SettingsManager.GetValue("TypeHotkey", "Global")

        ; 将快捷键转换为可读文本
        readableMainHotkey := this.ConvertHotkeyToReadable(currentMainHotkey)
        readableTypeHotkey := this.ConvertHotkeyToReadable(currentTypeHotkey)
        
        ;!!! 修改：重新设计布局，添加两行快捷键设置
        contentWidth := WindowConstants.HOTKEY_GUI_WIDTH
        
        ; 主热键行
        hotkeyGui.AddText("w" contentWidth, "主热键：")
        mainHotkeyTextCtrl := hotkeyGui.AddText("wp y+2 cGray", "当前热键: " readableMainHotkey)
        mainHotkeyInput := hotkeyGui.AddHotkey("wp vMainHotkeyInput", currentMainHotkey)
        
        ; 类型热键行
        hotkeyGui.AddText("wp y+10", "类型热键：")
        typeHotkeyTextCtrl := hotkeyGui.AddText("wp y+2 cGray", "当前热键: " readableTypeHotkey)
        typeHotkeyInput := hotkeyGui.AddHotkey("wp vTypeHotkeyInput", currentTypeHotkey)

        ; 存储控件引用到GUI对象中
        hotkeyGui.mainHotkeyTextCtrl := mainHotkeyTextCtrl  ;!!! 新增：存储主热键文本控件
        hotkeyGui.typeHotkeyTextCtrl := typeHotkeyTextCtrl  ;!!! 新增：存储类型热键文本控件
        
        ;!!! 修改：添加保存和重置按钮
        btnRow := hotkeyGui.Add("Button", "w80 xm y+10", "保存")
        btnRow.OnEvent("Click", (*) => this.SaveHotkeys(mainHotkeyInput, typeHotkeyInput, hotkeyGui))
        
        btnReset  := hotkeyGui.Add("Button", "w80 x+10 yp", "重置")
        btnReset.OnEvent("Click", (*) => this.ResetHotkeys(mainHotkeyInput, typeHotkeyInput, hotkeyGui))
        
        hotkeyGui.OnEvent("Close",(*) => this.handleCloseHotKeyGui(hotkeyGui,parentGui))
        hotkeyGui.OnEvent("Escape",(*) => this.handleCloseHotKeyGui(hotkeyGui,parentGui))
        
        ; 显示窗口
        ;!!! 修改：调整窗口高度，因为增加了类型热键行
        WindowPositionUtils.CenterChildWindowWithConstants(
            parentGui.Hwnd,                           ; 父窗口句柄
            hotkeyGui,                                ; 子窗口对象
            WindowConstants.HOTKEY_GUI_WIDTH,         ; 对话框宽度
            WindowConstants.HOTKEY_GUI_HEIGHT,   ;!!! 增加高度容纳类型热键行
            WindowConstants.HOTKEY_GUI_ADJUST_LEFT,   ; 水平微调
            WindowConstants.HOTKEY_GUI_ADJUST_TOP     ; 垂直微调
        )
    }

    ; 工具函数：将热键转换为可读格式
    static ConvertHotkeyToReadable(hotkey) {
        if (!hotkey || hotkey = "") {
            return "未设置"
        }
        
        readable := hotkey
        readable := StrReplace(readable, "#", "Win-")
        readable := StrReplace(readable, "^", "Ctrl-")
        readable := StrReplace(readable, "!", "Alt-")
        readable := StrReplace(readable, "+", "Shift-")
        return readable
    }

    ; 重置快捷键到默认值 (Win+Q)
    static ResetHotkeys(mainHotkeyInput, typeHotkeyInput,hotkeyGui) {
        ; 设置默认快捷键
        defaultMainHotkey := "#q"
        defaultTypeHotkey := "!c"

        ; 禁用当前热键
        try {
            Hotkey(mainHotkeyInput.Value, "off")
        } catch as e {
            ; 忽略错误
        }
        
        try {
            Hotkey(typeHotkeyInput.Value, "off")
        } catch as e {
            ; 忽略错误
        }
        
        ; 更新热键输入框的值
        mainHotkeyInput.Value := defaultMainHotkey
        typeHotkeyInput.Value := defaultTypeHotkey
        
        ; 更新显示文本
        readableMainHotkey := this.ConvertHotkeyToReadable(defaultMainHotkey)
        readableTypeHotkey := this.ConvertHotkeyToReadable(defaultTypeHotkey)
        hotkeyGui.mainHotkeyTextCtrl.Value := "当前热键: " readableMainHotkey
        hotkeyGui.typeHotkeyTextCtrl.Value := "当前热键: " readableTypeHotkey
            
        ; 保存到配置文件
        SettingsManager.SetValue("MainHotkey", defaultMainHotkey, "Global")
        SettingsManager.SetValue("TypeHotkey", defaultTypeHotkey, "Global")
        
        ; 重新注册热键
        RegisterMainShortcut()
        RegisterTypeHotkey()
        
        MessageManager.ShowInfo("快捷键已重置为默认值", "成功", "OK 0x40", hotkeyGui.Hwnd)
    }

    
    ; 保存热键设置
    static SaveHotkeys(mainHotkeyInput, typeHotkeyInput, hotkeyGui) {
        newMainHotkey := mainHotkeyInput.Value
        newTypeHotkey := typeHotkeyInput.Value

        ; MessageManager.ShowSuccess("值为" mainHotkeyInput.Value)
        
         ; 验证热键
        if (newMainHotkey = "") {
            newMainHotkey := "#q"
            mainHotkeyInput.Value := newMainHotkey  ; 更新输入框显示
            ; MessageManager.ShowError("主热键不能为空！", "错误", "OK 0x10", hotkeyGui.Hwnd)
            ; return
        }
        
        if (newTypeHotkey = "") {
            newTypeHotkey := "!c"
            typeHotkeyInput.Value := newTypeHotkey  ; 更新输入框显示
            ; MessageManager.ShowError("类型热键不能为空！", "错误", "OK 0x10", hotkeyGui.Hwnd)
            ; return
        }

        ; 检查是否与之前的热键相同
        oldMainHotkey := SettingsManager.GetValue("MainHotkey", "Global")
        oldTypeHotkey := SettingsManager.GetValue("TypeHotkey", "Global")

        ;!!! 新增：如果两个热键都没变化，直接返回
        if (newMainHotkey = oldMainHotkey && newTypeHotkey = oldTypeHotkey) {
            ; MessageManager.ShowInfo("热键设置没有变化", "提示", "OK 0x40", hotkeyGui.Hwnd)
            return
        }

        ; 检查热键冲突
        if (this.CheckHotkeyConflict(newMainHotkey) || this.CheckHotkeyConflict(newTypeHotkey)) {
            if (!MessageManager.ShowConfirm("热键可能与系统快捷键冲突，是否继续？", "警告", , hotkeyGui.Hwnd)) {
                return
            }
        }

        ; 禁用旧热键
        if (oldMainHotkey != "") {
            try {
                Hotkey(oldMainHotkey, "Off")
            } catch {
                ; 忽略错误
            }
        }
        
        if (oldTypeHotkey != "") {
            try {
                Hotkey(oldTypeHotkey, "Off")
            } catch {
                ; 忽略错误
            }
        }
        
        ; 保存到配置文件
        mainSaved := SettingsManager.SetValue("MainHotkey", newMainHotkey, "Global")
        typeSaved := SettingsManager.SetValue("TypeHotkey", newTypeHotkey, "Global")
        
        if (mainSaved && typeSaved) {
            try {
                ; 更新显示文本
                readableMainHotkey := this.ConvertHotkeyToReadable(newMainHotkey)
                readableTypeHotkey := this.ConvertHotkeyToReadable(newTypeHotkey)
                hotkeyGui.mainHotkeyTextCtrl.Value := "当前热键: " readableMainHotkey
                hotkeyGui.typeHotkeyTextCtrl.Value := "当前热键: " readableTypeHotkey
                
                ; 重新注册热键
                RegisterMainShortcut()
                RegisterTypeHotkey()
                
                MessageManager.ShowInfo("热键设置已更新", "成功", "OK 0x40", hotkeyGui.Hwnd)
            } catch as e {
                ; 如果注册失败，恢复原来的热键
                oldReadableMainHotkey := SettingsManager.SetValue("MainHotkey", oldMainHotkey, "Global")
                oldReadableTypeHotkey := SettingsManager.SetValue("TypeHotkey", oldTypeHotkey, "Global")
                hotkeyGui.mainHotkeyTextCtrl.Value := "当前热键: " oldReadableMainHotkey
                hotkeyGui.typeHotkeyTextCtrl.Value := "当前热键: " oldReadableTypeHotkey
                MessageManager.ShowError("注册热键失败，已恢复原设置`n错误信息: " e.Message, "错误", "OK 0x10", hotkeyGui.Hwnd)
            }
        } else {
            MessageManager.ShowError("保存热键失败！", "错误", "OK 0x10", hotkeyGui.Hwnd)
        }
    }
    
    ; 检查热键冲突
    static CheckHotkeyConflict(hotkey) {
        ; 检查常见系统快捷键
        systemHotkeys := [
            "^!Delete",  ; Ctrl+Alt+Del
            "!F4",       ; Alt+F4
            "#",         ; Win
            "#l",        ; Win+L
            "#e",        ; Win+E
            "#r",        ; Win+R
            "#d",        ; Win+D
            "#m",        ; Win+M
            "#Tab",      ; Win+Tab
            "Ctrl+Escape" ; Ctrl+Esc
        ]
        
        hotkey := StrLower(hotkey)
        
        for sysHotkey in systemHotkeys {
            if (StrLower(sysHotkey) = hotkey) {
                return true
            }
        }
        
        return false
    }

    static handleCloseHotKeyGui(hotKey, parentGui){
        ; 恢复父窗口
        parentGui.Opt("-Disabled")

        ; 关闭热键窗口
        hotKey.Destroy()
    }

    ; 处理联系按钮点击
    static HandleContactClick(guiManager, moreGui) {
        contactUrl := SettingsManager.GetValue("Link","Global")
        if (!contactUrl || contactUrl = "") {
            contactUrl := SettingsManager.GlobalConfigKeys.Get("Link")
        }
        Run(contactUrl)
    }
}