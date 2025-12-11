#Include "./common/IniTools.ahk"
#Include "./common/ImportExportManager.ahk"
#Include "./common/PathUtils.ahk"
#Include "./common/GuiEventHandlers.ahk"
#Include "./common/PinyinHelper.ahk"
#Include "./common/ListBoxHelper.ahk"
; ==============================
; GuiManager.ahk
; GUI管理类（支持增删改查）
; ==============================
class GuiManager {
    ; 构造函数
    __New(configManager) {
        ; 保存ConfigManager实例
        this.configManager := configManager
        
        ; 获取软件列表
        this.softwareList := configManager.GetSoftwareListArray()

        ; 获取Root路径
        this.rootPath := configManager.GetRootPath()
        
        ; 保存配置类型和路径，用于修改INI文件
        this.configType := configManager.GetConfigType()
        this.configPath := configManager.GetConfigPath()

        ; 保存导入导出管理器实例
        this.importExportMgr := ImportExportManager(this.configType, this.configPath)
        
        ; 初始化其他属性
        this.gui := ""
        this.listBox := ""
        this.softwareMap := Map()
        ; 添加搜索相关属性
        this.searchBox := ""
        this.allSoftwareList := []  ; 保存所有软件的原始列表
        
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

        ; >>> 新增：存储按钮引用，用于启用/禁用
        this.buttons := Map()
        ; >>> 新增：标记是否为多选状态
        this._isMultiSelect := false

        ; >>> 新增：右键菜单相关属性
        this.contextMenu := ""
        this.moveMenu := ""
        this.targetConfigs := []  ; 存储可移动的目标配置

    }
    
    ; 显示软件列表GUI
    ShowSoftwareList() {
        ; 创建GUI
        this.gui := Gui()
        this.gui.Title := (this.configType)

        ; 移除最大化按钮
        try {
           WinSetStyle("-0x00010000", this.gui.Hwnd)
        }

        ;设置字体
        this.gui.SetFont("s9", "JetBrains Mono")

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

        ; >>> 新增：监听ListBox选择变化，更新按钮状态
        this.listBox.OnEvent("Change", (*) => this.UpdateButtonStates())
        
        ; 添加软件到ListBox
        this.PopulateSoftwareList()

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
        ; btnOpen := this.gui.Add("Button", "x+10 w80", "打开")
        btnEdit := this.gui.Add("Button", "x+10 w80", "编辑")
        btnDelete := this.gui.Add("Button", "x+10 w80", "删除")
        btnRefresh := this.gui.Add("Button", "x+10 w80", "刷新")
        ; btnClose := this.gui.Add("Button", "x+10 w80", "关闭")
        btnLocate := this.gui.Add("Button", "x+10 w80", "定位")  ; 新增定位按钮
        btnMore := this.gui.Add("Button", "x+10 w80", "更多")  ; 新增更多按钮
        ; 新增回车打开事件
        this.gui.Add("Button",  "x+10 w0 Hidden Default", "打开").OnEvent('Click', (*) => GuiEventHandlers.HandleOpenSoftware(this))

        ; >>> 保存按钮引用
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
        btnMore.OnEvent("Click", (*) => GuiEventHandlers.HandleMoreClick(this))
        
        ; 双击ListBox事件 - 打开软件
        this.listBox.OnEvent("DoubleClick", (*) => GuiEventHandlers.HandleOpenSoftware(this))

        ; 为ListBox添加Tab键事件
        this.listBox.OnEvent("Focus", (*) => GuiEventHandlers.HandleListBoxFocus(this))
        ; this.listBox.OnEvent("LoseFocus", this.HandleListBoxLoseFocus.Bind(this))

        this.gui.OnEvent("Escape", (*) => this.gui.Destroy())  ; ESC关闭窗口

        ; 显示GUI
        this.gui.Show("w550")

        ; >>> 初始更新按钮状态
        this.UpdateButtonStates()

        ; 使用一次性定时器启用搜索框Tabstop
        ; SetTimer(ObjBindMethod(this, "EnableSearchBoxTab"), -50)
    }

    /* EnableSearchBoxTab() {
    ; 启用搜索框的Tabstop
    ; this.searchBox.Opt("+Tabstop")
    
    ; 确保ListBox有选中项（再次确认）
    if (this.allSoftwareList.Length > 0 && this.listBox.Value = 0) {
        this.listBox.Value := 1
    }
} */
    ; 检查是否是提示信息 - 标记
    IsFirstItemPrompt() {
        return this.showingPrompt
    }

    ; >>> 新增：检查用户是否真正离开了搜索框
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
    
    
    ; 修改PopulateSoftwareList方法
    PopulateSoftwareList() {
        ; 保存原始软件列表
        this.allSoftwareList := this.softwareList
        
        ; 显示所有软件
        this.ShowAllSoftware()
    }

