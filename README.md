# LocalPaste

一个本地运行的 macOS 剪贴板历史应用，支持记录文本复制历史并快速回贴。

## 功能

- 自动监听系统剪贴板文本变化
- 保存历史记录（不限制条数，可按缓存时间策略自动清理）
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

## 打包 DMG

```bash
cd /Users/woody/workspace/local-paste
./scripts/package_dmg.sh
```

打包完成后输出文件：

- `dist/LocalPaste.dmg`

默认会构建通用二进制（`arm64 + x86_64`），可同时支持 Apple 芯片和 Intel Mac。

如需仅构建单架构：

```bash
BUILD_ARCHS="arm64" ./scripts/package_dmg.sh
BUILD_ARCHS="x86_64" ./scripts/package_dmg.sh
```

### 出现“文件已损坏”时

这是 macOS Gatekeeper 对未公证包的常见拦截提示。

本机测试可先执行：

```bash
xattr -dr com.apple.quarantine /Users/woody/workspace/local-paste/dist/LocalPaste.app
xattr -dr com.apple.quarantine /Users/woody/workspace/local-paste/dist/LocalPaste.dmg
```

### 对外分发建议（Developer ID）

打包 App 时指定签名证书：

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/package_dmg.sh
```

可选：给 DMG 也签名：

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
DMG_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./scripts/package_dmg.sh
```

### 其他 Mac 可直接安装（推荐发布流程）

要避免“已损坏/无法验证开发者”，需要 **Developer ID 签名 + Apple 公证（Notarization）**。

先在本机保存 notary 凭据（仅首次）：

```bash
xcrun notarytool store-credentials "localpaste-notary" \
  --apple-id "<your-apple-id>" \
  --team-id "<your-team-id>" \
  --password "<app-specific-password>"
```

然后执行发布打包：

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
DMG_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARIZE=1 \
NOTARY_PROFILE="localpaste-notary" \
./scripts/package_dmg.sh
```

发布前可验证（可选）：

```bash
spctl -a -vvv dist/LocalPaste.app
spctl -a -vvv -t open dist/LocalPaste.dmg
```

## 在 Xcode 打开

```bash
open Package.swift
```

## 组件预览

- 可视模块说明与预览入口见：`docs/VISUAL_MODULES.md`
- 在 Xcode 中打开对应视图文件后，使用 Canvas 查看 `#Preview` 场景

首次运行时建议把应用加入登录项（系统设置 -> 通用 -> 登录项），方便开机自动使用。
