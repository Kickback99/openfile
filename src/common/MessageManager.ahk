; ==============================
; MessageManager.ahk
; 消息管理工具类（统一控制消息显示，带图标标识）
; ==============================
class MessageManager {
    ; 消息类型常量
    static TYPE_SUCCESS := "success"
    static TYPE_ERROR := "error"
    static TYPE_WARNING := "warning"
    static TYPE_INFO := "info"
    static TYPE_CONFIRM := "confirm"
    
    ; 图标类型常量
    static ICON_NONE := 0        ; 无图标
    static ICON_STOP := 16       ; 停止/错误图标 (0x10)
    static ICON_QUESTION := 32   ; 问号图标 (0x20)
    static ICON_EXCLAMATION := 48 ; 惊叹号图标 (0x30)
    static ICON_ASTERISK := 64   ; 星号/信息图标 (0x40)
    
    ; 主窗口句柄（用于智能判断）
    static MainWindowHwnd := 0
    
    ; t_openfile_settings：showSuccessMsg-get-multi
    ; 设置主窗口句柄（在GuiManager初始化时调用）
    static SetMainWindowHwnd(hwnd) {
        this.MainWindowHwnd := hwnd
    }
    
    ; 智能获取所有者窗口句柄
    static GetOwnerHwnd(ownerHwnd := 0) {

        ;检查AlwaysOnTop配置
        ; t_openfile_settings：alwaysOnTop-get
        if (!SettingsManager.GetBool("AlwaysOnTop")) {
            return 0  ; AlwaysOnTop为false，不使用Owner
        }

        ; 1. 如果调用方明确指定了ownerHwnd，使用指定的
        if (ownerHwnd != 0) {
            return ownerHwnd
        }
        
        ; 2. 如果设置了主窗口句柄，使用主窗口
        if (this.MainWindowHwnd != 0) {
            return this.MainWindowHwnd
        }
        
        ; 3. 否则返回0（表示无Owner）
        return 0
    }
    
    ; 显示消息框（智能选择所有者窗口-带图标标识和置顶处理）
    static ShowMessageBox(message, title := "", options := "", icon := 0, ownerHwnd := 0) {
        ; 获取智能判断的所有者窗口
        actualOwner := this.GetOwnerHwnd(ownerHwnd)
        
        ; 合并图标选项
        finalOptions := this.BuildOptions(options, icon)
        
        ; 添加Owner参数（如果获取到有效的所有者窗口）
        if (actualOwner != 0) {
            finalOptions := "Owner" . actualOwner . " " . finalOptions
        }
        
        ; 根据消息类型和配置决定是否显示
        local result := ""
        
        ; 检查消息类型
        if (this.IsConfirmMessage(options)) {
            ; 确认消息始终显示（默认使用问号图标）
            if (icon = 0) {
                finalOptions := this.BuildOptions(options, this.ICON_QUESTION)
                if (actualOwner != 0) {
                    finalOptions := "Owner" . actualOwner . " " . finalOptions
                }
            }
            result := MsgBox(message, title, finalOptions)
        } else if (this.IsErrorMessage(message)) {
            ; 错误消息始终显示（默认使用停止图标）
            if (icon = 0) {
                finalOptions := this.BuildOptions(options, this.ICON_STOP)
                if (actualOwner != 0) {
                    finalOptions := "Owner" . actualOwner . " " . finalOptions
                }
            }
            result := MsgBox(message, title, finalOptions)
        } else if (this.IsWarningMessage(message)) {
            ; 警告消息始终显示（默认使用惊叹号图标）
            if (icon = 0) {
                finalOptions := this.BuildOptions(options, this.ICON_EXCLAMATION)
                if (actualOwner != 0) {
                    finalOptions := "Owner" . actualOwner . " " . finalOptions
                }
            }
            result := MsgBox(message, title, finalOptions)
        } else if (this.IsSuccessMessage(message)) {
            ; 成功消息受配置控制（默认使用信息图标）
            if (SettingsManager.GetBool("ShowSuccessMsg")) {
                if (icon = 0) {
                    finalOptions := this.BuildOptions(options, this.ICON_ASTERISK)
                    if (actualOwner != 0) {
                        finalOptions := "Owner" . actualOwner . " " . finalOptions
                    }
                }
                result := MsgBox(message, title, finalOptions)
            } else {
                ; 不显示成功消息，直接返回默认值
                result := "OK"
            }
        } else {
            ; 其他消息按信息消息处理（默认使用信息图标）
            if (SettingsManager.GetBool("ShowSuccessMsg")) {
                if (icon = 0) {
                    finalOptions := this.BuildOptions(options, this.ICON_ASTERISK)
                    if (actualOwner != 0) {
                        finalOptions := "Owner" . actualOwner . " " . finalOptions
                    }
                }
                result := MsgBox(message, title, finalOptions)
            } else {
                result := "OK"
            }
        }
        
        return result
    }
    
