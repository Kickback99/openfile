; ==============================
; SettingsDialogManager.ahk
; 设置对话框相关功能管理
; ==============================
class SettingsDialogManager {
    ; ==================== 设置按钮事件处理 ====================
    ; 设置按钮点击事件处理
    ; t_softmanager_settings：get&set
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
        if(SettingsManager.GetBool("AlwaysOnTop")){
            moreGui.Opt("+AlwaysOnTop")
        }

        ; 关键：禁用主窗口（灰色不可操作）
        guiManager.gui.Opt("+Disabled")

        ; 移除最小化按钮
        try {
        WinSetStyle("-0x00020000", moreGui.Hwnd)
        }
        
        ; 设置字体
        moreGui.SetFont("s9", "JetBrains Mono")

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
        btnRefs := this.CreateSettingButtonsWithLayout(moreGui, buttonLayout)

        this.BindSettingButtonEvents(btnRefs, guiManager, moreGui)

        ; 添加分割线
        if (WindowConstants.SHOW_DIVIDER_LINE) {
            this.AddDividerLine(moreGui)
        }
                
        ;!!! 修改：调用 CreateRegularButtons 方法
        this.CreateRegularButtonsWithGui(moreGui, guiManager)
        
        ; 计算并设置窗口尺寸和位置
        this.CalculateAndPositionWindow(moreGui, guiManager, buttonLayout.Length)
        
