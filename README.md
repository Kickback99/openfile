# OpenFile

**一个基于 AutoHotkey v2 的 Windows 文件列表管理器。**

<div align="center">

<p>
  <a href="https://github.com/Kickback99/openfile/stargazers">
    <img src="https://img.shields.io/github/stars/Kickback99/openfile?style=for-the-badge&logo=github&labelColor=1f2328&color=181717" alt="Stars">
  </a>
  <a href="https://github.com/Kickback99/openfile/network/members">
    <img src="https://img.shields.io/github/forks/Kickback99/openfile?style=for-the-badge&logo=github&labelColor=1f2328&color=181717" alt="Forks">
  </a>
  <a href="https://github.com/Kickback99/openfile/releases/tag/v1.0.0">
    <img src="https://img.shields.io/badge/Version-v1.0.0-2ea44f?style=for-the-badge" alt="Version">
  </a>
  <img src="https://img.shields.io/badge/Platform-Windows-0078d4?style=for-the-badge&logo=windows&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/AutoHotkey-v2-0E7B42?style=for-the-badge" alt="AutoHotkey">
  <a href="https://github.com/sponsors/Kickback99">
    <img src="https://img.shields.io/badge/Sponsor-GitHub-ec4a89?style=for-the-badge" alt="Sponsor">
  </a>
</p>

</div>

## 项目简介

OpenFile 是一个基于 AutoHotkey v2 的 GUI 文件管理工具，支持多实例、独立 INI 配置、文件拖放、智能搜索等功能。

每个配置类型对应一个独立的文件列表和 INI 配置（默认 `openfile`，也可自建 `ai`、`dev` 等），通过全局热键随时唤起，适合把常用文件、脚本和工具收在一起快速启动。

项目分 **lite** 与 **complete** 两个版本：lite 功能精简，complete 提供完整功能，额外包含右键菜单（批量移动等）。

## 核心特性

- **多实例管理**：每个配置类型独立窗口、独立 INI（如 `openfile` / `ai` / `dev`）
- **全局热键**：`Win+Q` 唤起或最小化，`Alt+C` 按类型打开
- **智能搜索**：支持中文拼音与关键字过滤
- **文件拖放**：拖入文件即加入列表
- **批量创建**：从资源管理器批量创建条目
- **导入 / 导出 / 追加**：配置在类型之间流转
- **设置对话框**：配置类型管理、Root 路径修改、热键设置
- **托盘与自启**：托盘菜单入口，开机自启（Run 值路径漂移自动修复）
- **自托管字体**：内置 JetBrains Mono，不依赖系统安装

## 版本对比

| 功能 | lite | complete |
|---|---|---|
| 文件列表 / 搜索 / 拖放 | ✅ | ✅ |
| 导入 / 导出 / 追加 | ✅ | ✅ |
| 设置对话框 | ✅ | ✅ |
| 托盘菜单与开机自启 | ✅ | ✅ |
| 多实例独立配置 | — | ✅ |
| 跨实例批量复制移动文件 | — | ✅ |

> complete 的源码天然包含 lite 的内容，两个版本是分支隔离，不是代码互斥。

## 下载

前往 [Releases](https://github.com/Kickback99/openfile/releases/tag/v1.0.0) 下载 `v1.0.0`：

| 文件 | 说明 |
|---|---|
| `openfile-windows-complete-1.0.0.zip` | complete 版 exe，开箱即用 |
| `openfile-windows-lite-1.0.0.zip` | lite 版 exe |
| `openfile-ahk-complete-1.0.0.zip` | complete 版 AHK 源码 |
| `openfile-ahk-lite-1.0.0.zip` | lite 版 AHK 源码 |

exe 包是扁平结构，解压后直接运行 `OpenFile.exe`。

## 快速开始

### 使用 exe

1. 下载对应版本的 Windows 包并解压
2. 运行 `OpenFile.exe`
3. 按 `Win+Q` 唤起文件列表

### 运行源码

1. 安装 [AutoHotkey v2](https://www.autohotkey.com/)
2. 下载对应版本的 AHK 源码包并解压
3. 双击 `main.ahk`

## 热键

| 热键 | 作用 |
|---|---|
| `Win+Q` | 显示或最小化当前配置类型的窗口 |
| `Alt+C` | 输入配置类型名称并打开对应窗口 |

两个热键都可以在设置对话框中修改。

## 配置文件

源码运行时，配置写在 `main.ahk` 同目录的 `settings.ini`；exe 版写在用户目录的 `OpenFile\settings.ini`。配置版本变化时按版本标记重置设置。

## 目录结构

```
openfile/
├── main.ahk                  # 入口：热键、单实例、托盘、自启
├── src/
│   ├── ConfigManager.ahk     # INI 配置读写与配置类型管理
│   ├── GuiManager.ahk        # 主窗口与列表
│   ├── assets/fonts/         # JetBrains Mono
│   └── common/               # 设置、导入导出、拼音、消息框等
└── lib/py-master/            # 拼音 DLL 与 py.ahk
```

## 联系作者

如果你有任何问题或建议，请加我 vx：chk17805

## 许可声明

> 本项目仅限学习交流，可自由使用、修改、分发，需保留署名并以相同协议开源；不可商用或闭源分发。
