; ==============================
; WindowConstants.ahk
; 窗口布局常量类
; ==============================
class WindowConstants {
    
    ; ==================== MoreGui 窗口常量 ====================
    
    ; MoreGui 宽度
    static MORE_GUI_WIDTH := 400
    
    ; MoreGui 高度
    static MORE_GUI_HEIGHT := 200  ;  修改：增加高度以容纳设置按钮
    
    ; MoreGui 水平微调量（向左偏移）
    static MORE_GUI_ADJUST_LEFT := 90
    
    ; MoreGui 垂直微调量（目前为0，如需可调整）
    static MORE_GUI_ADJUST_TOP := 40  ;  新增：设置区域高度
    
    
    ; ==================== EditGui 窗口常量 ====================
    
    ; EditGui 宽度
    static EDIT_GUI_WIDTH := 400
    
    ; EditGui 高度 - 创建模式（包含批量添加复选框）
    static EDIT_GUI_HEIGHT_CREATE := 300
    
    ; EditGui 高度 - 编辑模式（不包含批量添加复选框）
    static EDIT_GUI_HEIGHT_EDIT := 240
    
    ; EditGui 水平微调量（向左偏移）
    static EDIT_GUI_ADJUST_LEFT := 70
    
    ; EditGui 垂直微调量（目前为0，如需可调整）
    static EDIT_GUI_ADJUST_TOP := 0
    
    
    ; ==================== 按钮布局常量 ====================
    
    ; 按钮宽度
    static BUTTON_WIDTH := 80
    
    ; 按钮间距
    static BUTTON_SPACING := 10
    
    ; 按钮总数（MoreGui）
    static MORE_GUI_BUTTON_COUNT := 4
    
    ; 按钮总数（EditGui - 保存和取消）
    static EDIT_GUI_BUTTON_COUNT := 2

    ; ==================== 设置按钮常量 ====================

    ; 设置按钮窄宽度（置顶、重置）
    static SETTING_BUTTON_NARROW_WIDTH := 60
    
    ; 设置按钮宽宽度（字母排序、显示扩展名、批量阈值、成功消息）
    static SETTING_BUTTON_WIDE_WIDTH := 110
}