#Include "./common/IniTools.ahk"
#Include "./common/ImportExportManager.ahk"
#Include "./common/PathUtils.ahk"
#Include "./common/GuiEventHandlers.ahk"
#Include "./common/PinyinHelper.ahk"
#Include "./common/FileProcessor.ahk"
#Include "./common/MessageManager.ahk"
#Include "./common/WindowConstants.ahk"
#Include "./common/WindowPositionUtils.ahk"
#Include "./common/ListBoxHelper.ahk"
#Include "./common/SettingsDialogManager.ahk"
; ==============================
; GuiManager.ahk
; GUI管理类（支持增删改查）
; ==============================
class GuiManager {
    ; 构造函数
    __New(configManager) {
        ; 保存ConfigManager实例
        this.configManager := configManager

        ; 保存配置类型和路径，用于修改INI文件
        this.configType := configManager.GetConfigType()
        this.configPath := configManager.GetConfigPath()

        ; 载入settings.ini配置
        ;  使用刷新方法来初始化配置
        this.RefreshSettings()
        
        ; 获取文件列表
        this.fileList := configManager.GetFileListArray()

        ; 获取Root路径
        this.rootPath := configManager.GetRootPath()

        ; 保存导入导出管理器实例
        this.importExportMgr := ImportExportManager(this.configType, this.configPath)
        
        ; 初始化其他属性
        this.gui := ""
        this.listBox := ""
        this.fileMap := Map()
        ; 添加搜索相关属性
        this.searchBox := ""
        this.allFileList := []  ; 保存所有文件的原始列表
        
        ; 当前编辑的模式：create 或 edit
        this.editMode := ""
        ; 当前编辑的原始section名称（编辑模式时使用）
        this.currentEditSection := ""

        ; 焦点状态跟踪
        this.searchBoxHasFocus := false

        ; 添加一个属性来跟踪是否显示了提示信息
        this.showingPrompt := false
        ; 添加一个标志，记录用户是否"刚刚"在搜索框中
        this.userWasInSearchBox := false

        this.listEmptyPrompt := false  ; 标记列表是否完全为空

        ; 存储按钮引用，用于启用/禁用
        this.buttons := Map()
        ; 标记是否为多选状态
        this._isMultiSelect := false

        ; >>> 新增：右键菜单相关属性
        this.contextMenu := ""
        this.moveMenu := ""
        this.targetConfigs := []  ; 存储可移动的目标配置

    }
    
