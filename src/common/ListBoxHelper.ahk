; ==============================
; ListBoxHelper.ahk
; ListBox控件工具类（处理单选/多选、文本获取等）
; ==============================
class ListBoxHelper {

    ; >>> 新增：获取选中的文本数组（正确处理多选模式）
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
    
    ; >>> 新增：获取选中的索引数组（正确处理多选模式）
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
    
    ; >>> 新增：获取ListBox的文本（处理单选和多选）
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