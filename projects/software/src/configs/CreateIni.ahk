#SingleInstance Force

; folder := 'C:\Users\wz\Desktop\tools'

;创建软件配置文件
IniWrite('JJDown','software.ini','JJDown','name')
IniWrite('C:\Users\wz\Desktop\tools\software\[WPF]JJDown\JiJiDownForWPF.exe','software.ini','JJDown','path')  


IniWrite('CareUEyes','software.ini','CareUEyes','name')  
IniWrite('C:\Users\wz\Desktop\tools\software\CareUEyes.exe','software.ini','CareUEyes','path')  

;创建ai配置文件
IniWrite('Cherry-Studio','ai.ini','Cherry-Studio','name')
IniWrite('C:\Users\wz\Desktop\tools\ai\Cherry-Studio-1.6.7-x64-portable.exe','ai.ini','Cherry-Studio','path')  

IniWrite('cc-switch','ai.ini','cc-switch','name')
IniWrite('C:\Users\wz\Desktop\tools\ai\CC-Switch-v3.6.2-Windows-Portable\cc-switch.exe','ai.ini','cc-switch','path')