    ; 显示文件列表GUI
    ShowFileList() {
        ; 创建GUI
        this.gui := Gui()
        this.gui.Title := (this.configType)

        ; 添加AlwaysOnTop选项确保窗口置顶
        ; t_openfile_settings：alwaysOnTop
        ; 根据配置动态设置窗口置顶
        if(this.isTop){
            this.gui.Opt("+AlwaysOnTop")
        } else {
            this.gui.Opt("-AlwaysOnTop")
        }

        ; 移除最大化按钮
        try {
           WinSetStyle("-0x00010000", this.gui.Hwnd)
        }

        ;设置字体
        this.gui.SetFont("s9")  ; 先重置为默认字体
        this.gui.SetFont("s10", "Microsoft YaHei")  ; 最低优先级
        this.gui.SetFont("s10", "Consolas")         ; 中等优先级  
        this.gui.SetFont("s9", "JetBrains Mono")   ; 最高优先级（最后设置）

        ; 设置默认边距（左、上、右、下）
        this.gui.MarginX := 25
        this.gui.MarginY := 10

        ; 创建搜索框
        this.gui.Add("Text", "w500", "搜索:")
        this.searchBox := this.gui.Add("Edit", "w500", "")
    
        ; 监听搜索框变化
        this.searchBox.OnEvent("Change", this.HandleSearchChange.Bind(this))
        this.searchBox.OnEvent("Focus", (*) => GuiEventHandlers.HandleSearchBoxFocus(this))
        this.searchBox.OnEvent("LoseFocus", (*) => GuiEventHandlers.HandleSearchBoxLoseFocus(this))
        
        ; 创建ListBox,作为第一个可Tab访问的控件
        this.listBox := this.gui.Add("ListBox", "w500 r15 Center Tabstop +Multi")
        
        ; 添加文件到ListBox
        this.PopulateFileList()

        ; >>> 新增：创建右键菜单
        this.CreateContextMenu()
        
        ; >>> 新增：绑定ListBox右键事件
        this.listBox.OnEvent("ContextMenu", (*) => this.ShowContextMenu())
        
        ; 添加按钮区域
        this.gui.Add("Text", "w500", "双击列表项或点击按钮操作")

        ; 计算按钮位置
        buttonWidth := 80
        buttonSpacing := 10
        totalWidth := (buttonWidth * 6) + (buttonSpacing * 5)

        ; GUI宽度是550，所以要居中在550宽度内
        startX := (550 - totalWidth) // 2
        
        ; 创建按钮 - 调整顺序和位置
        btnCreate := this.gui.Add("Button",  "x" startX " y+5 w80", "创建")
        btnEdit := this.gui.Add("Button", "x+10 w80", "编辑")
        btnDelete := this.gui.Add("Button", "x+10 w80", "删除")
        btnRefresh := this.gui.Add("Button", "x+10 w80", "刷新")
        btnLocate := this.gui.Add("Button", "x+10 w80", "定位")
        btnMore := this.gui.Add("Button", "x+10 w80", "设置")
        ; 回车打开事件
        this.gui.Add("Button",  "x+10 w0 Hidden Default", "打开").OnEvent('Click', (*) => GuiEventHandlers.HandleOpenFile(this))

        ; 保存按钮引用
        this.buttons["create"] := btnCreate
        this.buttons["edit"] := btnEdit
        this.buttons["delete"] := btnDelete
        this.buttons["refresh"] := btnRefresh
        this.buttons["locate"] := btnLocate
        this.buttons["more"] := btnMore

        ; 绑定事件
        btnCreate.OnEvent("Click", (*) => GuiEventHandlers.HandleCreateClick(this))
        btnEdit.OnEvent("Click", (*) => GuiEventHandlers.HandleEditClick(this))
        btnDelete.OnEvent("Click", (*) => GuiEventHandlers.HandleBulkDeleteClick(this))
        btnRefresh.OnEvent("Click", (*) => GuiEventHandlers.HandleRefreshClick(this))
        btnLocate.OnEvent("Click", (*) => GuiEventHandlers.HandleLocateClick(this))
        btnMore.OnEvent("Click", (*) => GuiEventHandlers.HandleSettingClick(this))
        
        ; 双击ListBox事件 - 打开文件
        this.listBox.OnEvent("DoubleClick", (*) => GuiEventHandlers.HandleOpenFile(this))

        ; 为ListBox添加Tab键事件
        this.listBox.OnEvent("Focus", (*) => GuiEventHandlers.HandleListBoxFocus(this))
        ; this.listBox.OnEvent("LoseFocus", this.HandleListBoxLoseFocus.Bind(this))

        ; 使用CloseGui方法关闭窗口
        this.gui.OnEvent("Escape", (*) => this.CloseGui())  ; ESC关闭窗口
        this.gui.OnEvent("Close", (*) => this.CloseGui())   ; 窗口关闭按钮

        ; 显示GUI
        this.gui.Show("w550")

        ; 使用ObjBindMethod注册窗口消息监听
        this.messageListener := ObjBindMethod(this, "HandleWindowMessage", this.gui.Hwnd)
        OnMessage(0x47, this.messageListener)   ; WM_WINDOWPOSCHANGED

        this.lastTopState := false

        ; 使用一次性定时器启用搜索框Tabstop
        ; SetTimer(ObjBindMethod(this, "EnableSearchBoxTab"), -50)

        ; 设置主窗口句柄给MessageManager
        ; t_openfile_settings：alwaysOnTop
        MessageManager.SetMainWindowHwnd(this.gui.Hwnd,this.configType)
        
    }
    