    ; 显示成功消息（智能选择所有者窗口-受配置控制）
    static ShowSuccess(message, title := "", options := "OK", ownerHwnd := 0) {
        ; 检查是否显示成功消息
        if (!SettingsManager.GetBool("ShowSuccessMsg")) {
            return "OK"  ; 配置为false，不显示成功消息
        }
        
        ; 显示成功消息（带信息图标，智能选择所有者）
        return this.ShowMessageBoxInternal(message, title, options, this.ICON_ASTERISK, ownerHwnd)
    }
    
    ; 显示错误消息（智能选择所有者窗口-始终显示）
    static ShowError(message, title := "", options := "OK", ownerHwnd := 0) {
        ; 错误消息始终显示（带停止图标，智能选择所有者）
        return this.ShowMessageBoxInternal(message, title, options, this.ICON_STOP, ownerHwnd)
    }
    
    ; 显示确认消息（智能选择所有者窗口-始终显示）
    static ShowConfirm(message, title := "", options := "YesNo", ownerHwnd := 0) {
        ; 确认消息始终显示（带问号图标，智能选择所有者）
        return this.ShowMessageBoxInternal(message, title, options, this.ICON_QUESTION, ownerHwnd)
    }
    
    ; 显示警告消息（智能选择所有者窗口-始终显示）
    static ShowWarning(message, title := "", options := "OK", ownerHwnd := 0) {
        ; 警告消息始终显示（带惊叹号图标，智能选择所有者）
        return this.ShowMessageBoxInternal(message, title, options, this.ICON_EXCLAMATION, ownerHwnd)
    }
    
    ; 显示信息消息（智能选择所有者窗口-受配置控制）
    static ShowInfo(message, title := "", options := "OK", ownerHwnd := 0) {
        ; 信息消息受配置控制
        return this.ShowSuccess(message, title, options, ownerHwnd)
    }
    
    ; 延迟显示成功消息（智能选择所有者窗口-受配置控制）
    static ShowSuccessDelayed(message, delay := 100, ownerHwnd := 0) {
        if (SettingsManager.GetBool("ShowSuccessMsg")) {
            SetTimer(() => this.ShowMessageBoxInternal(message, , "OK", this.ICON_ASTERISK, ownerHwnd), -delay)
        }
    }
    
    ; 延迟显示信息消息（智能选择所有者窗口-受配置控制）
    static ShowInfoDelayed(message, delay := 100, ownerHwnd := 0) {
        this.ShowSuccessDelayed(message, delay, ownerHwnd)
    }

    ; 内部方法：智能选择所有者的消息框（备选方法）
    ; 注意：此方法使用智能所有者判断，不处理置顶/取消置顶逻辑
    ; 主要用于内部调用，或需要精确控制选项的场景
    static ShowMessageBoxInternal(message, title := "", options := "", icon := 0, ownerHwnd := 0) {
        ; 获取智能判断的所有者窗口
        actualOwner := this.GetOwnerHwnd(ownerHwnd)
        
        ; 合并图标选项
        finalOptions := this.BuildOptions(options, icon)
        
        ; 添加Owner参数（如果获取到有效的所有者窗口）
        if (actualOwner != 0) {
            finalOptions := "Owner" . actualOwner . " " . finalOptions
        }
        
        ; 显示消息框
        result := MsgBox(message, title, finalOptions)
        
        return result
    }
    
