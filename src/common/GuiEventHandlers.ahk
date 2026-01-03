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
        selectedIndex := guiManager.listBox.Value
        if (selectedIndex <= 0) {
            MessageManager.ShowError("请先选择一个要编辑的软件","提示")
            return
        }
        
        selectedText := guiManager.listBox.Text
        if (!guiManager.softwareMap.Has(selectedText)) {
            MessageManager.ShowError("未找到选中的软件信息","提示")
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
            MessageManager.ShowError("请先选择一个要删除的软件","提示")
            return
        }
        
        selectedText := guiManager.listBox.Text
        if (!guiManager.softwareMap.Has(selectedText)) {
            MessageManager.ShowError("未找到选中的软件信息","提示")
            return
        }
        
        software := guiManager.softwareMap[selectedText]
        
        ; 确认删除
        response := MessageManager.ShowConfirm("确定要删除 '" software["name"] "' 吗？", "确认删除")
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
            MessageManager.ShowError("删除失败，无法更新配置文件")
            return
        }
        
        ; 刷新列表
        guiManager.RefreshList()

        ; >>> 删除后尝试选中之前找到的下一项/上一项
        if (nextItemText != "") {
            this.SelectItemByText(guiManager, nextItemText)
        }
        
        MessageManager.ShowSuccess("删除成功！")
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
    
    ; ==================== 设置按钮事件处理 ====================
    
    ; 设置按钮点击事件处理
    ; t_softmanager_settings：get&set
    static HandleSettingClick(guiManager) {
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
        moreGui.OnEvent("Close", this.HandleMoreGuiClose.Bind(this, guiManager, moreGui))
        moreGui.OnEvent("Escape", this.HandleMoreGuiClose.Bind(this,guiManager,moreGui))

        ; 预定义按钮变量
        btnAlwaysOnTop := ""
        btnSortAlphabet := ""
        btnShowExtension := ""
        btnBatchThreshold := ""
        btnShowSuccessMsg := ""
        btnResetSettings := ""
        
        ; 按钮间距和对话框宽度
        btnSpacing := WindowConstants.BUTTON_SPACING
        dialogWidth := WindowConstants.MORE_GUI_WIDTH
        maxRowWidth := WindowConstants.SETTING_MAX_ROW_WIDTH - 20  ; 减去边距，确保按钮不会贴边
        
        ;>>>重构：实现自适应分行算法
        buttonLayout := []  ; 存储按钮布局信息：每行包含哪些按钮
        
        ; 第一步：计算所有按钮的宽度
        buttonWidths := Map()
        for btnName in WindowConstants.SETTING_BUTTON_ORDER {
            buttonWidths[btnName] := WindowConstants.GetButtonWidth(btnName)
        }

        ; 调试：在布局计算完成后立即检查
        if (WindowConstants.DEBUG_MODE) {
            this.DebugLayoutInfo(buttonLayout, dialogWidth)
        }
        
        ; 第二步：自动分行算法（基于可用宽度）
        currentRow := []
        currentRowWidth := 0
        totalButtons := WindowConstants.SETTING_BUTTON_ORDER.Length
        
        for btnName in WindowConstants.SETTING_BUTTON_ORDER {
            btnWidth := buttonWidths[btnName]
            
            ; 如果是当前行的第一个按钮
            if (currentRow.Length = 0) {
                currentRow.Push(btnName)
                currentRowWidth := btnWidth
            } else {
                ; 检查当前行是否能容纳这个按钮（加上间距）
                neededWidth := currentRowWidth + btnSpacing + btnWidth
                
                if (neededWidth <= maxRowWidth) {
                    ; 当前行还能放下这个按钮
                    currentRow.Push(btnName)
                    currentRowWidth := neededWidth
                } else {
                    ; 放不下了，保存当前行，开始新行
                    buttonLayout.Push(currentRow.Clone())
                    currentRow := [btnName]
                    currentRowWidth := btnWidth
                }
            }
        }
        
        ; 添加最后一行
        if (currentRow.Length > 0) {
            buttonLayout.Push(currentRow.Clone())
        }
        
        ; 第三步：创建按钮，基于计算出的布局
        ; 获取按钮文本的辅助函数
        ; 第三步：创建按钮，基于计算出的布局
        ; 获取按钮文本的辅助函数
        getButtonText(btnName) {
            if (btnName = "AlwaysOnTop") {
                return this.GetAlwaysOnTopButtonText()
            } else if (btnName = "SortByAlphabet") {
                return this.GetSortAlphabetButtonText()
            } else if (btnName = "EnableExtension") {
                return this.GetShowExtensionButtonText()
            } else if (btnName = "BatchThreshold") {
                return this.GetBatchThresholdButtonText()
            } else if (btnName = "ShowSuccessMsg") {
                return this.GetShowSuccessMsgButtonText()
            } else if (btnName = "ResetSettings") {
                return "重置"
            } else {
                return btnName
            }
        }
    
        ; 创建所有按钮行
        firstButtonPos := ""  ; 记录第一个按钮的位置信息
        for rowIndex, rowButtons in buttonLayout {
            ; 计算当前行的总宽度
            rowTotalWidth := 0
            firstBtnWidth := true  ; 标记是否是第一个按钮宽度
            
            for btnName in rowButtons {
                btnWidth := WindowConstants.GetButtonWidth(btnName)
                if (firstBtnWidth) {
                    rowTotalWidth := btnWidth
                    firstBtnWidth := false
                } else {
                    rowTotalWidth += btnSpacing + btnWidth
                }
            }
        
        ; 计算起始X位置（水平居中）
        ; 计算起始X位置（水平居中并添加偏移量）
        rowStartX := (dialogWidth - rowTotalWidth) // 2 + WindowConstants.SETTING_BUTTON_HORIZONTAL_OFFSET

        ; 确保起始位置不为负
        if (rowStartX < 5) {
            rowStartX := 5
        }
        
        ; 创建当前行的按钮
        currentX := rowStartX
        for btnIndex, btnName in rowButtons {
            btnWidth := WindowConstants.GetButtonWidth(btnName)
            btnText := getButtonText(btnName)
            
            ; 确定按钮位置参数
            positionParams := ""
            if (rowIndex = 1 && btnIndex = 1) {
                ; 第一个按钮（整个按钮区域的第一按钮）
                positionParams := "x" currentX
            } else if (btnIndex = 1) {
                ; 新行的第一个按钮
                positionParams := "x" currentX " y+10"
            } else {
                ; 同一行的后续按钮
                positionParams := "x+" btnSpacing
            }
            
            ; 创建按钮
            btn := moreGui.Add("Button", positionParams " w" btnWidth, btnText)
            
            ; 记录第一个按钮的位置信息（用于布局计算）
            if (rowIndex = 1 && btnIndex = 1) {
                firstButtonPos := "x" currentX
            }
            
            ; 存储按钮引用并绑定事件
            switch btnName {
                case "AlwaysOnTop":
                    btnAlwaysOnTop := btn
                    btnAlwaysOnTop.OnEvent("Click", (*) => this.HandleSettingToggle("AlwaysOnTop", btnAlwaysOnTop, guiManager,moreGui))
                case "SortByAlphabet":
                    btnSortAlphabet := btn
                    btnSortAlphabet.OnEvent("Click", (*) => this.HandleSettingToggle("SortByAlphabet", btnSortAlphabet, guiManager,moreGui))
                case "EnableExtension":
                    btnShowExtension := btn
                    btnShowExtension.OnEvent("Click", (*) => this.HandleSettingToggle("EnableExtension", btnShowExtension, guiManager,moreGui))
                case "BatchThreshold":
                    btnBatchThreshold := btn
                    btnBatchThreshold.OnEvent("Click", (*) => this.HandleBatchThresholdClick(guiManager, btnBatchThreshold, moreGui))
                case "ShowSuccessMsg":
                    btnShowSuccessMsg := btn
                    btnShowSuccessMsg.OnEvent("Click", (*) => this.HandleSettingToggle("ShowSuccessMsg", btnShowSuccessMsg, guiManager,moreGui))
                case "ResetSettings":
                    btnResetSettings := btn
                    ; 事件绑定在循环外处理
            }
            
            currentX += btnWidth + btnSpacing
        }
    }

        if (WindowConstants.DEBUG_MODE) {
            this.DebugLayoutInfo(buttonLayout, dialogWidth)
        }
        
        ; 绑定重置按钮事件
        if (btnResetSettings) {
            btnResetSettings.OnEvent("Click", (*) => this.HandleResetSettings(
                btnAlwaysOnTop, 
                btnSortAlphabet, 
                btnShowExtension, 
                btnBatchThreshold, 
                btnShowSuccessMsg, 
                guiManager,
                moreGui
            ))
        }

        ; 添加分割线
        ; 计算分割线位置（在最后一个按钮行下方）
        ; moreGui.Add("Text", "xm y+15 w" dialogWidth " 0x10")  ; 水平分割线
        ; 添加分割线（根据常量决定是否显示）
        if (WindowConstants.SHOW_DIVIDER_LINE) {
            ; 计算分割线的实际宽度
            dividerLineWidth := WindowConstants.MORE_GUI_WIDTH * WindowConstants.DIVIDER_LINE_WIDTH_PERCENT // 100
            
            ; 计算分割线的起始位置（居中并考虑偏移量）
            if (WindowConstants.DIVIDER_LINE_WIDTH_PERCENT == 100) {
                ; 100%宽度时，使用xm（自动居中）
                dividerPosition := "xm"
            } else {
                ; 部分宽度时，计算居中位置
                dividerStartX := (WindowConstants.MORE_GUI_WIDTH - dividerLineWidth) // 2 + WindowConstants.DIVIDER_LINE_HORIZONTAL_OFFSET
                
                ; 确保位置不为负
                if (dividerStartX < 0) {
                    dividerStartX := 0
                }
                dividerPosition := "x" dividerStartX
            }
            
            ; 创建分割线
            moreGui.Add("Text", dividerPosition " y+" WindowConstants.DIVIDER_LINE_TOP_MARGIN " w" dividerLineWidth " 0x10")
            
            ; 设置分割线后的垂直间距
            nextControlYOffset := "y+" WindowConstants.DIVIDER_LINE_BOTTOM_MARGIN
        } else {
            ; 不显示分割线，设置较小的间距
            nextControlYOffset := "y+10"
        }
        
        ; 计算常规按钮位置（水平居中）
        ; 在计算常规按钮位置部分，添加偏移量
        normalBtnWidth := WindowConstants.BUTTON_WIDTH
        normalBtnCount := WindowConstants.MORE_GUI_BUTTON_COUNT
        btnSpacing := WindowConstants.BUTTON_SPACING
        normalTotalWidth := (normalBtnWidth * normalBtnCount) + (btnSpacing * (normalBtnCount - 1))
        
        ; 根据对话框宽度选择布局策略
        if (dialogWidth >= 300) {
            ; 方案1：宽度>=300，水平排列
            normalStartX := (dialogWidth - normalTotalWidth) // 2 + WindowConstants.MORE_GUI_BUTTON_HORIZONTAL_OFFSET
            
            ; 确保起始位置不为负
            if (normalStartX < 0) {
                normalStartX := 0
            }
            
            ; 使用正确的Y位置参数（考虑是否显示分割线）
            if (WindowConstants.SHOW_DIVIDER_LINE) {
                yPosition := nextControlYOffset
            } else {
                yPosition := "y+10"
            }
            
            btnImport := moreGui.Add("Button", "xm+" normalStartX " " yPosition " w" normalBtnWidth, "导入")
            btnExport := moreGui.Add("Button", "x+" btnSpacing " w" normalBtnWidth, "导出")
            btnAppend := moreGui.Add("Button", "x+" btnSpacing " w" normalBtnWidth, "追加")
            btnLoad   := moreGui.Add("Button", "x+" btnSpacing " w" normalBtnWidth, "载入")
            
        } else if (dialogWidth >= 100) {
            ; 方案2：宽度在100-300之间，垂直排列
            ; 给出提示
            if (dialogWidth < 200 && WindowConstants.DEBUG_MODE) {
                ; 只在宽度较小时提示
                MessageManager.ShowInfo("对话框宽度较小(" dialogWidth "px)，已自动切换为垂直布局")
            }
            
            ; 计算垂直排列的X位置（居中）
            buttonX := (dialogWidth - normalBtnWidth) // 2 + WindowConstants.MORE_GUI_BUTTON_HORIZONTAL_OFFSET
            
            ; 确保最小边距
            if (buttonX < 10) {
                buttonX := 10
            }
            
            ; 使用正确的Y位置参数（考虑是否显示分割线）
            if (WindowConstants.SHOW_DIVIDER_LINE) {
                firstButtonY := nextControlYOffset
            } else {
                firstButtonY := "y+15"
            }
            
            btnImport := moreGui.Add("Button", "x" buttonX " " firstButtonY " w" normalBtnWidth, "导入")
            btnExport := moreGui.Add("Button", "xp y+10 w" normalBtnWidth, "导出")
            btnAppend := moreGui.Add("Button", "xp y+10 w" normalBtnWidth, "追加")
            btnLoad   := moreGui.Add("Button", "xp y+10 w" normalBtnWidth, "载入")
        }
    
        ; 绑定事件
        btnImport.OnEvent("Click", (btnCtrl, info) => guiManager.HandleImport(moreGui))
        btnExport.OnEvent("Click", (btnCtrl, info) => guiManager.HandleExport(moreGui))
        btnAppend.OnEvent("Click", (btnCtrl, info) => guiManager.HandleAppend(moreGui))
        btnLoad.OnEvent("Click", (btnCtrl, info) => guiManager.HandleLoad(moreGui))
        
        ; 动态计算窗口高度
        ; 按钮行数 * (按钮高度 + 行间距) + 说明文本高度 + 分割线 + 常规按钮区域 + 边距
       /*  estimatedHeight := 30 + ; 说明文本
                        (buttonLayout.Length * 35) + ; 设置按钮行（每行约35像素）
                        15 + ; 分割线
                        35 + ; 常规按钮
                        20 ; 上下边距
        MsgBox('最终高度' . estimatedHeight) ;135 */

        estimatedHeight := WindowConstants.CalculateEmpiricalHeight(buttonLayout.Length)

        if(WindowConstants.MORE_GUI_HEIGHT < estimatedHeight){
            if(WindowConstants.HEIGHT_MODE != "auto"){
                WindowConstants.HEIGHT_MODE := "auto"
                if(WindowConstants.DEBUG_MODE){
                    tip := "当前高度小于计算高度，已为你切换到auto模式"
                    tip .= "`n"  ; 这里使用 `n 而不是 \n
                    tip .= "当前高度为：" . WindowConstants.MORE_GUI_HEIGHT
                    tip .= "`n"  ; 这里也需要换行
                    tip .= "计算高度为：" . estimatedHeight
                    tip .= "`n"
                    tip .= "如果需要调整偏移："
                    tip .= "`n"
                    tip .= "请调整WindowConstants.MORE_GUI_ADJUST_LEFT和WindowConstants.MORE_GUI_ADJUST_TOP"
                    MessageManager.ShowInfo(tip)
                }
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
                    WindowConstants.MORE_GUI_ADJUST_TOP  ; 添加垂直微调 
                )
            case "auto":
                ; 动态计算高度
                WindowPositionUtils.CenterChildWindowWithConstants(
                    guiManager.gui.Hwnd,
                    moreGui,
                    WindowConstants.MORE_GUI_WIDTH,
                    estimatedHeight,  ; 使用动态计算的高度
                    WindowConstants.MORE_GUI_ADJUST_LEFT,
                    WindowConstants.MORE_GUI_ADJUST_TOP
                )
            case "max":
                ; max模式：取固定高度和自动计算高度的较大值
                ; 先获取自动计算的高度
                ; moreGui.Show("Hide")  ; 隐藏以获取尺寸
                ; WinGetPos(, , &autoW, &autoH, "ahk_id " moreGui.Hwnd)
                
                ; 使用较大值
                    if (WindowConstants.MORE_GUI_HEIGHT > estimatedHeight) {
                        ; 固定高度更大，使用固定尺寸
                        WindowPositionUtils.CenterChildWindow(
                            guiManager.gui.Hwnd,
                            moreGui,
                            WindowConstants.MORE_GUI_WIDTH,
                            WindowConstants.MORE_GUI_HEIGHT,
                            WindowConstants.MORE_GUI_ADJUST_LEFT,
                            WindowConstants.MORE_GUI_ADJUST_TOP
                        )
                    }else {
                        ; 动态计算高度
                        WindowPositionUtils.CenterChildWindowWithConstants(
                            guiManager.gui.Hwnd,
                            moreGui,
                            WindowConstants.MORE_GUI_WIDTH,
                            estimatedHeight,  ; 使用动态计算的高度
                            WindowConstants.MORE_GUI_ADJUST_LEFT,
                            WindowConstants.MORE_GUI_ADJUST_TOP
                        )
                    }
            default:
                ; 默认使用fixed模式
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

    ;>>>新增：绑定设置按钮事件的方法
    static BindSettingButtonEvents(btnRefs, guiManager, moreGui) {
        if (btnRefs.Has("AlwaysOnTop")) {
            btnRefs["AlwaysOnTop"].OnEvent("Click", (*) => this.HandleSettingToggle("AlwaysOnTop", btnRefs["AlwaysOnTop"], guiManager,moreGui))
        }
        if (btnRefs.Has("SortByAlphabet")) {
            btnRefs["SortByAlphabet"].OnEvent("Click", (*) => this.HandleSettingToggle("SortByAlphabet", btnRefs["SortByAlphabet"], guiManager,moreGui))
        }
        if (btnRefs.Has("EnableExtension")) {
            btnRefs["EnableExtension"].OnEvent("Click", (*) => this.HandleSettingToggle("EnableExtension", btnRefs["EnableExtension"], guiManager,moreGui))
        }
        if (btnRefs.Has("BatchThreshold")) {
            btnRefs["BatchThreshold"].OnEvent("Click", (*) => this.HandleBatchThresholdClick(guiManager, btnRefs["BatchThreshold"], moreGui))
        }
        if (btnRefs.Has("ShowSuccessMsg")) {
            btnRefs["ShowSuccessMsg"].OnEvent("Click", (*) => this.HandleSettingToggle("ShowSuccessMsg", btnRefs["ShowSuccessMsg"], guiManager,moreGui))
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
    }
    
    ;>>>新增：创建常规操作按钮的方法
    static CreateRegularButtons(moreGui, dialogWidth) {
        normalBtnWidth := WindowConstants.BUTTON_WIDTH
        normalBtnCount := WindowConstants.MORE_GUI_BUTTON_COUNT
        btnSpacing := WindowConstants.BUTTON_SPACING
        
        normalTotalWidth := (normalBtnWidth * normalBtnCount) + (btnSpacing * (normalBtnCount - 1))
        normalStartX := (dialogWidth - normalTotalWidth) // 2
        
        ; 确保常规按钮位置合理
        if (normalStartX < 10) {
            normalStartX := 10
        }
        
        ; 创建常规操作按钮
        btnImport := moreGui.Add("Button", "x" normalStartX " y+2 w" normalBtnWidth, "导入")
        btnExport := moreGui.Add("Button", "x+" btnSpacing " w" normalBtnWidth, "导出")
        btnAppend := moreGui.Add("Button", "x+" btnSpacing " w" normalBtnWidth, "追加")
        btnCancel := moreGui.Add("Button", "x+" btnSpacing " w" normalBtnWidth, "取消")
        
        ; 绑定事件
        btnImport.OnEvent("Click", (btnCtrl, info) => guiManager.HandleImport(moreGui))
        btnExport.OnEvent("Click", (btnCtrl, info) => guiManager.HandleExport(moreGui))
        btnAppend.OnEvent("Click", (btnCtrl, info) => guiManager.HandleAppend(moreGui))
        btnCancel.OnEvent("Click", (*) => moreGui.Destroy())
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
        
        ctlThreshold := inputGui.Add("Edit", "w100 Number", currentValue)
        ctlThreshold.OnEvent("Change", (*) => this.ValidateThresholdInput(ctlThreshold))
        
        ; 添加按钮
        btnSave := inputGui.Add("Button", "w80", "保存")
        btnCancel := inputGui.Add("Button", "x+10 w80", "取消")
        
        ;  修正：定义单独的函数
        ; btnSave.OnEvent("Click", this.HandleBatchThresholdSave.Bind(this, ctlThreshold, btnBatchThreshold,inputGui,parentGui))
        btnSave.OnEvent("Click", (*) => this.HandleBatchThresholdSave(ctlThreshold, btnBatchThreshold, inputGui, parentGui))
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
    static HandleBatchThresholdSave(ctlThreshold, btnBatchThreshold,inputGui,parentGui) {
        ; 获取原始值
        rawValue := Trim(ctlThreshold.Value)
        
        ;  检查是否为空
        if (rawValue = "") {
            MessageManager.ShowError("批量阈值不能为空",,,parentGui.Hwnd)
            return  ; 不关闭窗口，让用户重新输入
        }
        
        ;  检查是否为有效数字
        if (!RegExMatch(rawValue, "^\d+$")) {
            MessageManager.ShowError("请输入有效的数字",,,parentGui.Hwnd)
            return
        }
        
        ; 转换为数字
        try {
            value := Integer(rawValue)
        } catch {
            MessageManager.ShowError("请输入有效的数字",,,parentGui.Hwnd)
            return
        }
        
        ; 验证范围
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
    
    ;  新增：验证阈值输入（简化版，只过滤非数字字符）
    static ValidateThresholdInput(ctrl, *) {
        rawValue := ctrl.Value
        
        ; 只允许数字
        if (rawValue != "" && !RegExMatch(rawValue, "^\d*$")) {
            ; 删除非数字字符
            newValue := ""
            for i, ch in StrSplit(rawValue) {
                if (ch >= "0" && ch <= "9") {
                    newValue .= ch
                }
            }
            ctrl.Value := newValue
        }
    }

    ;  新增：简单的关闭处理
    static HandleInputGuiClose(inputGui, parentGui) {
        ; 恢复主窗口
        parentGui.Opt("-Disabled")
        
        ; 关闭输入窗口
        inputGui.Destroy()
    }

    ;  新增：处理editGui关闭
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

    ;  新增：处理moreGui关闭
    static HandleMoreGuiClose(guiManager, moreGui, *) {
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

    
    ; ==================== 打开软件事件处理 ====================
    
    ; 打开软件事件处理
    static HandleOpenSoftware(guiManager) {
        selectedIndex := guiManager.listBox.Value
        if (selectedIndex <= 0) {
            MessageManager.ShowError("请先选择一个软件","提示")
            return
        }

        ; 检查是否是提示项（列表为空时显示的提示信息）
        if (guiManager.listEmptyPrompt && guiManager.showingPrompt) {
            ; 是列表完全为空的提示项，执行载入操作
            guiManager.importExportMgr.HandleLoad("", guiManager)
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
            MessageManager.ShowError(result) ; 显示错误信息
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
                    MessageManager.ShowError("ControlFocus失败: " e.Message)
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
        ;    if(!guiManager.IsFirstItemPrompt()){
                guiManager.listBox.Value := 1
        ;    }
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
            MessageManager.ShowError("保存配置文件时出错：`n" e.Message)
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
                MessageManager.ShowError("在配置文件中未找到对应的section")
                return false
            }
        } catch as e {
            MessageManager.ShowError("删除配置文件时出错：`n" e.Message)
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
            MessageManager.ShowError("软件名称不能为空", "提示", ,editGui.Hwnd)
            return
        }
        
        if (path = "") {
             MessageManager.ShowError("软件路径不能为空", "提示", ,editGui.Hwnd)
            return
        }
        
        if (section = "") {
            MessageManager.ShowError("Section名称不能为空", "提示", ,editGui.Hwnd)
            return
        }

        ; >>> 使用统一的名称和路径校验
        if (!IniTools.IsValidName(name, 0, true)) {
            MessageManager.ShowError(
                "软件名称包含非法字符！`n`n"
                . "名称不能包含：\ / : * ? " . Chr(34) . " < > |`n"
                . "且不能以点开头或结尾", "提示", , editGui.Hwnd
            )
            return
        }

        if (!IniTools.IsValidPath(path, 0, true)) {
            MessageManager.ShowError(
                "软件路径格式不正确！`n`n"
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
                for displayName, software in guiManager.softwareMap {
                    ; 跳过自己（当前正在编辑的section）
                    if (software["section"] = guiManager.currentEditSection) {
                        continue
                    }

                    ; 如果尝试编辑为Root，不允许
                    if (StrLower(section) = "root" && StrLower(software["section"]) = "root") {
                        MessageManager.ShowError(
                            "Root section已存在，请使用其他名称", "提示", , editGui.Hwnd
                        )
                        return
                    }
                    
                    ; 检查其他软件是否有相同的section
                    if (software["section"] = section) {
                        MessageManager.ShowError(
                           "Section名称已存在，请使用其他名称", "提示", , editGui.Hwnd 
                        )
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
                    MessageManager.ShowError(
                        "软件名称已存在，请使用其他名称", "提示", , editGui.Hwnd
                    )
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
                        MessageManager.ShowError(
                            "软件名称已存在，请使用其他名称", "提示", , editGui.Hwnd
                        )
                        return
                    }
                }
                
                ; 检查section是否已存在
                for displayName, software in guiManager.softwareMap {
                    if (software["section"] = section) {
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
        if (!this.UpdateIniFileWithRoot(guiManager, name, path, section, guiManager.editMode)) {
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
                
                if (editGui.ctlSection) {
                    editGui.ctlSection.Value := displayName
                }
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