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
        
        ; 当前编辑的模式：create 或 edit
        this.editMode := ""
        ; 当前编辑的原始section名称（编辑模式时使用）
        this.currentEditSection := ""
    }
    
    ; 显示软件列表GUI
    ShowSoftwareList() {
        ; 创建GUI
        this.gui := Gui()
        this.gui.Title := (this.configType)
        this.gui.Opt("+Resize") ; 允许调整大小
        
        ; 创建ListBox
        this.listBox := this.gui.Add("ListBox", "w500 r15")
        
        ; 添加软件到ListBox
        this.PopulateSoftwareList()
        
        ; 添加按钮区域
        this.gui.Add("Text", "w500", "双击列表项或点击按钮操作")
        
        ; 创建按钮 - 调整顺序和位置
        btnCreate := this.gui.Add("Button", "w80", "创建")
        btnOpen := this.gui.Add("Button", "x+10 w80", "打开")
        btnEdit := this.gui.Add("Button", "x+10 w80", "编辑")
        btnDelete := this.gui.Add("Button", "x+10 w80", "删除")
        btnRefresh := this.gui.Add("Button", "x+10 w80", "刷新")
        ; btnClose := this.gui.Add("Button", "x+10 w80", "关闭")
        btnLocate := this.gui.Add("Button", "x+10 w80", "定位")  ; 新增定位按钮
        
        ; 绑定事件
        btnCreate.OnEvent("Click", this.ShowCreateDialog.Bind(this))
        btnOpen.OnEvent("Click", this.OpenSoftware.Bind(this))
        btnEdit.OnEvent("Click", this.ShowEditDialog.Bind(this))
        btnDelete.OnEvent("Click", this.DeleteSoftware.Bind(this))
        btnRefresh.OnEvent("Click", this.RefreshList.Bind(this))
        ; btnClose.OnEvent("Click", this.CloseGui.Bind(this))
        btnLocate.OnEvent("Click", this.LocateSoftware.Bind(this))  ; 绑定定位事件
        
        ; 双击ListBox事件 - 打开软件
        this.listBox.OnEvent("DoubleClick", this.OpenSoftware.Bind(this))
        
        ; 显示GUI
        this.gui.Show()
    }
    
    ; 填充软件列表
    PopulateSoftwareList() {
        ; 清空现有项
        this.listBox.Delete()
        
        ; 创建存储名称-路径映射的Map
        this.softwareMap := Map()
        
        ; 添加软件到ListBox
        for software in this.softwareList {
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
        
        this.ShowEditDialogGui(software["name"], software["path"])
    }
    
    ; 显示编辑对话框（内部方法）
    ; 显示编辑对话框（内部方法）- 修正版
    ShowEditDialogGui(defaultName, defaultPath) {
        ; 创建编辑对话框
        editGui := Gui()
        editGui.Title := (this.editMode = "create" ? "创建新软件" : "编辑软件")
        editGui.Opt("+AlwaysOnTop")
        
        ; 存储相关控件到GUI对象，以便在事件处理器中访问
        editGui.ctlName := ""
        editGui.ctlSection := ""
        editGui.autoUpdateSection := true
        editGui.originalSection := defaultName
        
        ; 添加输入控件
        editGui.Add("Text", "w400", "软件名称:")
        ctlName := editGui.Add("Edit", "w400", defaultName)
        editGui.ctlName := ctlName
        
        editGui.Add("Text", "w400", "软件路径:")
        ctlPath := editGui.Add("Edit", "w400", defaultPath)
        btnBrowse := editGui.Add("Button", "w80", "浏览...")
        btnBrowse.OnEvent("Click", (*) => this.BrowseForFile(ctlPath))
        
        editGui.Add("Text", "w400", "Section名称（自动生成，可修改）:")
        ctlSection := editGui.Add("Edit", "w400")
        editGui.ctlSection := ctlSection
        
        ; 根据模式设置Section
        if (this.editMode = "create") {
            ; 创建模式：默认用软件名称作为section
            ctlSection.Value := defaultName
            
            ; 绑定事件处理器
            ctlName.OnEvent("Change", this.HandleNameChangeForEditGui.Bind(this, editGui))
            ctlSection.OnEvent("Change", this.HandleSectionChangeForEditGui.Bind(this, editGui))
            ctlSection.OnEvent("Focus", this.HandleSectionFocusForEditGui.Bind(this, editGui))
            ctlSection.OnEvent("LoseFocus", this.HandleSectionLoseFocusForEditGui.Bind(this, editGui))
            ctlName.OnEvent("Focus", this.HandleNameFocusForEditGui.Bind(this, editGui))
            
        } else {
            ; 编辑模式：显示当前section
            ctlSection.Value := this.currentEditSection
            ctlSection.Opt("+ReadOnly")  ; 编辑时不允许修改section
        }
        
        ; 添加按钮
        btnSave := editGui.Add("Button", "w80", "保存")
        btnCancel := editGui.Add("Button", "x+10 w80", "取消")
        
        ; 绑定事件
        btnSave.OnEvent("Click", (*) => this.SaveSoftware(
            editGui, 
            ctlName.Value, 
            ctlPath.Value, 
            ctlSection.Value
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
    SaveSoftware(editGui, name, path, section) {
        ; 输入验证
        if (name = "") {
            MsgBox("软件名称不能为空")
            return
        }
        
        if (path = "") {
            MsgBox("软件路径不能为空")
            return
        }
        
        if (section = "") {
            MsgBox("Section名称不能为空")
            return
        }

        ; 防止创建Root项    
        if (section = "Root" || section = "root") {
            MsgBox("不能使用'Root'作为Section名称，这是保留名称")
            return
        }
        
        ; 检查名称是否已存在（创建模式下）
        if (this.editMode = "create") {
            for displayName in this.softwareMap {
                if (this.softwareMap[displayName]["name"] = name) {
                    MsgBox("软件名称已存在，请使用其他名称")
                    return
                }
            }
        }
        
        ; 检查section是否已存在（创建模式下）
        if (this.editMode = "create") {
            for displayName in this.softwareMap {
                if (this.softwareMap[displayName]["section"] = section) {
                    MsgBox("Section名称已存在，请使用其他名称")
                    return
                }
            }
        }
        
        ; 更新INI文件
        if (!this.UpdateIniFile(name, path, section)) {
            MsgBox("保存失败，无法更新配置文件")
            return
        }
        
        ; 关闭编辑窗口
        editGui.Destroy()
        
        ; 刷新列表
        this.RefreshList()
        
        MsgBox("保存成功！")
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
            FileAppend(content, this.configPath)
            
            return true
        } catch as e {
            MsgBox("更新配置文件时出错：`n" e.Message)
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
        
        ; 从INI文件中删除
        if (!this.DeleteFromIniFile(software["section"])) {
            MsgBox("删除失败，无法更新配置文件")
            return
        }
        
        ; 刷新列表
        this.RefreshList()
        
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
                FileAppend(content, this.configPath)
                
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

    ; 更新Section名称（当软件名称变化时）
    UpdateSectionFromName(nameControl, sectionControl, originalName, *) {
    if (sectionControl.Value = "" || sectionControl.Value = originalName) {
        sectionControl.Value := nameControl.Value
    }
}
    
    ; 刷新列表
    RefreshList(*) {
        ; 重新加载配置
        configMgr := ConfigManager(this.configType)
        this.configManager := configMgr
        this.softwareList := configMgr.GetSoftwareListArray()
        this.rootPath := configMgr.GetRootPath()  ; 重新获取Root路径
        
        ; 重新填充列表
        this.PopulateSoftwareList()
        
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

    ; ==================== 编辑对话框事件处理器 ====================

    ; 处理名称变化
    HandleNameChangeForEditGui(editGui, *) {
        if (editGui.autoUpdateSection) {
            editGui.ctlSection.Value := editGui.ctlName.Value
        }
    }

    ; 处理Section变化
    HandleSectionChangeForEditGui(editGui, *) {
        ; 如果用户修改了Section，且新值不等于当前软件名称，则关闭自动更新
        if (editGui.ctlSection.Value != editGui.ctlName.Value) {
            editGui.autoUpdateSection := false
        }
    }

    ; 处理Section获取焦点事件
    HandleSectionFocusForEditGui(editGui, *) {
        ; 当用户点击Section输入框时，暂时关闭自动更新
        editGui.autoUpdateSection := false
    }

    ; 处理Section失去焦点事件
    HandleSectionLoseFocusForEditGui(editGui, *) {
        ; 当Section输入框失去焦点时，如果内容为空或等于原始值，恢复自动更新
        if (editGui.ctlSection.Value = "" || editGui.ctlSection.Value = editGui.originalSection) {
            editGui.autoUpdateSection := true
            editGui.ctlSection.Value := editGui.ctlName.Value
        }
    }

    ; 处理软件名称获取焦点事件
    HandleNameFocusForEditGui(editGui, *) {
        ; 当用户点击名称输入框时，检查是否可以恢复自动更新
        if (editGui.ctlSection.Value = "" || editGui.ctlSection.Value = editGui.ctlName.Value) {
            editGui.autoUpdateSection := true
        }
    }
}