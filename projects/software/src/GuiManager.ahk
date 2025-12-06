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
        this.searchBox := this.gui.Add("Edit", "w500 -Tabstop", "")
    
        ; 监听搜索框变化
        this.searchBox.OnEvent("Change", this.HandleSearchChange.Bind(this))
        
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
        btnRefresh.OnEvent("Click", this.RefreshList.Bind(this))
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
        SetTimer(ObjBindMethod(this, "EnableSearchBoxTab"), -50)
        
    }

    EnableSearchBoxTab() {
    ; 启用搜索框的Tabstop
    this.searchBox.Opt("+Tabstop")
    
    ; 确保ListBox有选中项（再次确认）
    if (this.allSoftwareList.Length > 0 && this.listBox.Value = 0) {
        this.listBox.Value := 1
    }
}

    ; 处理ListBox获得焦点
    HandleListBoxFocus(*) {
        ; 当ListBox获得焦点时，确保有一个选中项

        ; 如果有项目，默认选择第一项
        if (this.allSoftwareList.Length > 0) {
            this.listBox.Value := 1
        }

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
        editGui.ctlPath := ctlPath 
        
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

        ; 创建复选框区域（只在创建模式下显示）
        if (this.editMode = "create") {
            ; 添加一个空行分隔
            editGui.Add("Text", "w400", "")
            
            ; 添加批量添加复选框
            chkBatchAdd := editGui.Add("CheckBox", "w400", "批量添加模式")
            editGui.chkBatchAdd := chkBatchAdd  ; 保存到editGui对象中
            
            ; 添加提示文本
            editGui.Add("Text", "w400 cGray", "勾选后，保存后不清空表单，可继续添加")
        }
        
        ; 添加按钮
        btnSave := editGui.Add("Button", "w80", "保存")
        btnCancel := editGui.Add("Button", "x+10 w80", "取消")
        
        ; 绑定事件
        btnSave.OnEvent("Click", (*) => this.SaveSoftware(
            editGui, 
            ctlName.Value, 
            ctlPath.Value, 
            ctlSection.Value,
            chkBatchAdd  ; 传递复选框控件
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

        ; 显示保存成功提示
        this.ShowToolTip("保存成功！", 1500)
        
        ; 检查是否批量添加模式
        isBatchMode := false
        if (this.editMode = "create" && chkBatchAdd && chkBatchAdd.Value = 1) {
            isBatchMode := true
        }
        
        if (!isBatchMode) {
            ; 非批量模式，关闭编辑窗口
            editGui.Destroy()
            
            ; 刷新列表
            this.RefreshList()
        } else {
            ; 批量模式，清空表单但不关闭窗口
            editGui.ctlName.Value := ""
            editGui.ctlPath.Value := ""
            editGui.ctlSection.Value := ""
            editGui.autoUpdateSection := true
            editGui.originalSection := ""
            
            ; 将焦点设置到名称输入框，方便继续输入
            editGui.ctlName.Focus()
            
            ; 刷新列表以显示新添加的项
            this.RefreshList()
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
                FileAppend(content, this.configPath, "UTF-8")
                
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
        
        ; 重新填充原始列表
        this.allSoftwareList := this.softwareList
        
        ; 根据当前搜索文本重新过滤
        ; 检查 searchBox 是否存在且有值
        if (HasProp(this, "searchBox") && this.searchBox.Value != "") {
            this.HandleSearchChange()
        } else {
            this.ShowAllSoftware()
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

    ; 处理搜索框变化（最终简化版）
    HandleSearchChange(*) {
        searchText := Trim(this.searchBox.Value)
        
        ; 如果搜索文本为空，显示所有软件
        if (searchText = "") {
            this.ShowAllSoftware()
            return
        }
        
        ; 转换为小写，实现不区分大小写的搜索
        searchText := StrLower(searchText)
        
        ; 清空现有项
        this.listBox.Delete()
        
        ; 清空当前映射Map（需要重新填充）
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
            if (InStr(lowerName, searchText)) {
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
        
        ; 如果没有找到匹配项
        if (foundCount = 0) {
            this.listBox.Add([">>> 未找到匹配项 <<<"])
        }
    }

    ; ==================== 导入导出事件处理器 ====================
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
            ; 读取TXT文件（UTF-8）
            content := FileOpen(filePath, "r", "UTF-8").Read()
            
            ; 转换并写入INI文件
            iniContent := this.TxtToIni(content)
            FileDelete(this.configPath)
            FileAppend(iniContent, this.configPath, "UTF-8")
            
            return true
        } catch {
            return false
        }
    }

    ; TXT转INI格式
    TxtToIni(txtContent) {
        lines := StrSplit(txtContent, "`n", "`r")
        iniLines := []
        
        ; 添加Root section（固定）
        iniLines.Push("[Root]")
        iniLines.Push("name=root")
        
        ; 尝试从txt中获取root路径，否则使用默认
        rootPath := ""
        currentName := ""
        
        for i, line in lines {
            line := Trim(line)
            if (line = "") {
                currentName := ""
                continue
            }
            
            ; 判断是名称还是路径
            if (!InStr(line, "\") && !InStr(line, ":/") && !InStr(line, ":\") && line != "") {
                ; 没有路径分隔符，是名称
                currentName := line
                if (currentName = "root") {
                    ; 尝试获取root路径
                        ; 尝试获取root路径
            for j, nextLine in lines {
                if (j <= i)  ; 跳过当前行之前的行
                    continue
                nextLine := Trim(nextLine)
                if (nextLine != "") {
                    rootPath := nextLine
                    break
                }
            }
        }
            } else if (InStr(line, "\") || InStr(line, ":/") || InStr(line, ":\")) {
                ; 有路径分隔符，是路径
                if (currentName != "") {
                    if (currentName = "root") {
                        rootPath := line
                    } else {
                        ; 普通软件项
                        sectionName := currentName
                        if (sectionName = "") {
                            sectionName := "Item_" A_Index
                        }
                        
                        iniLines.Push("")
                        iniLines.Push("[" sectionName "]")
                        iniLines.Push("name=" currentName)
                        iniLines.Push("path=" line)
                    }
                    currentName := ""
                }
            }
        }
        
        ; 设置root路径
        if (rootPath = "") {
            rootPath := "C:\Users\wz\Desktop\tools\" this.configType
        }
        ; 在第3行（name=root后面）插入path
        iniLines.InsertAt(3, "path=" rootPath)
        
        return this.StrJoin(iniLines, "`r`n") . "`r`n"
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
        oldContent := RTrim(oldContent, "`r`n") . "`r`n"
        
        ; 添加新section
        for section in newSections {
            newSection := "[" section["section"] . "]`r`n"
            newSection .= "name=" section["name"] . "`r`n"
            newSection .= "path=" section["path"] . "`r`n`r`n"
            
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
}