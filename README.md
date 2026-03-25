# LocalPaste

一个本地运行的 macOS 剪贴板历史应用，支持记录文本复制历史并快速回贴。

## 功能

- 自动监听系统剪贴板文本变化
- 保存历史记录（默认最多 200 条）
- 点击历史项可重新复制到剪贴板
- 支持搜索、删除单条、清空全部
- 菜单栏快速访问最近历史
- 记录持久化到本地：`~/Library/Application Support/LocalPaste/history.json`
- 支持自定义全局快捷键，快速唤起历史窗口
- 支持复制历史 TXT 导入/导出

## 运行（开发模式）

```bash
cd /Users/woody/workspace/local-paste
swift run
```

说明：`swift run` 启动的是命令行进程，不是标准 `.app` 包，可能出现类似 `missing main bundle identifier` 的系统日志。

## 运行（推荐）

```bash
cd /Users/woody/workspace/local-paste
./scripts/package_app.sh
open ./dist/LocalPaste.app
```

推荐从 `dist/LocalPaste.app` 启动，这样有完整 `Bundle Identifier`，系统集成更稳定。

## 在 Xcode 打开

```bash
open Package.swift
```

首次运行时建议把应用加入登录项（系统设置 -> 通用 -> 登录项），方便开机自动使用。
