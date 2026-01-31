class py
{
    static DLL_USE_MAP := map("cpp2ahk.dll" , map("chinese_convert_pinyin_allspell_muti", 0, "chinese_convert_pinyin_initials_muti", 0, "chinese_convert_double_pinyin_muti", 0))
    static __New() => this.load_all_dll_path()
	static out_str_size := 2048000
    static tempDllPath := ""  ; 存储临时DLL路径，用于清理
    
    ;!!! 重构：最简化的加载逻辑
    static load_all_dll_path()
    {
        ; 先设置默认的lib路径（开发环境用）
        SplitPath(A_LineFile,,&dir)
        libPath := (A_PtrSize == 4) ? dir . "\dll_32\" : dir . "\dll_64\"
        
        ; 如果是编译版本，尝试从资源加载
        if (A_IsCompiled) {
            ; 优先从资源加载
            tempPath := this.LoadDllFromResource()
            if (tempPath != "") {
                libPath := tempPath  ; 使用临时文件路径
            }
        }
        
        ; 设置DLL搜索路径
        dllcall("SetDllDirectory", "Str", libPath)
        
        ; 加载DLL并获取函数地址
        for k,v in this.DLL_USE_MAP
        {
            for k1, v1 in v 
            {
                this.DLL_USE_MAP[k][k1] := DllCall("GetProcAddress", "Ptr", DllCall("LoadLibrary", "Str", k, "Ptr"), "AStr", k1, "Ptr")
            }
        }
        
        ; 恢复原始搜索路径
        dllcall("SetDllDirectory", "Str", A_ScriptDir)
    }
    
    ;!!! 简化：直接从资源加载DLL到临时文件
    ;!!! 修改：检查已有文件，避免重复写入
    static LoadDllFromResource() {
        ; 确定资源名称
        resourceName := (A_PtrSize == 4) ? "DLL32" : "DLL64"
        
        ; 检查临时目录是否已存在DLL文件
        tempDir := A_Temp "\openfile"
        tempFile := tempDir "\cpp2ahk.dll"
        
        ; 如果文件已存在且有效，直接使用
        if (FileExist(tempFile)) {
            ; 验证文件大小是否正常（避免损坏的文件）
            try {
                fileSize := FileGetSize(tempFile)
                if (fileSize > 100000) {  ; DLL文件至少100KB
                    ; MsgBox("✅ 使用现有的DLL文件，大小: " fileSize " 字节")
                    this.tempDllPath := tempFile
                    return tempDir
                }
            }
        }
        
        ; 如果不存在或文件损坏，从资源创建
        if (buf := ResourceLoad(resourceName, 10)) {
            ; 确保目录存在
            DirCreate(tempDir)
            
            ; 写入DLL文件
            FileOpen(tempFile, "w").RawWrite(buf)
            
            ; 存储路径
            this.tempDllPath := tempFile
            
            ; 返回临时文件所在目录
            return tempDir
        }
        
        return ""
    }
    
    ; 原有的函数保持不变
    static double_spell_muti(in_str, out_str_size := this.out_str_size)
    {
	    out_str := Buffer(out_str_size, 0)
        DllCall(this.DLL_USE_MAP["cpp2ahk.dll"]["chinese_convert_double_pinyin_muti"], "Str", in_str, "ptr", out_str, "Cdecl Int")
        return StrGet(out_str, out_str_size, "UTF-8")
    }
    
    static allspell_muti(in_str, out_str_size := this.out_str_size)
    {
	    out_str := Buffer(out_str_size, 0)
        DllCall(this.DLL_USE_MAP["cpp2ahk.dll"]["chinese_convert_pinyin_allspell_muti"], "Str", in_str, "ptr", out_str, "Cdecl Int")
        return StrGet(out_str, out_str_size, "UTF-8")
    }
    
    static initials_muti(in_str, out_str_size := this.out_str_size)
    {
	    out_str := Buffer(out_str_size, 0)
        DllCall(this.DLL_USE_MAP["cpp2ahk.dll"]["chinese_convert_pinyin_initials_muti"], "Str", in_str, "ptr", out_str, "Cdecl Int")
        return StrGet(out_str, out_str_size, "UTF-8")
    }
    
    static strbuf(str, encoding)
    {
        buf := buffer(strput(str, encoding))
        strput(str, buf, encoding)
        return buf
    }
    
}