    ; t_openfile_settings：alwaysOnTop-get
    ;  刷新配置值的方法
    RefreshSettings() {
        ; 重新读取所有相关配置
        ; 修改：使用configType作为section名称
        this.isTop := SettingsManager.GetBool("AlwaysOnTop", this.configType)
        this.sortByAlphabet := SettingsManager.GetBool("SortByAlphabet", this.configType)
        this.enableExtension := SettingsManager.GetBool("EnableExtension", this.configType)
        this.batchThreshold := SettingsManager.GetInt("BatchThreshold", this.configType)
        this.showSuccessMsg := SettingsManager.GetBool("ShowSuccessMsg", this.configType)
        ; 可以在这里添加其他需要刷新的配置
    }

    ; 窗口监听的回调
    HandleWindowMessage(windowHwnd, wParam, lParam, msg, hwnd) {
        ; 只处理当前窗口的消息
        if (hwnd = windowHwnd) {
            this.HandleWindowPosChanged(hwnd)
        }
    }
    
    ; 处理消息监听
    HandleWindowPosChanged(hwnd) {
        ; 检查窗口是否还存在
        if (!WinExist("ahk_id " hwnd)) {
            return
        }
        
        try {
            DetectHiddenWindows true
            
            ; 只检查窗口的置顶状态
            ExStyle := WinGetExStyle("ahk_id " hwnd)
            isCurrentlyTop := (ExStyle & 0x8) ; 0x8 = WS_EX_TOPMOST
            
            DetectHiddenWindows false
            
            ; 只有置顶状态改变时才处理
            if (isCurrentlyTop != this.lastTopState) {
                this.lastTopState := isCurrentlyTop
                
                ; 获取当前的配置状态
                currentConfigValue := SettingsManager.GetBool("AlwaysOnTop", this.configType)
                
                ; 如果当前实际状态与配置不一致，更新配置
                if (isCurrentlyTop != currentConfigValue) {
                    SettingsManager.SetValue("AlwaysOnTop", isCurrentlyTop ? "true" : "false", this.configType)
                    this.RefreshSettings()
                    
                    ; 显示提示（可选）
                    if(WindowConstants.DEBUG_MODE){
                        ToolTip("窗口置顶状态已更新: " (isCurrentlyTop ? "已置顶" : "取消置顶"))
                        SetTimer () => ToolTip(), -2000
                    }
    
                }
            }
        } catch {
            return
        }
    }

    ; 统一关闭函数
    CloseGui() {
        ; 取消消息监听
        if (this.messageListener) {
            OnMessage(0x47, this.messageListener, 0)  ; 取消监听
            this.messageListener := 0
        }
        
        ; 销毁GUI
        if (this.gui) {
            this.gui.Destroy()
            this.gui := ""
        }
    }

    /* EnableSearchBoxTab() {
        ; 启用搜索框的Tabstop
        ; this.searchBox.Opt("+Tabstop")
        
        ; 确保ListBox有选中项（再次确认）
        if (this.allFileList.Length > 0 && this.listBox.Value = 0) {
            this.listBox.Value := 1
        }
    } */

    ; 检查是否是提示信息 - 标记
    IsFirstItemPrompt() {
        return this.showingPrompt
    }

    ; 检查用户是否真正离开了搜索框
    CheckIfUserLeftSearchBox() {
        try {
            focusedControl := ControlGetFocus(this.gui)
            ; 如果焦点还在搜索框，恢复标记
            if (focusedControl = this.searchBox.ClassNN) {
                this.userWasInSearchBox := true
                return
            }
        } catch {
            ; 获取焦点失败
        }
        
        ; 用户真正离开了搜索框，清除标记
        this.userWasInSearchBox := false
    }
    
    
    PopulateFileList() {
        ; 保存原始文件列表
        this.allFileList := this.fileList
        
        ; 显示所有文件
        this.ShowAllFile()
    }

