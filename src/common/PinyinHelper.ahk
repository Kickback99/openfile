#Include "../../lib/py-master/lib/py.ahk"
; ==============================
; PinyinHelper.ahk
; 中文拼音处理工具类
; ==============================
class PinyinHelper {
    ; 检查字符串是否包含中文
    static HasChinese(str) {
        ; 简单的中文Unicode范围检查
        Loop Parse, str {
            charCode := Ord(A_LoopField)
            ; 中文字符的Unicode范围（基本汉字：0x4E00-0x9FFF）
            if (charCode >= 0x4E00 && charCode <= 0x9FFF) {
                return true
            }
        }
        return false
    }

    ; 判断输入是否像拼音
    static LooksLikePinyin(str) {
        ; 简单判断：如果只包含字母，看起来像拼音
        if (RegExMatch(str, "^[a-z]+$")) {
            return true
        }
        
        ; 或者包含数字（拼音声调），也认为是拼音
        if (RegExMatch(str, "^[a-z0-9]+$")) {
            return true
        }
        
        return false
    }

    ; 获取拼音匹配分数
    static GetPinyinMatchScore(chineseName, searchText) {
        try {

            ; 添加错误处理
            if (!chineseName || chineseName == "") {
                return 0
            }
            
            ; 检查DLL是否正常工作
            fullPinyin := py.allspell_muti(chineseName)
            if (fullPinyin == "") {
                return 0 ; DLL未加载或出错
            }

            ; 获取拼音全拼，去掉竖线分隔符，转小写
            fullPinyin := StrReplace(py.allspell_muti(chineseName), "|", "")
            fullPinyinLower := StrLower(fullPinyin)
            
            ; 获取拼音首字母，去掉竖线分隔符，转小写
            initials := StrReplace(py.initials_muti(chineseName), "|", "")
            initialsLower := StrLower(initials)
            
            ; 检查是否匹配全拼或首字母
            searchTextLower := StrLower(searchText)
            
            if (InStr(fullPinyinLower, searchTextLower)) {
                return 0.9  ; 全拼匹配分数
            }
            
            if (InStr(initialsLower, searchTextLower)) {
                return 0.7  ; 首字母匹配分数
            }
        } catch {
            return 0
        }
        
        return 0
    }
}