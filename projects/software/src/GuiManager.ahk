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
        this.searchBox.OnEvent("Focus", this.HandleSearchBoxFocus.Bind(this))
        this.searchBox.OnEvent("LoseFocus", this.HandleSearchBoxLoseFocus.Bind(this))
        
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
        btnEnter := this.gui.Add("Button",  "x+10 w0 Hidden Default", "打开").OnEvent('Click',this.OpenSoftware.Bind(this))
        
        ; 绑定事件
        btnCreate.OnEvent("Click", this.ShowCreateDialog.Bind(this))
        ; btnOpen.OnEvent("Click", this.OpenSoftware.Bind(this))
        btnEdit.OnEvent("Click", this.ShowEditDialog.Bind(this))
        btnDelete.OnEvent("Click", this.DeleteSoftware.Bind(this))
        btnRefresh.OnEvent("Click", this.HandleRefreshButtonClick.Bind(this))
        ; btnClose.OnEvent("Click", this.CloseGui.Bind(this))
        btnLocate.OnEvent("Click", this.LocateSoftware.Bind(this))  ; 绑定定位事件
        btnMore.OnEvent("Click", this.ShowMoreDialog.Bind(this))  ; 绑定更多事件
        
        ; 双击ListBox事件 - 打开软件
        this.listBox.OnEvent("DoubleClick", this.OpenSoftware.Bind(this))

        ; 为ListBox添加Tab键事件
        this.listBox.OnEvent("Focus", this.HandleListBoxFocus.Bind(this))
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

    ; >>> 新增：处理刷新按钮点击
    HandleRefreshButtonClick(*) {
        ; 保存刷新前的状态
        searchBoxWasEmpty  := this.searchBox.Value
        wasInSearchBox  := this.userWasInSearchBox
        
        ; >>> 调试：显示当前状态
        /* MsgBox("刷新前状态：`n"
            . "userWasInSearchBox: " wasInSearchBox "`n"
            . "searchBoxText: '" searchBoxWasEmpty "'`n"
            . "searchBoxHasFocus: " this.searchBoxHasFocus) */


        ; 执行刷新
        this.RefreshList()
        ; >>> 关键逻辑：如果应该跳过自动选中，确保不选中
        if (wasInSearchBox && searchBoxWasEmpty = '') {
            this.listBox.Value := 0
            
            ; >>> 调试：检查搜索框状态
            /* isVisible := this.searchBox.Visible
            isEnabled := this.searchBox.Enabled
            hwnd := this.searchBox.Hwnd
            guiHwnd := this.gui.Hwnd */
            
            /* MsgBox("搜索框状态：`n"
                . "可见: " isVisible "`n"
                . "启用: " isEnabled "`n"
                . "搜索框句柄: " hwnd "`n"
                . "GUI句柄: " guiHwnd) */
            
            ; 尝试设置焦点
            try {
                ControlFocus(this.searchBox, this.gui)
                ; MsgBox("ControlFocus调用成功")
            } catch as e {
                MsgBox("ControlFocus失败: " e.Message)
            }
        } else {
            ; >>> 只有条件不满足时才清除标记
            this.userWasInSearchBox := false
        }

    }
    
    ; 处理ListBox获得焦点 - 简化版
    HandleListBoxFocus(*) {
        ; 只有当ListBox当前没有选中项时，才设置选中第一项
        if (this.listBox.Value = 0) {
            ; 不是提示消息，设置为选中项
           if(!this.IsFirstItemPrompt()){
                this.listBox.Value := 1
           }
        }
    }

    ; 处理搜索框获得焦点
    HandleSearchBoxFocus(*) {
        this.searchBoxHasFocus := true
        this.userWasInSearchBox := true  ; >>> 标记用户进入了搜索框
        
        ; 如果搜索框为空，清除ListBox选中项
        if (this.searchBox.Value = "") {
            this.listBox.Value := 0
        }
    }

    ; 处理搜索框失去焦点
    HandleSearchBoxLoseFocus(*) {
        this.searchBoxHasFocus := false

        ; >>> 延迟检查用户是否离开了搜索框
        SetTimer(() => this.CheckIfUserLeftSearchBox(), -100)
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
        btnBrowse.OnEvent("Click", (*) => this.BrowseForFile(ctlPath))
        editGui.ctlPath := ctlPath 
        
        editGui.Add("Text", "w400", "Section名称:")
        ctlSection := editGui.Add("Edit", "w400 +ReadOnly +Disabled")
        editGui.ctlSection := ctlSection
        
        ; 根据模式设置Section初始值
        if (this.editMode = "create") {
            ; 创建模式：使用软件名称作为section
            ctlSection.Value := defaultName
            
            ; 绑定名称变化事件（自动更新Section）
            ctlName.OnEvent("Change", (*) => ctlSection.Value := ctlName.Value)
            
            ; 创建复选框区域
            editGui.Add("Text", "w400", "")
            chkBatchAdd := editGui.Add("CheckBox", "w400", "批量添加模式")
            editGui.chkBatchAdd := chkBatchAdd  ; 必须：用于批量添加判断
            editGui.Add("Text", "w400 cGray", "勾选后，保存后不清空表单，可继续添加")
            
        } else {
            ; 编辑模式：显示当前section
            ctlSection.Value := this.currentEditSection
            
            ; 绑定名称变化事件（自动更新Section）
            ctlName.OnEvent("Change", (*) => ctlSection.Value := ctlName.Value)
        }
        
        ; 添加按钮
        btnSave := editGui.Add("Button", "w80", "保存")
        btnCancel := editGui.Add("Button", "x+10 w80", "取消")
        
        ; 绑定保存事件
        btnSave.OnEvent("Click", (*) => this.SaveSoftware(
            editGui, 
            ctlName.Value, 
            ctlPath.Value, 
            ctlSection.Value,
            this.editMode = "create" ? editGui.chkBatchAdd : false  ; 编辑模式不传递复选框
        ))
        
        btnCancel.OnEvent("Click", (*) => editGui.Destroy())
        
        editGui.Show()
    }
    ; 浏览文件
    BrowseForFile(pathControl) {
        selectedFile := FileSelect(1, , "选择可执行文件", "可执行文件 (*.exe; *.bat; *.cmd)")
        if (selectedFile != "") {
            pathControl.Value := selectedFile
        }
    }
    
    ; 保存软件（创建或编辑）
    SaveSoftware(editGui, name, path, section, chkBatchAdd := "") {

       ; >>> 保存旧的选择信息
        oldSelectedText := ""
        isEditingMode := (this.editMode = "edit")
        if (isEditingMode && this.listBox.Value > 0) {
            oldSelectedText := this.listBox.Text
        }

        ; 输入验证
        if (name = "") {
            MsgBox("软件名称不能为空", "提示", "Owner" editGui.Hwnd)
            return
        }
        
        if (path = "") {
             MsgBox("软件路径不能为空", "提示", "Owner" editGui.Hwnd)
            return
        }
        
        if (section = "") {
            MsgBox("Section名称不能为空", "提示", "Owner" editGui.Hwnd)
            return
        }

        ; >>> 使用统一的名称和路径校验
        if (!this.IsValidName(name, 0, true)) {
            MsgBox("软件名称包含非法字符！`n`n"
                . "名称不能包含：\ / : * ? " . Chr(34) . " < > |`n"
                . "且不能以点开头或结尾", "提示", "Owner" editGui.Hwnd)
            return
        }
    
        if (!this.IsValidPath(path, 0, true)) {
            MsgBox("软件路径格式不正确！`n`n"
                . "路径必须包含：`n"
                . "1. 盘符（如C:）`n"
                . "2. 路径分隔符（\或/）`n"
                . "3. 不能包含非法字符：* ? " . Chr(34) . " < > |", "提示", "Owner" editGui.Hwnd)
            return
        }

        ; >>> 修改：编辑模式下不允许使用Root
        if (this.editMode = "edit") {
            if (section = "Root" || section = "root" || StrLower(section) = "root") {
                MsgBox("编辑模式不允许使用'Root'作为Section名称", "提示", "Owner" editGui.Hwnd)
                return
            }
        }

        ; ==================== 重名检查逻辑 ====================
        
        if (this.editMode = "edit") {
            ; ************** 编辑模式检查逻辑 **************
            
            ; 检查新的section名称是否已存在（排除自身）
            if (section != this.currentEditSection) {
                for displayName, software in this.softwareMap {
                    ; 跳过自己（当前正在编辑的section）
                    if (software["section"] = this.currentEditSection) {
                        continue
                    }

                    
                    if (StrLower(section) = "root" && StrLower(software["section"]) = "root") {
                        MsgBox("Root section已存在，请使用其他名称", "提示", "Owner" editGui.Hwnd)
                        return
                    }
                    
                    ; 检查其他软件是否有相同的section
                    if (software["section"] = section) {
                        MsgBox("Section名称已存在，请使用其他名称", "提示", "Owner" editGui.Hwnd)
                        return
                    }
                }
            }
            
            ; 检查新的软件名称是否已存在（排除自身）
            for displayName, software in this.softwareMap {
                ; 跳过自己（当前正在编辑的软件）
                if (software["section"] = this.currentEditSection) {
                    continue
                }
                
                ; 检查其他软件是否有相同的名称
                if (software["name"] = name) {
                    MsgBox("软件名称已存在，请使用其他名称", "提示", "Owner" editGui.Hwnd)
                    return
                }
            }
            
        } else if (this.editMode = "create") {
        ; ************** 创建模式检查逻辑 **************
            
            ; >>> 修改：创建模式允许Root，但要检查唯一性
            if (StrLower(section) = "root") {
                ; 检查Root是否已存在
                for displayName, software in this.softwareMap {
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
                for displayName, software in this.softwareMap {
                    if (software["name"] = name) {
                        MsgBox("软件名称已存在，请使用其他名称", "提示", "Owner" editGui.Hwnd)
                        return
                    }
                }
                
                ; 检查section是否已存在
                for displayName, software in this.softwareMap {
                    if (software["section"] = section) {
                        MsgBox("Section名称已存在，请使用其他名称", "提示", "Owner" editGui.Hwnd)
                        return
                    }
                }
            }
        }
        
        ; ==================== 更新INI文件 ====================
        
        ; 更新INI文件（用于：1.编辑模式但section未变化 2.创建模式）
        if (!this.UpdateIniFileWithRoot(name, path, section,this.editMode)) {
            MsgBox("保存失败，无法更新配置文件", "错误", "Owner" editGui.Hwnd)
            return
        }

        ; 显示保存成功提示
        this.ShowToolTip("保存成功！", 1500)
        
        ; 检查是否批量添加模式（只针对创建模式）
        isBatchMode := false
        if (this.editMode = "create" && chkBatchAdd && chkBatchAdd != false && chkBatchAdd.Value = 1) {
            isBatchMode := true
        }
        
        if (!isBatchMode) {
            ; 非批量模式，关闭编辑窗口
            editGui.Destroy()
            
            ; >>> 刷新列表并根据模式选择相应的项
            if (this.editMode = "edit") {
                ; 编辑模式：重新选中编辑的项（或新名称）
                this.RefreshAndSelect(name)
            } else {
                ; 创建模式：选中新增的项
                this.RefreshAndSelect(name)
            }
        } else {
            ; 批量模式，清空表单但不关闭窗口
            editGui.ctlName.Value := ""
            editGui.ctlPath.Value := ""
            editGui.ctlSection.Value := ""
            ; 将焦点设置到名称输入框，方便继续输入
            editGui.ctlName.Focus()
            
            ; >>> 刷新列表并选中新增的项
            this.RefreshAndSelect(name)
        }
    }



    ; >>> 新增：刷新列表并选择指定项
    RefreshAndSelect(itemNameToSelect := "") {
        ; 保存要选择的项名称
        this.itemToSelectAfterRefresh := itemNameToSelect
        
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
        
        ; 如果有指定要选择的项，尝试选中它
        if (itemNameToSelect != "") {
            this.SelectItemByText(itemNameToSelect)
        }
        
        ; 清除临时变量
        this.itemToSelectAfterRefresh := ""
    }

    ; >>> 新增：根据文本选择列表项
    SelectItemByText(textToSelect) {
        if (textToSelect = "" || this.showingPrompt) {
            return
        }
        
        ; 遍历所有软件项，查找匹配的文本
        for i in this.allSoftwareList {
            if (i["name"] = textToSelect) {
                ; 找到了匹配的项，现在需要在ListBox中找到它
                this.SelectItemInListBox(textToSelect)
                return
            }
        }
    }

    ; >>> 新增：在ListBox中选中指定文本的项（优化版）
    SelectItemInListBox(textToSelect) {
        if (textToSelect = "" || this.showingPrompt) {
            return
        }
        
        ; 先检查当前选中的项
        if (this.listBox.Value > 0 && this.listBox.Text = textToSelect) {
            return  ; 已经是选中的项
        }
        
        ; 从第1项开始查找
        index := 1
        found := false
        
        while (true) {
            try {
                this.listBox.Value := index
                if (this.listBox.Text = textToSelect) {
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
                this.listBox.Value := 0
            } catch {
                ; 如果清除失败，不做处理
            }
        }
    }

    ; 显示工具提示的方法
    ShowToolTip(message, duration := 1500) {
        ; 在保存按钮位置显示提示
        ToolTip(message)
        SetTimer () => ToolTip(), -duration
    }
    
    ; >>> 新增函数：更新INI文件，支持Root处理
    ; UpdateIniFile
    UpdateIniFileWithRoot(name, path, section, editMode) {
        try {
            ; 读取现有INI内容
            iniContent := ""
            if (FileExist(this.configPath)) {
                iniContent := FileRead(this.configPath)
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
                    oldSectionPattern := "\[" this.currentEditSection "\][\s\S]*?(?=\n\[|$)"
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
            FileDelete(this.configPath)
            FileAppend(iniContent, this.configPath, "UTF-8")
            
            ; 格式化文件
            this.FormatAndSaveIniFile()
            
            return true
        } catch {
            return false
        }
    }
    
    ; 删除软件
    DeleteSoftware(*) {
        selectedIndex := this.listBox.Value
        if (selectedIndex <= 0) {
            MsgBox("请先选择一个要删除的软件")
            return
        }
        
        selectedText := this.listBox.Text
        if (!this.softwareMap.Has(selectedText)) {
            MsgBox("未找到选中的软件信息")
            return
        }
        
        software := this.softwareMap[selectedText]
        
        ; 确认删除
        response := MsgBox("确定要删除 '" software["name"] "' 吗？", "确认删除", "YesNo")
        if (response != "Yes") {
            return
        }

        ; >>> 获取当前选中项之后的一项（如果有的话）
        nextItemText := ""
        try {
            ; 尝试获取下一项的文本
            this.listBox.Value := selectedIndex + 1
            nextItemText := this.listBox.Text
            ; 恢复原来的选中
            this.listBox.Value := selectedIndex
        } catch {
            ; 没有下一项，尝试获取上一项
            if (selectedIndex > 1) {
                try {
                    this.listBox.Value := selectedIndex - 1
                    nextItemText := this.listBox.Text
                    this.listBox.Value := selectedIndex
                } catch {
                    ; 也没有上一项
                }
            }
        }
        
        ; 从INI文件中删除
        if (!this.DeleteFromIniFile(software["section"])) {
            MsgBox("删除失败，无法更新配置文件")
            return
        }
        
        ; 刷新列表
        this.RefreshList()

        ; >>> 删除后尝试选中之前找到的下一项/上一项
        if (nextItemText != "") {
            this.SelectItemByText(nextItemText)
        }
        
        MsgBox("删除成功！")
    }
    
    ; 从INI文件中删除section
    DeleteFromIniFile(sectionName) {
        try {
            ; 读取整个INI文件
            content := FileRead(this.configPath)
            
            ; 构建正则表达式匹配要删除的section
            pattern := "\[" sectionName "\][\s\S]*?(?=\n\[|$)"
            if (RegExMatch(content, pattern, &match)) {
                ; 删除该section
                content := StrReplace(content, match[0] "`r`n", "")
                content := StrReplace(content, match[0], "")
                
                ; 写回文件
                FileDelete(this.configPath)
                FileAppend(content, this.configPath, "UTF-8")

                ; 格式化文件
                this.FormatAndSaveIniFile()
                
                return true
            } else {
                MsgBox("在配置文件中未找到对应的section")
                return false
            }
        } catch as e {
            MsgBox("删除配置文件时出错：`n" e.Message)
            return false
        }
    }
    
    ; ==================== 原有方法 ====================
    
    ; 打开选中的软件
    OpenSoftware(*) {
        selectedIndex := this.listBox.Value
        if (selectedIndex > 0) {
            selectedText := this.listBox.Text
            
            if (this.softwareMap.Has(selectedText)) {
                software := this.softwareMap[selectedText]
                path := software["path"]
                
                ; 检查文件是否存在
                if (FileExist(path)) {
                    try {
                        Run(path)
                        ; ==================== 打开软件后的业务 ====================
                        if (this.searchBox.Value != "") {
                            ; >>> 情况1：搜索框有值，清空并设置焦点
                            this.searchBox.Value := ""
                            this.ShowAllSoftware()  ; 使用已有的方法显示全部软件
                            this.listBox.Value := 0 ; 清除ListBox选中状态，让它失去焦点
                            ; 设置焦点到搜索框
                            try {
                                this.searchBox.Focus()
                                this.userWasInSearchBox := true
                            } catch {
                                ; 如果焦点设置失败，尝试其他方法
                                try {
                                    ControlFocus(this.searchBox, this.gui)
                                    this.userWasInSearchBox := true
                                }catch as e {
                                    MsgBox("ControlFocus失败: " e.Message)
                                }
                            }
                        }else {
                            ; >>> 情况2：搜索框没值，保持选中刚才打开的项
                            ; 使用已有的方法尝试选中
                            this.SelectItemInListBox(software["name"])
                        }
                    } catch as e {
                        MsgBox("打开失败: " e.Message)
                    }
                } else {
                    MsgBox("文件不存在或路径错误:`n`n" path)
                }
            }
        } else {
            MsgBox("请先选择一个软件")
        }
    }
    
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
            this.SelectItemByText(oldSelectedText)
        }
        
        ; 提示刷新完成
        ToolTip("列表已刷新")
        SetTimer () => ToolTip(), -1000
    }

    ; 定位软件（在资源管理器中打开所在文件夹）
    LocateSoftware(*) {
        ; 如果选择了软件
        if (this.listBox.Value > 0) {
            this.LocateSelectedSoftware()
            return
        }
        
        ; 没有选择软件
        if (this.rootPath != "" && DirExist(this.rootPath)) {
            ; 有Root配置
            try {
                Run('explorer.exe "' this.rootPath '"')
            } catch {
                this.OpenThisPC()
            }
        } else {
            ; 无Root配置
            this.OpenThisPC()
        }
    }

    ; 定位选中的软件
    LocateSelectedSoftware() {
        selectedText := this.listBox.Text
        if (!this.softwareMap.Has(selectedText)) {
            return
        }
        
        software := this.softwareMap[selectedText]
        filePath := software["path"]
        
        if (filePath != "") {
            if (FileExist(filePath)) {
                try {
                    Run('explorer.exe /select,"' filePath '"')
                } catch {
                    SplitPath(filePath, , &fileDir)
                    if (fileDir != "") {
                        Run('explorer.exe "' fileDir '"')
                    }
                }
            } else {
                SplitPath(filePath, , &fileDir)
                if (fileDir != "") {
                    Run('explorer.exe "' fileDir '"')
                }
            }
        }
    }

    ; 打开此电脑
    OpenThisPC() {
        try {
            Run("explorer.exe shell:MyComputerFolder")
        } catch {
            try {
                Run("explorer.exe")
            }
        }
    }
    
    ; 关闭GUI
    CloseGui(*) {
        this.gui.Destroy()
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

    ; ==================== 编辑对话框事件处理器 ====================

    ; 处理名称变化
    HandleNameChangeForEditGui(editGui, *) {
        editGui.ctlSection.Value := editGui.ctlName.Value
    }


    ; 显示更多对话框
    ShowMoreDialog(btn,*) {
        ; 创建更多对话框
        moreGui := Gui()
        moreGui.Title := "更多操作 - " this.configType
        moreGui.Opt("+AlwaysOnTop")
        
        ; 设置字体
        moreGui.SetFont("s9", "JetBrains Mono")

        ; 设置边距，减少顶部间距
        moreGui.MarginY := 5
        
        ; 添加说明
        moreGui.Add("Text", "w380 Center", "配置管理操作")
        moreGui.Add("Text", "w380 Center cGray", "管理" this.configType ".ini 配置文件")

        ; 创建按钮 - 计算居中位置
        buttonWidth := 80
        buttonSpacing := 10
        totalWidth := (buttonWidth * 4) + (buttonSpacing * 3)
        dialogWidth := 400  ; 增加对话框宽度
        startX := (dialogWidth - totalWidth) // 2
        
        ; 创建按钮
        btnImport := moreGui.Add("Button", "x" startX " y+30 w80", "导入")
        btnExport := moreGui.Add("Button", "x+10 w80", "导出")
        btnAppend := moreGui.Add("Button", "x+10 w80", "追加")
        btnCancel := moreGui.Add("Button", "x+10 w80", "取消")
        
        ; 绑定事件
        btnImport.OnEvent("Click", (*) => this.ImportConfig(moreGui))
        btnExport.OnEvent("Click", (*) => this.ExportConfig(moreGui))
        btnAppend.OnEvent("Click", (*) => this.AppendConfig(moreGui))
        btnCancel.OnEvent("Click", (*) => moreGui.Destroy())
        
        moreGui.Show()
    }

    ; ==================== 导入导出事件处理器 ====================

    ; 导出配置
    ExportConfig(moreGui) {
        moreGui.Destroy()
        
        ; 自动填充文件名
        defaultFileName := this.configType ".txt"
        exportPath := FileSelect("S", defaultFileName, "导出配置文件", "文本文件 (*.txt)")
        if (exportPath = "") {
            return
        }
        
        ; 确保扩展名
        if (!RegExMatch(exportPath, "\.txt$")) {
            exportPath .= ".txt"
        }

        ; >>> 使用统一的文件名校验
        if (!this.ValidateFileName(exportPath, this.configType)) {
            return
        }
        
        ; 导出配置
        if (this.ExportToTxt(exportPath)) {
            MsgBox("导出成功！`n文件保存到: " exportPath)
        } else {
            MsgBox("导出失败！")
        }
    }

    ; 导出为TXT格式（不添加标题）
    ExportToTxt(filePath) {
        try {
            ; 读取INI文件（自动处理编码）
            content := FileRead(this.configPath)
            txtContent := this.IniToTxtWithRoot(content)

            ; >>> 修改点：先删除文件，再写入，确保覆盖而不是追加
            if (FileExist(filePath)) {
                FileDelete(filePath)
            }
            
            ; 写入UTF-8文件
            FileAppend(txtContent, filePath, "UTF-8")
            return true
        } catch {
            return false
        }
    }

    ; INI转TXT格式
    ; >>> 修改点1: 新增支持Root导出的INI转TXT函数
    ; IniToTxt
    IniToTxtWithRoot(iniContent) {
        ; 存储条目的数组
        allItems := []
        currentSection := ""
        rootItem := Map()
        
        ; 解析INI内容
        Loop Parse, iniContent, "`n", "`r" {
            line := Trim(A_LoopField)
            
            ; 跳过注释和空行
            if (line = "" || SubStr(line, 1, 1) = ";") {
                continue
            }
            
            ; 解析section
            if (SubStr(line, 1, 1) = "[") {
                currentSection := SubStr(line, 2, InStr(line, "]") - 2)
                ; >>> 重置当前条目的name和path
                currentName := ""
                currentPath := ""
                continue
            }
            
            ; 解析key=value
            if (InStr(line, "=")) {
                pos := InStr(line, "=")
                key := Trim(SubStr(line, 1, pos - 1))
                value := Trim(SubStr(line, pos + 1))
                
                if (key = "name") {
                    currentName := value
                    ; >>> 重要：如果name与section不一致，使用section名
                    if (currentSection != "" && currentName != currentSection) {
                        currentName := currentSection
                    }
                } else if (key = "path") {
                    currentPath := value
                    
                    ; 当获取到path时，保存条目
                    if (currentSection != "" && currentName != "" && currentPath != "") {
                        item := Map()
                        item["section"] := currentSection
                        item["name"] := currentName
                        item["path"] := currentPath
                        
                        ; 如果是Root section，单独存储
                        if (currentSection = "Root" || StrLower(currentSection) = "root") {
                            rootItem := item
                        } else {
                            allItems.Push(item)
                        }
                    }
                }
            }
        }
        
        ; 构建TXT内容
        txtLines := []
        
        ; >>> 首先添加Root（如果有）
        if (rootItem.Count > 0) {
            ; 验证Root数据
            tempTxtForRoot := rootItem["name"] "`r`n" rootItem["path"]
            if (this.ValidateTxtContent(tempTxtForRoot, true,true)) {
                ; >>> 使用section名（保持原始大小写）
                txtLines.Push(rootItem["section"])
                txtLines.Push(rootItem["path"])
                txtLines.Push("")  ; 空行分隔
            }
        }
        
        ; 添加其他条目
        for item in allItems {
            ; 验证条目数据
            tempTxtForItem := item["name"] "`r`n" item["path"]
            if (this.ValidateTxtContent(tempTxtForItem, true,true)) {
                ; >>> 使用section名（保持原始大小写）
                txtLines.Push(item["section"])
                txtLines.Push(item["path"])
                txtLines.Push("")  ; 空行分隔
            }
        }
        
        ; 清理末尾多余的空行
        while (txtLines.Length > 0 && txtLines[txtLines.Length] = "") {
            txtLines.Pop()
        }
        
        ; 确保最后有一个换行符
        return this.StrJoin(txtLines, "`r`n") . (txtLines.Length > 0 ? "`r`n" : "")
    }



    ; 导入配置
    ImportConfig(moreGui) {
        moreGui.Destroy()
        
        importPath := FileSelect(1, , "选择要导入的配置文件", "文本文件 (*.txt)")
        if (importPath = "" || !FileExist(importPath)) {
            return
        }

        ; >>> 使用统一的文件名校验
        if (!this.ValidateFileName(importPath, this.configType)) {
            return
        }
        
        if (this.ImportFromTxtWithRoot(importPath)) {
            MsgBox("导入成功！")
            this.RefreshList()
        } else {
            MsgBox("导入失败！")
        }
    }

    ; 从TXT导入
    ;ImportFromTxt
    ImportFromTxtWithRoot(filePath) {
        try {
            ; 读取TXT文件
            content := FileRead(filePath, "UTF-8")
            
            ; 验证TXT文件内容
            if (!this.ValidateTxtContent(content, false, false)) {
                return false
            }
            
            ; 解析TXT内容
            lines := StrSplit(content, "`n", "`r")
            nonEmptyLines := []
            
            ; 过滤空行
            for line in lines {
                trimmedLine := Trim(line)
                if (trimmedLine != "") {
                    nonEmptyLines.Push(trimmedLine)
                }
            }
            
            ; 解析所有条目
            allItems := []
            rootItem := Map()
            
            ; 逐对处理（名称+路径）
            for i in this.Range(1, nonEmptyLines.Length, 2) {
                if (i + 1 <= nonEmptyLines.Length) {
                    itemName := nonEmptyLines[i]
                    itemPath := nonEmptyLines[i + 1]
                    
                    ; 验证这对数据
                    tempTxtForItem := itemName "`r`n" itemPath
                    if (this.ValidateTxtContent(tempTxtForItem, true,true)) {
                        item := Map()
                        
                        ; >>> 如果是Root（不区分大小写）
                        if (StrLower(itemName) = "root") {
                            ; 保持原始大小写
                            item["section"] := itemName
                            item["name"] := itemName  ; name与section保持一致
                            item["path"] := itemPath
                            rootItem := item
                        } else {
                            ; >>> 普通条目：section和name使用相同的值
                            item["section"] := itemName
                            item["name"] := itemName  ; name与section保持一致
                            item["path"] := itemPath
                            allItems.Push(item)
                        }
                    }
                }
            }
            
            ; 构建INI内容
            iniLines := []
            
            ; >>> 添加Root section（如果有）
            if (rootItem.Count > 0) {
                ; >>> section名使用Root的原始大小写
                iniLines.Push("[" rootItem["section"] "]")
                ; >>> name值与section名保持一致
                iniLines.Push("name=" rootItem["name"])
                iniLines.Push("path=" rootItem["path"])
                
                ; 只有在有后续内容时才添加空行
                if (allItems.Length > 0) {
                    iniLines.Push("")  ; 空行分隔
                }
            }
            
            ; 添加其他section
            for i, item in allItems {
                ; >>> section名使用原始大小写
                iniLines.Push("[" item["section"] "]")
                ; >>> name值与section名保持一致
                iniLines.Push("name=" item["name"])
                iniLines.Push("path=" item["path"])
                
                ; 如果不是最后一个，添加空行分隔
                if (i < allItems.Length) {
                    iniLines.Push("")
                }
            }
            
            ; 写入文件
            if (iniLines.Length > 0) {
                iniContent := this.StrJoin(iniLines, "`r`n") . "`r`n"
                FileDelete(this.configPath)
                FileAppend(iniContent, this.configPath, "UTF-8")
                
                ; 格式化文件
                this.FormatAndSaveIniFile()
                return true
            } else {
                MsgBox("导入失败：没有有效数据可以导入！")
                return false
            }
            
        } catch Error as e {
            MsgBox("导入错误: " e.Message "`n位置: " e.What " 行: " e.Line)
            return false
        }
    }

    ; >>> 修改Range函数，添加步长参数
    Range(start, end, step := 1) {
        arr := []
        if (step > 0) {
            Loop (Ceil((end - start + 1) / step)) {
                currentValue := start + (A_Index - 1) * step
                if (currentValue <= end) {
                    arr.Push(currentValue)
                }
            }
        }
        return arr
    }

    ; 追加配置
    AppendConfig(moreGui) {
        moreGui.Destroy()
        
        if (!FileExist(this.configPath)) {
            MsgBox("配置文件不存在，无法追加！")
            return
        }
        
        appendPath := FileSelect(1, , "选择要追加的配置文件", "文本文件 (*.txt)")
        if (appendPath = "" || !FileExist(appendPath)) {
            return
        }

        ; >>> 使用统一的文件名校验
        if (!this.ValidateFileName(appendPath, this.configType)) {
            return
        }
        
        if (this.AppendFromTxtWithRoot(appendPath)) {
            MsgBox("追加成功！")
            this.RefreshList()
        } else {
            MsgBox("追加失败！")
        }
    }

    ; 从TXT追加
    ;AppendFromTxt
    AppendFromTxtWithRoot(filePath) {
        try {
            ; 读取现有INI内容
            oldContent := FileRead(this.configPath)
            
            ; 读取要追加的TXT内容
            appendContent := FileRead(filePath, "UTF-8")
            
            ; >>> 使用ValidateTxtContent验证追加内容
            if (!this.ValidateTxtContent(appendContent,false,false)) {
                return false
            }
            
            ; 解析要追加的TXT内容（包含Root处理）
            parsedData := this.ParseTxtContentWithRoot(appendContent)
            
            ; 合并内容（支持Root覆盖）
            mergedContent := this.MergeIniContentWithRoot(oldContent, parsedData)
            
            ; 写入文件
            FileDelete(this.configPath)
            FileAppend(mergedContent, this.configPath, "UTF-8")

            ; 格式化文件
            this.FormatAndSaveIniFile()
            
            return true
        } catch Error as e {
            MsgBox("追加错误: " e.Message)
            return false
        }
    }

    ; 合并INI内容
    MergeIniContentWithRoot(oldContent, newData) {
        newRoot := newData["root"]
        newSections := newData["sections"]
        
        ; 解析旧内容中的sections（建立不区分大小写的映射）
        oldSections := Map()  ; 存储section名称 -> 原始大小写
        oldSectionLines := Map()  ; 存储section名称 -> 对应的行数索引
        
        currentSection := ""
        currentLineNumber := 0
        sectionStartLine := 0
        
        ; >>> 第一次遍历：建立不区分大小写的section映射
        Loop Parse, oldContent, "`n", "`r" {
            currentLineNumber++
            line := Trim(A_LoopField)
            
            if (SubStr(line, 1, 1) = "[") {
                if (currentSection != "") {
                    ; 保存上一个section的信息
                    oldSectionLines[currentSection] := Map("start", sectionStartLine, "end", currentLineNumber - 1)
                }
                
                currentSection := SubStr(line, 2, InStr(line, "]") - 2)
                ; >>> 以小写为key存储，值为原始大小写
                oldSections[StrLower(currentSection)] := currentSection
                sectionStartLine := currentLineNumber
            }
        }
        
        ; 保存最后一个section的信息
        if (currentSection != "") {
            oldSectionLines[currentSection] := Map("start", sectionStartLine, "end", currentLineNumber)
        }
        
        ; >>> 处理Root：如果有新的Root，就替换或添加
        if (newRoot.Count > 0) {
            ; 如果旧内容中有Root（不区分大小写），先移除
            rootKey := StrLower("Root")
            if (oldSections.Has(rootKey)) {
                rootSectionName := oldSections[rootKey]
                ; 移除Root section
                oldContent := this.RemoveSectionByLines(oldContent, oldSectionLines[rootSectionName]["start"], oldSectionLines[rootSectionName]["end"])
                ; 从映射中移除
                oldSections.Delete(rootKey)
            }
            
            ; 将新的Root section添加到文件顶部
            rootContent := ""
            if (oldContent = "" || Trim(oldContent) = "") {
                ; 如果是空文件，直接添加Root
                rootContent := "[" newRoot["section"] . "]`r`n"
                rootContent .= "name=" newRoot["name"] . "`r`n"
                rootContent .= "path=" newRoot["path"] . "`r`n"
                
                if (newSections.Length > 0) {
                    rootContent .= "`r`n"  ; 如果有其他section，加空行
                }
                oldContent := rootContent
            } else {
                ; 在非空文件中插入Root到顶部
                rootContent := "[" newRoot["section"] . "]`r`n"
                rootContent .= "name=" newRoot["name"] . "`r`n"
                rootContent .= "path=" newRoot["path"] . "`r`n"
                rootContent .= "`r`n"  ; 添加空行分隔
                
                oldContent := rootContent . oldContent
            }
        }
        
        ; >>> 处理普通section：不区分首字母大小写的匹配
        for i, newSection in newSections {
            sectionName := newSection["section"]
            sectionNameLower := StrLower(sectionName)
            
            ; >>> 查找是否存在匹配的section（不区分大小写）
            existingSectionName := ""
            
            ; 直接查找匹配的section
            if (oldSections.Has(sectionNameLower)) {
                existingSectionName := oldSections[sectionNameLower]
        }
            
            if (existingSectionName != "") {
                ; >>> 替换现有section
                oldContent := this.ReplaceSection(oldContent, existingSectionName, newSection)
            } else {
                ; 追加新的section
                oldContent := this.AppendSection(oldContent, newSection)
            }
        }
        
        ; 清理多余空行
        oldContent := RegExReplace(oldContent, "(`r`n){3,}", "`r`n`r`n")
        oldContent := RTrim(oldContent, "`r`n")
        
        ; 确保最后有一个换行符
        return oldContent . "`r`n"
    }

    ; >>> 新增辅助函数：按行号移除section
    RemoveSectionByLines(content, startLine, endLine) {
        lines := StrSplit(content, "`n", "`r")
        newLines := []
        
        for i, line in lines {
            if (i < startLine || i > endLine) {
                newLines.Push(line)
            }
        }
        
        ; 重新组合并清理空行
        result := this.StrJoin(newLines, "`r`n")
        result := RegExReplace(result, "(`r`n){3,}", "`r`n`r`n")
        result := RTrim(result, "`r`n")
        
        return result
    }

    ; >>> 修改ReplaceSection函数，支持不区分大小写的section名称
    ReplaceSection(content, existingSectionName, newSectionData) {
        ; 构建正则表达式，匹配原始大小写的section
        escapedSectionName := RegExReplace(existingSectionName, "[.*+?^${}()|[\]\\]", "\$0")
        pattern := "\[" escapedSectionName "\][\s\S]*?(?=\n\[|$)"
        
        if (RegExMatch(content, pattern, &match)) {
            ; 构建新的section内容
            newSectionContent := "[" newSectionData["section"] . "]`r`n"
            newSectionContent .= "name=" newSectionData["name"] . "`r`n"
            newSectionContent .= "path=" newSectionData["path"] . "`r`n"
            
            content := StrReplace(content, match[0], newSectionContent)
            
            ; 清理可能产生的连续空行
            content := RegExReplace(content, "(`r`n){3,}", "`r`n`r`n")
            content := RTrim(content, "`r`n")
            
            ; 如果内容不为空，确保有换行符
            if (content != "") {
                content .= "`r`n"
            }
        }
        
        return content
    }

    ;ParseTxtSections
    ; 解析TXT中的section
    ParseTxtContentWithRoot(txtContent) {
        result := Map()
        sections := []
        rootItem := Map()

        ; 解析TXT内容
        lines := StrSplit(txtContent, "`n", "`r")
        nonEmptyLines := []

        ; 过滤空行
        for line in lines {
            trimmedLine := Trim(line)
            if (trimmedLine != "") {
                nonEmptyLines.Push(trimmedLine)
            }
        }

        ; 逐对处理（名称+路径）
        for i in this.Range(1, nonEmptyLines.Length, 2) {
            if (i + 1 <= nonEmptyLines.Length) {
                itemName := nonEmptyLines[i]
                itemPath := nonEmptyLines[i + 1]
                
                ; 验证这对数据
                tempTxtForItem := itemName "`r`n" itemPath
                if (this.ValidateTxtContent(tempTxtForItem, true,true)) {
                    item := Map()
                    
                    ; >>> 如果是Root（不区分大小写）
                    if (StrLower(itemName) = "root") {
                        ; 保持原始大小写
                        item["section"] := itemName
                        item["name"] := itemName  ; name与section保持一致
                        item["path"] := itemPath
                        rootItem := item
                    } else {
                        ; >>> 普通条目：section和name使用相同的值
                        item["section"] := itemName
                        item["name"] := itemName  ; name与section保持一致
                        item["path"] := itemPath
                        sections.Push(item)
                    }
                }
            }
        }

        result["root"] := rootItem
        result["sections"] := sections

        return result
        }

    ; +++ 新增辅助函数：追加section到文件末尾
    AppendSection(content, sectionData) {
        ; 清理末尾多余的空行
        content := RTrim(content, "`r`n")
        
        ; 如果不是空文件，添加空行分隔
        if (content != "") {
            content .= "`r`n`r`n"
        }
        
        ; 添加新的section
        content .= "[" sectionData["section"] . "]`r`n"
        content .= "name=" sectionData["name"] . "`r`n"
        content .= "path=" sectionData["path"] . "`r`n"
        
        return content
    }

    ; 辅助函数：连接数组
    StrJoin(arr, delimiter) {
        result := ""
        for i, item in arr {
            if (i > 1) {
                result .= delimiter
            }
            result .= item
        }
        return result
    }

    ; +++ 新增函数：文件名校验
    ValidateFileName(filePath, expectedConfigType) {
        SplitPath(filePath, , , , &fileNameNoExt)
        ; >>> 严格检查：文件名必须完全等于当前configType
        if (fileNameNoExt != expectedConfigType) {
            MsgBox("请选择 " expectedConfigType ".txt 文件进行操作！`n`n"
                . "当前选择的是: " fileNameNoExt ".txt`n"
                . "当前配置类型是: " expectedConfigType, "文件不匹配", "Iconx")
            return false
        }
        return true
    }

    ; >>> 新增：校验TXT文件内容格式
    ;ValidateTxtContent
    ValidateTxtContent(content, skipFirstPairCheck := false, skipMsgBox := false) {
        ; 分割成行并过滤空行
        lines := StrSplit(content, "`n", "`r")
        nonEmptyLines := []
        
        for line in lines {
            if (Trim(line) != "") {
                nonEmptyLines.Push(Trim(line))
            }
        }
        
        ; 检查是否有内容
        if (nonEmptyLines.Length = 0) {
            if (!skipMsgBox && !skipFirstPairCheck) {
                MsgBox("文件内容为空，请检查文件！", "格式错误", "Iconx")
            }
            return false
        }
        
        ; 如果skipFirstPairCheck为true，则跳过行数奇偶性检查
        if (!skipFirstPairCheck && Mod(nonEmptyLines.Length, 2) != 0) {
            if (!skipMsgBox) {
                MsgBox("文件格式不正确！`n`n"
                    . "有效内容行数应为偶数（名称+路径成对出现）", "格式错误", "Iconx")
            }
            return false
        }
        
        ; 逐对检查：奇数行（名称）+ 偶数行（路径）
        for i, line in nonEmptyLines {
            if (!skipFirstPairCheck) {
                if (Mod(i, 2) = 1) {  ; 奇数行：第1、3、5...行（i=1,3,5...）
                    ; 检查是否是合法的文件名
                    if (RegExMatch(line, '[\\/:*?"<>|]')) {
                        if (!skipMsgBox) {
                            MsgBox("第 " i " 行包含非法字符：`n`n" line "`n`n"
                                . "文件名不能包含：\ / : * ? " . Chr(34) . " < > |", "格式错误", "Iconx")
                        }
                        return false
                    }
                    
                    ; 不能以点开头或结尾
                    if (SubStr(line, 1, 1) = "." || SubStr(line, 0, 1) = ".") {
                        if (!skipMsgBox) {
                            MsgBox("第 " i " 行格式错误：`n`n" line "`n`n"
                                . "文件名不能以点开头或结尾", "格式错误", "Iconx")
                        }
                        return false
                    }
                } else {  ; 偶数行：第2、4、6...行（i=2,4,6...）
                    ; 检查是否是合法的路径
                    if (!this.IsValidPath(line, i, skipMsgBox)) {
                        return false
                    }
                }
            } else {
                ; 对于单个条目验证，根据位置判断是名称还是路径
                if (Mod(i, 2) = 1) {
                    ; 奇数位置视为名称
                    if (RegExMatch(line, '[\\/:*?"<>|]')) {
                        return false
                    }
                    if (SubStr(line, 1, 1) = "." || SubStr(line, 0, 1) = ".") {
                        return false
                    }
                } else {
                    ; 偶数位置视为路径
                    if (!this.IsValidPath(line, i, true)) {
                        return false
                    }
                }
            }
        }
        
        return true
    }

    ; >>> 新增辅助函数：验证名称是否合法
    IsValidName(name, lineNumber := 0, skipMsgBox := false) {
        ; 检查是否是合法的文件名
        ; 文件名不能包含：\ / : * ? " < > |
        if (RegExMatch(name, '[\\/:*?"<>|]')) {
            if (!skipMsgBox) {
                MsgBox("第 " lineNumber " 行包含非法字符：`n`n" name "`n`n"
                    . "文件名不能包含：\ / : * ? " . Chr(34) . " < > |", "格式错误", "Iconx")
            }
            return false
        }
        
        ; 不能以点开头或结尾
        if (SubStr(name, 1, 1) = "." || SubStr(name, 0, 1) = ".") {
            if (!skipMsgBox) {
                MsgBox("第 " lineNumber " 行格式错误：`n`n" name "`n`n"
                    . "文件名不能以点开头或结尾", "格式错误", "Iconx")
            }
            return false
        }
        
        ; >>> 新增：不允许为空
        if (name = "") {
            if (!skipMsgBox) {
                MsgBox("第 " lineNumber " 行：名称不能为空", "格式错误", "Iconx")
            }
            return false
        }
        
        return true
    }

    ; >>> 新增辅助函数：验证路径是否合法
    IsValidPath(path, lineNumber := 0, skipMsgBox := false) {
        ; 必须包含多个\或/（至少一个）
        backslashCount := 0
        slashCount := 0
        colonCount := 0
        
        ; 统计字符数量
        Loop Parse, path {
            switch A_LoopField {
                case "\": backslashCount++
                case "/": slashCount++
                case ":": colonCount++
            }
        }
        
        ; 条件1：必须包含多个\或者多个/（至少一个）
        if (backslashCount = 0 && slashCount = 0) {
            if (!skipMsgBox) {
                MsgBox("第 " lineNumber " 行不是有效的路径：`n`n" path "`n`n"
                    . "路径必须包含路径分隔符（\或/）", "格式错误", "Iconx")
            }
            return false
        }
        
        ; 条件2：必须只包含一个:
        if (colonCount != 1) {
            if (!skipMsgBox) {
                msg := "第 " lineNumber " 行不是有效的路径：`n`n" path "`n`n"
                if (colonCount = 0) {
                    msg .= "路径缺少盘符（如C:）"
                } else {
                    msg .= "路径只能包含一个盘符（:），当前包含 " colonCount " 个"
                }
                MsgBox(msg, "格式错误", "Iconx")
            }
            return false
        }
        
        ; 检查其他非法字符
        if (RegExMatch(path, '[*?"<>|]')) {
            if (!skipMsgBox) {
                MsgBox("第 " lineNumber " 行包含非法字符：`n`n" path "`n`n"
                    . "路径不能包含：* ? " . Chr(34) . " < > |", "格式错误", "Iconx")
            }
            return false
        }
        
        ; >>> 新增：不允许为空
        if (path = "") {
            if (!skipMsgBox) {
                MsgBox("第 " lineNumber " 行：路径不能为空", "格式错误", "Iconx")
            }
            return false
        }
        
        return true
    }

    

    ; ==================== 格式化函数 ====================

    ; 格式化INI文件内容，确保每个section前面有空行
    FormatIniContent(iniContent) {
        ; 如果内容为空，直接返回
        if (iniContent = "") {
            return iniContent
        }
        
        ; 按行分割
        lines := StrSplit(iniContent, "`n", "`r")
        formattedLines := []
        
        for i, line in lines {
            trimmedLine := Trim(line)
            
            ; 如果是section行 ([xxx])
            if (SubStr(trimmedLine, 1, 1) = "[") {
                ; 检查前一行是否为空行
                if (i > 1 && Trim(lines[i - 1]) != "") {
                    ; 前一行不为空，添加一个空行
                    formattedLines.Push("")
                }
            }
            
            formattedLines.Push(line)
        }
        
        ; 重新组合并确保以换行符结尾
        formattedContent := this.StrJoin(formattedLines, "`r`n")
        
        ; 清理连续的空行（最多保留一个）
        formattedContent := RegExReplace(formattedContent, "(`r`n){3,}", "`r`n`r`n")
        
        ; 确保以换行符结尾
        formattedContent := RTrim(formattedContent, "`r`n") . "`r`n"
        
        return formattedContent
    }

    ; 格式化并保存INI文件
    FormatAndSaveIniFile() {
        try {
            ; 读取当前INI文件内容
            content := FileRead(this.configPath)
            
            ; 格式化内容
            formattedContent := this.FormatIniContent(content)
            
            ; 写回文件
            FileDelete(this.configPath)
            FileAppend(formattedContent, this.configPath, "UTF-8")
            
            return true
        } catch as e {
            ; 格式化失败不影响主要功能
            ; MsgBox("格式化文件时出错: " e.Message)
            return false
        }
    }
}