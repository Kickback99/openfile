; ==============================
; PathUtils.ahk
; 文件路径处理工具类
; ==============================
class PathUtils {
    ; 静态方法：运行程序（包含所有验证和处理逻辑）
    static RunProgram(filePath, guiObj := "") {
        ; 检查文件是否存在
        if (!FileExist(filePath)) {
            return "文件不存在或路径错误:`n`n" filePath
        }
        
        try {
            Run(filePath)
            return true
        } catch as e {
            return "打开失败: " e.Message
        }
    }
    
    ; 静态方法：在资源管理器中定位文件
    static LocateFile(filePath) {
        if (filePath = "") {
            return false
        }
        
        if (FileExist(filePath)) {
            try {
                Run('explorer.exe /select,"' filePath '"')
                return true
            } catch {
                ; 如果 /select 失败，尝试打开所在目录
                SplitPath(filePath, , &fileDir)
                if (fileDir != "") {
                    try {
                        Run('explorer.exe "' fileDir '"')
                        return true
                    } catch {
                        return false
                    }
                }
                return false
            }
        } else {
            ; 文件不存在，尝试打开所在目录
            SplitPath(filePath, , &fileDir)
            if (fileDir != "") {
                try {
                    Run('explorer.exe "' fileDir '"')
                    return true
                } catch {
                    return false
                }
            }
            return false
        }
    }
    
    ; 静态方法：定位根目录
    static LocateRootPath(rootPath) {
        if (rootPath != "" && DirExist(rootPath)) {
            try {
                Run('explorer.exe "' rootPath '"')
                return true
            } catch {
                return false
            }
        }
        return false
    }
    
    ; 静态方法：打开此电脑
    static OpenThisPC() {
        try {
            Run("explorer.exe shell:MyComputerFolder")
            return true
        } catch {
            try {
                Run("explorer.exe")
                return true
            } catch {
                return false
            }
        }
    }
    
    ; 静态方法：浏览选择文件
    static BrowseForExecutable(currentPath := "") {
        selectedFile := FileSelect(1, currentPath, "选择可执行文件", "可执行文件 (*.exe; *.bat; *.cmd)")
        return selectedFile
    }
    
    ; 静态方法：检查文件是否存在并返回结果
    static CheckFileExists(filePath) {
        return FileExist(filePath)
    }
    
    ; 静态方法：获取文件所在目录
    static GetFileDirectory(filePath) {
        SplitPath(filePath, , &dir)
        return dir
    }
    
    ; 静态方法：智能定位（根据路径选择最优方式）
    static SmartLocate(filePath, rootPath := "") {
        if (filePath != "") {
            return this.LocateFile(filePath)
        }
        
        if (rootPath != "") {
            return this.LocateRootPath(rootPath) || this.OpenThisPC()
        }
        
        return this.OpenThisPC()
    }
}