    ; 显示所有软件
    ShowAllSoftware() {
        ; 清空现有项
        this.listBox.Delete()
        
        ; 创建存储名称-路径映射的Map
        this.softwareMap := Map()

    ; 检查是否有软件
    if (this.allSoftwareList.Length = 0) {
        ; 列表为空，显示提示信息
        this.listBox.Add([">>> 列表为空，点击'创建'按钮添加软件 <<<"])
        this.showingPrompt := true  ; 设置标记
        return
    }
        
        ; 添加软件到ListBox
        for software in this.allSoftwareList {
            name := software["name"]
            path := software["path"]
            section := software["section"]
            
            displayName := name
            
            ; 添加到ListBox
            this.listBox.Add([displayName])
            
            ; 存储到映射Map
            this.softwareMap[displayName] := Map(
                "name", name,
                "path", path,
                "section", section,
                "displayName", displayName
            )
        }

        this.showingPrompt := false  ; 没有显示提示信息

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
        
        ; 获取所有可用的配置类型（排除当前类型）
        this.targetConfigs := ConfigManager.GetAllConfigTypes(this.configType)
       
        ; 只有在有可移动目标时才添加"移动到..."菜单
        if (this.targetConfigs.Length > 0) {
            ; 创建"移动到..."子菜单
            this.moveMenu := Menu()
            
            ; 为每个目标配置创建子菜单项
            for index, configType in this.targetConfigs {
                ; >>> 修正：使用闭包捕获循环变量
                this.moveMenu.Add(configType, ((config) => (*) => this.HandleMenuMove(config))(configType))
            }
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
    
    ; >>> 新增：处理菜单移动
    HandleMenuMove(targetConfigType) {
        ; 直接调用GuiEventHandlers的移动方法
        GuiEventHandlers.HandleMoveTo(this, targetConfigType)
    }

    ; ==================== 核心功能方法 ====================
    
    ; 显示创建对话框
    ShowCreateDialog(*) {
        this.editMode := "create"
        this.currentEditSection := ""
        this.ShowEditDialogGui("", "")
    }
    
    ; 显示编辑对话框
    ShowEditDialog(*) {
        selectedIndex := this.listBox.Value
        if (selectedIndex <= 0) {
            MsgBox("请先选择一个要编辑的软件")
            return
        }
        
        selectedText := this.listBox.Text
        if (!this.softwareMap.Has(selectedText)) {
            MsgBox("未找到选中的软件信息")
            return
        }
        
        software := this.softwareMap[selectedText]
        this.editMode := "edit"
        this.currentEditSection := software["section"]

        ; >>> 检查是否为Root section，不允许编辑Root
        if (StrLower(software["section"]) = "root") {
            MsgBox("Root section不允许编辑，请使用其他方法修改Root设置。", "提示")
            return
        }


        ; >>> 保存要编辑的软件名称，用于编辑后重新选中
        this.softwareToSelectAfterEdit := software["name"]
        
        this.ShowEditDialogGui(software["name"], software["path"])
    }
    
    ; 显示编辑对话框（内部方法）- 修正版
    ShowEditDialogGui(defaultName, defaultPath) {
        ; 创建编辑对话框
        editGui := Gui()
        editGui.Title := (this.editMode = "create" ? "创建新软件" : "编辑软件")
        editGui.Opt("+AlwaysOnTop")
        
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
        editGui.Add("Text", "w400", "软件名称:")
        ctlName := editGui.Add("Edit", "w400", defaultName)
        editGui.ctlName := ctlName
        
        editGui.Add("Text", "w400", "软件路径:")
        ctlPath := editGui.Add("Edit", "w400", defaultPath)
        btnBrowse := editGui.Add("Button", "w80", "浏览...")
        btnBrowse.OnEvent("Click", (*) => GuiEventHandlers.HandleBrowseClick(ctlPath))
        editGui.ctlPath := ctlPath 
        
        editGui.Add("Text", "w400", "Section名称:")
        ctlSection := editGui.Add("Edit", "w400 +ReadOnly +Disabled")
        editGui.ctlSection := ctlSection
        
        ; 根据模式设置Section初始值
        if (this.editMode = "create") {
            ; 创建模式：使用软件名称作为section
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
        
        btnCancel.OnEvent("Click", (*) => editGui.Destroy())
        
        editGui.Show()
    }
    
    ; ==================== 原有方法 ====================
    
    ; >>> 新增：更新按钮状态的方法
    UpdateButtonStates() {
        ; 获取当前选择状态
        selectedTexts := this.listBox.Text
        
        ; 判断是否为多选
        if (Type(selectedTexts) = "Array") {
            this._isMultiSelect := selectedTexts.Length > 1
        } else {
            this._isMultiSelect := false
        }
        
        ; 根据多选状态启用/禁用按钮
        if (this._isMultiSelect) {
            ; 多选状态：禁用除删除和刷新外的所有按钮
            this.buttons["create"].Enabled := false
            this.buttons["edit"].Enabled := false
            this.buttons["locate"].Enabled := false
            this.buttons["more"].Enabled := false
            
            ; 启用删除和刷新按钮
            this.buttons["delete"].Enabled := true
            this.buttons["refresh"].Enabled := true
        } else {
            ; 单选或未选状态：启用所有按钮
            for name, btn in this.buttons {
                btn.Enabled := true
            }
        }
    }
    
    ; >>> 修改：刷新列表时重置多选状态
    ; >>> 修改：刷新列表时重置多选状态（修复边界情况）
    RefreshList(*) {
        ; >>> 保存当前选中的所有文本和索引
        oldSelectedTexts := ListBoxHelper.GetSelectedTexts(this.listBox)
        oldSelectedIndices := ListBoxHelper.GetSelectedIndices(this.listBox)
        
        ; 重新加载配置
        configMgr := ConfigManager(this.configType)
        this.configManager := configMgr
        this.softwareList := configMgr.GetSoftwareListArray()
        this.rootPath := configMgr.GetRootPath()
        
        ; 重新填充原始列表
        this.allSoftwareList := this.softwareList
        
        ; 根据当前搜索文本重新过滤
        if (HasProp(this, "searchBox") && this.searchBox.Value != "") {
            this.HandleSearchChange()
        } else {
            this.ShowAllSoftware()
        }

        ; >>> 检查是否显示提示信息（列表为空）
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
            
            ; >>> 更新按钮状态
            this.UpdateButtonStates()
            
            ; 提示刷新完成
            ToolTip("列表已刷新")
            SetTimer () => ToolTip(), -1000
            return
        }

        ; >>> 尝试恢复之前的所有选中项（多选）
        if (oldSelectedTexts.Length > 0 && this.allSoftwareList.Length > 0) {
            this.RestoreSelectedItems(oldSelectedTexts, oldSelectedIndices)
        } else if (this.allSoftwareList.Length > 0) {
            ; 如果没有之前的选中项但列表不为空，选择第一项
            try {
                this.listBox.Value := 1
            } catch {
                ; 忽略错误
            }
        }
        
        ; >>> 更新按钮状态
        this.UpdateButtonStates()
        
        ; 提示刷新完成
        ToolTip("列表已刷新")
        SetTimer () => ToolTip(), -1000
    }
    
    ; >>> 新增：恢复选中项（支持多选）
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
    
    ; >>> 新增：恢复单个选中项（智能恢复位置）
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
   ; >>> 修改：搜索框变化时也更新按钮状态
    HandleSearchChange(*) {
        ; >>> 用户正在搜索框中操作，设置标记
        this.userWasInSearchBox := true
        searchText := Trim(this.searchBox.Value)
        
        ; 如果搜索文本为空
        if (searchText = "") {
            ; 清空ListBox并显示所有软件
            this.listBox.Delete()
            this.softwareMap := Map()
            
            ; 重新填充所有软件
            for software in this.allSoftwareList {
                name := software["name"]
                path := software["path"]
                section := software["section"]
                
                displayName := name
                
                ; 添加到ListBox
                this.listBox.Add([displayName])
                
                ; 存储到映射Map
                this.softwareMap[displayName] := Map(
                    "name", name,
                    "path", path,
                    "section", section,
                    "displayName", displayName
                )
            }
            
            ; 搜索框为空时，如果用户在搜索框中，清除选中项
            ; 否则，如果有实际软件，选中第一项
            if (this.userWasInSearchBox) {
                this.listBox.Value := 0
            } else if (!this.IsFirstItemPrompt()) {
                this.listBox.Value := 1
            }
            
            ; >>> 更新按钮状态
            this.UpdateButtonStates()
            return
        }
        
        ; 如果有搜索文本，进行过滤
        searchTextLower := StrLower(searchText)
        
        ; 清空现有项
        this.listBox.Delete()
        this.softwareMap := Map()
        
        ; 记录找到的项目数量
        foundCount := 0
        
        ; 过滤并添加匹配的软件到ListBox
        for software in this.allSoftwareList {
            name := software["name"]
            path := software["path"]
            section := software["section"]
            
            ; 使用GuiTools进行匹配
            directMatch := InStr(StrLower(name), searchTextLower)
            pinyinScore := PinyinHelper.HasChinese(name) && PinyinHelper.LooksLikePinyin(searchTextLower) 
                ? PinyinHelper.GetPinyinMatchScore(name, searchText)
                : 0
            
            ; 如果直接匹配或拼音匹配成功
            if (directMatch || pinyinScore > 0) {
                this.listBox.Add([name])
                this.softwareMap[name] := Map(
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
            ; 不设置选中项
        }
        
        ; >>> 更新按钮状态
        this.UpdateButtonStates()
    }

    ; ==================== 导入导出事件处理器 ====================

    ; 导出配置
    ; >>> 新增：处理导入按钮点击
    HandleImport(moreGui) {
        if (this.importExportMgr.ImportConfig(moreGui)) {
            ; 导入成功后刷新列表
            this.RefreshList()
        }
    }

    ; >>> 新增：处理导出按钮点击
    HandleExport(moreGui) {
        this.importExportMgr.ExportConfig(moreGui)
    }

    ; >>> 新增：处理追加按钮点击
    HandleAppend(moreGui) {
        if (this.importExportMgr.AppendConfig(moreGui)) {
            ; 追加成功后刷新列表
            this.RefreshList()
        }
    }
}