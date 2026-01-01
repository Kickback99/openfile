; ==============================
; WindowPositionUtils.ahk
; 窗口位置计算工具类
; ==============================
class WindowPositionUtils {
    
    ; 在父窗口中居中显示子窗口（带微调），适用于fixed
    static CenterChildWindow(parentHwnd, childGui, childWidth, childHeight, adjustLeft := 0,adjustTop := 0) {
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

        ; 应用垂直微调
        childY := childY - adjustTop
        
        ; 显示窗口（使用指定的宽度和高度）
        childGui.Show("x" childX " y" childY " w" childWidth " h" childHeight)
    }
    
    ; 在父窗口中居中显示子窗口（使用宽度和高度常量）自动计算
    static CenterChildWindowWithConstants(parentHwnd, childGui, width, height, adjustLeft := 0,adjustTop := 0) {
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

        ; 应用垂直微调
        childY := childY - adjustTop

        ; 调试信息 - 添加这个
        if (WindowConstants.DEBUG_MODE) {
            MessageManager.ShowInfo("父窗口位置: X=" parentX " Y=" parentY " W=" parentW " H=" parentH "`n" 
                "父窗口中心: X=" windowCenterX " Y=" windowCenterY "`n"
                "子窗口计算位置: X=" childX " Y=" childY " W=" width " H=" height "`n"
                "微调: Left=" adjustLeft " Top=" adjustTop, "CenterChildWindowWithConstants")
        }
        
         ; 显示窗口（不指定宽度和高度，让AHK自动确定）
        childGui.Show("x" childX " y" childY)
    }
}