    ; 显示所有文件
    ShowAllFile() {
        ; 清空现有项
        this.listBox.Delete()
        
        ; 创建存储名称-路径映射的Map
        this.fileMap := Map()

    ; 检查是否有文件
    if (this.allFileList.Length = 0) {
        ; 列表为空，显示提示信息
        this.listBox.Add([">>> 列表为空，点击'创建'按钮添加文件 <<<"])
        this.showingPrompt := true  ; 设置标记
        this.listEmptyPrompt := true  ; 设置列表为空标记
        return
    }
        
        ; 添加文件到ListBox
        for file in this.allFileList {
            name := file["name"]
            path := file["path"]
            section := file["section"]
            
            displayName := name
            
            ; 添加到ListBox
            this.listBox.Add([displayName])
            
            ; 存储到映射Map
            this.fileMap[displayName] := Map(
                "name", name,
                "path", path,
                "section", section,
                "displayName", displayName
            )
        }

        this.showingPrompt := false  ; 没有显示提示信息
        this.listEmptyPrompt := false  ; 列表不为空

        ; 条件：不是提示信息 + 用户不在搜索框中 + 搜索框为空
        /* if (!this.showingPrompt && !this.userWasInSearchBox && this.searchBox.Value = "") {
            this.listBox.Value := 1
        } */

    }

    ; ==================== 右键菜单功能方法 ====================

    ; >>> 新增：创建上下文菜单
    CreateContextMenu() {
        ; 创建主菜单
        this.contextMenu := Menu()
        
        ; 添加"移动到..."子菜单
        this.moveMenu := Menu()

        ;!!! 新增：创建"复制到"子菜单  
        this.copyMenu := Menu()  ; 新增复制菜单
        
        ; 获取所有可用的配置类型（排除当前类型）
        this.targetConfigs := ConfigManager.GetAllConfigTypes(this.configType)
       
        ; 只有在有可移动目标时才添加"移动到..."菜单
        if (this.targetConfigs.Length > 0) {
            
            ; 为每个目标配置创建子菜单项
            for index, configType in this.targetConfigs {
                ; 创建一个闭包来捕获当前configType
                ;!!! 修改：使用闭包确保参数正确传递
                this.moveMenu.Add(configType, ((currentType) => (*) => GuiEventHandlers.HandleMoveTo(this, currentType))(configType))
            
                ;!!! 新增：复制菜单项
                this.copyMenu.Add(configType, ((currentType) => (*) => GuiEventHandlers.HandleCopyTo(this, currentType))(configType))
            }
            ;!!! 新增：添加复制菜单项
            this.contextMenu.Add("复制到", this.copyMenu)
            this.contextMenu.Add("移动到...", this.moveMenu)
        }

    }
    
    ; >>> 新增：显示上下文菜单
    ShowContextMenu() {
        ; 检查是否有选中项，如果没有，不显示菜单
        selectedTexts := ListBoxHelper.GetSelectedTexts(this.listBox)
        if (selectedTexts.Length = 0) {
            return
        }
        
        ; 检查是否显示提示信息，如果是，不显示菜单
        if (this.showingPrompt) {
            return
        }
        
        ; 显示菜单
        this.contextMenu.Show()
    }

    ; ==================== 核心功能方法 ====================
    
