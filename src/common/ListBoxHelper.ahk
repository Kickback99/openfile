; ============================================================
; ListBoxHelper.ahk
; ListBox控件工具类（处理单选/多选、文本获取等）
; ============================================================
class ListBoxHelper {

    ; 获取选中的文本数组（正确处理多选模式）
    static GetSelectedTexts(listBox) {
        try {
            textValue := listBox.Text
            
            if (Type(textValue) = "Array") {
                ; 多选模式：返回数组
                return textValue
            } else if (textValue != "") {
                ; 单选模式：返回包含单个字符串的数组
                return [textValue]
            } else {
                ; 没有选中
                return []
            }
        } catch {
            ; 出错时返回空数组
            return []
        }
    }

    ; 获取选中的索引数组（正确处理多选模式）
    static GetSelectedIndices(listBox) {
        try {
            value := listBox.Value
            
            if (Type(value) = "Array") {
                ; 多选模式：返回数组
                return value
            } else if (value > 0) {
                ; 单选模式：返回包含单个数字的数组
                return [value]
            } else {
                ; 没有选中
                return []
            }
        } catch {
            ; 出错时返回空数组
            return []
        }
    }

    ; 列表项数
    static GetItemCount(listBox) {
        return SendMessage(0x018B, 0, 0, , listBox.Hwnd)  ; LB_GETCOUNT
    }

    ; 选中项的首尾索引，没选中时都返回 0
    static GetSelectionRange(listBox) {
        indices := this.GetSelectedIndices(listBox)
        if (indices.Length = 0)
            return Map("first", 0, "last", 0)

        first := indices[1], last := indices[1]
        for index in indices {
            if (index < first)
                first := index
            if (index > last)
                last := index
        }
        return Map("first", first, "last", last)
    }

    ; 上下键进入列表时该落在哪一项，direction: 1 向下 / -1 向上；返回 0 表示保持不动
    static GetArrowTargetIndex(listBox, direction) {
        total := this.GetItemCount(listBox)
        if (total <= 1)
            return 0

        indices := this.GetSelectedIndices(listBox)
        if (indices.Length = 0)
            return direction > 0 ? 1 : total

        range := this.GetSelectionRange(listBox)
        first := range["first"], last := range["last"]

        ; 只选中一项时到边界折返，多选时夹在边界上
        if (indices.Length = 1) {
            if (direction > 0)
                return last = total ? 1 : last + 1
            return first = 1 ? total : first - 1
        }
        if (direction > 0)
            return last = total ? last : last + 1
        return first = 1 ? first : first - 1
    }

    ; 获取 ListBox 的文本（处理单选和多选）
    static GetListBoxText(listBox) {
        try {
            textValue := listBox.Text
            
            if (Type(textValue) = "Array") {
                ; 多选模式：返回数组中的第一个文本
                if (textValue.Length > 0) {
                    return textValue[1]
                }
                return ""
            } else {
                ; 单选模式：直接返回字符串
                return textValue
            }
        } catch {
            return ""
        }
    }
}