# GCL 0.3.0 平台与验证范围

| 平台 | 下载 | 启动器运行时 | 当前功能 | 验证情况 |
| --- | --- | --- | --- | --- |
| macOS 13+，Apple Silicon / Intel | DMG、ZIP、macOS JAR | 原生 SwiftUI；Mac JAR 入口另需 Java 8+ | 原有资源、实例、模组、皮肤与联机功能；正式版列表扩展为 1.7+ 与 26.x | 通用编译、签名、包校验；原生侧栏与工具栏已在本机打开检查 |
| Windows x64 | 自带 Java 的 ZIP，解压运行 Start-GCL.cmd | 包内 Temurin 17 | 原版 / Fabric / Quilt、Java 准备、独立实例、模组搜索下载与启停、窗口/内存、日志 | 核心隔离测试及 Windows GitHub runner 的编译、核心测试、窗口构造/退出检查通过；尚未完成实际进入世界 |
| Linux x64 桌面 | 自带 Java 的 tar.gz，解压运行 ./start-gcl.sh | 包内 Temurin 17 | 同 Windows；需要正常的桌面、显示服务和图形驱动 | Ubuntu GitHub runner 编译、核心测试与 Xvfb 窗口构造/退出检查通过；尚未进入世界，发行版桌面和显卡差异仍可能影响运行 |
| iOS / iPadOS 14+，ARM64 | 侧载 IPA | iOS 专用 OpenJDK 8/17/21/25 + 图形适配 | GCL 原生首页与底层版本/实例、加载器、模组包和触控流程 | ARM64 原生及 Java 编译、完整包内容、签名校验；尚未在真实 iPhone/iPad 上安装、启用 JIT 或进入世界 |

Apple 版使用 Apple 自己的 Liquid Glass API：macOS 26+ 的 `glassEffect`、系统分栏、工具栏与玻璃按钮；iOS 26+ 首页使用 `UIGlassEffect`。旧 Apple 系统回退系统材质。没有用彩色渐变、边缘描线和光晕模拟 Apple 玻璃。Windows / Linux 使用系统桌面控件，不声称调用 Apple Liquid Glass。

GCL 是独立项目，但不声称所有底层都是从零开发。iOS JVM / 图形与触控引擎采用固定版本的 Amethyst / Pojav 系开源组件。源码、固定提交、GCL 界面覆盖文件、第三方署名及运行时许可证均保留。

## Minecraft 版本

Mac / Java 桌面版从 Mojang 正式版列表中显示 1.7 及之后的 `1.x` 版本，以及新的 `26.x` 正式版编号，新增旧版 Java 8 默认值、`minecraftArguments`、旧资源目录映射与离线 UUID 修正。已核对 1.7.10、1.12.2、1.20.1 和 26.3 官方元数据；不等于这些版本都完成实际游戏测试。不列出快照或预发布版本；26.x 按官方元数据准备 Java，缺省为 Java 25。

旧版 LWJGL 和原生库可能只支持 x86；Apple Silicon 的旧版本会选择 x64 Java，需要系统已安装 Rosetta 2；原生库或图形兼容性仍可能导致无法运行。Windows / Linux 本次打包为 x64，不是 ARM64 包。原版列表范围扩大也不代表任意 Forge、NeoForge 或整合包兼容。Windows / Linux 暂不提供 Forge / NeoForge 安装、mrpack 导入、陶瓦联机和本地皮肤功能，Mac 原有功能保留。iOS 功能由专用引擎决定，不与桌面版宣称完全一致。

## iOS 安装与限制

1. 下载 `GCL-0.3.0-iOS.ipa`，通过支持的侧载工具按其官方流程重新签名安装。它是临时签名的开发包，不能从 Safari 点击直接安装，也没有上架 App Store。
2. 按实际系统、签名方式与工具支持情况启用 JIT，并处理相应的内存权限。只有写入 entitlement 不代表设备已经允许 JIT；签名工具也可能移除某些权限。
3. 打开 GCL，在版本/实例中建立配置，选择匹配的 Java 与渲染器。设备内存、JIT、图形驱动和游戏/模组组合决定能否运行，不能保证“大多数 iPad”直接可玩。
4. 在游戏运行前，先验证最简单的原版配置，再尝试整合包。当前没有完成任何 iOS 真机验证，不提供“所有版本可玩”承诺。

原生玻璃需要 iOS 26 / iPadOS 26。低版本即使可以安装，也只会显示系统模糊材质。

iOS 引擎来源：https://github.com/AngelAuraMC/Amethyst-iOS
底层安装与 JIT 条件：https://wiki.angelauramc.dev/wiki/getting_started/INSTALL

## 构建

- Mac：`bash scripts/package.sh /绝对路径/输出目录`
- Java 桌面：JDK 17，`bash scripts/build-desktop.sh /绝对路径/输出目录`；`bash scripts/test-desktop.sh`。`scripts/bundle-desktop.py` 用官方校验和验证 Temurin 运行时并生成 Windows / Linux 自包含包。
- iOS：macOS、Xcode、CMake、Python 3、完整 JDK 8。设置 `GCL_JDK8_HOME`，运行 `bash scripts/build-ios.sh /绝对路径/输出目录`。脚本只修改 `ios/build` 的构建副本，保留固定引擎提交；核对 `ios/runtime-lock.json` 后再打包。发布的 IPA 内含 `GCL-LICENSES`。

所有平台仍是开发预览。没有 Microsoft 登录集成；本地账号不能进入 Realms 或要求正版验证的服务器。

Windows / Ubuntu 验证记录（2026-10-26）：https://github.com/Aaron-CNSD/GCL/actions/runs/40310336573 。两个系统均通过核心测试、构建和 GUI 窗口构造/退出检查；它不是游戏进入世界测试。
