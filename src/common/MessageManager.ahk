; ==============================
; MessageManager.ahk
; 消息管理工具类（统一控制消息显示）
; ==============================
class MessageManager {
    ; ++++ 显示消息框（带置顶处理，根据配置控制成功消息） ++++
    static ShowMessageBox(message, title := "", options := "") {
        ; 先取消主窗口置顶
        try {
            ; 获取活动窗口（可能是GUI窗口）
            WinSetAlwaysOnTop(false, "A")
        }
        
        ; 根据消息类型和配置决定是否显示
        local result := ""
        
        ; 检查消息类型
        if (options = "YesNo") {
            ; 确认消息始终显示
            result := MsgBox(message, title, options)
        } else if (this.IsErrorMessage(message) || this.IsWarningMessage(message)) {
            ; 错误和警告消息始终显示
            result := MsgBox(message, title, options)
        } else if (this.IsSuccessMessage(message)) {
            ; 成功消息受配置控制
            if (SettingsManager.GetBool("ShowSuccessMsg", true)) {
                result := MsgBox(message, title, options)
            } else {
                ; 不显示成功消息，直接返回默认值
                result := "OK"
            }
        } else {
            ; 其他消息按成功消息处理（默认显示）
            if (SettingsManager.GetBool("ShowSuccessMsg", true)) {
                result := MsgBox(message, title, options)
            } else {
                result := "OK"
            }
        }
        
        ; 恢复主窗口置顶
        try {
            WinSetAlwaysOnTop(true, "A")
        }
        
        return result
    }
    
    ; ++++ 显示成功消息（受配置控制，带置顶处理） ++++
    static ShowSuccess(message, title := "", options := "") {
        ; 检查是否显示成功消息
        if (!SettingsManager.GetBool("ShowSuccessMsg", true)) {
            return "OK"  ; 配置为false，不显示成功消息
        }
        
        ; 显示成功消息（带置顶处理）
        return this.ShowMessageBoxInternal(message, title, options)
    }
    
    ; ++++ 显示错误消息（不受配置限制，带置顶处理） ++++
    static ShowError(message, title := "", options := "") {
        ; 错误消息始终显示
        return this.ShowMessageBoxInternal(message, title, options)
    }
    
    ; ++++ 显示确认消息（不受配置限制，带置顶处理） ++++
    static ShowConfirm(message, title := "", options := "YesNo") {
        ; 确认消息始终显示
        return this.ShowMessageBoxInternal(message, title, options)
    }
    
    ; ++++ 显示警告消息（不受配置限制，带置顶处理） ++++
    static ShowWarning(message, title := "", options := "") {
        ; 警告消息始终显示
        return this.ShowMessageBoxInternal(message, title, options)
    }
    
    ; ++++ 延迟显示成功消息（受配置控制，带置顶处理） ++++
    static ShowSuccessDelayed(message, delay := 100) {
        if (SettingsManager.GetBool("ShowSuccessMsg", true)) {
            SetTimer(() => this.ShowMessageBoxInternal(message), -delay)
        }
    }
    
    ; ++++ 内部方法：带置顶处理的消息框 ++++
    static ShowMessageBoxInternal(message, title := "", options := "") {
        ; 先取消主窗口置顶
        try {
            WinSetAlwaysOnTop(false, "A")
        }
        
        ; 显示消息框
        result := MsgBox(message, title, options)
        
        ; 恢复主窗口置顶
        try {
            WinSetAlwaysOnTop(true, "A")
        }
        
        return result
    }
    
    ; ++++ 检查是否为成功消息 ++++
    static IsSuccessMessage(message) {
        successKeywords := ["成功", "完成", "导出成功", "导入成功", "追加成功", "保存成功", "添加成功", "覆盖成功", "添加", "保存", "导出", "导入", "追加"]
        
        for keyword in successKeywords {
            if (InStr(message, keyword)) {
                return true
            }
        }
        return false
    }
    
    ; ++++ 检查是否为错误消息 ++++
    static IsErrorMessage(message) {
        errorKeywords := ["错误", "失败", "出错", "异常", "无效", "不存在", "无法", "不能", "未找到", "不支持"]
        
        for keyword in errorKeywords {
            if (InStr(message, keyword)) {
                return true
            }
        }
        return false
    }
    
    ; ++++ 检查是否为警告消息 ++++
    static IsWarningMessage(message) {
        warningKeywords := ["警告", "注意", "提示", "确认", "是否", "覆盖", "删除"]
        
        for keyword in warningKeywords {
            if (InStr(message, keyword)) {
                return true
            }
        }
        return false
    }
    
    ; ++++ 智能显示消息（自动判断类型） ++++
    static ShowSmartMessage(message, title := "", options := "") {
        ; 智能判断消息类型
        if (options = "YesNo") {
            ; 确认对话框
            return this.ShowConfirm(message, title, options)
        } else if (this.IsErrorMessage(message)) {
            ; 错误消息
            return this.ShowError(message, title, options)
        } else if (this.IsWarningMessage(message)) {
            ; 警告消息
            return this.ShowWarning(message, title, options)
        } else if (this.IsSuccessMessage(message)) {
            ; 成功消息
            return this.ShowSuccess(message, title, options)
        } else {
            ; 其他消息按成功消息处理
            return this.ShowSuccess(message, title, options)
        }
    }
}