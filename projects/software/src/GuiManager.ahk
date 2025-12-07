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
        
        ; 创建按钮 - 调整顺序和位置
        btnCreate := this.gui.Add("Button", "w80", "创建")
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

        ; 防止创建Root项    
        if (section = "Root" || section = "root") {
            MsgBox("不能使用'Root'作为Section名称，这是保留名称", "提示", "Owner" editGui.Hwnd)
            return
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
        
        ; ==================== 更新INI文件 ====================
        
        ; 更新INI文件（用于：1.编辑模式但section未变化 2.创建模式）
        if (!this.UpdateIniFile(name, path, section)) {
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
    
    ; 更新INI文件
    UpdateIniFile(name, path, section) {
        try {
            ; 读取整个INI文件
            content := FileRead(this.configPath)
            
            if (this.editMode = "edit") {
                ; 编辑模式：找到并替换对应的section
                newSection := "[" section "]`r`nname=" name "`r`npath=" path "`r`n"
                
                ; 构建正则表达式匹配原section
                pattern := "\[" this.currentEditSection "\][\s\S]*?(?=\n\[|$)"
                if (RegExMatch(content, pattern, &match)) {
                    ; 替换原section
                    content := StrReplace(content, match[0], newSection)
                } else {
                    ; 如果没找到，在文件末尾添加
                    content .= "`r`n" newSection
                }
            } else {
                ; 创建模式：在文件末尾添加新section
                content .= "`r`n[" section "]`r`nname=" name "`r`npath=" path "`r`n"
            }
            
            ; 写回文件
            FileDelete(this.configPath)
            FileAppend(content, this.configPath,"UTF-8")

            ; 格式化文件
            this.FormatAndSaveIniFile()
            
            return true
        } catch as e {
            MsgBox("更新配置文件时出错：`n" e.Message, "错误", "Owner" this.gui.Hwnd)
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
        
        ; 添加说明
        moreGui.Add("Text", "w300 Center", "配置管理操作")
        moreGui.Add("Text", "w300 Center cGray", "管理" this.configType ".ini 配置文件")
        
        ; 创建按钮
        btnImport := moreGui.Add("Button", "w80", "导入")
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
            txtContent := this.IniToTxt(content)
            
            ; 写入UTF-8文件
            FileAppend(txtContent, filePath, "UTF-8")
            return true
        } catch {
            return false
        }
    }

    ; INI转TXT格式
    IniToTxt(iniContent) {
        txtLines := []
        currentName := ""
        
        Loop Parse, iniContent, "`n", "`r" {
            line := Trim(A_LoopField)
            
            ; 跳过注释和空行
            if (line = "" || SubStr(line, 1, 1) = ";") {
                continue
            }
            
            ; 解析section，跳过Root
            if (SubStr(line, 1, 1) = "[") {
                section := SubStr(line, 2, InStr(line, "]") - 2)
                if (section != "Root") {
                    currentName := ""
                }
                continue
            }
            
            ; 解析key=value
            if (InStr(line, "=")) {
                pos := InStr(line, "=")
                key := Trim(SubStr(line, 1, pos - 1))
                value := Trim(SubStr(line, pos + 1))
                
                if (key = "name") {
                    currentName := value
                } else if (key = "path" && currentName != "" && currentName != "root") {
                    txtLines.Push(currentName)
                    txtLines.Push(value)
                    txtLines.Push("")  ; 空行分隔
                    currentName := ""
                }
            }
        }
        
        return Trim(this.StrJoin(txtLines, "`r`n"), "`r`n") . "`r`n"
    }

    ; 导入配置
    ImportConfig(moreGui) {
        moreGui.Destroy()
        
        importPath := FileSelect(1, , "选择要导入的配置文件", "文本文件 (*.txt)")
        if (importPath = "" || !FileExist(importPath)) {
            return
        }
        
        if (this.ImportFromTxt(importPath)) {
            MsgBox("导入成功！")
            this.RefreshList()
        } else {
            MsgBox("导入失败！")
        }
    }

    ; 从TXT导入
    ImportFromTxt(filePath) {
        try {
            ; 读取TXT文件
            content := FileRead(filePath, "UTF-8")
            
            ; 获取现有的root配置（如果有）
            existingRootContent := ""
            if (FileExist(this.configPath)) {
                existingContent := FileRead(this.configPath)
                existingRootContent := this.ExtractRootSection(existingContent)
            }
            
            ; 转换TXT为INI内容（不包括root）
            iniContentWithoutRoot := this.TxtToIniWithoutRoot(content)
            
            ; 合并：现有root + 导入的内容
            finalContent := ""
            if (existingRootContent != "" && existingRootContent != "`r`n") {
                ; 使用现有的root，清理多余空行
                existingRootContent := RTrim(existingRootContent, "`r`n")
                finalContent := existingRootContent . "`r`n`r`n"
            } else {
                ; 使用默认root
                defaultRootPath := "C:\Users\wz\Desktop\tools\" this.configType
                finalContent := "[Root]`r`nname=root`r`npath=" defaultRootPath "`r`n`r`n"
            }
            
            ; 添加导入的内容
            finalContent .= iniContentWithoutRoot
            
            ; 写入文件
            FileDelete(this.configPath)
            FileAppend(finalContent, this.configPath, "UTF-8")
            
            ; 格式化文件
            this.FormatAndSaveIniFile()

            return true
        } catch Error as e {
            ; 显示具体错误以便调试
            MsgBox("导入错误: " e.Message "`n位置: " e.What " 行: " e.Line)
            return false
        }
    }

    ; 提取Root section内容
    ExtractRootSection(iniContent) {
        rootLines := []
        inRootSection := false
        foundRoot := false
        
        Loop Parse, iniContent, "`n", "`r" {
            line := Trim(A_LoopField)
            
            ; 解析section
            if (SubStr(line, 1, 1) = "[") {
                if (inRootSection) {
                    ; Root section结束
                    break
                }
                
                section := SubStr(line, 2, InStr(line, "]") - 2)
                if (section = "Root") {
                    inRootSection := true
                    foundRoot := true
                    rootLines.Push("[Root]")
                }
                continue
            }
            
            ; 在Root section中
            if (inRootSection) {
                ; 检查是否是其他section的开始
                if (line != "" && SubStr(line, 1, 1) = "[") {
                    break
                }
                
                ; 添加root section的内容
                if (line != "" && (SubStr(line, 1, 4) = "name" || SubStr(line, 1, 4) = "path")) {
                    rootLines.Push(line)
                }
            }
        }
        
        if (foundRoot && rootLines.Length > 0) {
            ; 确保有name和path
            hasName := false
            hasPath := false
            for line in rootLines {
                if (SubStr(line, 1, 4) = "name") {
                    hasName := true
                }
                if (SubStr(line, 1, 4) = "path") {
                    hasPath := true
                }
            }
            
            ; 补全缺少的字段
            if (!hasName) {
                rootLines.Push("name=root")
            }
            if (!hasPath) {
                ; 使用默认路径
                rootLines.Push("path=C:\Users\wz\Desktop\tools\" this.configType)
            }
            
            return this.StrJoin(rootLines, "`r`n")
        }
        
        return ""  ; 没有找到有效的Root section
    }

    ; 简化版的TXT转INI格式（不包括root）（改进版）
    TxtToIniWithoutRoot(txtContent) {
        lines := StrSplit(txtContent, "`n", "`r")
        iniLines := []
        currentName := ""
        
        for i, line in lines {
            line := Trim(line)
            if (line = "") {
                continue
            }
            
            ; 判断是否是路径（包含路径分隔符）
            isPath := InStr(line, "\") || InStr(line, ":/") || InStr(line, ":\")
            
            if (!isPath && line != "root") {
                ; 是名称
                currentName := line
            } else if (isPath && currentName != "") {
                ; 是路径，且有对应的名称
                ; 添加空行（除非是第一个section）
                if (iniLines.Length > 0) {
                    iniLines.Push("")
                }
                
                iniLines.Push("[" currentName "]")
                iniLines.Push("name=" currentName)
                iniLines.Push("path=" line)
                
                currentName := ""
            }
        }
        
        return this.StrJoin(iniLines, "`r`n") . (iniLines.Length > 0 ? "`r`n" : "")
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
        
        if (this.AppendFromTxt(appendPath)) {
            MsgBox("追加成功！")
            this.RefreshList()
        } else {
            MsgBox("追加失败！")
        }
    }

    ; 从TXT追加
    AppendFromTxt(filePath) {
        try {
            ; 读取现有INI内容
            oldContent := FileRead(this.configPath)
            
            ; 读取要追加的TXT内容
            appendContent := FileOpen(filePath, "r", "UTF-8").Read()
            
            ; 获取现有section名称
            existingSections := this.GetExistingSections(oldContent)
            
            ; 解析要追加的内容
            sectionsToAdd := this.ParseTxtSections(appendContent)
            
            ; 合并内容
            mergedContent := this.MergeIniContent(oldContent, sectionsToAdd, existingSections)
            
            ; 写入文件
            FileDelete(this.configPath)
            FileAppend(mergedContent, this.configPath, "UTF-8")

            ; 格式化文件
            this.FormatAndSaveIniFile()
            
            return true
        } catch {
            return false
        }
    }

    ; 获取现有section名称
    GetExistingSections(iniContent) {
        sections := Map()
        
        Loop Parse, iniContent, "`n", "`r" {
            line := Trim(A_LoopField)
            if (SubStr(line, 1, 1) = "[") {
                section := SubStr(line, 2, InStr(line, "]") - 2)
                sections[section] := true
            }
        }
        
        return sections
    }

    ; 解析TXT中的section
    ParseTxtSections(txtContent) {
        sections := []
        lines := StrSplit(txtContent, "`n", "`r")
        currentName := ""
        
        for i, line in lines {
            line := Trim(line)
            if (line = "") {
                continue
            }
            
            ; 判断是名称还是路径
            if (!InStr(line, "\") && !InStr(line, ":/") && !InStr(line, ":\")) {
                currentName := line
            } else if (currentName != "" && (InStr(line, "\") || InStr(line, ":/") || InStr(line, ":\"))) {
                if (currentName != "root") {  ; 跳过root
                    section := Map()
                    section["name"] := currentName
                    section["path"] := line
                    section["section"] := currentName 
                    if (section["section"] = "") {
                        section["section"] := "Item_" A_Index
                    }
                    
                    sections.Push(section)
                }
                currentName := ""
            }
        }
        
        return sections
    }

    ; 合并INI内容
    MergeIniContent(oldContent, newSections, existingSections) {
        ; 移除旧内容中与新section相同的项
        for section in newSections {
            sectionName := section["section"]
            if (existingSections.Has(sectionName)) {
                ; 替换现有section
                pattern := "\[" sectionName "\][\s\S]*?(?=\n\[|$)"
                if (RegExMatch(oldContent, pattern, &match)) {
                    oldContent := StrReplace(oldContent, match[0], "")
                }
            }
        }
        
        ; 清理多余空行
        oldContent := RegExReplace(oldContent, "(`r`n){3,}", "`r`n`r`n")
        oldContent := RTrim(oldContent, "`r`n")
        
        ; 确保原内容以空行结尾
        if (oldContent != "" && !RegExMatch(oldContent, "`r`n$")) {
            oldContent .= "`r`n"
        }
        
        ; 添加新section，确保每个section之间有空行
        for i, section in newSections {
            ; 如果不是第一个新section，添加空行
            if (i > 1 || (oldContent != "" && !RegExMatch(oldContent, "`r`n$"))) {
                oldContent .= "`r`n"
            }
            
            newSection := "[" section["section"] . "]`r`n"
            newSection .= "name=" section["name"] . "`r`n"
            newSection .= "path=" section["path"] . "`r`n"
            
            oldContent .= newSection
        }
        
        return oldContent
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