    ; 显示编辑对话框（内部方法）- 修正版
    ShowEditDialogGui(defaultName, defaultPath) {
        ; 创建编辑对话框
        editGui := Gui()
        editGui.Title := (this.editMode = "create" ? "创建新文件" : "编辑文件")
        ; 修正：在 GUI 层面启用文件拖放
        editGui.Opt("+E0x10")  ; +E0x10 允许拖放文件到窗口

        ; 总是设置 Owner 关系
        editGui.Opt("+Owner" this.gui.Hwnd)

        ; t_openfile_settings：alwaysOnTop
        if(this.isTop){
            editGui.Opt("+AlwaysOnTop")
        }

        ; 关键：禁用主窗口（灰色不可操作）
        this.gui.Opt("+Disabled")

        ; 移除最小化按钮
        try {
        WinSetStyle("-0x00020000", editGui.Hwnd)
        }
        
        ; 存储必要属性到GUI对象
        editGui.editMode := this.editMode  ; 必须：区分创建/编辑模式
        editGui.ctlName := ""  ; 用于事件绑定
        editGui.ctlPath := ""  ; 用于浏览文件
        editGui.ctlSection := ""  ; 用于更新Section
        
        ; 如果需要，保存当前编辑的原始section（编辑模式）
        if (this.editMode = "edit") {
            editGui.currentEditSection := this.currentEditSection  ; 用于重复检查
        }
        
        ; 添加输入控件
        editGui.Add("Text", "w400", "文件名称:")
        ctlName := editGui.Add("Edit", "w400", defaultName)
        editGui.ctlName := ctlName
        
        editGui.Add("Text", "w400", "文件路径:")
        ctlPath := editGui.Add("Edit", "w400", defaultPath)
        btnBrowse := editGui.Add("Button", "w80", "浏览...")
        btnBrowse.OnEvent("Click", (*) => GuiEventHandlers.HandleBrowseClick(ctlPath,editGui,this))
        editGui.ctlPath := ctlPath 
        
        editGui.Add("Text", "w400", "Section名称:")
        ctlSection := editGui.Add("Edit", "w400 +ReadOnly +Disabled")
        editGui.ctlSection := ctlSection
        
        ; 根据模式设置Section初始值
        if (this.editMode = "create") {
            ; 创建模式：使用文件名称作为section
            ctlSection.Value := defaultName
            
            ; 绑定名称变化事件（自动更新Section）
            ctlName.OnEvent("Change", (*) => GuiEventHandlers.HandleNameChangeForEditGui(editGui))
            
            ; 创建复选框区域
            editGui.Add("Text", "w400", "")
            chkBatchAdd := editGui.Add("CheckBox", "w400", "批量添加模式")
            editGui.chkBatchAdd := chkBatchAdd  ; 必须：用于批量添加判断
            editGui.Add("Text", "w400 cGray", "勾选后，保存后不清空表单，可继续添加")
            
        } else {
            ; 编辑模式：显示当前section
            ctlSection.Value := this.currentEditSection
            
            ; 绑定名称变化事件（自动更新Section）
            ctlName.OnEvent("Change", (*) => GuiEventHandlers.HandleNameChangeForEditGui(editGui))
        }

        ; 添加拖放支持
        ; editGui.OnEvent("DropFiles", (guiObj, ctrlObj, filesArray, x, y) => GuiEventHandlers.OnDropFilesCallback(guiObj, ctrlObj, filesArray, x, y))
        editGui.OnEvent("DropFiles", handleDropFiles)
        handleDropFiles(guiObj, ctrlObj, filesArray, x, y) => GuiEventHandlers.OnDropFilesCallback(this, guiObj, ctrlObj, filesArray, x, y)
        
        ; 添加按钮
        btnSave := editGui.Add("Button", "w80", "保存")
        btnCancel := editGui.Add("Button", "x+10 w80", "取消")
        
        ; 绑定保存事件
        btnSave.OnEvent("Click", (*) => GuiEventHandlers.HandleSaveClick(
            editGui, 
            this,
            ctlName.Value, 
            ctlPath.Value, 
            ctlSection.Value,
            this.editMode = "create" ? editGui.chkBatchAdd : false ; 编辑模式不传递复选框
        ))
        
        ; 销毁事件
        btnCancel.OnEvent("Click", (*) => GuiEventHandlers.HandleEditGuiClose(this,editGui))
        editGui.OnEvent("close",(*) => GuiEventHandlers.HandleEditGuiClose(this,editGui))
        editGui.OnEvent("Escape", (*) => GuiEventHandlers.HandleEditGuiClose(this, editGui))
        
        ; 计算EditGui高度
        editHeight := (this.editMode = "create" ? WindowConstants.EDIT_GUI_HEIGHT_CREATE : WindowConstants.EDIT_GUI_HEIGHT_EDIT)
        
        ; 使用工具类居中显示窗口
        WindowPositionUtils.CenterChildWindowWithConstants(
            this.gui.Hwnd,
            editGui,
            WindowConstants.EDIT_GUI_WIDTH,
            editHeight,
            WindowConstants.EDIT_GUI_ADJUST_LEFT,
            WindowConstants.EDIT_GUI_ADJUST_TOP
        )
    }


    
    ; ==================== 原有方法 ====================
    
