; ============================================================
; WindowConstants.ahk
; 窗口布局常量类
; ============================================================
class WindowConstants {

    ; 调试模式开关
    static DEBUG_MODE := false

    ; ==================== MoreGui 窗口常量 ====================

    ; MoreGui 宽度
    static MORE_GUI_WIDTH := 420

    ; ==================== 按钮布局常量 ====================

    ; 按钮宽度
    static BUTTON_WIDTH := 80

    ; 按钮间距
    static BUTTON_SPACING := 10

    ; 按钮总数（MoreGui）
    static MORE_GUI_BUTTON_COUNT := 4

    ; 导入导出追加取消水平偏移量（用于微调居中位置）
    static MORE_GUI_BUTTON_HORIZONTAL_OFFSET := -3

    ; 按钮总数（EditGui - 保存和取消）
    static EDIT_GUI_BUTTON_COUNT := 2

    ; ==================== 设置按钮常量 ====================

    ; 设置按钮窄宽度（置顶、重置）
    static SETTING_BUTTON_NARROW_WIDTH := 80

    ; 设置按钮中等宽度（配置类型、快捷键）
    static SETTING_BUTTON_MEDIUM_WIDTH := 90

    ; 设置按钮宽宽度（字母排序、显示扩展名、批量阈值、成功消息）
    static SETTING_BUTTON_WIDE_WIDTH := 110

    ; 设置按钮水平偏移量（用于微调居中位置）
    static SETTING_BUTTON_HORIZONTAL_OFFSET := 10

    ; 设置按钮顺序
    static SETTING_BUTTON_ORDER := [
        "AlwaysOnTop",
        "SortByAlphabet",
        "EnableExtension",
        "BatchThreshold",
        "ShowSuccessMsg",
        "ResetSettings",
        "Shortcuts",
        "Contact"
    ]

    ; 最大允许的按钮行宽度（留出边距）
    static SETTING_MAX_ROW_WIDTH := this.MORE_GUI_WIDTH - 20  ; 减去边距

    ; 获取按钮宽度的辅助方法
    static GetButtonWidth(btnName) {
        switch btnName {
            case "AlwaysOnTop", "ResetSettings", "Contact":
                return WindowConstants.SETTING_BUTTON_NARROW_WIDTH
            case "Shortcuts":
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

    ; ==================== HotkeyGui 窗口常量 ====================

    ; HotkeyGui 宽度
    static HOTKEY_GUI_WIDTH := 200
}
