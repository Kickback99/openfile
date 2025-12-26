#Include "./common/IniTools.ahk"
#Include "./common/ImportExportManager.ahk"
#Include "./common/PathUtils.ahk"
#Include "./common/GuiEventHandlers.ahk"
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

    }
    
    ; 显示软件列表GUI
    ShowSoftwareList() {
        ; 创建GUI
        this.gui := Gui()
        this.gui.Title := (this.configType)
        this.gui.Opt("+Resize") ; 允许调整大小

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
        this.listBox := this.gui.Add("ListBox", "w500 r15 Center Tabstop")
        
        ; 添加软件到ListBox
        this.PopulateSoftwareList()
        
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
        ; 绑定事件
        btnCreate.OnEvent("Click", (*) => GuiEventHandlers.HandleCreateClick(this))
        btnEdit.OnEvent("Click", (*) => GuiEventHandlers.HandleEditClick(this))
        btnDelete.OnEvent("Click", (*) => GuiEventHandlers.HandleDeleteClick(this))
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
    
    ; 刷新列表
    RefreshList(*) {

        ; >>> 保存当前选中的文本
        oldSelectedText := ""
        if (this.listBox.Value > 0) {
            oldSelectedText := this.listBox.Text
        }

        ; 重新加载配置
        configMgr := ConfigManager(this.configType)
        this.configManager := configMgr
        this.softwareList := configMgr.GetSoftwareListArray()
        this.rootPath := configMgr.GetRootPath()  ; 重新获取Root路径
        
        ; 重新填充原始列表
        this.allSoftwareList := this.softwareList
        
        ; 根据当前搜索文本重新过滤
        ; 检查 searchBox 是否存在且有值
        if (HasProp(this, "searchBox") && this.searchBox.Value != "") {
            this.HandleSearchChange()
        } else {
            this.ShowAllSoftware()
        }

        ; >>> 尝试恢复之前的选中项
        if (oldSelectedText != "") {
            GuiEventHandlers.SelectItemByText(this, oldSelectedText)
        }
        
        ; 提示刷新完成
        ToolTip("列表已刷新")
        SetTimer () => ToolTip(), -1000
    }
    
    ; 处理搜索框变化（简化且高效）
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
            
            ; 转换为小写进行匹配
            lowerName := StrLower(name)
            
            ; 简单匹配：是否包含搜索文本
            if (InStr(lowerName, searchTextLower)) {
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
                
                foundCount++
            }
        }
        
        ; 设置选中项逻辑
        if (foundCount > 0) {
            ; 有匹配项，选择第一项
            this.listBox.Value := 1
            this.showingPrompt := false  ; 没有显示提示信息
        } else {
            ; 没有匹配项，显示提示
            this.listBox.Add([">>> 未找到匹配项 <<<"])
            this.showingPrompt := true  ; 设置标记
            ; 不设置选中项
        }
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