    ; 刷新列表时重置多选状态
    RefreshList(*) {
        ; 保存当前选中的所有文本和索引
        oldSelectedTexts := ListBoxHelper.GetSelectedTexts(this.listBox)
        oldSelectedIndices := ListBoxHelper.GetSelectedIndices(this.listBox)
        
        ; 重新加载配置
        configMgr := ConfigManager(this.configType)
        this.configManager := configMgr
        this.fileList := configMgr.GetFileListArray()
        this.rootPath := configMgr.GetRootPath()
        
        ; 重新填充原始列表
        this.allFileList := this.fileList
        
        ; 根据当前搜索文本重新过滤
        if (HasProp(this, "searchBox") && this.searchBox.Value != "") {
            this.HandleSearchChange()
        } else {
            this.ShowAllFile()
        }

        ; 检查是否显示提示信息（列表为空）
        if (this.showingPrompt) {
            ; 列表为空，设置搜索框焦点
            try {
                this.listBox.Value := 0  ; 清除任何选中
                this.searchBox.Focus()
            } catch {
                try {
                    ControlFocus(this.searchBox, this.gui)
                } catch {
                    ; 忽略错误
                }
            }
            
            ; 提示刷新完成
            ToolTip("列表已刷新")
            SetTimer () => ToolTip(), -1000
            return
        }

        ; 尝试恢复之前的所有选中项（多选）
        if (oldSelectedTexts.Length > 0 && this.allFileList.Length > 0) {
            this.RestoreSelectedItems(oldSelectedTexts, oldSelectedIndices)
        } else if (this.allFileList.Length > 0) {
            ; 如果没有之前的选中项但列表不为空，选择第一项
            try {
                this.listBox.Value := 1
            } catch {
                ; 忽略错误
            }
        }
        
        ; 提示刷新完成
        ToolTip("列表已刷新")
        SetTimer () => ToolTip(), -1000
    }
    
    ; 恢复选中项（支持多选）
    RestoreSelectedItems(selectedTexts, oldIndices) {
        ; 清空当前选中
        try {
            this.listBox.Value := 0
        } catch {
            ; 忽略错误
        }
        
        ; 用于存储找到的索引
        foundIndices := []
        
        ; 如果只有一个选中项，使用智能恢复（优先尝试相同位置）
        if (selectedTexts.Length == 1) {
            this.RestoreSingleItem(selectedTexts[1], oldIndices[1])
            return
        }
        
        ; 多个选中项：尝试按文本查找
        for text in selectedTexts {
            ; 从第1项开始查找
            index := 1
            found := false
            
            while (true) {
                try {
                    ; 临时选中该项
                    this.listBox.Value := index
                    
                    ; 获取选中文本（使用 ListBoxHelper，简化类型处理）
                    currentText := ListBoxHelper.GetListBoxText(this.listBox)
                    
                    ; 检查是否匹配（现在直接比较字符串，不再需要类型检查）
                    if (currentText = text) {
                        foundIndices.Push(index)
                        found := true
                        break
                    }
                    
                    index++
                } catch {
                    ; 超出范围
                    break
                }
            }
            
            ; 如果没找到这个文本，跳过
            if (!found) {
                continue
            }
        }
        
        ; 设置多选
        if (foundIndices.Length > 0) {
            try {
                ; 如果有多个索引，设置多选
                if (foundIndices.Length > 1) {
                    this.listBox.Value := foundIndices
                } else {
                    this.listBox.Value := foundIndices[1]
                }
            } catch {
                ; 如果设置失败，至少选中第一个
                try {
                    this.listBox.Value := foundIndices[1]
                } catch {
                    ; 完全失败，不清空
                }
            }
        }
    }
    