    ; 构建选项字符串（合并按钮和图标选项）
    static BuildOptions(buttonOptions := "", icon := 0) {
        ; 如果已经包含图标选项，直接返回
        if (InStr(buttonOptions, "Icon")) {
            return buttonOptions
        }
        
        ; 添加图标选项
        switch icon {
            case this.ICON_STOP:        ; 16
                iconOption := " Iconx"
            case this.ICON_QUESTION:    ; 32
                iconOption := " Icon?"
            case this.ICON_EXCLAMATION: ; 48
                iconOption := " Icon!"
            case this.ICON_ASTERISK:    ; 64
                iconOption := " Iconi"
            default:
                iconOption := ""
        }
        
        return (buttonOptions != "" ? buttonOptions . " " : "") . iconOption
    }
    
    ; 检查是否为确认消息
    static IsConfirmMessage(options) {
        ; 检查选项是否包含确认按钮
        confirmKeywords := ["YesNo", "Y/N", "YN", "OKCancel", "O/C", "OC", "AbortRetryIgnore", "A/R/I", "ARI", "YesNoCancel", "Y/N/C", "YNC", "RetryCancel", "R/C", "RC", "CancelTryAgainContinue", "C/T/C", "CTC"]
        
        for keyword in confirmKeywords {
            if (InStr(options, keyword)) {
                return true
            }
        }
        return false
    }
    
    ; 检查是否为成功消息
    static IsSuccessMessage(message) {
        successKeywords := ["成功", "完成", "导出成功", "导入成功", "追加成功", "保存成功", "添加成功", "覆盖成功", "添加", "保存", "导出", "导入", "追加", "已添加", "已保存"]
        
        for keyword in successKeywords {
            if (InStr(message, keyword)) {
                return true
            }
        }
        return false
    }
    
    ; 检查是否为错误消息
    static IsErrorMessage(message) {
        errorKeywords := ["错误", "失败", "出错", "异常", "无效", "不存在", "无法", "不能", "未找到", "不支持", "失败", "出错", "错误"]
        
        for keyword in errorKeywords {
            if (InStr(message, keyword)) {
                return true
            }
        }
        return false
    }
    
    ; 检查是否为警告消息
    static IsWarningMessage(message) {
        warningKeywords := ["警告", "注意", "提示", "确认", "是否", "覆盖", "删除", "危险", "谨慎", "小心"]
        
        for keyword in warningKeywords {
            if (InStr(message, keyword)) {
                return true
            }
        }
        return false
    }
    
    ; 智能显示消息（自动判断类型和图标）
    static ShowSmartMessage(message, title := "", options := "") {
        ; 智能判断消息类型并显示对应图标
        if (this.IsConfirmMessage(options)) {
            ; 确认对话框
            return this.ShowConfirm(message, title, options)
        } else if (this.IsErrorMessage(message)) {
            ; 错误消息（带停止图标）
            return this.ShowError(message, title, options)
        } else if (this.IsWarningMessage(message)) {
            ; 警告消息（带惊叹号图标）
            return this.ShowWarning(message, title, options)
        } else if (this.IsSuccessMessage(message)) {
            ; 成功消息（带信息图标）
            return this.ShowSuccess(message, title, options)
        } else {
            ; 其他消息按信息消息处理
            return this.ShowSuccess(message, title, options)
        }
    }
    
    ; 自定义图标消息框
    static ShowCustom(message, title := "", options := "", icon := 0) {
        ; 完全自定义的消息框
        return this.ShowMessageBoxInternal(message, title, options, icon)
    }
    
    ; 显示带超时的消息框
    static ShowWithTimeout(message, title := "", options := "", timeout := 5) {
        ; 添加超时选项
        timeoutOption := " T" . timeout
        finalOptions := options . timeoutOption
        
        result := this.ShowMessageBoxInternal(message, title, finalOptions)
        
        ; 检查是否超时
        if (result = "Timeout") {
            ; 超时处理
            return "Timeout"
        }
        
        return result
    }
}