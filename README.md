# GCL — GlassCraft Launcher

你的世界，由你定义。独立的 macOS 原生 Minecraft Java Edition 启动器项目，由 Aaron-CNSD 维护。

[下载 Release](https://github.com/Aaron-CNSD/GCL/releases) · [贡献者与致谢](CONTRIBUTORS.md) · [使用说明](docs/MACOS.md)

## 下载格式

| 文件 | 用途与要求 |
| --- | --- |
| `.dmg` | macOS 13+ 安装镜像，拖入 Applications |
| `.zip` | 同一个 Mac 原生应用的压缩包，支持 Apple Silicon / Intel |
| `.jar` | Java 8+ 的 **macOS 启动入口**，内含同一个原生应用；不是跨平台 Java 引擎，不支持 Windows / Linux |

三种格式运行同一个 GCL.app。应用临时签名，未经 Apple 公证；不用关闭系统安全保护。原生版无需预先安装 Java，首次游戏启动会下载运行时；JAR 入口本身需先有 Java。

## 功能

- 游戏版本、Java 与加载器管理；原版 / Forge / NeoForge / Fabric / Quilt。
- 软件内搜索下载模组、整合包和光影，导入 `.mrpack`。
- 本地 PNG 皮肤，通过按需下载 CustomSkinLoader 实现。
- 陶瓦房间式联机：系统授权安装组件后，创建房间、分享房间码、加入朋友。
- macOS 26+ 系统液态玻璃，旧系统半透明材质。

## 验证范围

开发预览，不保证任意版本可玩。既有版本已测试编译、下载接口、资源 / 皮肤配置、整合包导入和模拟房间 API；**完整进入世界、游戏内皮肤和真实跨网联机尚未验证**，Forge / NeoForge 完整安装亦未验证。CurseForge ZIP 暂不支持。iOS IPA 不在本项目发布范围。

由 GlassCraft 的 macOS 分支整理而来，沿用 `~/Library/Application Support/GlassCraft` 数据目录，避免升级丢失原有配置。本仓库不包含 Amethyst iOS 原生引擎。非 Mojang / Microsoft 官方产品。

## 构建

`bash scripts/package.sh /绝对路径/输出目录`。需要 macOS、Xcode 命令行工具和 JDK 17+（JAR 使用 Java 8 目标字节码）。构建器输出 ZIP、DMG、JAR 与 SHA256SUMS。许可 GPL-3.0，第三方组件遵循其各自许可。

独立项目首个开发版本为 **v0.1.0**。应用与 DMG 现使用 GCL 玻璃方块图标；JAR 文件在 Finder 中通常显示 Java 图标，运行后打开的 GCL.app 使用应用图标。