    ; 恢复单个选中项（智能恢复位置）
    RestoreSingleItem(textToSelect, oldIndex) {
        ; 先尝试在原来的位置查找
        try {
            this.listBox.Value := oldIndex
            currentText := ListBoxHelper.GetListBoxText(this.listBox)  ; 使用 ListBoxHelper
            
            ; 检查是否匹配（直接比较字符串）
            if (currentText = textToSelect) {
                return  ; 找到了，直接返回
            }
        } catch {
            ; 原来的位置无效，继续查找
        }
        
        ; 如果原来的位置不匹配，使用SelectItemByText查找
        GuiEventHandlers.SelectItemByText(this, textToSelect)
    }
    
    ; 处理搜索框变化（简化且高效）
    ; 搜索框变化时也更新按钮状态
    HandleSearchChange(*) {
        ; 用户正在搜索框中操作，设置标记
        this.userWasInSearchBox := true
        searchText := Trim(this.searchBox.Value)
        
        ; 如果搜索文本为空
        if (searchText = "") {
            
            ; 直接调用 ShowAllFile 方法
            this.ShowAllFile()

            ; 搜索框为空时，如果用户在搜索框中，清除选中项
            ; 否则，如果有实际文件，选中第一项
            if (this.userWasInSearchBox) {
                this.listBox.Value := 0
            } else if (!this.IsFirstItemPrompt()) {
                this.listBox.Value := 1
            }

            return
        }
        
        ; 如果有搜索文本，进行过滤
        searchTextLower := StrLower(searchText)
        
        ; 清空现有项
        this.listBox.Delete()
        this.fileMap := Map()
        
        ; 记录找到的项目数量
        foundCount := 0
        
        ; 过滤并添加匹配的文件到ListBox
        for file in this.allFileList {
            name := file["name"]
            path := file["path"]
            section := file["section"]
            
            ; 使用GuiTools进行匹配
            directMatch := InStr(StrLower(name), searchTextLower)
            pinyinScore := PinyinHelper.HasChinese(name) && PinyinHelper.LooksLikePinyin(searchTextLower) 
                ? PinyinHelper.GetPinyinMatchScore(name, searchText)
                : 0
            
            ; 如果直接匹配或拼音匹配成功
            if (directMatch || pinyinScore > 0) {
                this.listBox.Add([name])
                this.fileMap[name] := Map(
                    "name", name,
                    "path", path,
                    "section", section,
                    "displayName", name
                )
                foundCount++
            }
        }
        
        ; 设置选中项逻辑
        if (foundCount > 0) {
            ; 有匹配项，选择第一项
            this.listBox.Value := 1
            this.showingPrompt := false
        } else {
            ; 没有匹配项，显示提示
            this.listBox.Add([">>> 未找到匹配项 <<<"])
            this.showingPrompt := true
            this.listEmptyPrompt := false  ; 这不是列表为空的情况
            ; 不设置选中项
        }
    }

    ; ==================== 导入导出事件处理器 ====================

    ; 处理导出按钮点击
    HandleExport(moreGui) {
        this.importExportMgr.ExportConfig(moreGui,this)
    }

    ; 处理导入按钮点击
    HandleImport(moreGui) {
        if (this.importExportMgr.ImportConfig(moreGui,this)) {
            ; 导入成功后刷新列表
            this.RefreshList()
        }
    }

    ; 处理追加按钮点击
    HandleAppend(moreGui) {
        if (this.importExportMgr.AppendConfig(moreGui,this)) {
            ; 追加成功后刷新列表
            this.RefreshList()
        }
    }
    
    ; 处理载入按钮点击
    HandleLoad(moreGui){
        ; 内部处理刷新列表
        this.importExportMgr.HandleLoad(moreGui,this)
    }
}