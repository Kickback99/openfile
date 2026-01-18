; ==============================
; WindowConstants.ahk
; 窗口布局常量类
; ==============================
class WindowConstants {

    ; 调试模式开关
    static DEBUG_MODE := false
    
    ; ==================== MoreGui 窗口常量 ====================
    
    ; MoreGui 宽度
    static MORE_GUI_WIDTH := 420
    
    ; MoreGui 高度
    static MORE_GUI_HEIGHT := 200  ;  修改：增加高度以容纳设置按钮

    ; 高度控制模式：
    ; "fixed" - 固定使用 MORE_GUI_HEIGHT
    ; "auto" - 自动计算高度
    ; "max" - 使用固定高度和自动计算高度的较大值
    static HEIGHT_MODE := "auto"
    
    ; MoreGui 水平微调量（向左偏移）
    static MORE_GUI_ADJUST_LEFT := 78
    
    ; MoreGui 垂直微调量（向上偏移）
    static MORE_GUI_ADJUST_TOP := 50  ;  新增：设置区域高度
    
    
    ; ==================== EditGui 窗口常量 ====================
    
    ; EditGui 宽度
    static EDIT_GUI_WIDTH := 400
    
    ; EditGui 高度 - 创建模式（包含批量添加复选框）
    static EDIT_GUI_HEIGHT_CREATE := 300
    
    ; EditGui 高度 - 编辑模式（不包含批量添加复选框）
    static EDIT_GUI_HEIGHT_EDIT := 240
    
    ; EditGui 水平微调量（向左偏移）
    static EDIT_GUI_ADJUST_LEFT := 70
    
    ; EditGui 垂直微调量（向上偏移）
    static EDIT_GUI_ADJUST_TOP := 43
    
    
    ; ==================== 按钮布局常量 ====================
    
    ; 按钮宽度
    static BUTTON_WIDTH := 80
    
    ; 按钮间距
    static BUTTON_SPACING := 10
    
    ; 按钮总数（MoreGui）
    static MORE_GUI_BUTTON_COUNT := 4

    ;>>>新增：导入导出追加取消水平偏移量（用于微调居中位置）
    static MORE_GUI_BUTTON_HORIZONTAL_OFFSET := -3
    
    ; 按钮总数（EditGui - 保存和取消）
    static EDIT_GUI_BUTTON_COUNT := 2

    ; ==================== 设置按钮常量 ====================

    ; 设置按钮窄宽度（置顶、重置）
    static SETTING_BUTTON_NARROW_WIDTH := 80

    ; 设置按钮中等宽度（配置类型、快捷键）
    static SETTING_BUTTON_MEDIUM_WIDTH := 90  ;!!! 新增：中等宽度按钮
    
    ; 设置按钮宽宽度（字母排序、显示扩展名、批量阈值、成功消息）
    static SETTING_BUTTON_WIDE_WIDTH := 110

    ;>>>新增：设置按钮水平偏移量（用于微调居中位置）
    static SETTING_BUTTON_HORIZONTAL_OFFSET := 10

    ; 设置按钮顺序
    static SETTING_BUTTON_ORDER := [
        "AlwaysOnTop", 
        "SortByAlphabet",
        "EnableExtension", 
        "BatchThreshold", 
        "ShowSuccessMsg", 
        "ResetSettings",
        "Shortcuts",         ;!!! 新增：快捷键按钮
        "Contact"            ;!!! 新增：联系按钮
    ]

    ;>>>已移除：不再需要固定第一行按钮数量
    ; static SETTING_BUTTON_FIRST_ROW_COUNT := 4
    
    ;>>>新增：最大允许的按钮行宽度（留出边距）
    static SETTING_MAX_ROW_WIDTH := this.MORE_GUI_WIDTH - 20  ; 减去边距
    
    ;>>>新增：获取按钮宽度的辅助方法
    static GetButtonWidth(btnName) {
        switch btnName {
            case "AlwaysOnTop", "ResetSettings", "Contact":
                return WindowConstants.SETTING_BUTTON_NARROW_WIDTH
            case "Shortcuts":      ; 新增：中等宽度按钮
                return WindowConstants.SETTING_BUTTON_MEDIUM_WIDTH
            default:
                return WindowConstants.SETTING_BUTTON_WIDE_WIDTH
        }
    }


    ; ==================== 分割线常量 ====================
    
    ; 是否显示分割线
    static SHOW_DIVIDER_LINE := true
    
    ; 分割线水平偏移量（用于微调位置）
    static DIVIDER_LINE_HORIZONTAL_OFFSET := 0
    
    ; 分割线宽度调整（相对于对话框宽度的百分比，0-100）
    static DIVIDER_LINE_WIDTH_PERCENT := 100  ; 100%表示与对话框同宽
    
    ; 分割线上下间距
    static DIVIDER_LINE_TOP_MARGIN := 15  ; 分割线上方间距
    static DIVIDER_LINE_BOTTOM_MARGIN := 2  ; 分割线下方间距

    ; ==================== 批量阈值对话框常量 ====================

    static BATCH_THRESHOLD_WIDTH := 300
    static BATCH_THRESHOLD_HEIGHT := 150
    static BATCH_THRESHOLD_ADJUST_LEFT := 60
    static BATCH_THRESHOLD_ADJUST_TOP := 20

    ; ==================== HotkeyGui 窗口常量 ====================
    
    ; HotkeyGui 宽度
    static HOTKEY_GUI_WIDTH := 200
    
    ; HotkeyGui 高度
    static HOTKEY_GUI_HEIGHT := 155
    
    ; HotkeyGui 水平微调量（向左偏移）
    static HOTKEY_GUI_ADJUST_LEFT := 55
    
    ; HotkeyGui 垂直微调量（向上偏移）
    static HOTKEY_GUI_ADJUST_TOP := 0
    

    ; ==================== 经验高度常量 ====================
    
    ; 一行设置按钮的基础高度
    static BASE_HEIGHT_ONE_ROW := 135
    
    ; 每增加一行设置按钮增加的高度
    static EXTRA_HEIGHT_PER_ROW := 32
    
    ;>>>新增：基于经验的高度计算
    static CalculateEmpiricalHeight(buttonLayoutRows) {
        ; 简单经验公式
        return this.BASE_HEIGHT_ONE_ROW + 
               (this.EXTRA_HEIGHT_PER_ROW * (buttonLayoutRows - 1))
    }
}
