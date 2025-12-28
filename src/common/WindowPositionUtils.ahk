; ==============================
; WindowPositionUtils.ahk
; 窗口位置计算工具类
; ==============================
class WindowPositionUtils {
    
    ; 在父窗口中居中显示子窗口（带微调）
    static CenterChildWindow(parentHwnd, childGui, childWidth, childHeight, adjustLeft := 0) {
        if (!parentHwnd || !IsObject(childGui)) {
            childGui.Show("Center")
            return
        }
        
        ; 获取父窗口位置
        WinGetPos(&parentX, &parentY, &parentW, &parentH, "ahk_id " parentHwnd)
        
        ; 计算父窗口中心点
        windowCenterX := parentX + parentW // 2
        windowCenterY := parentY + parentH // 2
        
        ; 计算子窗口位置（使其中心对齐父窗口中心）
        childX := windowCenterX - childWidth // 2
        childY := windowCenterY - childHeight // 2
        
        ; 应用水平微调
        childX := childX - adjustLeft
        
        ; 显示窗口
        childGui.Show("x" childX " y" childY)
    }
    
    ; 在父窗口中居中显示子窗口（使用宽度和高度常量）
    static CenterChildWindowWithConstants(parentHwnd, childGui, width, height, adjustLeft := 0) {
        if (!parentHwnd || !IsObject(childGui)) {
            childGui.Show("Center")
            return
        }
        
        ; 获取父窗口位置
        WinGetPos(&parentX, &parentY, &parentW, &parentH, "ahk_id " parentHwnd)
        
        ; 计算父窗口中心点
        windowCenterX := parentX + parentW // 2
        windowCenterY := parentY + parentH // 2
        
        ; 计算子窗口位置
        childX := windowCenterX - width // 2
        childY := windowCenterY - height // 2
        
        ; 应用水平微调
        childX := childX - adjustLeft
        
        ; 显示窗口
        childGui.Show("x" childX " y" childY)
    }
}