        return moreGui
    }

    ;!!! 新增：根据布局创建设置按钮的方法
    static CreateSettingButtonsWithLayout(moreGui, buttonLayout) {
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
                btnText := this.GetButtonTextInternal(btnName)
                
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

    ;!!! 新增：创建按钮布局的方法
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

    ;!!! 新增：添加分割线的方法
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

    ;!!! 新增：更新 CreateRegularButtons 方法，添加 guiManager 参数
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
    
    ;!!! 新增：计算并定位窗口的方法
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

    ;!!! 修改：更新 BindSettingButtonEvents 方法
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
        
        ;!!! 新增：绑定快捷键按钮事件
        if (btnRefs.Has("Shortcuts")) {
            btnRefs["Shortcuts"].OnEvent("Click", (*) => this.HandleShortcutsClick(guiManager, moreGui))
        }

        ;!!! 新增：绑定快捷键按钮事件
        if (btnRefs.Has("Contact")) {
            btnRefs["Contact"].OnEvent("Click", (*) => this.HandleContactClick(guiManager, moreGui))
        }
    }

    static GetButtonTextInternal(btnName) {
        switch btnName {
            case "AlwaysOnTop":
                return this.GetAlwaysOnTopButtonText()
            case "SortByAlphabet":
                return this.GetSortAlphabetButtonText()
            case "EnableExtension":
                return this.GetShowExtensionButtonText()
            case "BatchThreshold":
                return this.GetBatchThresholdButtonText()
            case "ShowSuccessMsg":
                return this.GetShowSuccessMsgButtonText()
            case "ResetSettings":
                return "重置"
            case "Shortcuts":        ;!!! 新增：快捷键按钮文本
                return "快捷键"
            case "Contact":          ;!!! 新增：联系按钮
                return "联系"
            default:
                return btnName
        }
    }
    
    ;>>>新增：调试方法
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

    ;  新增：获取置顶按钮文本
    static GetAlwaysOnTopButtonText() {
        isOnTop := SettingsManager.GetBool("AlwaysOnTop")
        return "置顶: " . (isOnTop ? "✅" : "❌")
    }
    
    ;  新增：获取字母排序按钮文本
    static GetSortAlphabetButtonText() {
        isSorted := SettingsManager.GetBool("SortByAlphabet")
        return "字母排序: " . (isSorted ? "✅" : "❌")
    }
    
    ;  新增：获取扩展名按钮文本
    static GetShowExtensionButtonText() {
        showExt := SettingsManager.GetBool("EnableExtension")
        return "显示扩展名: " . (showExt ? "✅" : "❌")
    }

    ;  新增：获取批量阈值按钮文本
    static GetBatchThresholdButtonText() {
        threshold := SettingsManager.GetInt("BatchThreshold")
        return "批量阈值: " . threshold
    }
    
    ;  新增：获取成功消息按钮文本
    static GetShowSuccessMsgButtonText() {
        showMsg := SettingsManager.GetBool("ShowSuccessMsg")
        return "成功消息: " . (showMsg ? "✅" : "❌")
    }
    
    ;  新增：处理设置切换
    static HandleSettingToggle(settingKey, buttonCtrl, guiManager,moreGui) {
        ; 获取当前值并切换
        currentValue := SettingsManager.GetBool(settingKey)
        newValue := !currentValue
        
        ; 更新配置文件
        if (SettingsManager.SetValue(settingKey, newValue ? "true" : "false")) {
            ; 更新按钮文本
            switch settingKey {
                case "AlwaysOnTop":
                    buttonCtrl.Text := this.GetAlwaysOnTopButtonText()
                    ; 更新主窗口置顶状态
                    guiManager.isTop := newValue
                    if (newValue) {
                        guiManager.gui.Opt("+AlwaysOnTop")
                    } else {
                        guiManager.gui.Opt("-AlwaysOnTop")
                    }
                    
                case "SortByAlphabet":
                    buttonCtrl.Text := this.GetSortAlphabetButtonText()
                    ; 刷新列表以应用新的排序方式
                    SetTimer(() => guiManager.RefreshList(), -100)
                    
                case "EnableExtension":
                    buttonCtrl.Text := this.GetShowExtensionButtonText()
                    ; 扩展名设置可能在显示时用到，需要时可以刷新
                    ; SetTimer(() => guiManager.RefreshList(), -100)

                case "ShowSuccessMsg":
                    buttonCtrl.Text := this.GetShowSuccessMsgButtonText()
                    ; 成功消息设置影响MessageManager，但不需要立即刷新界面

            }
            
            ; 显示成功提示
            MessageManager.ShowSuccessDelayed("设置已更新: " . settingKey . " = " . (newValue ? "true" : "false"),,moreGui.Hwnd)
        } else {
            MessageManager.ShowError("更新设置失败",,,moreGui.Hwnd)
        }
    }

    ;  新增：处理批量阈值点击
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
        currentValue := SettingsManager.GetInt("BatchThreshold")
        
        ; 添加控件
        inputGui.SetFont("s9", "JetBrains Mono")
        inputGui.Add("Text", "w" (WindowConstants.BATCH_THRESHOLD_WIDTH), "批量操作阈值：")
        inputGui.Add("Text", "w" (WindowConstants.BATCH_THRESHOLD_WIDTH) " cGray", "选中文件数量达到此值时显示进度条")

        ;!!! 修改：使用 Edit 控件作为 UpDown 的伙伴控件
        ; 创建 Edit 控件（用于显示和输入）
        ctlEdit := inputGui.Add("Edit", "w100 Number")
        ; 创建 UpDown 控件并绑定到 Edit
        ctlUpDown := inputGui.Add("UpDown", "Range1-1000", currentValue)
        
        ;!!! 修改：设置 Edit 控件的内容为当前值
        ctlEdit.Value := currentValue
        
        ;!!! 修改：添加 UpDown 的 Change 事件处理
        ctlUpDown.OnEvent("Change", (*) => this.ValidateUpDownInput(ctlUpDown, ctlEdit))
        
        ; 添加按钮
        btnSave := inputGui.Add("Button", "w80", "保存")
        btnCancel := inputGui.Add("Button", "x+10 w80", "取消")
        
        ;  修正：定义单独的函数
        ; btnSave.OnEvent("Click", this.HandleBatchThresholdSave.Bind(this, ctlThreshold, btnBatchThreshold,inputGui,parentGui))
        btnSave.OnEvent("Click", (*) => this.HandleBatchThresholdSave(ctlUpDown, btnBatchThreshold, inputGui, parentGui))
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
    
    ;  新增：处理批量阈值保存
    static HandleBatchThresholdSave(ctlUpDown, btnBatchThreshold,inputGui,parentGui) {
        ; 直接从 UpDown 控件获取值（确保在范围内）
        value := ctlUpDown.Value
        
        ; 验证范围（UpDown 已经自动限制，但双重检查）
        if (value < 1 || value > 1000) {
            MessageManager.ShowError("请输入1-1000之间的数字",,,parentGui.Hwnd)
            return
        }
        
        ; 保存配置
        if (SettingsManager.SetValue("BatchThreshold", value)) {
            MessageManager.ShowSuccessDelayed("批量阈值已更新: " . value,,parentGui.Hwnd)
            btnBatchThreshold.Text := this.GetBatchThresholdButtonText()
            ;  统一恢复和关闭
            this.HandleInputGuiClose(inputGui, parentGui)
        } else {
            MessageManager.ShowError("更新失败",,,parentGui.Hwnd)
        }
    }

    ;!!! 新增：处理 UpDown 控件的 Change 事件
    static ValidateUpDownInput(updownCtrl, editCtrl) {
        ; 从 UpDown 获取当前值并同步到 Edit 控件
        editCtrl.Value := updownCtrl.Value
    }
    
    ;  新增：简单的关闭处理
    static HandleInputGuiClose(inputGui, parentGui) {
        ; 恢复主窗口
        parentGui.Opt("-Disabled")
        
        ; 关闭输入窗口
        inputGui.Destroy()
    }

    ;  新增：处理moreGui关闭
    static HandleMoreGuiClose(guiManager, moreGui) {
        ; 恢复主窗口
        guiManager.gui.Opt("-Disabled")
        
        ; 销毁moreGui
        moreGui.Destroy()
    }

    ; 3. 最简化重置设置函数:
    ;  新增：处理重置设置到默认值
    static HandleResetSettings(btnAlwaysOnTop, btnSortAlphabet, btnShowExtension, btnBatchThreshold, btnShowSuccessMsg, guiManager,moreGui) {
        ; 简单确认
        result := MessageManager.ShowConfirm("确定要重置所有设置到默认值吗？", "重置设置确认",,moreGui.Hwnd)
        
        if (result = "Yes") {
            ; 使用 ResetToDefault 方法重置
            if (SettingsManager.ResetToDefault()) {
                ; 直接调用现有的按钮文本函数更新所有按钮
                btnAlwaysOnTop.Text := this.GetAlwaysOnTopButtonText()
                btnSortAlphabet.Text := this.GetSortAlphabetButtonText()
                btnShowExtension.Text := this.GetShowExtensionButtonText()
                btnBatchThreshold.Text := this.GetBatchThresholdButtonText()
                btnShowSuccessMsg.Text := this.GetShowSuccessMsgButtonText()
                
                ; 置顶状态会自动通过 GetBool 读取
                newAlwaysOnTop := SettingsManager.GetBool("AlwaysOnTop")
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

    ; 新增：处理快捷键按钮点击
    static HandleShortcutsClick(guiManager, moreGui) {
        ; 简单消息框提示
        MessageManager.ShowInfo("快捷键", "提示", "OK 0x40", moreGui.Hwnd)
    }

    ; 新增：处理联系按钮点击
    static HandleContactClick(guiManager, moreGui) {
        ; 简单消息框提示
        MessageManager.ShowInfo("联系", "提示", "OK 0x40", moreGui.Hwnd)
    }
}