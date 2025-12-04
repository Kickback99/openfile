; ==============================
; GuiManager.ahk
; GUI管理类
; ==============================
class GuiManager {
    ; 构造函数
    __New(configManager) {
        ; 保存ConfigManager实例
        this.configManager := configManager
        
        ; 获取软件列表
        this.softwareList := configManager.GetSoftwareListArray()
        
        ; 初始化其他属性
        this.gui := ""
        this.listBox := ""
        this.softwareMap := Map()
    }
    
    ; 显示软件列表GUI
    ShowSoftwareList() {
        ; 创建GUI
        this.gui := Gui()
        this.gui.Title := "软件管理器"
        this.gui.Opt("+Resize") ; 允许调整大小
        
        ; 创建ListBox
        this.listBox := this.gui.Add("ListBox", "w500 r15")
        
        ; 添加软件到ListBox
        this.PopulateSoftwareList()
        
        ; 添加按钮区域
        this.gui.Add("Text", "w500", "双击列表项或点击按钮打开软件")
        
        ; 创建按钮
        btnOpen := this.gui.Add("Button", "w80", "打开")
        btnRefresh := this.gui.Add("Button", "x+10 w80", "刷新")
        btnInfo := this.gui.Add("Button", "x+10 w80", "详情")
        btnClose := this.gui.Add("Button", "x+10 w80", "关闭")
        
        ; 绑定事件
        btnOpen.OnEvent("Click", this.OpenSoftware.Bind(this))
        btnRefresh.OnEvent("Click", this.RefreshList.Bind(this))
        btnInfo.OnEvent("Click", this.ShowSoftwareInfo.Bind(this))
        btnClose.OnEvent("Click", this.CloseGui.Bind(this))
        
        ; 双击ListBox事件
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
            
            ; 检查文件是否存在
            /* status := " ✗" ; 默认显示叉号
            if (FileExist(path)) {
                status := " ✓" ; 文件存在显示勾号
            } */
            
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
                        ; 可以添加打开成功的提示
                        ; ToolTip "正在打开 " software["name"]
                        ; SetTimer () => ToolTip(), -1000
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
    
    ; 显示软件详情
    ShowSoftwareInfo(*) {
        selectedIndex := this.listBox.Value
        if (selectedIndex > 0) {
            selectedText := this.listBox.Text
            
            if (this.softwareMap.Has(selectedText)) {
                software := this.softwareMap[selectedText]
                
                ; 检查文件是否存在
                fileExists := FileExist(software["path"])
                
                ; 创建详情对话框
                infoGui := Gui()
                infoGui.Title := "软件详情 - " software["name"]
                infoGui.Add("Text", "w400", "名称: " software["name"])
                infoGui.Add("Text", "w400", "Section: " software["section"])
                infoGui.Add("Text", "w400", "路径:")
                infoGui.Add("Edit", "w400 ReadOnly", software["path"])
                infoGui.Add("Text", "w400", "状态: " (fileExists ? "✓ 文件存在" : "✗ 文件不存在"))
                
                ; 添加按钮
                if (fileExists) {
                    btnOpen := infoGui.Add("Button", "w80", "打开")
                    ; 使用闭包捕获变量
                    btnOpen.OnEvent("Click", (*) => this.OpenSoftwareInInfo(software["path"], infoGui))
                }
                
                btnClose := infoGui.Add("Button", "w80", "关闭")
                btnClose.OnEvent("Click", (*) => infoGui.Destroy())
                
                infoGui.Show()
            }
        } else {
            MsgBox("请先选择一个软件")
        }
    }
    
    ; 在详情窗口中打开软件（辅助函数）
    OpenSoftwareInInfo(path, infoGui) {
        try {
            Run(path)
            infoGui.Destroy()
        } catch as e {
            MsgBox("打开失败: " e.Message)
        }
    }
    
    ; 刷新列表
    RefreshList(*) {
        ; 重新加载配置
        this.configManager := ConfigManager()
        this.softwareList := this.configManager.GetSoftwareListArray()
        
        ; 重新填充列表
        this.PopulateSoftwareList()
        
        ; 提示刷新完成
        ToolTip("列表已刷新")
        SetTimer () => ToolTip(), -1000
    }
    
    ; 关闭GUI
    CloseGui(*) {
        this.gui.Destroy()
    }
}